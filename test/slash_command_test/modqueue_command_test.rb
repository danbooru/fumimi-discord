require "test_helper"

class ModQueueCommandTest < Minitest::Test
  include TestMocks

  def test_responds_to_command
    mock_slash_command("/modqueue") => { reply_embeds:, ** }

    assert_equal 1, reply_embeds.length
    report = reply_embeds.first
    assert_equal "Mod Queue Report", report.title
    assert_match(/Top users by pending uploads:\n- \[.*?\]\(https:/, report.description)
  end
end
