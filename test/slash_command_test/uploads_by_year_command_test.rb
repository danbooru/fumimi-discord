require "test_helper"

class UploadsByYearCommandTest < ApplicationTest
  def test_responds_to_command
    mock_slash_command("/uploads_by_year", args: { tags: "touhou" }) => { reply_embeds:, ** }

    assert_equal 1, reply_embeds.length
    report = reply_embeds.first
    assert_equal "Uploads by Year Report", report.title
    assert report.description
  end
end
