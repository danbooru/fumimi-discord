require "test_helper"

class PullEventTest < Minitest::Test
  include TestMocks

  def test_pull_event
    messages = mock_event("pull #77") => { messages:, ** }

    assert_equal 1, messages.length
    assert_equal "https://github.com/danbooru/danbooru/pull/77", messages.first
  end
end
