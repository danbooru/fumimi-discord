require "json"
require "time"
require_relative "http_client"

# Client for querying SigNoz log analytics endpoints.
class SigNozClient
  class SignozResponseChangedError < StandardError; end

  # @param base [String] SigNoz base URL.
  # @param api_key [String] SigNoz API key header value.
  # @param log [Logger] Logger instance.
  # @param cache [Object] Cache object with `get` support.
  def initialize(base, api_key, log:, cache:)
    @base     = base
    @api_key  = api_key
    @log      = log
    @cache    = cache
    @http     = HTTPClient.new(base: @base, signoz_api_key: @api_key, log: @log)
  end

  # Returns unique IP counts for a tag query over a given time range.
  #
  # @return [Integer]
  def unique_ips_in_range(tags, range)
    until_ms = (Time.now.to_f * 1000).to_i
    since_ms = until_ms - range.in_milliseconds

    query_payload = create_payload(since_ms, until_ms, tags)

    @cache.get(cache_key(range, tags), lifetime: cache_lifetime(range)) do
      # cache queries about a tag for their selected timespan
      @log.info("[Signoz] Fetching signoz query for #{tags} for the last #{range.inspect}...")

      data = post_json("/api/v5/query_range", query_payload)

      data["data"]["data"]["results"][0]["data"][0][0]
    end
  end

  def cache_key(range, tags)
    :"signoz_count_tags_#{tags.join("_")}_#{range.in_seconds}"
  end

  def cache_lifetime(range)
    # cache queries for a minimum of one hour, to a maximum of one day
    Fumimi::TimeRangeParser.clamp(range, min: 1.hour, max: 1.day).in_seconds
  end

  # Sends the query payload and returns parsed response JSON.
  #
  # @return [Hash]
  def post_json(path, payload)
    response = @http.post(path, json: payload)

    if response.code >= 400
      @log.info("[Signoz] Response: #{response.body}")
      raise "Signoz responded with HTTP #{response.code}."
    end

    parsed = JSON.parse(response.body).with_indifferent_access
    if parsed[:status] != "success"
      @log.info("[Signoz] Response: #{parsed}")
      raise "Signoz API response: unexpected status."
    end

    parsed
  end

  # Builds the query payload used by SigNoz' query_range endpoint.
  #
  # @return [Hash]
  def create_payload(since_ms, until_ms, tags)
    # creates a payload for a query that gets the amount of searches for a tag every hour for the past 24 days
    expression = "k8s.daemonset.name = 'nginx-ingress-controller'"
    expression += " AND userAgent CONTAINS 'Mozilla/5.0' "
    expression += " AND userAgent NOT CONTAINS 'compatible'" # googlebot, etc
    expression += " AND url CONTAINS '/posts?'"
    expression += " AND url CONTAINS 'tags='"

    tags.each do |tag|
      expression += " and url REGEXP '#{tag_regex(tag)}'"
    end

    {
      schemaVersion: "v1",
      start: since_ms,
      end: until_ms,
      requestType: "scalar",
      compositeQuery: {
        queries: [{
          type: "builder_query",
          spec: {
            name: "Unique Ips",
            signal: "logs",
            stepInterval: 300, # every hour
            disabled: false,
            filter: {
              expression: expression,
            },
            having: {
              expression: "",
            },
            aggregations: [{
              expression: "count_distinct(ip)",
            }],
          },
        }],
      },
      formatOptions: {
        formatTableResultForUI: false,
        fillGaps: false,
      },
      variables: {},
    }
      .with_indifferent_access
  end

  def tag_regex(tag)
    tag = URI.encode_www_form_component(tag)
    tag = Regexp.escape(tag)
    # Replace encoded asterisk back with a regex wildcard that stops at tag boundaries
    tag = tag.gsub('\*', ".*")

    return negative_tag_regex(tag.delete_prefix("-")) if tag.start_with?("-")

    positive_tag_regex(tag)
  end

  def positive_tag_regex(tag)
    /(?i)(^|\+)(#{tag}(\+|$)|%28#{tag}(\+|%29)|%28.+\+#{tag}(\+|%29))/.source
  end

  def negative_tag_regex(tag)
    /(?i)(^|\+)(-#{tag}(\+|$)|-%28#{tag}(\+|%29)|-%28.+\+#{tag}(\+|%29))/.source
  end

  def wildcard_tag_regex(tag)
  end
end
