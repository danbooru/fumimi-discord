require "test_helper"

class PostAnalyticsCommandTest < ApplicationTest
  def test_default_range
    VCR.use_cassette("post_analytics_1girl_1d") do
      response = mock_slash_command("/searches", args: { tags: "1girl" })
      report = response.reply_embeds.first
      table_lines = table_lines_for(report)

      assert_equal "Searches for 1girl", report.title
      assert_equal %w[Name Value], table_lines.first
      assert_equal ["Unique Searches", "3,936"], table_lines.second
      assert_equal ["Type-in Searches", "46.7%"], table_lines.third
      assert_equal ["Avg. Pages Viewed", "9.0"], table_lines.fourth
      assert_equal ["Avg. Posts Viewed", "7.5"], table_lines.fifth
    end
  end

  def test_invalid_range
    response = mock_slash_command("/searches", args: { tags: "1girl", time_range: "invalid" })
    reply_embeds = response.reply_embeds

    assert_equal 1, reply_embeds.length
    assert_equal "Bad Argument!", reply_embeds.first.title
    assert_match(/invalid range format/i, reply_embeds.first.description)
  end

  def test_custom_time_range
    VCR.use_cassette("post_analytics_1girl_1h") do
      response = mock_slash_command("/searches", args: { tags: "1girl", time_range: "1h" })
      report = response.reply_embeds.first
      table_lines = table_lines_for(report)

      assert_equal "Searches for 1girl", report.title
      assert_equal %w[Name Value], table_lines.first
      assert_equal ["Unique Searches", "192"], table_lines.second
      assert_equal ["Type-in Searches", "43.2%"], table_lines.third
      assert_equal ["Avg. Pages Viewed", "8.4"], table_lines.fourth
      assert_equal ["Avg. Posts Viewed", "4.8"], table_lines.fifth
    end
  end

  def test_multiple_tags
    VCR.use_cassette("post_analytics_1girl_solo_4h") do
      response = mock_slash_command("/searches", args: { tags: "1girl solo", time_range: "4h" })
      report = response.reply_embeds.first
      table_lines = table_lines_for(report)

      assert_equal "Searches for 1girl solo", report.title
      assert_equal %w[Name Value], table_lines.first
      assert_equal ["Unique Searches", "13"], table_lines.second
      assert_equal ["Type-in Searches", "92.3%"], table_lines.third
      assert_equal ["Avg. Pages Viewed", "9.7"], table_lines.fourth
      assert_equal ["Avg. Posts Viewed", "12.4"], table_lines.fifth
    end
  end

  def test_blank_search
    VCR.use_cassette("post_analytics_blank_1h") do
      response = mock_slash_command("/searches", args: { time_range: "1h" })
      report = response.reply_embeds.first
      table_lines = table_lines_for(report)

      assert_equal "Searches for anything", report.title
      assert_equal %w[Name Value], table_lines.first
      assert_equal ["Unique Searches", "42,811"], table_lines.second
      assert_equal ["Type-in Searches", "35.9%"], table_lines.third
      assert_equal ["Avg. Pages Viewed", "11.8"], table_lines.fourth
      assert_equal ["Avg. Posts Viewed", "12.1"], table_lines.fifth
    end
  end
end
