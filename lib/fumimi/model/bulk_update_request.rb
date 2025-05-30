require "fumimi/model"

class Fumimi::Model::BulkUpdateRequest < Fumimi::Model
  include Fumimi::HasDTextFields
  def embed(embed, channel) # rubocop:disable Lint/UnusedMethodArgument
    embed.title = shortlink
    embed.url = url

    embed.author = Discordrb::Webhooks::EmbedAuthor.new(
      name: forum_topic.title,
      url: try(:forum_post)&.url || forum_topic.url # for when a BUR is removed from a forum post
    )

    embed.description = pretty_bur

    embed.footer = embed_footer
    embed.footer.text = "Status: #{status.titleize} | #{embed_footer.text}"

    embed
  end

  def pretty_bur
    lines = script.split("\n").compact
    body = lines.first(10).join("\n")
    body += "\n...and #{lines.size - 10} more lines." if lines.size > 10
    sanitize_for_discord(body)
  end

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
    burs_by_topic.first(max_topics).map do |_, burs|
      topic = burs.first.forum_topic
      topic_pending_link = pending_link_for_topic(booru, topic)
      embed.fields << Discordrb::Webhooks::EmbedField.new(inline: false,
                                                          name: topic.title,
                                                          value: "[#{burs.count} pending](#{topic_pending_link})")
    end
  end

  def self.pending_link_for_topic(booru, topic)
    "#{booru.url}/bulk_update_requests?search[forum_topic_id]=#{topic.id}&search[status]=pending"
  end

  def self.about_to_expire_link(booru)
    "#{booru.url}/bulk_update_requests?search[status]=pending&search[created_at]=<#{40.days.ago.iso8601}"
  end
end
