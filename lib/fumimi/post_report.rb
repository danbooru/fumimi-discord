class Fumimi::PostReport
  def initialize(booru, tags)
    @booru = booru
    @tags = tags
  end

  def send_embed(embed)
    embed.title = title
    embed.url = url

    if total_posts == 0
      embed.description = "No posts under that search!"
    else
      embed.description = generate_table(headers: headers, rows: rows)
    end
    embed
  end

  def url
    "#{@booru.url}/reports/posts?#{search_params.to_query}"
  end

  def total_posts
    @total_posts ||= @booru.counts.index(tags: @tags.join(" ")).counts.posts
  end

  def start_date
    "2005-05-24"
  end

  def end_date
    Time.now.strftime("%Y-%m-%d")
  end

  def report
    @report ||= @booru.post_reports.index(**search_params).as_json
  end

  def generate_table(headers:, rows:)
    column_lengths = []

    headers.each_with_index do |header, index|
      column = rows.map { |l| l[index] }.map(&:to_s)
      max_column_length = column.max_by(&:length).length
      column_lengths << [header.length, max_column_length].max
    end

    table = "```\n"
    horizontal_separator = ""

    headers.each_with_index do |_header, index|
      column_length = column_lengths[index]
      horizontal_separator << "+-#{"-" * column_length}-"
    end
    table << "#{horizontal_separator}+\n"

    headers.each_with_index do |header, index|
      column_length = column_lengths[index]
      table << "| #{header.ljust(column_length)} "
    end
    table << "|\n"
    table << "#{horizontal_separator}+\n"

    rows.each do |row|
      row.each_with_index do |value, index|
        column_length = column_lengths[index]
        table << "| #{value.to_s.ljust(column_length)} "
      end
      table << "|\n"
    end
    table << "#{horizontal_separator}+\n"

    table << "```"

    table
  end
end
