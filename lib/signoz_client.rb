require "json"
require "time"

# Client for querying SigNoz log analytics endpoints.
#
# Required signoz configuration:
# attributes.url -> donmai\.\w+(?<danbooru_path>[\w\/]+) -> attributes (Regex parser)
# attributes.url -> tags=(?P<query_string_tags>[^&]*) -> attributes (Regex parser)
class SignozClient
  # @param base_url [String] SigNoz base URL.
  # @param api_key [String] SigNoz API key header value.
  # @param log [Logger] Logger instance.
  # @param http [HTTPClient] HTTP client instance.
  # @param cache [Object] Cache object with `get` support.
  def initialize(base_url, api_key, log:, http:, cache:)
    @api_key     = api_key
    @log         = log
    @cache       = cache
    @http        = http.base_url(base_url).headers("SIGNOZ-API-KEY": api_key)
  end

  # Returns a data structure detailing unique IP counts for sets of tags over a given time range.
  # { :duration => 1.second, :unique_ips => [10, 11]}
  # @return [Hash]
  def unique_ips_in_range(sets_of_tags, range)
    until_ms = (Time.now.to_f * 1000).to_i
    since_ms = until_ms - range.in_milliseconds

    payload = base_payload(since_ms, until_ms)
    sets_of_tags.each_with_index do |tags, index|
      payload[:compositeQuery][:queries] << create_tag_payload(tags, index)
    end

    @cache.fetch(cache_key(range, sets_of_tags), expires_in: cache_lifetime(range)) do
      # cache queries about a set of tags for their selected timespan
      @log.info("[Signoz] Fetching signoz query for #{sets_of_tags} for the last #{range.inspect}...")
      parse_request(payload)
    end
  end

  # Converts the stupid graphql return format into something more easily accessible
  def parse_request(payload)
    data = post_json("/api/v5/query_range", payload)

    {
      duration: (data["data"]["meta"]["durationMs"] / 1000.to_f).seconds,
      unique_ips: data["data"]["data"]["results"].sort_by { |q| q["queryName"] }.map { |q| q["data"] }.flatten,
    }
  end

  def cache_key(range, tags)
    :"signoz_count_tags_#{tags.flatten.sort.join("_")}_#{range.in_seconds}"
  end

  def cache_lifetime(range)
    # cache queries for a minimum of one hour, to a maximum of one day
    Fumimi::TimeRangeParser.clamp(range, min: 1.hour, max: 1.day).in_seconds
  end

  # Sends the query payload and returns parsed response JSON.
  #
  # @return [Hash]
  def post_json(path, payload)
    response = @http.use(:json).post(path, body: payload)

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

  def base_payload(since_ms, until_ms)
    {
      schemaVersion: "v1",
      start: since_ms,
      end: until_ms,
      requestType: "scalar",
      compositeQuery: {
        queries: [],
      },
      formatOptions: {
        formatTableResultForUI: false,
        fillGaps: false,
      },
      variables: {},
    }.with_indifferent_access
  end

  def create_tag_payload(tags, query_n)
    expressions = []
    expressions << "k8s.daemonset.name = 'nginx-ingress-controller'"
    expressions << "userAgent CONTAINS 'Mozilla/5.0' "
    expressions << "userAgent NOT CONTAINS 'compatible'" # googlebot, etc
    expressions << "url contains '/posts?'"
    expressions << "url contains 'tags='"

    tags.each do |tag|
      expressions << "url REGEXP '#{tag_regex(tag)}'"
    end

    {
      type: "builder_query",
      spec: {
        name: query_n.to_s,
        signal: "logs",
        filter: {
          expression: expressions.join(" AND "),
        },
        having: {
          expression: "",
        },
        aggregations: [{
          expression: "count_distinct(ip)",
        }],
      },
    }.with_indifferent_access
  end

  def tag_regex(tag)
    tag = URI.encode_www_form_component(tag)
    tag = Regexp.escape(tag)
    # Replace encoded asterisk back with a regex wildcard that stops at tag boundaries
    if tag.include? "\\*"
      tag = tag.gsub('\*', ".*")
      return tag
    end

    self.class.old_tag_regex(tag).source
  end

  def self.positive_tag_regex(tag)
    /(?i)(^|\+)(#{tag}(\+|$)|%28(.+\+)?#{tag}(\+|%29))/
  end

  def self.negative_tag_regex(tag)
    /(?i)(^|\+)(-#{tag}(\+|$)|-%28(.+\+)?#{tag}(\+|%29))/
  end

  def self.old_tag_regex(tag)
    /tags=(?i)(?:[^&]*\++\(?|[+(]*)(#{tag})([+&)]|$)/
  end
end
