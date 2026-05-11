require "test_helper"

class PostAnalyticsCommandTest < ApplicationTest
  def test_api_call
    skip unless default_fumimi.signoz_api_key.present?

    user = user_mock(roles: [])
    mock_slash_command("/searches", args: { tags: "1girl", time_range: "30mi" }, user:) => { reply_embeds: }

    assert_equal 1, reply_embeds.length
    report = reply_embeds.first

    assert_equal "Searches for 1girl", report.title

    table_lines = table_lines_for(report)
    assert_equal %w[Contains Users], table_lines.first
    assert_equal ["1girl"], table_lines.second.first(1)
  end

  def test_invalid_range
    user = user_mock(roles: [])
    mock_slash_command("/searches", args: { tags: "1girl", time_range: "invalid" }, user:) => { reply_embeds: }

    assert_equal 1, reply_embeds.length
    assert_equal "Bad Argument!", reply_embeds.first.title
    assert_match(/invalid range format/i, reply_embeds.first.description)
  end

  def test_2h_single_tag_shows_tag
    since = 2.hours
    report = build_report(tags: ["no_humans"], since:)

    with_stubbed_client(report, ["no_humans"] => { since => 24 }) do
      lines = table_lines_for(report.embed)

      assert_equal %w[Contains Users], lines.first
      assert_equal %w[no_humans 24], lines.second
    end
  end

  def test_1h_single_tag_shows_tag
    since = 1.hour
    report = build_report(tags: ["no_humans"], since:)

    with_stubbed_client(report, ["no_humans"] => { since => 24 }) do
      lines = table_lines_for(report.embed)

      assert_equal %w[Contains Users], lines.first
      assert_equal %w[no_humans 24], lines.second
    end
  end

  def test_2h_multiple_tags_shows_only_tag_row
    since = 2.hours
    report = build_report(tags: %w[1girl solo], since:)

    with_stubbed_client(report, %w[1girl solo] => { since => 10 }) do
      lines = table_lines_for(report.embed)

      assert_equal 2, lines.length
    end
  end

  def test_30m_single_tag_shows_tag
    since = 30.minutes
    report = build_report(tags: ["no_humans"], since:)

    with_stubbed_client(report, ["no_humans"] => { since => 5 }) do
      lines = table_lines_for(report.embed)

      assert_equal 2, lines.length # header + 1 data row
      assert_equal %w[no_humans 5], lines.second
    end
  end

  def test_table_header_uses_short_range_format
    since = 90.minutes
    report = build_report(tags: ["no_humans"], since:)

    with_stubbed_client(report, ["no_humans"] => { since => 5 }) do
      assert_equal %w[Contains Users], table_lines_for(report.embed).first
    end
  end

  private

  def now
    @now ||= Time.now
  end

  def build_report(tags:, since:)
    Fumimi::Report::PostAnalyticsReport.new(tags: tags, since: since, fumimi: default_fumimi)
  end

  def with_stubbed_client(report, data, &block)
    now = Time.now
    Time.stubs(:now).returns(now)

    client = stub

    client.stubs(:unique_ips_in_range).returns({ unique_ips: [0], duration: 0 })
    data.each do |tag_set, sinces|
      sinces.each do |since, count|
        client.stubs(:unique_ips_in_range).with(tag_set, since.ago..now).returns({ unique_ips: [count], duration: 0 })
      end
    end

    report.stubs(:signoz).returns(client)
    block.call
  end
end
