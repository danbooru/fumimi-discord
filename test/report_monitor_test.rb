require "test_helper"

class ReportMonitorTest < Minitest::Test
  include TestMocks

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
      params.empty? ? @initial_reports : @new_reports
    end
  end

  def test_monitor_reports_logs_when_no_new_reports
    report_channel = CHANNEL_MOCK.new(name: current_report_channel_name)
    moderation_reports = FakeModerationReports.new(initial_reports: [], new_reports: [])
    booru = Struct.new(:moderation_reports).new(moderation_reports)
    logger = Minitest::Mock.new
    logger.expect(:info, nil, ["Scanning for new danbooru reports since ID 25"])
    logger.expect(:info, nil, ["No new danbooru reports found."])

    monitor = Fumimi::ReportMonitor.new(bot: bot_with_channels(report_channel), booru:, log: logger)
    monitor.instance_variable_set(:@mutex, Mutex.new)
    monitor.last_report_id = 25

    monitor.send(:monitor_reports)

    assert_equal [], report_channel.messages
    assert_equal [], report_channel.embeds
    assert_equal({ limit: 20, params: { "search[id]": ">25" } }, moderation_reports.calls.last)
    logger.verify
  end

  def test_monitor_reports_sends_reports_sorted_by_id_and_updates_last_report_id
    report_channel = CHANNEL_MOCK.new(name: current_report_channel_name)
    report12 = Report.new(12, :embed12, [:buttons12])
    report15 = Report.new(15, :embed15, [:buttons15])
    moderation_reports = FakeModerationReports.new(initial_reports: [], new_reports: [report15, report12])
    booru = Struct.new(:moderation_reports).new(moderation_reports)
    logger = Minitest::Mock.new
    logger.expect(:info, nil, ["Scanning for new danbooru reports since ID 10"])
    logger.expect(:info, nil, ["New danbooru report: 12. Sending it to ##{current_report_channel_name}..."])
    logger.expect(:info, nil, ["New danbooru report: 15. Sending it to ##{current_report_channel_name}..."])

    monitor = Fumimi::ReportMonitor.new(bot: bot_with_channels(report_channel), booru:, log: logger)
    monitor.instance_variable_set(:@mutex, Mutex.new)
    monitor.last_report_id = 10

    monitor.send(:monitor_reports)

    assert_equal 15, monitor.last_report_id
    assert_equal ["", ""], report_channel.messages
    assert_equal %i[embed12 embed15], report_channel.embeds
    logger.verify
  end

  def test_start_sets_last_report_id_and_logs_startup_message
    report_channel = CHANNEL_MOCK.new(name: current_report_channel_name)
    initial_report = Report.new(42, nil, nil)
    moderation_reports = FakeModerationReports.new(initial_reports: [initial_report], new_reports: [])
    booru = Struct.new(:moderation_reports).new(moderation_reports)
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
    report_channel = CHANNEL_MOCK.new(name: current_report_channel_name)
    logger = Minitest::Mock.new
    logger.expect(:info, nil, ["New danbooru report: 77. Sending it to ##{current_report_channel_name}..."])

    monitor = Fumimi::ReportMonitor.new(bot: bot_with_channels(report_channel), booru: Object.new, log: logger)

    report = Fumimi::Model::ModerationReport.new(
      {
        "id" => 77,
        "created_at" => "2026-04-20T00:00:00Z",
        "model_type" => "Post",
        "model_id" => 123,
        "reason" => "a" * 1200,
        "creator" => { "id" => 1, "name" => "reporter" },
        "model" => { "creator" => { "id" => 2, "name" => "reported_user" } },
      },
      "moderation_report",
      Struct.new(:booru).new(Danbooru.new(log: log))
    )

    monitor.send(:send_report, report)

    reason_field = report_channel.embeds.first.fields.find { |field| field.name == "Reason" }
    assert reason_field
    assert_equal 1000, reason_field.value.length
    assert reason_field.value.end_with?("[…]")
    logger.verify
  end

  private

  def bot_with_channels(*channels)
    Bot.new({ 1 => SERVER_MOCK.new(channels) })
  end

  def with_report_channel_name(value)
    previous = ENV.fetch("DISCORD_REPORT_CHANNEL_NAME", nil)
    ENV["DISCORD_REPORT_CHANNEL_NAME"] = value
    yield
  ensure
    ENV["DISCORD_REPORT_CHANNEL_NAME"] = previous
  end

  def current_report_channel_name
    ENV.fetch("DISCORD_REPORT_CHANNEL_NAME", "user-reports")
  end
end
