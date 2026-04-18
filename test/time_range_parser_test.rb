require "test_helper"

class TimeRangeParserTest < Minitest::Test
  def test_parses_seconds
    assert_equal 30.seconds, Fumimi::TimeRangeParser.string_to_range("30s")
  end

  def test_parses_minutes_mi_suffix
    assert_equal 1.minute, Fumimi::TimeRangeParser.string_to_range("1mi")
  end

  def test_parses_hours
    assert_equal 2.hours, Fumimi::TimeRangeParser.string_to_range("2h")
  end

  def test_parses_days
    assert_equal 3.days, Fumimi::TimeRangeParser.string_to_range("3d")
  end

  def test_parses_weeks
    assert_equal 1.week, Fumimi::TimeRangeParser.string_to_range("1w")
  end

  def test_parses_months
    assert_equal 1.month, Fumimi::TimeRangeParser.string_to_range("1mo")
  end

  def test_raises_when_invalid_format
    error = assert_raises(Fumimi::Exceptions::CommandArgumentError) do
      Fumimi::TimeRangeParser.string_to_range("abc", min: 1.second, max: 1.month)
    end

    assert_match(/Invalid range format/, error.message)
  end

  def test_raises_when_below_min_with_validation_enabled
    error = assert_raises(Fumimi::Exceptions::CommandArgumentError) do
      Fumimi::TimeRangeParser.string_to_range("0h", min: 1.second, max: 1.month, raise_on_validation: true)
    end

    assert_match(/at least/, error.message)
  end

  def test_raises_when_above_max_with_validation_enabled
    error = assert_raises(Fumimi::Exceptions::CommandArgumentError) do
      Fumimi::TimeRangeParser.string_to_range("999mo", min: 1.second, max: 1.month, raise_on_validation: true)
    end

    assert_match(/not exceed/, error.message)
  end

  def test_clamps_to_min_when_below_range
    assert_equal 1.second, Fumimi::TimeRangeParser.string_to_range("0h", min: 1.second, max: 1.month)
  end

  def test_clamps_to_max_when_above_range
    assert_equal 1.month, Fumimi::TimeRangeParser.string_to_range("999mo", min: 1.second, max: 1.month)
  end
  # range_to_string

  def test_range_to_string_seconds
    assert_equal "30s", Fumimi::TimeRangeParser.range_to_string(30.seconds)
  end

  def test_range_to_string_minutes
    assert_equal "20mi", Fumimi::TimeRangeParser.range_to_string(20.minutes)
  end

  def test_range_to_string_hours
    assert_equal "2h", Fumimi::TimeRangeParser.range_to_string(2.hours)
  end

  def test_range_to_string_days
    assert_equal "3d", Fumimi::TimeRangeParser.range_to_string(3.days)
  end

  def test_range_to_string_weeks
    assert_equal "1w", Fumimi::TimeRangeParser.range_to_string(1.week)
  end

  def test_range_to_string_months
    assert_equal "1mo", Fumimi::TimeRangeParser.range_to_string(1.month)
  end
end
