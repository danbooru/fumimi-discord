class Fumimi::Report::PostAnalyticsReport
  include Fumimi::HasDiscordEmbed

  attr_reader :signoz, :tags, :since

  # @param fumimi [Fumimi::Bot] Fumimi instance for accessing the bot.
  # @param tags [Array<String>] List of tags contained in the search.
  # @param since [Time] Starting point for the time range.
  def initialize(fumimi:, tags: [], since: 1.day)
    @signoz = fumimi.signoz
    @tags = tags.sort
    @since = since
  end

  def embed_title
    "Searches for #{@tags.join(" ")}"
  end

  def embed_description
    <<~EOS
      #{clarification}
      ```
      #{table.prettified}
      ```
    EOS
  end

  def embed_footer
    "Took: #{request_time}s"
  end

  def embed_timestamp
    Time.parse(range_request[:cached_at]) if range_request[:cached_at].present?
  end

  def clarification
    lines = []
    if @tags.to_a.length > 1
      lines << "Unique users whose searches in the last #{@since.inspect} included all of these tags at once:"
      lines << @tags.map { |t| "`#{t}`" }.join(", ")
    elsif @tags.present?
      lines << "Unique users whose searches in the last #{@since.inspect} included `#{@tags.first}`:"
    else
      lines << "Unique users who searched for anything in the last #{@since.inspect}:"
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

  def table_headers
    %w[Contains Users]
  end

  def table_rows
    rows = []
    rows << [@tags.join(" + ").truncate(20, omission: "…"), unique_ips_in_range.to_fs(:delimited)]
    rows
  end

  def range_request
    @range_request ||= signoz.unique_ips_in_range(@tags.compact, @since.ago..Time.now)
  end

  def unique_ips_in_range
    @unique_ips_in_range ||= range_request[:unique_ips][0]
  end

  def request_time
    range_request[:duration].to_fs(:rounded, precision: 1)
  end
end
