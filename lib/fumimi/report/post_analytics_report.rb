class Fumimi::PostAnalyticsReport
  include Fumimi::HasDiscordEmbed

  def initialize(tags:, log:, cache:, range: 1.day)
    @tags = tags.sort
    @log = log
    @cache = cache
    @range = range
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
      -# Results are cached for a minimum of 1 hour and a maximum of 1 day.
    EOS
  end

  def clarification # rubocop:disable Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
    lines = ["Time range: #{@range.inspect}."]

    if @tags.to_a.length > 1
      lines << "Unique users whose searches included all of these tags at once:"
      lines << @tags.map { |t| "`#{t}`" }.join(", ")
    elsif @tags.present?
      lines << "Unique users whose searches included `#{@tags.first}`:"
    else
      lines << "Unique users who searched for anything:"
    end

    lines << "Order does not matter." if @tags.length > 1

    lines << "Note: `*` matches anything, it's not a literal danbooru wildcard." if @tags.any? { |t| t.include?("*") }

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

    begin
      signoz_api_key = ENV.fetch("SIGNOZ_API_KEY")
    rescue KeyError
      raise Fumimi::Exceptions::MissingCredentialsError, "SIGNOZ_API_KEY is not configured."
    end

    @client ||= SigNozClient.new(
      "https://signoz.donmai.us",
      signoz_api_key,
      log: @log,
      cache: @cache
    )
  end

  def negated_tags
    return [] unless @tags.length == 1

    @tags.map { |t| t.start_with?("-") || t == "or" ? t.delete_prefix("-") : "-#{t}" }
  end

  private

  def table_headers
    headers = ["Contains", "Users <#{Fumimi::TimeRangeParser.range_to_string(@range)}"]
    headers << "Users <1h" if show_hourly_comparison?
    headers
  end

  def table_rows
    rows = [build_row(@tags)]
    rows << build_row(negated_tags) if show_negated_row?
    rows
  end

  def build_row(tags)
    row = [tags.join(" + ").truncate(20, omission: "…"), client.unique_ips_in_range(tags, @range)]
    row << client.unique_ips_in_range(tags, 1.hour) if show_hourly_comparison?
    row
  end

  def show_hourly_comparison?
    @range > 1.hour && @range <= 1.day
  end

  def show_negated_row?
    negated_tags.present? && @range <= 1.day
  end
end
