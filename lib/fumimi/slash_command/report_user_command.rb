require "fumimi/slash_command"

class Fumimi::SlashCommand::ReportUserCommand < Fumimi::SlashCommand
  def self.name
    "report"
  end

  def self.description
    "Report a danbooru user to the staff. Don't submit joke reports, or else."
  end

  def self.ephemeral?
    true
  end

  def self.options
    [
      { type: OPTION_TYPES[:integer], name: "user_id", description: "The danbooru user ID.", required: true },
      { type: OPTION_TYPES[:string], name: "reason", description: "The reason for the report.", required: true },
    ]
  end

  def report_reason
    reason = arguments[:reason]
    raise Fumimi::Exceptions::CommandArgumentError, "Reason must be below 1000 characters." if reason.length > 1000

    reason
  end

  def respond_to_event
    report = Fumimi::Report::ReportedUserReport.new(reported_id: arguments[:user_id],
                                                    reporter_id: @event.user.id,
                                                    report_reason: report_reason)

    mod_channel = @event.server.channels.detect do |c|
      c.name == @report_channel_name
    end
    mod_channel.send_message(
      "",
      false,
      report.embed,
      nil, # attachments
      nil, # allowed_mentions
      nil, # message_reference
      report.buttons, # components
    )
    @event.edit_response(content: "Your report has been submitted.")
  end
end
