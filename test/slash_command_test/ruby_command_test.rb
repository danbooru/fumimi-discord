require "test_helper"

class RubyCommandTest < ApplicationTest
  OWNER_ID = 456

  def test_rejects_non_owner
    with_mocked_owners([OWNER_ID]) do
      mock_slash_command("/ruby", args: { code: "1 + 1" }, user_id: 123) => { reply_embeds:, ** }

      assert_equal 1, reply_embeds.length
      error = reply_embeds.first
      assert_equal "No Permissions", error.title
    end
  end

  def test_owner_can_eval
    with_mocked_owners([OWNER_ID]) do
      mock_slash_command("/ruby", args: { code: "1 + 1" }, user_id: OWNER_ID) => { replies:, ** }

      assert_equal ["`2`"], replies
    end
  end
end
