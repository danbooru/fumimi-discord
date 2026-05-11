require "test_helper"

class PostAnalyticsCommandTest < ApplicationTest
  def test_default_range
    VCR.use_cassette("post_analytics_1girl_1d") do
      response = mock_slash_command("/searches", args: { tags: "1girl" })
      report = response.reply_embeds.first
      table_lines = table_lines_for(report)

      assert_equal "Searches for 1girl", report.title
      assert_equal %w[Contains Users], table_lines.first
      assert_equal %w[1girl 3,645], table_lines.second
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
      assert_equal %w[Contains Users], table_lines.first
      assert_equal %w[1girl 152], table_lines.second
    end
  end

  def test_multiple_tags
    VCR.use_cassette("post_analytics_1girl_solo_4h") do
      response = mock_slash_command("/searches", args: { tags: "1girl solo", time_range: "4h" })
      report = response.reply_embeds.first
      table_lines = table_lines_for(report)

      assert_equal 2, table_lines.length
      assert_equal "Searches for 1girl solo", report.title
      assert_equal %w[Contains Users], table_lines.first
      assert_equal ["1girl + solo", "22"], table_lines.second
    end
  end
end
