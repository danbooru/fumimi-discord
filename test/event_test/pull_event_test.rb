require "test_helper"

class PullEventTest < Minitest::Test
  include TestMocks

  def test_pull_event
    msgs = mock_event("pull #77") => { msgs:, ** }

    assert_equal 1, msgs.length
    assert_equal "https://github.com/danbooru/danbooru/pull/77", msgs.first
  end
end
