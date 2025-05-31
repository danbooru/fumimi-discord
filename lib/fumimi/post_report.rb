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
    column_widths = generate_column_widths(headers, rows)

    table = "```\n"
    horizontal_separator = ""

    headers.each_with_index do |_header, index|
      column_width = column_widths[index]
      horizontal_separator << "+-#{"-" * column_width}-"
    end
    table << "#{horizontal_separator}+\n"

    headers.each_with_index do |header, index|
      column_width = column_widths[index]
      table << "| #{header.ljust(column_width)} "
    end
    table << "|\n"
    table << "#{horizontal_separator}+\n"

    rows.each do |row|
      row.each_with_index do |value, index|
        column_width = column_widths[index]
        table << "| #{value.to_s.ljust(column_width)} "
      end
      table << "|\n"
    end
    table << "#{horizontal_separator}+\n"

    table << "```"

    table
  end

  def generate_column_widths(headers, rows)
    # returns a list of widths for supplied headers + rows, for table autospacing
    headers.each_with_index.map do |header, index|
      column = rows.map { |l| l[index] }.map(&:to_s)
      max_column_width = column.max_by(&:length).length
      [header.length, max_column_width].max
    end
  end
end
