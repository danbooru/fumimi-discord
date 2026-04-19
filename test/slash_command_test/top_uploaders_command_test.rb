require "test_helper"

class TopUploadersCommandTest < Minitest::Test
  include TestMocks

  def test_responds_to_command
    mock_slash_command("/top_uploaders", args: { tags: "age:<1h" }) => { reply_embeds:, ** }

    assert_equal 1, reply_embeds.length
    report = reply_embeds.first
    assert_equal "Top Uploaders Report", report.title
    assert report.description
  end
end
