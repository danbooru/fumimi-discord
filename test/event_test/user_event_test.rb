require "test_helper"

class UserEventTest < Minitest::Test
  include TestMocks

  def test_user_event
    embeds = mock_event("user #1") => { embeds:, ** }
    assert_equal 1, embeds.length
    user = embeds.first

    assert_equal "@albert", user.title
    assert_equal "https://danbooru.donmai.us/users/1", user.url

    fields = user.fields
    assert_equal "Admin", fields[0].value
    assert_match(/\d+/, fields[3].value)
  end

  def test_user_link_event
    embeds = mock_event("https://danbooru.donmai.us/users/1") => { embeds:, ** }
    assert_equal 1, embeds.length
    user = embeds.first

    assert_equal "@albert", user.title
    assert_equal "https://danbooru.donmai.us/users/1", user.url

    fields = user.fields
    assert_equal "Admin", fields[0].value
    assert_match(/\d+/, fields[3].value)
  end

  def test_no_user
    embeds = mock_event("user #999999999") => { embeds:, ** }

    assert_equal 0, embeds.length
  end
end
