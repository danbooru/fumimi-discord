require "test_helper"

class IssueEventTest < ApplicationTest
  def test_issue_event
    messages = mock_event("issue #42") => { messages:, ** }

    assert_equal 1, messages.length
    assert_equal "https://github.com/danbooru/danbooru/issues/42", messages.first
  end
end
