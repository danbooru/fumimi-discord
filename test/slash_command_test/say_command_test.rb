require "test_helper"

class SayCommandTest < Minitest::Test
  include TestMocks

  OWNER_ID = 456

  def test_rejects_non_owner
    with_mocked_owners([OWNER_ID]) do
      mock_slash_command("/say", args: { message: "hello", channel: "123" }, user_id: 123) => { reply_embeds:, ** }

      assert_equal 1, reply_embeds.length
      error = reply_embeds.first
      assert_equal "No Permissions", error.title
    end
  end

  def test_owner_can_say
    with_mocked_owners([OWNER_ID]) do
      mock_slash_command("/say", args: { message: "hello", channel: "123" },
                                 user_id: OWNER_ID) => { replies:, messages:, ** }

      assert_equal ["Sent."], replies
      assert_equal ["hello"], messages
    end
  end
end
