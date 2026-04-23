class Fumimi::PostAnalyticsReport
  include Fumimi::HasDiscordEmbed

  def initialize(tags:, log:, cache:, range: 1.day, signoz_api_key: nil)
    @tags = tags.sort
    @log = log
    @cache = cache
    @range = range
    @signoz_api_key = signoz_api_key
  end

  def embed_title
    "Post Analytics Report"
  end

  def embed_description
    <<~EOS
      #{clarification}
      ```
      #{table.prettified}
      ```
      -# Results may be cached for #{@range.inspect}.
      -# Request time: #{request_time}s.
    EOS
  end

  def clarification
    lines = []
    if @tags.to_a.length > 1
      lines << "Unique users whose searches in the last #{@range.inspect} included all of these tags at once:"
      lines << @tags.map { |t| "`#{t}`" }.join(", ")
    elsif @tags.present?
      lines << "Unique users whose searches in the last #{@range.inspect} included `#{@tags.first}`:"
    else
      lines << "Unique users who searched for anything in the last #{@range.inspect}:"
    end

    lines << "Order does not matter." if @tags.length > 1

    lines << "Note: `*` matches anything, including exclusions." if @tags.any? { |t| t.include?("*") }

    if @tags.any? { |t| t =~ /^rating:(\w+)$/ }
      lines << "Note: `rating:#{Regexp.last_match(1)}` will be an exact search. Use `rating:#{Regexp.last_match(1)[0]}*` if you want to find all forms." # rubocop:disable Layout/LineLength
    end

    lines.join("\n")
  end

  def table
    Fumimi::DiscordTable.new(headers: table_headers, rows: table_rows)
  end

  def client
    return @client if defined? @client

    raise Fumimi::Exceptions::MissingCredentialsError, "SIGNOZ_API_KEY is not configured." if @signoz_api_key.nil?

    @client ||= SigNozClient.new("https://signoz.donmai.us", @signoz_api_key, log: @log, cache: @cache)
  end

  def negated_tags
    return nil if @range > 1.day
    return nil unless @tags.length == 1
    return nil if @tags.any? { |t| t.include? "*" }

    @tags.map { |t| t.start_with?("-") || t == "or" ? t.delete_prefix("-") : "-#{t}" }
  end

  private

  def table_headers
    headers = ["Contains", "Users <#{Fumimi::TimeRangeParser.range_to_string(@range)}"]
    headers << "Users <1h" if show_hourly_comparison?
    headers
  end

  def table_rows
    rows = []

    unique_ips_in_range = range_request[:unique_ips][0]

    row = [@tags.join(" + ").truncate(20, omission: "…"), unique_ips_in_range.to_fs(:delimited)]
    row << hourly_request[:unique_ips][0].to_fs(:delimited) if show_hourly_comparison?
    rows << row

    if negated_tags.present?
      unique_ips_in_range = negated_range_request[:unique_ips][0]

      row = [negated_tags.join(" + ").truncate(20, omission: "…"), unique_ips_in_range.to_fs(:delimited)]
      row << negated_hourly_request[:unique_ips][0].to_fs(:delimited) if show_hourly_comparison?
      rows << row
    end

    rows
  end

  def range_request
    @range_request ||= client.unique_ips_in_range([@tags].compact, @range)
  end

  def negated_range_request
    @negated_range_request ||= client.unique_ips_in_range([negated_tags].compact, @range)
  end

  def hourly_request
    @hourly_request ||= client.unique_ips_in_range([@tags].compact, 1.hour)
  end

  def negated_hourly_request
    @negated_hourly_request ||= client.unique_ips_in_range([negated_tags].compact, 1.hour)
  end

  def show_hourly_comparison?
    @range > 1.hour && @range <= 1.day
  end

  def request_time
    t = range_request[:duration]
    t += negated_range_request[:duration] if negated_tags.present?
    t += hourly_request[:duration] if show_hourly_comparison?
    t += negated_hourly_request[:duration] if show_hourly_comparison? && negated_tags.present?
    "%.2f" % t
  end
end
