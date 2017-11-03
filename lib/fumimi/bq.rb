require "google/cloud/bigquery"
require "terminal-table"
require "fumimi/util"

class Fumimi::BQ
  class BigQueryError < StandardError; end

  attr_reader :bq, :project, :dataset

  def initialize(project:, dataset:, timeout: 60)
    @project, @dataset, @timeout = project, dataset, timeout
    @bq = Google::Cloud::Bigquery.new(timeout: timeout)
  end

  def exec(query, **params)
    job = bq.query_job(query, project: project, dataset: dataset, standard_sql: true, params: params)
    job.wait_until_done!
    raise BigQueryError.new(job.errors.map { |e| e["message"] }.join("\n")) if job.failed?

    job
  end

  def query(query, **params)
    job = exec(query, **params)

    results = job.data(max: 200)
    results.extend(BQMethods)
    results.instance_eval { @job = job }

    results
  end

  module BQMethods
    attr_reader :job

    def to_table(title="")
      rows = map(&:values)
      footer_size = "XXXX of #{total} rows (updated XXm ago) | XXXX seconds | X.XX GB ($X.XX)".size

      table = Terminal::Table.new do |t|
        t.headings = first.try(:keys)

        rows.each do |row|
          t << row
          break if title.size + t.to_s.size + footer_size >= 1900
        end
      end

      referencedTables = @job.stats.dig("query", "referencedTables") || []
      tables = referencedTables.map do |table|
        Google::Cloud::Bigquery.new(project: table["projectId"]).dataset(table["datasetId"]).table(table["tableId"])
      end
      last_updated = tables.map(&:modified_at).min || Time.current

      cost = 0.005 * @job.bytes_processed.to_f / (2**30) # 0.5 cents per gibibyte (https://cloud.google.com/bigquery/pricing#on_demand_pricing)
      footer = "#{table.rows.size} of #{total} rows (updated #{last_updated.to_pretty}) | #{(@job.ended_at - @job.started_at).round(1)} seconds | #{@job.bytes_processed.to_s(:human_size)} ($#{cost.round(2)})"

      "```\n#{title}\n#{table}\n#{footer}```".force_encoding("UTF-8")
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
