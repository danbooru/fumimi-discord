require "google/cloud/bigquery"
require "terminal-table"

class Fumimi::BQ
  class BigQueryError < StandardError; end

  attr_reader :bq, :project, :dataset, :booru, :timeout

  def initialize(project:, dataset:, booru:, timeout: 60000)
    @project, @dataset, @booru, @timeout = project, dataset, booru, timeout
    @bq = Google::Cloud::Bigquery.new
  end

  def exec(query, **params)
    results = bq.query(query, project: project, dataset: dataset, standard_sql: true, timeout: timeout, **params)
    raise BigQueryError if results.job.failed?

    results
  end

  def query(query, **params)
    results = exec(query, **params)
    results.extend(BQMethods)

    results
  end

  module BQMethods
    def to_table(title="")
      rows = map(&:values)

      table = Terminal::Table.new do |t|
        t.headings = first.keys

        rows.each do |row|
          t << row
          break if t.to_s.size >= 1600
        end
      end

      body = to_s.force_encoding("UTF-8")
      footer = "#{table.rows.size} of #{total} rows | #{(job.ended_at - job.started_at).round(3)} seconds | #{total_bytes.to_s(:human_size)} (cached: #{cache_hit?})"

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
