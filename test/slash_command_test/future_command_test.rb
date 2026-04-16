require "test_helper"

class FutureCommandTest < Minitest::Test
  include TestMocks

  def test_responds_to_command
    mock_slash_command("/future") => { reply_embeds:, ** }

    assert_equal 1, reply_embeds.length
    report = reply_embeds.first
    assert_equal "Future GETs", report.title
    assert report.description
  end
end
