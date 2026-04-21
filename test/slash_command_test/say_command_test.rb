require "test_helper"

class SayCommandTest < ApplicationTest
  def test_say
    mock_slash_command("/say", args: { message: "hello", channel: "123" }) => { replies:, messages:, ** }

    assert_equal ["Sent."], replies
    assert_equal ["hello"], messages
  end
end
