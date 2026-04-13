require "fumimi/model"

class Fumimi::Model::BulkUpdateRequest < Fumimi::Model
  include Fumimi::HasDTextFields

  # no embed, just embed the forum post instead so we can also get votes and argument

  def pretty_title
    "**[BUR ##{id}](#{url}) (#{status.titleize})**"
  end

  def pretty_script
    lines = normalized_script.split("\n")
    body = "```\n#{lines.first(10).join("\n\n")}```"
    body += "...and #{lines.size - 10} more lines." if lines.size > 10
    sanitize_for_discord(body)
  end

  def normalized_script
    script.split("\n").map do |line|
      line.gsub(/^create implication/, "imply")
          .gsub(/^remove implication/, "unimply")
          .gsub(/^create alias/, "alias")
          .gsub(/^remove alias/, "unalias")
          .gsub(/^mass update/, "update")
    end.map(&:strip).compact.join("\n").gsub(" -> ", " → ")
  end

  # def pretty_status
  #   color = case status
  #           when "approved" || "processing"
  #             "green"
  #           when "pending"
  #             "blue"
  #           else
  #             "red"
  #           end
  #   Fumimi::Colors.message_to_ansi(message: status.titleize, color: color)
  # end

  def self.send_embed_for_stats(embed, booru, max_topics: 5)
    bulk_update_requests = booru.bulk_update_requests.index(limit: 1000, "search[status]": "pending")
    latest_burs = bulk_update_requests.filter { |bur| bur.created_at > 24.hours.ago }
    about_to_expire = bulk_update_requests.filter { |bur| bur.created_at < 40.days.ago }

    embed.title = "Pending BUR Stats"

    embed.description = <<~EOF.chomp
      **Total pending BURs**: #{bulk_update_requests.count}
      * **Submitted in the past 24 hours**: #{latest_burs.count}
      * **About to expire**: [#{about_to_expire.count}](<#{about_to_expire_link(booru)}>)

      Top topics by pending requests:
    EOF

    embed.fields << Discordrb::Webhooks::EmbedField.new(inline: false, name: "", value: "")

    burs_by_topic = bulk_update_requests.group_by { |bur| bur.forum_topic.id }.sort_by { |_, bur| -bur.count }
    burs_by_topic.map do |_, burs|
      break if embed.fields.length > 10

      topic = burs.first.forum_topic
      topic_pending_link = pending_link_for_topic(booru, topic)

      embed_name = topic.title
      embed_value = "[#{burs.count} pending](#{topic_pending_link})"
      break if embed_length(embed) + embed_value.length + embed_name.length >= 5800

      embed.fields << Discordrb::Webhooks::EmbedField.new(inline: false, name: embed_name, value: embed_value)
    end
  end

  def self.pending_link_for_topic(booru, topic)
    "#{booru.url}/bulk_update_requests?search[forum_topic_id]=#{topic.id}&search[status]=pending"
  end

  def self.about_to_expire_link(booru)
    "#{booru.url}/bulk_update_requests?search[status]=pending&search[created_at]=<#{40.days.ago.iso8601}"
  end
end
