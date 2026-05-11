# Client for querying the SigNoz API.
#
# Required signoz configuration:
#
#   attributes.url -> donmai\.\w+(?<danbooru_path>[\w\/]+) -> attributes (Regex parser)
#   attributes.url -> tags=(?P<query_string_tags>[^&]*) -> attributes (Regex parser)
#
# Usage:
#
#   signoz = SignozClient.new
#
#   queries =
#     signoz
#     .query_set
#     .start(since.ago)
#     .end(Time.now)
#     .query("unique_ips") do |query|
#         query
#         .where("k8s.daemonset.name = 'nginx-ingress-controller'")
#         .where("userAgent CONTAINS 'Mozilla/5.0'")
#         .where("userAgent NOT CONTAINS 'compatible'") # googlebot, etc
#         .where("url CONTAINS '/posts?tags='")
#         .aggregate_by("count_distinct(ip)")
#     end
#
#   puts queries.results[:unique_ips]
#
class SignozClient
  # @param base_url [String] SigNoz base URL.
  # @param api_key [String] SigNoz API key header value.
  # @param log [Logger] Logger instance.
  # @param http [HTTPClient] HTTP client instance.
  # @param cache [Object] Cache object with `get` support.
  def initialize(base_url, api_key, log:, http:, cache:)
    raise Fumimi::Exceptions::FumimiException, "SIGNOZ_URL is not configured." if base_url.blank?
    raise Fumimi::Exceptions::FumimiException, "SIGNOZ_API_KEY is not configured." if api_key.blank?

    @api_key = api_key
    @log = log
    @cache = cache
    @http = http.base_url(base_url).headers("SIGNOZ-API-KEY": api_key)
  end

  # Perform a query_range request to the SigNoz API.
  #
  # @param payload [Hash] The query payload according to the SigNoz API specification.
  # @return [Hash] The parsed response from SigNoz.
  #
  # @see https://signoz.io/api-reference/v0.122.0#/operations/QueryRangeV5
  def query_range(payload)
    request("/api/v5/query_range", payload)
  end

  # Send a request to the SigNoz API and return the parsed response.
  #
  # @param path [String] The SigNoz API endpoint path.
  # @param body [Hash] The request body.
  # @return [Result] The response from SigNoz.
  def request(path, body)
    response = @http.use(:json).post(path, body: body)

    if response.code >= 400
      @log.info("[Signoz] Response: #{response.body}")
      raise "Signoz responded with HTTP #{response.code}."
    end

    parsed = JSON.parse(response.body).with_indifferent_access
    if parsed[:status] != "success"
      @log.info("[Signoz] Response: #{parsed}")
      raise "Signoz API response: unexpected status."
    end

    Result.new(parsed)
  end

  # @return [QuerySet] A new QuerySet instance for building and executing queries.
  def query_set
    QuerySet.new(self)
  end

  # The SigNoz API allows multiple queries to be sent together in a single request. A QuerySet consists of a set
  # of one or more SigNoz queries that are executed together, and a start and end time range for all the queries.
  class QuerySet
    attr_reader :signoz, :start_at, :end_at, :queries
    protected attr_writer :start_at, :end_at, :queries

    # @param signoz [SignozClient] The SignozClient instance to use for executing the queries.
    def initialize(signoz)
      @signoz = signoz
      @start_at = nil
      @end_at = nil
      @queries = []
      @results = nil
    end

    # @param time [Time] The start time for the query range.
    # @return [QuerySet] A new QuerySet instance with the specified start time.
    def start(time)
      dup.tap do |copy|
        copy.start_at = time
      end
    end

    # @param time [Time] The end time for the query range.
    # @return [QuerySet] A new QuerySet instance with the specified end time.
    def end(time)
      dup.tap do |copy|
        copy.end_at = time
      end
    end

    # Add a query to the query set.
    #
    # @param name [String] The name of the query.
    # @param signal [String] The signal (table) to query (e.g. "logs", "metrics", "traces")
    # @yieldparam query [Query] The Query instance to configure.
    # @return [QuerySet] A new QuerySet instance with the specified log query added.
    def query(name, signal = "logs", &block)
      dup.tap do |copy|
        query = yield Query.new(name, signal)
        copy.queries += [query]
      end
    end

    # @return [Result] The results from executing this query set against the SigNoz API.
    def results
      @results ||= signoz.request("/api/v5/query_range", payload)
    end

    # @return [Hash] The payload to send to the SigNoz query_range API for this query set.
    def payload
      {
        schemaVersion: "v1",
        start: start_at.to_i * 1000,
        end: end_at.to_i * 1000,
        requestType: "scalar",
        compositeQuery: {
          queries: queries.map(&:payload),
        },
        formatOptions: {
          formatTableResultForUI: false,
          fillGaps: false,
        },
        variables: {},
      }.with_indifferent_access
    end

    # The instance variables to include in the `.inspect` output for this object.
    def instance_variables_to_inspect
      instance_variable_names - ["@signoz"]
    end
  end

  # A Query represents a single query to be sent to the SigNoz API. A Query consists of a set of where clauses and at
  # least one aggregation. Multiple queries can be batched together in a QuerySet.
  class Query
    attr_reader :name, :signal, :where_clauses, :aggregations
    protected attr_writer :name, :signal, :where_clauses, :aggregations

    # Create a new Query for the logs signal.
    #
    # @param name [String] The name of the query, which will be used to identify the results in the response.
    # @return [Query] A new Query instance for the logs signal.
    def self.logs(name = "query")
      new(name, signal: "logs")
    end

    # @param name [String] The name of the query, which will be used to identify the results in the response.
    # @param signal [String] The signal (table) to query (e.g. "logs", "metrics", "traces")
    def initialize(name = "query", signal = "logs")
      @name = name
      @signal = signal
      @where_clauses = []
      @aggregations = []
    end

    # @param expression [String] A filter expression to add to the query (e.g. `url CONTAINS '/posts'`).
    # @return [Query] A new Query instance with the specified where clause added.
    def where(expression)
      return self if expression.blank?

      dup.tap do |copy|
        copy.where_clauses += [expression]
      end
    end

    # @param expression [String] An aggregation expression to add to the query (e.g. `count_distinct(ip)`).
    # @return [Query] A new Query instance with the specified aggregation added.
    def aggregate_by(expression)
      dup.tap do |copy|
        copy.aggregations += [{ expression: expression }]
      end
    end

    # @return [Hash] The payload to include in the SigNoz query_range API request for this query.
    def payload
      {
        type: "builder_query",
        spec: {
          name: name.to_s,
          signal: signal,
          filter: { expression: where_clauses.join(" AND ") },
          having: { expression: "" },
          aggregations: aggregations,
        },
      }
    end
  end

  # A Result represents the results returned by a SigNoz request.
  class Result
    attr_reader :results, :finished_at

    delegate :[], to: :query_results

    # @param results [Hash] The raw results hash returned from the SigNoz API.
    def initialize(results)
      @results = results.with_indifferent_access
      @finished_at = Time.now
    end

    # @return [Boolean] Whether the query was successful
    def success?
      results[:status] == "success"
    end

    # @return [ActiveSupport::Duration] Duration of the query execution.
    def duration
      (results.dig(:data, :meta, :durationMs) / 1000.0).seconds
    end

    # @return [Hash<String, Array>] The query results, keyed by query name. The values are arrays of the column values.
    def query_results
      results.dig(:data, :data, :results).index_by { |r| r[:queryName] }.with_indifferent_access.transform_values do |result|
        result[:columns].map.with_index do |_column, i|
          result.dig(:data, 0, i)
        end
      end
    end
  end
end
