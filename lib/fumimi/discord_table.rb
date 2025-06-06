require "unicode/display_width/string_ext"

class Fumimi::DiscordTable
  # This class generates a table from a list of headers and list of rows
  # For example, with headers: [name, year]; rows: [["bowser", 2006], ["luigi_mario", 2007]]
  # * "luigi_mario" is longer than "bowser" and "name", so that's the max length for the first column (11)
  # * "2007", "2006" and "year" all have the same length, so the length of the second column is 4

  def initialize(headers:, rows:)
    @headers = headers
    @rows = rows
  end

  def to_s
    "```\n#{prettified}\n```"
  end

  def raw_table
    table = separator.to_s
    table << rendered_header
    table << separator

    return table if @rows.blank?

    table << rendered_rows
    table << separator
    table
  end

  def prettified
    # This makes the rows look neater
    # Lord forgive me but it's easier this way than generating them at table creation
    table_rows = raw_table.split("\n")
    table_rows.each_with_index.map do |row, index|
      if index == 0
        row.sub(/^┼/, "┌").sub(/┼$/, "┐").tr("┼", "┬")
      elsif index == table_rows.size - 1
        row.sub(/^┼/, "└").sub(/┼$/, "┘").tr("┼", "┴")
      else
        row.sub(/^┼/, "├").sub(/┼$/, "┤")
      end
    end.join("\n")
  end

  def rendered_header
    @headers.each_with_index.map do |header, index| # rubocop:disable Style/StringConcatenation
      column_width = column_widths[index]
      "│ #{ljust(header, column_width)} "
    end.join + "│\n"
  end

  def rendered_rows
    @rows.map do |row|
      row.each_with_index.map do |value, index| # rubocop:disable Style/StringConcatenation
        column_width = column_widths[index]
        "│ #{ljust(value, column_width)} "
      end.join + "│\n"
    end.join
  end

  def ljust(string, width)
    adjust = string.to_s.display_width - string.to_s.length
    # this is an ugly trick. tl;dr the discord monospace font displays ~3 kanji per 5 ascii characters
    # some alphabets like katakana still shift the text a bit, but this hack makes it a lot better
    adjust -= (adjust / 4).ceil + 1 if adjust > 0
    # don't ask me how this ratio exactly works, it came to me in a dream
    string.to_s.ljust(width - adjust)

    # before:
    # ┌─────────┬─────────┬───────┐
    # │ Name    │ Uploads │ %     │
    # ├─────────┼─────────┼───────┤
    # │ 葉月      │ 1,260   │ 70.71 │
    # │ 馮福水牛校軾昆 │ 405     │ 22.73 │
    # │ 紫希貴     │ 117     │ 6.57  │
    # └─────────┴─────────┴───────┘
    #
    # after:
    # ┌────────────────┬─────────┬───────┐
    # │ Name           │ Uploads │ %     │
    # ├────────────────┼─────────┼───────┤
    # │ 葉月            │ 1,260   │ 70.71 │
    # │ 馮福水牛校軾昆   │ 405     │ 22.73 │
    # │ 紫希貴          │ 117     │ 6.57  │
    # └────────────────┴─────────┴───────┘
  end

  def column_widths
    # returns a list of widths for supplied headers + rows, for table autospacing
    @headers.each_with_index.map do |header, index|
      column = @rows.map { |l| l[index] }.map(&:to_s)
      max_column_width = column.max_by(&:display_width)&.display_width || 0
      [header.display_width, max_column_width].max
    end
  end

  def separator
    @headers.each_with_index.map do |_header, index| # rubocop:disable Style/StringConcatenation
      column_width = column_widths[index]
      "┼─#{"─" * column_width}─"
    end.join + "┼\n"
  end
end
