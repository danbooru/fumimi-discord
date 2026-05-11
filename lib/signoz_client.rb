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
    raise Fumimi::Exceptions::FumimiException, "SIGNOZ_URL is not configured." if base_url.blank?
    raise Fumimi::Exceptions::FumimiException, "SIGNOZ_API_KEY is not configured." if api_key.blank?

    @api_key     = api_key
    @log         = log
    @cache       = cache
    @http        = http.base_url(base_url).headers("SIGNOZ-API-KEY": api_key)
  end

  # Returns a data structure detailing unique IP counts for sets of tags over a given time range.
  # { :duration => 1.second, :unique_ips => [10, 11]}
  # @return [Hash]
  def unique_ips_in_range(tags, range)
    payload = base_payload(range)
    payload[:compositeQuery][:queries] << create_tag_payload(tags)

    @cache.fetch(cache_key(range, tags), expires_in: 3.minutes) do
      # cache queries about a set of tags for their selected timespan
      @log.info("[Signoz] Fetching signoz query for #{tags} for the last #{range.inspect}...")
      parse_request(payload)
    end
  end

  # Converts the stupid graphql return format into something more easily accessible
  def parse_request(payload)
    data = post_json("/api/v5/query_range", payload)

    {
      duration: (data["data"]["meta"]["durationMs"] / 1000.to_f).seconds,
      unique_ips: data["data"]["data"]["results"].sort_by { |q| q["queryName"] }.map { |q| q["data"] }.flatten,
      cached_at: Time.now.to_s,
    }
  end

  def cache_key(range, tags)
    :"signoz_count_tags_#{tags.flatten.sort.join("_")}_#{range}"
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

  def base_payload(range)
    {
      schemaVersion: "v1",
      start: range.begin.to_i * 1000,
      end: range.last.to_i * 1000,
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

  def create_tag_payload(tags)
    expressions = []
    expressions << "k8s.daemonset.name = 'nginx-ingress-controller'"
    expressions << "userAgent CONTAINS 'Mozilla/5.0' "
    expressions << "userAgent NOT CONTAINS 'compatible'" # googlebot, etc
    expressions << "url CONTAINS '/posts?tags='"
    expressions << "query_string_page NOT EXISTS"

    tags.each do |tag|
      expressions << "url REGEXP '#{tag_regex(tag)}'"
    end

    {
      type: "builder_query",
      spec: {
        name: "query",
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
    tag = tag.gsub('\*', ".*") if tag.include?("\\*")

    /tags=(?i)(?:[^&]*\++\(?|[+(]*)(#{tag})([+&)]|$)/.source
  end
end
