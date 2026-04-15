require "test_helper"

class BursCommandTest < Minitest::Test
  include TestMocks

  def test_responds_to_command
    mock_slash_command("/burs") => { reply_embeds:, ** }

    assert_equal reply_embeds.length, 1
    report = reply_embeds.first

    assert_equal "Pending BUR Stats", report.title
    assert_match(/Top topics by pending requests:/, report.description)
    assert_match(/\d+ pending/, report.fields.last.value)
    assert report.timestamp
  end
end
