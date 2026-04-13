require "test_helper"

class CalcCommandTest < Minitest::Test
  include TestMocks

  def test_responds_to_command
    mock_slash_command("/calc", args: { expression: "100*100" }) => { replies:, ** }

    assert_equal ["`100*100 = 10_000`"], replies
  end

  def test_decimal_rounding
    mock_slash_command("/calc", args: { expression: "1/3" }) => { replies:, ** }

    assert_equal ["`1/3 = 0.3333`"], replies
  end

  def test_preserving_precision
    mock_slash_command("/calc", args: { expression: "1/10000000000" }) => { replies:, ** }

    assert_equal ["`1/10000000000 = 0.0000000001`"], replies
  end

  def test_responds_to_bad_operation
    mock_slash_command("/calc", args: { expression: "asd" }) => { reply_embeds:, ** }

    error = reply_embeds.first
    assert_equal "Bad Argument!", error.title
    assert_equal "`asd` is not a valid math expression.", error.description.to_s
  end
end
