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
      Amount of unique users who used all of the following tags in at least one search:
      #{tags_sentence}
      #{clarification}
      ```
      #{table.prettified}
      ```
      -# Requested by <@#{@event.user.id}>. Results may be cached.
    EOS
  end

  def clarification
    clarifications = []
    if @tags.any? { |t| t.include? "*" }
      clarifications << "Note: `*` matches any search, it's not like searching with an asterisk on danbooru."
    end
    clarifications << "Order does not matter." if @tags.length > 1

    clarifications.join("\n")
  end

  def tags_sentence
    @tags.map { |t| "`#{t}`" }.join(", ")
  end

  def table
    headers = ["Usage", "Last 24 hours", "Last hour"]
    rows = [
      [@tags.join(" + ").truncate(20, omission: "…"), searches_including_search_today,
       searches_including_search_last_hour,],
    ]

    if reversed_tag.present?
      rows << [reversed_tag.join(" + ").truncate(20, omission: "…"), searches_excluding_search_today,
               searches_excluding_search_last_hour,]
    end

    Fumimi::DiscordTable.new(headers: headers, rows: rows)
  end

  def searches_including_search_today
    client.unique_ips_for_search(@tags, 1.day)
  end

  def searches_including_search_last_hour
    client.unique_ips_for_search(@tags, 1.hour)
  end

  def reversed_tag
    # only show reversed search for single tag searches
    return [] unless @tags.length == 1

    @tags.map { |t| t.start_with?("-") || t == "or" ? t.delete_prefix("-") : "-#{t}" }
  end

  def searches_excluding_search_today
    client.unique_ips_for_search(reversed_tag, 1.day) if reversed_tag.present?
  end

  def searches_excluding_search_last_hour
    client.unique_ips_for_search(reversed_tag, 1.hour) if reversed_tag.present?
  end

  def client
    return @client if defined? @client

    begin
      signoz_email = ENV.fetch("FUMIMI_SIGNOZ_EMAIL")
      signoz_password = ENV.fetch("FUMIMI_SIGNOZ_PASSWORD")
    rescue KeyError
      raise Fumimi::Exceptions::MissingCredentialsError
    end

    @client ||= SigNozClient.new(
      "https://signoz.donmai.us",
      signoz_email,
      signoz_password,
      @log,
      @cache
    )
  end
end
