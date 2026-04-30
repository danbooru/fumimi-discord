require "test_helper"

class YappersCommandTest < ApplicationTest
  def test_responds_to_topic_id
    mock_slash_command("/yappers", args: { topic_id: 35_840 }) => { reply_embeds:, ** }

    assert_equal 1, reply_embeds.length
    report = reply_embeds.first
    assert_equal "Forum Yappers Report", report.title
    assert_match(/topic #35840/, report.description)

    table_lines = table_lines_for(report)
    assert_equal ["User", "Word Count"], table_lines.first
    assert_operator table_lines.length, :>, 6
  end

  def test_responds_to_age_search
    mock_slash_command("/yappers", args: { time_range: "1w" }) => { reply_embeds:, ** }

    assert_equal 1, reply_embeds.length
    report = reply_embeds.first
    assert_equal "Forum Yappers Report", report.title

    table_lines = table_lines_for(report)
    assert_equal ["User", "Word Count"], table_lines.first
    assert_operator table_lines.length, :>, 21
  end

  def test_responds_to_nonexistent_topic
    mock_slash_command("/yappers", args: { topic_id: 12_314_513 }) => { reply_embeds:, ** }

    assert_equal 1, reply_embeds.length
    report = reply_embeds.first
    assert_equal "Forum Yappers Report", report.title

    table_lines = table_lines_for(report)
    assert_equal ["User", "Word Count"], table_lines.first
    assert_equal ["0"], table_lines.second
  end
end
