require "test_helper"

class BurEventTest < Minitest::Test
  include TestMocks

  def test_bur_event
    embeds = mock_event("bur #50001, bur #50000") => { embeds:, ** }
    assert_equal 2, embeds.length

    approved = embeds.first
    failed = embeds.second

    assert_equal "Artist alias self-service thread", approved.title
    assert_equal Fumimi::Colors::GREEN, approved.color
    assert_match(/Score:\s+\e\[[0-9;]*m\+0\e\[0m \| \e\[[0-9;]*m0\e\[0m \| \e\[[0-9;]*m-0\e\[0m/, approved.description)

    assert_equal "Fingernails, nail polish, and nail colors", failed.title
    assert_equal Fumimi::Colors::RED, failed.color
    assert_match(/Score:\s+\e\[[0-9;]*m\+2\e\[0m \| \e\[[0-9;]*m9\e\[0m \| \e\[[0-9;]*m-3\e\[0m/, failed.description)
  end

  def test_no_bur
    embeds = mock_event("bur #101010101") => { embeds:, ** }
    assert_equal 0, embeds.length
  end
end
