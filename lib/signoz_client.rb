require "http"
require "json"
require "time"

class SigNozClient # rubocop:disable Metrics/ClassLength
  def initialize(base, api_key, log, cache)
    @base     = base
    @api_key  = api_key
    @log      = log
    @cache    = cache
  end

  def unique_ips_for_search(tags, range)
    until_ms = (Time.now.to_f * 1000).to_i
    since_ms = until_ms - range.in_milliseconds

    query_payload = base_payload(since_ms, until_ms)

    tags.each do |tag|
      tag_payload = tag_payload(tag)
      query_payload["compositeQuery"]["builderQueries"]["A"]["filters"]["items"].append(tag_payload)
    end

    @cache.get(:"signoz_count_tags_#{tags.join("_")}_#{range.in_milliseconds}", lifetime: range.in_seconds) do
      # cache queries about a tag for the selected timespan
      @log.info("[Signoz] Fetching signoz query for #{tags} for the last #{range.inspect}...")
      data = post_json("#{@base}/api/v4/query_range", query_payload)
      data["data"]["result"][0]["series"][0]["values"][0]["value"]
    end
  end

  def post_json(url, payload)
    response = HTTP.post(url,
                         json: payload,
                         headers: { Accept: "application/json", "SIGNOZ-API-KEY": @api_key })

    if response.code >= 400
      @log.info("[Signoz] Response: #{response.body}")
      raise "Signoz responded with HTTP #{response.code}"
    end

    parsed = JSON.parse(response.body).with_indifferent_access
    if parsed[:status] == "error"
      @log.info("[Signoz] Response: #{parsed}")
      raise "Signoz API response: error"
    end

    parsed
  end

  def base_payload(since_ms, until_ms)
    {
      start: since_ms,
      end: until_ms,
      variables: {},
      compositeQuery: {
        queryType: "builder",
        panelType: "table",
        builderQueries: {
          A: {
            dataSource: "logs",
            queryName: "A",
            aggregateOperator: "count_distinct",
            aggregateAttribute: {
              key: "ip", dataType: "string", type: "tag",
              isColumn: false, isJSON: false, id: "ip--string--tag--false",
            },
            timeAggregation: "count_distinct",
            spaceAggregation: "sum",
            functions: [],
            filters: {
              op: "AND",
              items: [
                {
                  id: "filter-method",
                  key: {
                    key: "method",
                    dataType: "string",
                    type: "tag",
                    isColumn: false,
                    isJSON: false,
                    id: "method--string--tag--false",
                  },
                  op: "=", value: "GET",
                },
                {
                  id: "filter-daemonset",
                  key: {
                    key: "k8s.daemonset.name",
                    dataType: "string",
                    type: "resource",
                    isColumn: false,
                    isJSON: false,
                    id: "k8s.daemonset.name--string--resource--false",
                  },
                  op: "=", value: "nginx-ingress-controller",
                },
                {
                  id: "filter-posts",
                  key: {
                    id: "------",
                    dataType: "string",
                    key: "body.url",
                    isColumn: false,
                    type: "", isJSON: true,
                  },
                  op: "contains", value: "/posts?",
                },
              ],
            },
            expression: "A",
          },
        },
      },
    }.with_indifferent_access
  end

  def tag_payload(tag_value)
    encoded = URI.encode_www_form_component(tag_value)

    escaped = Regexp.escape(encoded)

    # Replace encoded asterisk back with a regex wildcard that stops at tag
    # boundaries (won't cross + separators or & param separators)
    final = escaped.gsub('\*', '[^+&\s]*')

    # Matches a tag in a URL query string like:
    #   ?tags=foo+bar&other=x
    #
    # Asterisk (*) in input acts as a wildcard matching any characters up to
    # the next tag separator. e.g. "cat_*" matches "cat_foo", "cat_bar", etc.
    #
    # Two alternatives handle where the tag appears in the tags= value:
    #
    # 1. \+*<tag>(\+|&|\s|$)
    #    Tag at the START of tags= value (e.g. tags=cat_foo+bar)
    #    - \+*        : optional leading + separators between tags
    #    - <tag>      : the tag value (with wildcard expanded)
    #    - (\+|&|\s|$): must end at a separator, next param, whitespace, or EOS
    #
    # 2. [^&\s]*(=|\+)<tag>(\+|&|\s|$)
    #    Tag in the MIDDLE or preceded by key (e.g. tags=other+cat_foo+bar)
    #    - [^&\s]*    : any preceding characters (key name or other tag)
    #    - (=|\+)     : = (right after "tags") or + (between tags)
    #    - <tag>      : the tag value (with wildcard expanded)
    #    - (\+|&|\s|$): same trailing boundary as above
    pattern = /tags=(\+*#{final}(\+|&|\s|$)|[^&\s]*(=|\+)#{final}(\+|&|\s|$))/.source
    {
      id: "filter-url",
      key: {
        id: "------",
        dataType: "string",
        key: "body.url",
        isColumn: false,
        type: "",
        isJSON: true,
      },
      op: "REGEX", value: pattern,
    }
  end
end
