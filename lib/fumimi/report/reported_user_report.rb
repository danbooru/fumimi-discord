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
      { name: "Submitted at", value: "<t:#{Time.now.to_i}:R>", inline: true },
      { name: "", value: "", inline: false },

      { name: "Reported User", value: reported_user_shortlink, inline: true },
      { name: "Reporter", value: "<@#{@reporter_id}>", inline: true },

      { name: "", value: "", inline: false },

      { name: "Reason", value: @report_reason },
    ]
  end

  def reported_user_shortlink
    "[User ##{@reported_id}](https://danbooru.donmai.us/users/#{@reported_id})"
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
