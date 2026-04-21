require "test_helper"

class CountCommandTest < ApplicationTest
  def test_find_results
    mock_slash_command("/count", args: {tags: "age:<1d"}) => { replies:, messages:, ** }

    assert_match /Post count for `age:<1d`: [\d,]+./, replies.first
  end
end
