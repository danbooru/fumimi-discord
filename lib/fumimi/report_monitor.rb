class Fumimi::ReportMonitor
  attr_reader :log, :booru

  def initialize(bot:, booru:, log:)
    @bot = bot
    @booru = booru
    @log = log
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
      c.name == ENV.fetch("DISCORD_REPORT_CHANNEL_NAME", "user-reports")
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
          log.error("ReportMonitor error: #{e.message}")
        end
        sleep 30
      end
    end
  end

  private

  def monitor_reports
    log.info("Scanning for new danbooru reports since ID #{last_report_id}")
    new_reports = booru.moderation_reports.index(limit: 20, "search[id]": ">#{last_report_id}")
    if new_reports.empty?
      log.info("No new danbooru reports found.")
      return
    end

    new_reports.sort_by(&:id).each { |report| send_report(report) }
    self.last_report_id = new_reports.map(&:id).max
  end

  def send_report(report)
    log.info("New danbooru report: #{report.id}. Sending it to ##{report_channel.name}...")
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
