require "test_helper"

class HiCommandTest < ApplicationTest
  def test_responds_to_command
    Fumimi::SlashCommand::HiCommand.any_instance.stubs(:sleep)
    mock_slash_command("/hi") => { replies:, messages:, ** }

    assert_equal ["Command received. Deleting all animes."], replies
    assert_equal ["5...", "4...", "3...", "2...", "1...", "Done! Animes deleted."], messages
  end
end
