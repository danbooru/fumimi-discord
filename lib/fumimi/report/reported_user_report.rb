class Fumimi::Report::ReportedUserReport
  include Fumimi::HasDiscordEmbed

  def initialize(reported_id:, reporter_id:, report_reason:)
    @reported_id = reported_id
    @reporter_id = reporter_id
    @report_reason = report_reason
  end

  def embed_title
    "Discord User Report"
  end

  def embed_color
    Fumimi::Colors::RED
  end

  def embed_fields
    [
      { name: "Reporter", value: "<@#{@reporter_id}>" },
      { name: "Reported user", value: "https://danbooru.donmai.us/users/#{@reported_id}" },
      { name: "Submitted at", value: "<t:#{Time.now.to_i}:R>" },
      { name: "Reason", value: @report_reason },
    ]
  end

  def buttons
    Discordrb::Webhooks::View.new.tap do |view|
      view.row do |row|
        row.button(
          label: "Mark as Handled",
          style: :danger,
          custom_id: "fumimi_user_report"
        )
      end
    end
  end
end
