require "date"

require "active_support/all"
require "prophet-rb"

class Fumimi::FutureReport
  include ActiveSupport::NumberHelper

  def initialize(event, booru)
    @event = event
    @booru = booru
  end

  def send_embed(embed)
    embed.title = title
    embed.description = "-# Requested by <@#{@event.user.id}>\n#{description}"
    embed
  end

  def title
    "Future GETs"
  end

  def description
    final_dates = []

    current_post = last_post_id
    get_index = 0

    short_term_forecast_data.map do |date, post_count|
      current_post += post_count.to_i
      target_post = future_gets[get_index]
      break if target_post.blank?

      if target_post < current_post
        get_index += 1
        final_dates << [target_post, "<t:#{date.to_time.to_i}:D>, <t:#{date.to_time.to_i}:R>"]
      end
    end

    long_term_forecast_data.to_a[12..].map do |date, post_count|
      current_post += post_count.to_i
      target_post = future_gets[get_index]
      break if target_post.blank?

      if target_post < current_post
        get_index += 1
        final_dates << [target_post, "#{Date::MONTHNAMES[date.month]} #{date.year}, <t:#{date.to_time.to_i}:R>"]
      end
    end

    final_dates.map do |target_post, date_string|
      "* post #{n_to_h(target_post)} - #{date_string}"
    end.join("\n")
  end

  def n_to_h(number)
    number_to_human(number, units: { million: "M" }, format: "%n%u")
  end

  def last_post_id
    @last_post_id ||= @booru.posts.index(limit: 1).first.id
  end

  def future_gets
    current_million, _current_submil = last_post_id.divmod(1_000_000)

    current_million *= 1_000_000
    (1..10).map do |n|
      current_million + (n * 1_000_000)
    end
  end

  def short_term_forecast_data
    dates = short_term_report.to_h do |each_month|
      [Date.parse(each_month["date"]), each_month["posts"]]
    end
    Prophet.forecast(dates, count: 365)
  end

  def long_term_forecast_data
    dates = long_term_report.to_h do |each_month|
      [Date.parse(each_month["date"]), each_month["posts"]]
    end
    Prophet.forecast(dates, count: 24)
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
