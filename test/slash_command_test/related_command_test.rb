require "test_helper"

class RelatedCommandTest < Minitest::Test
  include TestMocks

  def test_responds_to_command
    mock_slash_command("/related_tags", args: { tags: "age:<1h", category: "artist" }) => { reply_embeds:, ** }

    assert_equal 1, reply_embeds.length
    report = reply_embeds.first

    assert_equal("Related Artist Tags Report", report.title)
    assert report.description
  end

  def test_bad_category
    mock_slash_command("/related_tags", args: { tags: "age:<1h", category: "artisto" }) => { reply_embeds:, ** }

    assert_equal 1, reply_embeds.length
    report = reply_embeds.first

    assert_equal("Bad Argument!", report.title)
    assert_equal "Unknown category: `artisto`.", report.description
  end
end
