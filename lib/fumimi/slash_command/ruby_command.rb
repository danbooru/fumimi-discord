require "fumimi/slash_command"

class Fumimi::SlashCommand::RubyCommand < Fumimi::SlashCommand
  OWNERS = [310167383912349697, 1373735183425208331].freeze # rubocop:disable Style/NumericLiterals

  def self.name
    "ruby"
  end

  def self.description
    "Evaluate a Ruby expression (owners only)."
  end

  def self.options
    [
      { type: OPTION_TYPES[:string], name: "code", description: "Ruby code to evaluate.", required: true },
    ]
  end

  def message
    raise Fumimi::Exceptions::PermissionError unless OWNERS.include?(@event.user.id)

    result = instance_eval(arguments[:code].to_s)
    "`#{result.inspect}`"
  end
end
