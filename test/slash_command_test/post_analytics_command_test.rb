require "test_helper"

class PostAnalyticsCommandTest < ApplicationTest
  def test_api_call
    skip unless default_fumimi.signoz_api_key.present?

    user = user_mock(roles: [])
    mock_slash_command("/searches", args: { tags: "1girl", time_range: "30mi" }, user:) => { reply_embeds: }

    assert_equal 1, reply_embeds.length
    report = reply_embeds.first

    assert_match(/Unique users whose searches in the last 30 minutes included `1girl`:/, report.description)
    assert_equal "Post Analytics Report", report.title

    table_lines = table_lines_for(report)
    assert_equal ["Contains", "Users <30mi"], table_lines.first
    assert_equal ["1girl"], table_lines.second.first(1)
    assert_equal ["-1girl"], table_lines.third.first(1)
  end

  def test_rejects_range_over_max
    user = user_mock(roles: [])
    mock_slash_command("/searches", args: { tags: "1girl", time_range: "2d" }, user:) => { reply_embeds: }

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
    Fumimi::Report::PostAnalyticsReport.new(tags: tags, range: range, fumimi: default_fumimi)
  end

  def with_stubbed_client(report, data, &block)
    client = stub

    client.stubs(:unique_ips_in_range).returns({ unique_ips: [0], duration: 0 })
    data.each do |tag_set, ranges|
      ranges.each do |range, count|
        client.stubs(:unique_ips_in_range).with([tag_set], range).returns({ unique_ips: [count], duration: 0 })
      end
    end

    report.stubs(:client).returns(client)
    block.call
  end
end
