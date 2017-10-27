require "google/cloud/bigquery"
require "terminal-table"

class BQ
  class BigQueryError < StandardError; end

  attr_reader :bq, :project, :dataset, :booru, :timeout, :max

  def initialize(project:, dataset:, booru:, timeout: 60000, max: 50)
    @project, @dataset, @booru, @timeout, @max = project, dataset, booru, timeout, max
    @bq = Google::Cloud::Bigquery.new
  end

  def exec(query)
    results = bq.query(query, project: project, dataset: dataset, standard_sql: true, timeout: timeout, max: max)
    raise BigQueryError if results.job.failed?

    results
  end

  def query(query)
    results = exec(query)
    results.extend(Formatter)
    resolve_user_ids!(results)

    results
  end

protected

  def resolve_user_ids!(results)
    user_ids = results.map { |row| row[:updater_id] || 13 }.uniq
    users = booru.users.search(id: user_ids.join(","))

    results.map! do |row|
      row.map do |k, v|
        if k == :updater_id
          [:updater, users.find { |user| user.id == v }.try(:name) || "MD Anonymous"]
        else
          [k, v]
        end
      end.to_h
    end
  end

  module Formatter
    def to_table
      rows = map(&:values)

      table = Terminal::Table.new do |t|
        t.headings = headers

        rows.each do |row|
          t << row
          break if t.to_s.size >= 1600
        end
      end

      body = to_s.force_encoding("UTF-8")
      footer = "#{table.rows.size} of #{total} rows | #{(job.ended_at - job.started_at).round(3)} seconds | #{total_bytes.to_s(:human_size)} (cached: #{cache_hit?})"

      "```\n#{table}\n#{footer}```"
    end
  end
end
