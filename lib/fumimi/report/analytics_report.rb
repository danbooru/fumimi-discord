class Fumimi::AnalyticsReport
  def initialize(event, tags, log, cache)
    @event = event
    @tags = tags.sort
    @log = log
    @cache = cache
  end

  def send_embed(embed)
    embed.title = title
    embed.description = description
  end

  def title
    "Analytics Report"
  end

  def description
    <<~EOS
      #{clarification}
      ```
      #{table.prettified}
      ```
      -# Requested by <@#{@event.user.id}>. Results may be cached.
    EOS
  end

  def clarification # rubocop:disable Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
    if @tags.present?
      clarification = "Unique users who used all of the following in at least one search:\n"
      clarification += @tags.map { |t| "* `#{t}`" }.join("\n")
    else
      clarification = "Unique users:"
    end

    clarification += "\n"

    clarification += "\nOrder does not matter." if @tags.length > 1

    if @tags.any? { |t| t.include? "*" }
      # warn about mistaken asterisk usage
      clarification += "\nNote: `*`matches anything, it's not a literal danbooru wildcard."
    end

    if @tags.any? { |t| t =~ /^rating:(\w+)$/ }
      clarification += "\nNote: `rating:#{::Regexp.last_match(1)}` will be an exact search. Use `rating:#{::Regexp.last_match(1)[0]}*` if you want to find all forms." # rubocop:disable Layout/LineLength
    end

    clarification
  end

  def table
    headers = ["Contains", "Searches <24h", "Searches <1h"]
    rows = [[@tags.join(" + ").truncate(20, omission: "…"),
             searches_in_last_hours(24),
             searches_in_last_hours(1),]]

    if negated_tags.present?
      rows << [negated_tags.join(" + ").truncate(20, omission: "…"),
               negated_searches_in_last_hours(24),
               negated_searches_in_last_hours(1),]
    end

    Fumimi::DiscordTable.new(headers: headers, rows: rows)
  end

  def client
    return @client if defined? @client

    begin
      signoz_api_key = ENV.fetch("SIGNOZ_API_KEY")
    rescue KeyError
      raise Fumimi::Exceptions::MissingCredentialsError
    end

    @client ||= SigNozClient.new(
      "https://signoz.donmai.us",
      signoz_api_key,
      @log,
      @cache
    )
  end

  def negated_tags
    # only show reversed search for single tag searches
    return [] unless @tags.length == 1

    @tags.map { |t| t.start_with?("-") || t == "or" ? t.delete_prefix("-") : "-#{t}" }
  end

  def searches_in_last_hours(hours)
    client.unique_ips_in_range(@tags, hours.hours)
  end

  def negated_searches_in_last_hours(hours)
    client.unique_ips_in_range(negated_tags, hours.hours)
  end
end
