class Fumimi::Report::ReportReport
  include Fumimi::HasDiscordEmbed

  def initialize(reporter_id:, report_reason:, booru:)
    @reporter_id = reporter_id
    @report_reason = report_reason
    @booru = booru
  end

  def embed_title
    "Discord Report"
  end

  def embed_color
    Fumimi::Colors::RED
  end

  def embed_fields
    [
      { name: "Submitted at", value: "<t:#{Time.now.to_i}:R>", inline: true },
      { name: "", value: "", inline: false },

      { name: "Reporter", value: "<@#{@reporter_id}>", inline: true },

      { name: "", value: "", inline: false },

      { name: "Reason", value: @report_reason },
    ]
  end

  def buttons
    Discordrb::Webhooks::View.new.tap do |view|
      view.row do |row|
        row.button(
          label: "Mark as Handled",
          style: :danger,
          custom_id: "fumimi_user_report",
        )
      end
    end
  end
end
