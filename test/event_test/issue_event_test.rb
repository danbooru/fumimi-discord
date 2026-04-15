require "test_helper"

class IssueEventTest < Minitest::Test
  include TestMocks

  def test_issue_event
    msgs = mock_event("issue #42") => { msgs:, ** }

    assert_equal 1, msgs.length
    assert_equal "https://github.com/danbooru/danbooru/issues/42", msgs.first
  end
end
