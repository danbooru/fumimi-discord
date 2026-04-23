require "date"

require "active_support/all"
require "prophet-rb"

class Fumimi::FutureReport
  include Fumimi::HasDiscordEmbed

  MAX_GETS = 10

  def initialize(booru:, cache:)
    @booru = booru
    @cache = cache
  end

  def embed_title
    "Future GETs"
  end

  def embed_description
    description = @cache.get(:future_report, lifetime: 60 * 60 * 24) do
      forecasted_milestones.map do |target_post, date_label|
        human_number = ActiveSupport::NumberHelper.number_to_human(target_post, units: { million: "M" }, format: "%n%u")
        "* post #{human_number} - #{date_label}"
      end.join("\n")
    end

    description + "\n\n#{cache_message(1.day)}"
  end

  def forecasted_milestones
    milestones = []
    current_post = last_post_id
    target_index = 0

    current_post, target_index = consume_forecast_points(
      short_term_forecast_data,
      current_post:,
      target_index:,
      milestones:,
      formatter: method(:short_date_label),
    )

    consume_forecast_points(
      # Skip the first year of long-term forecast because short-term data already
      # covers near dates with better day-level precision.
      long_term_forecast_data.to_a[12..],
      current_post:,
      target_index:,
      milestones:,
      formatter: method(:long_date_label),
    )

    milestones
  end

  # Walk through projected post counts and note when we cross each 1M milestone.
  def consume_forecast_points(points, current_post:, target_index:, milestones:, formatter:)
    points.each do |date, post_count|
      current_post += post_count.to_i
      target_post = future_gets[target_index]
      break if target_post.blank?
      next unless target_post < current_post

      target_index += 1
      milestones << [target_post, formatter.call(date)]
    end

    [current_post, target_index]
  end

  def short_date_label(date)
    "<t:#{date.to_time.to_i}:D>, <t:#{date.to_time.to_i}:R>"
  end

  def long_date_label(date)
    "#{Date::MONTHNAMES[date.month]} #{date.year}, <t:#{date.to_time.to_i}:R>"
  end

  def last_post_id
    @last_post_id ||= @booru.posts.index(limit: 1).first.id
  end

  def future_gets
    current_million, = last_post_id.divmod(1_000_000)
    current_million *= 1_000_000

    (1..MAX_GETS).map do |n|
      current_million + (n * 1_000_000)
    end
  end

  def short_term_forecast_data
    Prophet.forecast(series_for(short_term_report), count: 365)
  end

  def long_term_forecast_data
    Prophet.forecast(series_for(long_term_report), count: 24)
  end

  def series_for(report)
    report.to_h do |row|
      [Date.parse(row["date"]), row["posts"]]
    end
  end

  def short_term_report
    @short_term_report ||= @booru.post_reports.index(**short_term_search_params).as_json
  end

  def short_term_search_params
    {
      id: "posts",
      "search[from]": (Time.now - 3.months).strftime("%Y-%m-%d"),
      "search[to]": (Time.now + 1.day).strftime("%Y-%m-%d"),
      "search[period]": "day",
      limit: 1000,
    }
  end

  def long_term_report
    @long_term_report ||= @booru.post_reports.index(**long_term_search_params).as_json
  end

  def long_term_search_params
    {
      id: "posts",
      "search[from]": (Time.now - 2.years).strftime("%Y-%m-%d"),
      "search[to]": (Time.now + 1.day).strftime("%Y-%m-%d"),
      "search[period]": "month",
      limit: 100,
    }
  end
end
