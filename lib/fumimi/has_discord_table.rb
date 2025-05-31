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
      table << "│ #{header.ljust(column_width)} "
    end
    table << "│\n"
    table << "#{horizontal_separator}┼\n"

    rows.each do |row|
      row.each_with_index do |value, index|
        column_width = column_widths[index]
        table << "│ #{value.to_s.ljust(column_width)} "
      end
      table << "│\n"
    end
    table << "#{horizontal_separator}┼\n"

    table << "```"
    prettify_table(table)
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
      max_column_width = column.max_by(&:length).length
      [header.length, max_column_width].max
    end
  end
end
