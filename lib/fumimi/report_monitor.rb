class Fumimi::ReportMonitor
  attr_reader :log, :booru

  def initialize(fumimi: nil, bot: fumimi&.bot, booru: fumimi&.booru, log: fumimi&.log, report_channel_name: fumimi&.report_channel_name)
    @bot = bot
    @booru = booru
    @log = log || Logger.new(nil)
    @report_channel_name = report_channel_name || "user-reports"
    @report_channel = report_channel
  end

  def last_report_id
    @mutex.synchronize { @last_report_id }
  end

  def last_report_id=(id)
    @mutex.synchronize { @last_report_id = id }
  end

  def report_channel
    @report_channel ||= @bot.servers.values.map(&:channels).flatten.detect do |c|
      c.name == @report_channel_name
    end
  end

  def start
    @mutex = Mutex.new
    self.last_report_id = booru.moderation_reports.index(limit: 1).first&.id || 0
    log.info("Starting to monitor for new user reports...")

    Thread.new do
      loop do
        begin
          monitor_reports
        rescue StandardError => e
          log.error(e)
        end
        sleep 30
      end
    end
  end

  private

  def monitor_reports
    new_reports = booru.moderation_reports.index(limit: 20, "search[id]": ">#{last_report_id}")
    return if new_reports.empty?

    new_reports.sort_by(&:id).each { |report| send_report(report) }
    self.last_report_id = new_reports.map(&:id).max
  end

  def send_report(report)
    report_channel.send_message(
      "",
      false,
      report.embed,
      nil,
      nil,
      nil,
      report.buttons
    )
  end
end
