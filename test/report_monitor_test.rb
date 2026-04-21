require "test_helper"

class ReportMonitorTest < ApplicationTest
  Report = Struct.new(:id, :embed, :buttons)
  Bot = Struct.new(:servers)

  class FakeModerationReports
    attr_reader :calls

    def initialize(initial_reports:, new_reports:)
      @initial_reports = initial_reports
      @new_reports = new_reports
      @calls = []
    end

    def index(limit:, **params)
      @calls << { limit:, params: }
      result = params.empty? ? @initial_reports : @new_reports
      # Return an array that responds to #empty? and #sort_by
      Array(result)
    end
  end

  def test_monitor_reports_no_new_reports
    monitor = setup_monitor(new_reports: [])
    monitor.last_report_id = 25

    monitor.send(:monitor_reports)

    assert_empty monitor.instance_variable_get(:@report_channel).messages
    assert_empty monitor.instance_variable_get(:@report_channel).embeds
  end

  def test_monitor_reports_sends_reports_sorted_by_id_and_updates_last_report_id
    report12 = Report.new(12, :embed12, [:buttons12])
    report15 = Report.new(15, :embed15, [:buttons15])
    monitor = setup_monitor(new_reports: [report15, report12])
    monitor.last_report_id = 10

    monitor.send(:monitor_reports)

    assert_equal 15, monitor.last_report_id
    channel = monitor.instance_variable_get(:@report_channel)
    assert_equal ["", ""], channel.messages
    assert_equal %i[embed12 embed15], channel.embeds
  end

  def test_start_sets_last_report_id_and_logs_startup_message
    initial_report = Report.new(42, nil, nil)
    moderation_reports = FakeModerationReports.new(initial_reports: [initial_report], new_reports: [])
    booru = Struct.new(:moderation_reports).new(moderation_reports)
    report_channel = CHANNEL_MOCK.new(name: "user-reports")
    logger = Minitest::Mock.new
    logger.expect(:info, nil, ["Starting to monitor for new user reports..."])

    monitor = Fumimi::ReportMonitor.new(bot: bot_with_channels(report_channel), booru:, log: logger)

    Thread.stub(:new, ->(*_args, &_block) { :thread }) do
      monitor.start
    end

    assert_equal 42, monitor.last_report_id
    assert_equal({ limit: 1, params: {} }, moderation_reports.calls.first)
    logger.verify
  end

  def test_send_report_truncates_overlong_reason_field
    monitor = setup_monitor
    report = moderation_report(id: 77, model_type: "Post", model_id: 123, reason: "a" * 1200)

    monitor.send(:send_report, report)

    reason_field = monitor.instance_variable_get(:@report_channel).embeds.first.fields.find do |field|
      field.name == "Reason"
    end
    assert reason_field
    assert_equal 1000, reason_field.value.length
    assert reason_field.value.end_with?("[…]")
  end

  def test_send_report_includes_reporter_and_reported_user_links
    monitor = setup_monitor
    report = moderation_report(
      id: 88,
      model_type: "Comment",
      model_id: 999,
      creator_id: 10,
      creator_name: "reporter_name",
      reported_user_id: 20,
      reported_user_name: "reported_name"
    )

    monitor.send(:send_report, report)

    fields = monitor.instance_variable_get(:@report_channel).embeds.first.fields
    reported_user_field = fields.find { |f| f.name == "Reported user" }
    reporter_field = fields.find { |f| f.name == "Reporter" }

    assert_equal "[@reported_name](https://danbooru.donmai.us/users/20)", reported_user_field.value
    assert_equal "[@reporter_name](https://danbooru.donmai.us/users/10)", reporter_field.value
  end

  def test_send_report_includes_reported_content_link_for_forum_posts
    monitor = setup_monitor
    report = moderation_report(id: 99, model_type: "ForumPost", model_id: 123)

    monitor.send(:send_report, report)

    reported_content_field = monitor.instance_variable_get(:@report_channel).embeds.first.fields.find do |field|
      field.name == "Reported Content"
    end
    assert_equal "[forum #123](https://danbooru.donmai.us/forum_posts/123)", reported_content_field.value
  end

  def test_send_report_includes_reported_content_link_for_comments
    monitor = setup_monitor
    report = moderation_report(id: 100, model_type: "Comment", model_id: 456)

    monitor.send(:send_report, report)

    reported_content_field = monitor.instance_variable_get(:@report_channel).embeds.first.fields.find do |field|
      field.name == "Reported Content"
    end
    assert_equal "[comment #456](https://danbooru.donmai.us/comments/456)", reported_content_field.value
  end

  private

  def setup_monitor(new_reports: nil)
    ENV["DISCORD_REPORT_CHANNEL_NAME"] = "user-reports"
    report_channel = CHANNEL_MOCK.new(name: "user-reports")
    moderation_reports = FakeModerationReports.new(initial_reports: [], new_reports: new_reports || [])
    booru = Struct.new(:moderation_reports).new(moderation_reports)
    monitor = Fumimi::ReportMonitor.new(bot: bot_with_channels(report_channel), booru:, log: Object.new)
    monitor.instance_variable_set(:@mutex, Mutex.new)
    monitor
  end

  def moderation_report(id:,
                        model_type:,
                        model_id:,
                        reason: "ok",
                        creator_id: 1,
                        creator_name: "reporter",
                        reported_user_id: 2,
                        reported_user_name: "reported_user")
    Fumimi::Model::ModerationReport.new(
      {
        "id" => id,
        "created_at" => "2026-04-20T00:00:00Z",
        "model_type" => model_type,
        "model_id" => model_id,
        "reason" => reason,
        "creator" => { "id" => creator_id, "name" => creator_name },
        "model" => { "creator" => { "id" => reported_user_id, "name" => reported_user_name } },
      },
      "moderation_report",
      Struct.new(:booru).new(Danbooru.new(log: log))
    )
  end

  def bot_with_channels(*channels)
    Bot.new({ 1 => SERVER_MOCK.new(channels) })
  end
end
