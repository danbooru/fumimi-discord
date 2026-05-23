class Fumimi::Report::PostAnalyticsReport
  include Fumimi::HasDiscordEmbed

  attr_reader :cache, :signoz, :tags, :since

  # @param fumimi [Fumimi::Bot] Fumimi instance for accessing the bot.
  # @param tags [Array<String>] List of tags contained in the search.
  # @param since [Time] Starting point for the time range.
  def initialize(fumimi:, tags: [], since: 1.day)
    @cache = fumimi.cache
    @signoz = fumimi.signoz
    @tags = tags.sort
    @since = since
  end

  def embed_title
    tags.present? ? "Searches for #{@tags.join(" ").gsub("_", "\\_")}" : "Searches for anything"
  end

  def embed_description
    <<~EOS
      #{clarification}
      #{table}
    EOS
  end

  def embed_footer
    "Took: #{request_time}s"
  end

  def embed_timestamp
    results.finished_at
  end

  def clarification
    lines = []
    if @tags.present?
      lines << "Number of users who searched for `#{@tags.join(" & ")}` in the last #{@since.inspect}"
      lines << "(order doesn't matter)" if @tags.length > 1
    else
      lines << "Number of users who searched for anything in the last #{@since.inspect}"
    end

    lines << "Note: `*` matches anything, including exclusions." if @tags.any? { |t| t.include?("*") }

    if @tags.any? { |t| t =~ /^rating:(\w+)$/ }
      lines << "Note: `rating:#{Regexp.last_match(1)}` will be an exact search. Use `rating:#{Regexp.last_match(1)[0]}*` if you want to find all forms." # rubocop:disable Layout/LineLength
    end

    lines.join("\n")
  end

  def table
    unique_searchers = results[:searches].first
    direct_searches = results[:direct_searches].first
    pages_viewed = results[:searches].second
    posts_viewed = results[:post_views].first

    headers = %w[Name Value]
    rows = []
    rows << ["Unique Searches", unique_searchers.to_fs(:delimited)]
    rows << ["Type-in Searches", (direct_searches.to_f / unique_searchers * 100).to_fs(:rounded, precision: 1) + "%"]
    rows << ["Avg. Pages Viewed", (pages_viewed.to_f / unique_searchers).to_fs(:rounded, precision: 1)]
    rows << ["Avg. Posts Viewed", (posts_viewed.to_f / unique_searchers).to_fs(:rounded, precision: 1)]

    Fumimi::DiscordTable.new(headers:, rows:)
  end

  def results
    cache.fetch("post_analytics_report/#{tags.join(" ")}/#{since})}", expires_in: 5.minutes) do
      signoz
        .query_set
        .start(since.ago)
        .end(Time.now)
        .query("searches") do |query|
          query
            .where("k8s.daemonset.name = 'nginx-ingress-controller'")
            .where("userAgent CONTAINS 'Mozilla/5.0'")
            .where("userAgent NOT CONTAINS 'compatible'") # googlebot, etc
            .where("danbooru_path = '/posts'")
            .where(tags.map { |tag| "url REGEXP '#{tag_regex("tags", tag)}'" }.join(" AND "))
            .aggregate_by("count_distinct(ip)")
            .aggregate_by("count()")
        end
        .query("direct_searches") do |query|
          query
            .where("k8s.daemonset.name = 'nginx-ingress-controller'")
            .where("userAgent CONTAINS 'Mozilla/5.0'")
            .where("userAgent NOT CONTAINS 'compatible'") # googlebot, etc
            .where("danbooru_path = '/posts'")
            .where("url CONTAINS 'z=5'")
            .where(tags.map { |tag| "url REGEXP '#{tag_regex("tags", tag)}'" }.join(" AND "))
            .aggregate_by("count_distinct(ip)")
        end
        .query("post_views") do |query|
          query
            .where("k8s.daemonset.name = 'nginx-ingress-controller'")
            .where("userAgent CONTAINS 'Mozilla/5.0'")
            .where("userAgent NOT CONTAINS 'compatible'") # googlebot, etc
            .where("danbooru_path REGEXP '^/posts/[0-9]+$'")
            .where(tags.map { |tag| "url REGEXP '#{tag_regex("q", tag)}'" }.join(" AND "))
            .aggregate_by("count()")
        end.results
    end
  end

  def tag_regex(param, tag)
    tag = URI.encode_www_form_component(tag)
    tag = Regexp.escape(tag)
    tag = tag.gsub('\*', ".*") if tag.include?("\\*")

    /#{param}=(?i)(?:[^&]*\++\(?|[+(]*)(#{tag})([+&)]|$)/.source
  end

  def request_time
    results.duration.to_fs(:rounded, precision: 1)
  end
end
