require "fumimi/slash_command"
require "active_support/number_helper"

class Fumimi::SlashCommand::CalcCommand < Fumimi::SlashCommand
  def self.name
    "calc"
  end

  def self.description
    "Calculate a mathematical expression."
  end

  def self.options(cmd)
    cmd.string("expression", "The math expression.", required: true)
  end

  def show_typing_activity?
    false
  end

  def message
    expr = arguments[:expression]

    result = Dentaku::Calculator.new.evaluate(expr)
    raise Fumimi::Exceptions::CommandArgumentError, "`#{expr}` is not a valid math expression." if result.nil?

    result = smart_round(result, sig_figs: 4) # => 0.000001

    # format big numbers
    result = ActiveSupport::NumberHelper.number_to_delimited(result, delimiter: "_")

    "`#{expr} = #{result}`"
  end

  # round up decimals without losing precision
  def smart_round(value, sig_figs: 4)
    return value if value.nil? || value == 0

    # Find the first significant digit position
    magnitude = Math.log10(value.to_f.abs).floor
    decimal_places = [sig_figs - 1 - magnitude, 0].max

    value.round(decimal_places)
  end
end
