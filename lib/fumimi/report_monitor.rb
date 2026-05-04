# Monitors /moderation_reports for new reports and sends them to the #user-reports channel.
class Fumimi::ReportMonitor
  delegate :start, :shutdown, :running?, to: :monitor

  # @param fumimi [Fumimi::Bot] Fumimi instance for accessing the bot and its configuration.
  # @param booru [Danbooru, nil] Booru client to use. Defaults to fumimi.booru.
  # @param id [Integer, nil] Starting ID for the monitor. If nil, starts from the latest record.
  def initialize(fumimi:, booru: fumimi&.booru, id: nil)
    @fumimi = fumimi
    @booru = booru
    @id = id
  end

  def monitor
    @monitor ||= Danbooru::Monitor.new(resource: @booru.moderation_reports, log: @fumimi.log, id: @id) do |report|
      send_report(report)
    end
  end

  def report_channel
    @report_channel ||= @fumimi.server.channels.find do |c|
      c.name == @fumimi.report_channel_name
    end
  end

  def send_report(report)
    report_channel.send_message("", false, report.embed, nil, nil, nil, report.buttons)
  end
end
