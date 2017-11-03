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

    if job.failed?
      raise BigQueryError.new(job.errors.map { |e| e["message"] }.join("\n"))
    end

    job
  end

  def query(query, **params)
    job = exec(query, **params)

    results = job.data(max: 200)
    results.extend(BQMethods)
    results.instance_eval { @job = job }

    results
  end

  module ReportMethods
    def top_uploaders(period)
      query = <<-SQL
        SELECT
          updater_id AS uploader_id,
          COUNT(DISTINCT post_id) as uploads
        FROM `post_versions_flat_part`
        WHERE
          version = 1
          AND updated_at BETWEEN @start AND @finish
        GROUP BY updater_id
        ORDER BY uploads DESC
        LIMIT 20;
      SQL

      query(query, start: period.begin, finish: period.end)
    end

    def top_taggers(period)
      query = <<-SQL
        SELECT
          updater_id AS user_id,
          COUNTIF(added_tag IS NOT NULL) as tags_added,
          COUNTIF(removed_tag IS NOT NULL) as tags_removed,
          COUNT(DISTINCT post_id) AS posts_edited,
          COUNTIF(added_tag IS NOT NULL OR removed_tag IS NOT NULL) AS total_tags
        FROM `post_versions_flat_part`
        WHERE
          version > 1
          AND updated_at BETWEEN @start AND @finish
        GROUP BY updater_id
        ORDER BY 5 DESC
        LIMIT 20;
      SQL

      query(query, start: period.begin, finish: period.end)
    end

    def top_tags(period, cutoff)
      query = <<-SQL
        WITH
          added_tag_counts AS (
            SELECT added_tag AS tag, COUNT(*) AS added
            FROM `post_versions_flat_part`
            WHERE updated_at BETWEEN @start AND @finish
            GROUP BY added_tag
          ),
          removed_tag_counts AS (
            SELECT removed_tag AS tag, COUNT(*) AS removed
            FROM `post_versions_flat_part`
            WHERE updated_at BETWEEN @start AND @finish
            GROUP BY removed_tag
          ),
          total_tag_counts AS (
            SELECT
              COALESCE(added_tag, removed_tag) AS tag,
              COUNTIF(added_tag IS NOT NULL) - COUNTIF(removed_tag IS NOT NULL) AS count
            FROM `post_versions_flat_part`
            WHERE updated_at <= @finish
            GROUP BY COALESCE(added_tag, removed_tag)
          ),
          tag_stats AS (
            SELECT
              atc.tag AS tag,
              (CASE WHEN category = 0 THEN 'general' WHEN category = 1 THEN 'artist' WHEN category = 3 THEN 'copyright' WHEN category = 4 THEN 'character' ELSE 'unknown' END) AS category,
              COALESCE(added, 0) AS added,
              COALESCE(removed, 0) AS removed,
              COALESCE(ttc.count, 0) AS count
            FROM added_tag_counts atc
            LEFT OUTER JOIN removed_tag_counts rtc ON rtc.tag = atc.tag
            LEFT OUTER JOIN total_tag_counts ttc ON atc.tag = ttc.tag
            LEFT OUTER JOIN `tags` AS tags ON atc.tag = tags.name
          )
        SELECT
          tag,
          category,
          -- added,
          -- removed,
          added - removed AS net_change
          -- count AS total_count,
          -- ROUND(SAFE_DIVIDE(count, (count - (added - removed))) * 100 - 100, 1) AS percentage_change --- XXX safe divide returns NULLs instead of infinity, which sorts last.
        FROM tag_stats
        WHERE
          NOT REGEXP_CONTAINS(tag, '^(source|parent):')
          -- AND category_name = 'general'
          -- AND count - (added - removed) == 0 -- include only new tags
          AND ABS(ROUND(IEEE_DIVIDE(count, (count - (added - removed))) * 100 - 100, 1)) > @cutoff -- exclude large tags
        ORDER BY
          ABS(net_change) DESC
          -- percentage_change DESC
        LIMIT 200;
      SQL

      query(query, start: period.begin, finish: period.end, cutoff: cutoff)
    end

    def top_tags_for_user(user_id)
      query = <<-SQL
        WITH
          added_tags AS (
            SELECT
              added_tag AS tag,
              COUNT(*) AS added
            FROM `post_versions_flat_part`
            WHERE
              updater_id = @user_id
              AND added_tag IS NOT NULL
              AND NOT REGEXP_CONTAINS(added_tag, '^(source|parent):')
            GROUP BY added_tag
          ),
          removed_tags AS (
            SELECT
              removed_tag AS tag,
              COUNT(*) AS removed
            FROM `post_versions_flat_part`
            WHERE
              updater_id = @user_id
              AND removed_tag IS NOT NULL
              AND NOT REGEXP_CONTAINS(removed_tag, '^(source|parent):')
            GROUP BY removed_tag
          )

        SELECT
          added_tags.tag,
          added,
          removed,
          added + removed AS total
        FROM added_tags
        LEFT OUTER JOIN removed_tags ON added_tags.tag = removed_tags.tag
        ORDER BY 4 DESC;
      SQL

      query(query, user_id: user_id)
    end

    def tag_creator(tag)
      query = <<-SQL
        SELECT
          pv.added_tag AS tag,
          (CASE WHEN category = 0 THEN 'general' WHEN category = 1 THEN 'artist' WHEN category = 3 THEN 'copyright' WHEN category = 4 THEN 'character' ELSE 'unknown' END) AS category,
          t.count,
          pv.updater_id AS creator_id,
          pv.updated_at AS created_at,
          pv.post_id
        FROM `post_versions_flat_part` AS pv
        LEFT OUTER JOIN `tags` AS t ON pv.added_tag = t.name
        WHERE pv.added_tag = @tag
        ORDER BY pv.updated_at ASC
        LIMIT 1;
      SQL

      query(query, tag: tag)
    end

    def tag_usage_by_group(tag, group_key, alias_name, order)
      query = <<-SQL
        SELECT
          #{group_key} AS #{alias_name},
          COUNTIF(added_tag = @tag) AS added_count,
          COUNTIF(removed_tag = @tag) AS removed_count,
          COUNTIF(added_tag = @tag OR removed_tag = @tag) AS total_count
        FROM
          `post_versions_flat_part`
        WHERE
          added_tag = @tag OR removed_tag = @tag
        GROUP BY #{alias_name}
        ORDER BY #{order};
      SQL

      query(query, tag: tag)
    end

    def tags_created_by_user(user_id, categories)
      query = <<-SQL
        WITH
          initial_tags AS (
            SELECT
              added_tag,
              MIN(updated_at) AS updated_at
            FROM `post_versions_flat_part`
            GROUP BY added_tag
          )
        SELECT
          DISTINCT it.added_tag,
          t.count
        FROM `post_versions` AS pv
        JOIN initial_tags AS it ON pv.updated_at = it.updated_at
        LEFT OUTER JOIN `tags` AS t ON t.name = added_tag
        WHERE
          pv.updater_id = @user_id
          AND NOT REGEXP_CONTAINS(added_tag, '^source:|parent:')
          AND t.category IN (#{categories.join(", ")})
        ORDER BY count DESC;
      SQL

      query(query, user_id: user_id)
    end
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

  include ReportMethods
end
