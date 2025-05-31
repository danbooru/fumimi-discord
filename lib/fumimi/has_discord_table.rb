require "unicode/display_width/string_ext"

module Fumimi::HasDiscordTable
  def generate_table(headers:, rows:)
    # This function generates a table from a list of headers and list of rows
    # For example, with headers: [name, year]; rows: [["bowser", 2006], ["luigi_mario", 2007]]
    # * "luigi_mario" is longer than "bowser" and "name", so that's the max length for the first column (11)
    # * "2007", "2006" and "year" all have the same length, so the length of the second column is 4

    column_widths = generate_column_widths(headers, rows)

    table = "```\n"

    horizontal_separator = ""
    headers.each_with_index do |_header, index|
      column_width = column_widths[index]
      horizontal_separator << "┼─#{"─" * column_width}─"
    end

    table << "#{horizontal_separator}┼\n"

    headers.each_with_index do |header, index|
      column_width = column_widths[index]
      table << "│ #{ljust(header, column_width)} "
    end
    table << "│\n"
    table << "#{horizontal_separator}┼\n"

    rows.each do |row|
      row.each_with_index do |value, index|
        column_width = column_widths[index]
        table << "│ #{ljust(value, column_width)} "
      end
      table << "│\n"
    end
    table << "#{horizontal_separator}┼\n"

    table << "```"
    prettify_table(table)
  end

  def ljust(string, width)
    adjust = string.display_width - string.length
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

  def prettify_table(table)
    # This makes the rows look neater
    # Lord forgive mem but it's easier this way than generating them at table creation
    table_rows = table.split("\n")
    table_rows.each_with_index.map do |row, index|
      if index == 1
        row.sub(/^┼/, "┌").sub(/┼$/, "┐").tr("┼", "┬")
      elsif index == table_rows.size - 2
        row.sub(/^┼/, "└").sub(/┼$/, "┘").tr("┼", "┴")
      else
        row.sub(/^┼/, "├").sub(/┼$/, "┤")
      end
    end.join("\n")
  end

  def generate_column_widths(headers, rows)
    # returns a list of widths for supplied headers + rows, for table autospacing
    headers.each_with_index.map do |header, index|
      column = rows.map { |l| l[index] }.map(&:to_s)
      max_column_width = column.max_by(&:display_width).display_width
      [header.display_width, max_column_width].max
    end
  end
end
