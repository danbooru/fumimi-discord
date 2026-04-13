require "test_helper"

class HiCommandTest < Minitest::Test
  include TestMocks

  def test_responds_to_command
    mock_slash_command("/hi") => { replies:, messages:, ** }

    assert_equal ["Command received. Deleting all animes."], replies
    assert_equal ["5...", "4...", "3...", "2...", "1...", "Done! Animes deleted."], messages
  end
end
