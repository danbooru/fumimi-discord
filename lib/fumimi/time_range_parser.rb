class Fumimi::TimeRangeParser
  def self.string_to_range(str, min: nil, max: nil, raise_on_validation: false)
    range = parse_string(str)

    if range.nil?
      raise Fumimi::Exceptions::CommandArgumentError,
            "Invalid range format. Use e.g. 1h, 2d, 1w, 1mo."
    end

    range = clamp(range, min:, max:, raise_on_validation:) if min || max
    range
  end

  def self.range_to_string(range)
    parts = range.parts

    return "#{parts[:months]}mo" if parts[:months]
    return "#{parts[:weeks]}w" if parts[:weeks]
    return "#{parts[:days]}d" if parts[:days]
    return "#{parts[:hours]}h" if parts[:hours]
    return "#{parts[:minutes]}mi" if parts[:minutes]
    return "#{parts[:seconds]}s" if parts[:seconds]

    range.inspect
  end

  def self.parse_string(str) # rubocop:disable Metrics/CyclomaticComplexity
    return nil if str.blank?

    case str.strip.downcase
    when /^(\d+)\s*mo(?:nths?)?/i then Regexp.last_match(1).to_i.months
    when /^(\d+)\s*w(?:eeks?)?/i  then Regexp.last_match(1).to_i.weeks
    when /^(\d+)\s*d(?:ays?)?/i then Regexp.last_match(1).to_i.days
    when /^(\d+)\s*h(?:ours?)?/i then Regexp.last_match(1).to_i.hours
    when /^(\d+)\s*mi(?:nutes?)?/i then Regexp.last_match(1).to_i.minutes
    when /^(\d+)\s*s(?:econds?)?/i then Regexp.last_match(1).to_i.seconds
    end
  end

  def self.clamp(range, min:, max:, raise_on_validation: false)
    if min && range < min
      if raise_on_validation
        raise Fumimi::Exceptions::CommandArgumentError,
              "Range must be at least #{min.inspect}"
      end

      return min
    end

    if max && range > max
      if raise_on_validation
        raise Fumimi::Exceptions::CommandArgumentError,
              "Range must not exceed #{max.inspect}"
      end

      return max
    end

    range
  end
end
