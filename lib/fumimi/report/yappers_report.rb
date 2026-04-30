class Fumimi::Report::YappersReport
  include Fumimi::HasDiscordEmbed

  def initialize(fumimi:, range:, topic_id:, cache:)
    @fumimi = fumimi
    @range = range
    @range_str = Fumimi::TimeRangeParser.range_to_string(range)
    @topic_id = topic_id
    @cache = cache
  end

  def embed_title
    "Forum Yappers Report"
  end

  def embed_description
    <<~EOS
      #{description}
      ```
      #{table.prettified}
      ```
      -# Results are cached for one hour.
    EOS
  end

  def description
    if @topic_id
      "Top forum yappers for #{topic_link} (bots excluded):"
    else
      "Top forum yappers for the last #{@range.inspect} (bots excluded):"
    end
  end

  def topic_link
    "[topic ##{@topic_id}](#{@fumimi.booru.url}/#{@topic_id})"
  end

  def table
    Fumimi::DiscordTable.new(headers: table_headers, rows: table_rows)
  end

  def table_headers
    ["User", "Word Count"]
  end

  def table_rows
    rows = []

    rows << ["", top_yappers.values.sum]

    rows += top_yappers.to_a

    rows
  end

  def query_params
    query_params = {
      "search[topic][is_private]": false,
      "search[creator_id_not]": "502584,865894",
    }

    if @topic_id.present?
      query_params["search[topic_id]"] = @topic_id
    else
      query_params["search[created_at]"] = "<#{@range_str}"
    end
    query_params
  end

  def top_yappers
    @cache.fetch(cache_key, expires_in: 1.hour) do
      @top_yappers ||= Hash.new(0).tap do |yappers_map|
        forum_posts.each { |fp| yappers_map[fp.creator.name] += fp.word_count }
      end.sort_by { |_k, v| v }.reverse.to_h # rubocop:disable Style/MultilineBlockChain
    end
  end

  def cache_key
    if @topic_id
      :"yapper_report_topic_#{@topic_id}"
    else
      :"yapper_report_range_#{@range_str}"
    end
  end

  def forum_posts
    @forum_posts ||= [].tap do |posts|
      page = 1
      loop do
        page_posts = @fumimi.booru.forum_posts.index(**query_params, page: page)
        break if page_posts.empty?

        page = "b#{page_posts.map(&:id).min}"
        posts.concat(page_posts)
      end
    end
  end
end
