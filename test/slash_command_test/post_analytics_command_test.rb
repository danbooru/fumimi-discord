require "test_helper"

class PostAnalyticsCommandTest < Minitest::Test
  include TestMocks

  def test_api_call
    mock_slash_command("/searches", args: { tags: "1girl", time_range: "30mi" }) => { reply_embeds:, ** }

    assert_equal 1, reply_embeds.length
    report = reply_embeds.first

    assert_equal "Post Analytics Report", report.title
    assert_match(/Unique users whose searches in the last 30 minutes included `1girl`:/, report.description)

    table_lines = table_lines_for(report)
    assert_equal ["Contains", "Users <30mi"], table_lines.first
    assert_equal ["1girl"], table_lines.second.first(1)
    assert_equal ["-1girl"], table_lines.third.first(1)
  end

  def test_rejects_range_over_max
    mock_slash_command("/searches", args: { tags: "1girl", time_range: "2d" }) => { reply_embeds:, ** }

    assert_equal 1, reply_embeds.length
    assert_equal "Bad Argument!", reply_embeds.first.title
    assert_match(/not exceed/, reply_embeds.first.description)
  end

  def test_2h_single_tag_shows_tag_and_negated_rows
    report = build_report(tags: ["no_humans"], range: 2.hours)

    with_stubbed_client(report, ["no_humans"] => { 2.hours => 24, 1.hour => 20 },
                                ["-no_humans"] => { 2.hours => 1, 1.hour => 0 }) do
      lines = table_lines_for(report.embed)

      assert_equal ["Contains", "Users <2h", "Users <1h"], lines.first
      assert_equal %w[no_humans 24 20], lines.second
      assert_equal ["-no_humans", "1", "0"], lines.third
    end
  end

  def test_1h_single_tag_shows_tag_and_negated_rows
    report = build_report(tags: ["no_humans"], range: 1.hour)

    with_stubbed_client(report, ["no_humans"] => { 1.hour => 24 },
                                ["-no_humans"] => { 1.hour => 1 }) do
      lines = table_lines_for(report.embed)

      assert_equal ["Contains", "Users <1h"], lines.first
      assert_equal %w[no_humans 24], lines.second
      assert_equal ["-no_humans", "1"], lines.third
    end
  end

  def test_2h_multiple_tags_shows_only_tag_row
    report = build_report(tags: %w[1girl solo], range: 2.hours)

    with_stubbed_client(report, %w[1girl solo] => { 2.hours => 10, 1.hour => 5 }) do
      lines = table_lines_for(report.embed)

      assert_equal 2, lines.length # header + 1 data row, no negated row
    end
  end

  def test_30m_single_tag_shows_tag_and_negated_rows
    report = build_report(tags: ["no_humans"], range: 30.minutes)

    with_stubbed_client(report, ["no_humans"] => { 30.minutes => 5 },
                                ["-no_humans"] => { 30.minutes => 2 }) do
      lines = table_lines_for(report.embed)

      assert_equal 3, lines.length # header + 2 data rows
      assert_equal %w[no_humans 5], lines.second
      assert_equal ["-no_humans", "2"], lines.third
    end
  end

  def test_table_header_uses_short_range_format
    report = build_report(tags: ["no_humans"], range: 30.minutes)

    with_stubbed_client(report, ["no_humans"] => { 30.minutes => 5 },
                                ["-no_humans"] => { 30.minutes => 2 }) do
      assert_equal ["Contains", "Users <30mi"], table_lines_for(report.embed).first
    end
  end

  private

  def build_report(tags:, range:)
    Fumimi::PostAnalyticsReport.new(tags: tags, range: range, log: Logger.new(File::NULL), cache: Zache.new)
  end

  def with_stubbed_client(report, data, &block)
    client = Object.new
    client.define_singleton_method(:unique_ips_in_range) do |sets_of_tags, range|
      tag_set = sets_of_tags.first
      tag_data = data.find { |k, _| k == tag_set }&.last || {}
      count = tag_data.find { |k, _| k == range }&.last || 0
      { unique_ips: [count], duration: 0 }
    end
    report.stub(:client, client, &block)
  end
end
