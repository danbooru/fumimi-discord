require "test_helper"

class RubyCommandTest < Minitest::Test
  include TestMocks

  OWNER_ID = 456

  def with_mocked_owners(owner_ids)
    command_class = Fumimi::SlashCommand::RubyCommand
    original_owners = command_class::OWNERS

    command_class.send(:remove_const, :OWNERS)
    command_class.const_set(:OWNERS, owner_ids)

    yield
  ensure
    command_class.send(:remove_const, :OWNERS)
    command_class.const_set(:OWNERS, original_owners)
  end

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
