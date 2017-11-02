require "google/cloud/bigquery"
require "terminal-table"

class Fumimi::BQ
  class BigQueryError < StandardError; end

  attr_reader :bq, :project, :dataset, :booru

  def initialize(project:, dataset:, booru:, timeout: 60)
    @project, @dataset, @booru, @timeout = project, dataset, booru, timeout
    @bq = Google::Cloud::Bigquery.new(timeout: timeout)
  end

  def exec(query, **params)
    job = bq.query_job(query, project: project, dataset: dataset, standard_sql: true, params: params)
    job.wait_until_done!
    raise BigQueryError if job.failed?

    job
  end

  def query(query, **params)
    job = exec(query, **params)

    results = job.query_results
    results.extend(BQMethods)
    results.instance_eval { @job = job }

    results
  end

  module BQMethods
    def to_table(title="")
      rows = map(&:values)

      table = Terminal::Table.new do |t|
        t.headings = first.try(:keys)

        rows.each do |row|
          t << row
          break if t.to_s.size >= 1600
        end
      end

      body = to_s.force_encoding("UTF-8")
      cost = 0.005 * @job.bytes_processed.to_f / (2**30) # 0.5 cents per gibibyte (https://cloud.google.com/bigquery/pricing#on_demand_pricing)
      footer = "#{table.rows.size} of #{total} rows | #{(@job.ended_at - @job.started_at).round(3)} seconds | #{@job.bytes_processed.to_s(:human_size)} ($#{cost.round(2)}) | cached: #{@job.cache_hit?}"

      "```\n#{title}\n#{table}\n#{footer}```"
    end

    def resolve_user_ids!(booru)
      id_field = /(updater|creator|user|uploader)_id/

      id_fields = headers.grep(id_field)
      user_ids = map { |row| row.values_at(*id_fields) }.flatten.compact.sort.uniq
      users = booru.users.search(id: user_ids.join(","))

      map! do |row|
        row.map do |k, v|
          if k =~ id_field
            [$1.to_sym, users.find { |user| user.id == v }.try(:name) || "MD Anonymous"]
          else
            [k, v]
          end
        end.to_h
      end

      self
    end
  end
end
