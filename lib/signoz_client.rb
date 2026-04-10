require "http"
require "json"
require "time"

class SigNozClient
  class SignozResponseChangedError < StandardError; end

  def initialize(base, api_key, log, cache)
    @base     = base
    @api_key  = api_key
    @log      = log
    @cache    = cache
  end

  def unique_ips_in_range(tags, range)
    until_ms = (Time.now.to_f * 1000).to_i
    since_ms = until_ms - range.in_milliseconds

    query_payload = create_payload(since_ms, until_ms, tags)

    @cache.get(:"signoz_count_tags_#{tags.join("_")}_#{range.in_milliseconds}", lifetime: range.in_seconds) do
      # cache queries about a tag for their selected timespan
      @log.info("[Signoz] Fetching signoz query for #{tags} for the last #{range.inspect}...")
      data = post_json("#{@base}/api/v5/query_range", query_payload)

      data["data"]["data"]["results"][0]["data"][0][0]
    end
  end

  def post_json(url, payload)
    response = HTTP.post(url,
                         json: payload,
                         headers: { Accept: "application/json", "SIGNOZ-API-KEY": @api_key })

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

  def create_payload(since_ms, until_ms, tags)
    # creates a payload for a query that gets the amount of searches for a tag every hour for the past 24 days
    expression = "(k8s.daemonset.name = 'nginx-ingress-controller' AND url CONTAINS '/posts?' AND url CONTAINS 'tags='"
    tags.each do |tag|
      expression += " and url REGEXP '#{tag_regex(tag)}'"
    end
    expression += ")"

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

  def normalize_tag(tag)
    # Normalize a tag so it can be properly interpolated in a regex query

    tag = URI.encode_www_form_component(tag)
    # escape regex
    tag = Regexp.escape(tag)

    # Replace encoded asterisk back with a regex wildcard that stops at tag boundaries
    tag = tag.gsub('\*', ".*")
    tag
  end

  def tag_regex(tag)
    tag = normalize_tag(tag)

    # tags=([^&]*\++\(?|[+(]*)    tags= can only be followed by:
    #       [^&]*\++\(*            anything except &, followed by space(s), and optional brackets, ex: tags=1girl+(tag
    #                   [+(]*      any amount of spaces and parentheses, ex: tags=++(tag
    # #{tag}
    # ([+&)]|$)                   a space, a &, an end bracket, or the end of line
    /tags=(?i)(?:[^&]*\++\(?|[+(]*)(#{tag})([+&)]|$)/.source
  end
end
