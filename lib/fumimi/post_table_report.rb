module Fumimi::Report
  class PostTableReport
    include Fumimi::HasDiscordEmbed

    def initialize(booru:, tags:)
      @booru = booru
      @tags = tags
    end

    def embed_title
      self.class.name.demodulize.underscore.titleize
    end

    def embed_description
      if total_posts == 0
        <<~EOF.chomp
          #{tag_description}

          No posts under that search!
        EOF
      else
        <<~EOF.chomp
          #{cache_message}
          #{tag_description}
          #{table}
        EOF
      end
    end

    def tag_description
      return "" if tag_string.blank?

      "-# Tags: `%s`" % tag_string
    end

    def embed_url
      "#{@booru.url}/reports/posts?#{report_search_params.to_query}"
    end

    def embed_timestamp
      Time.now
    end

    def table_headers
    end

    def table_rows
    end

    def table
      Fumimi::DiscordTable.new(headers: table_headers, rows: table_rows)
    end

    def tag_string
      @tags.join(" ").strip
    end

    def total_posts
      @total_posts ||= @booru.counts.index(tags: tag_string).counts.posts
    end

    def report
      @report ||= @booru.post_reports.index(**report_search_params).as_json
    end
  end
end
