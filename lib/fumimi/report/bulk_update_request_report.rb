class Fumimi::Report::BulkUpdateRequestReport
  include Fumimi::HasDiscordEmbed

  def initialize(booru:, log:)
    @booru = booru
    @log = log
  end

  def embed_title
    "Pending BUR Stats"
  end

  def embed_description
    <<~EOF.chomp
      **Total pending BURs**: #{bulk_update_requests.count}
      * **Submitted in the past 24 hours**: #{latest_burs.count}
      * **About to expire**: [#{about_to_expire.count}](<#{about_to_expire_link}>)

      Top topics by pending requests:
    EOF
  end

  def embed_timestamp
    Time.now
  end

  def embed_fields
    fields = [{ inline: false, name: "", value: "" }]

    burs_by_topic.map do |_, burs|
      break if fields.length > 10

      topic = burs.first.forum_topic

      embed_name = topic.title
      embed_value = "[#{burs.count} pending](#{pending_link_for_topic(topic)})"

      fields << { inline: false, name: embed_name, value: embed_value }
    end

    fields
  end

  def bulk_update_requests
    @bulk_update_requests ||= @booru.bulk_update_requests.index(limit: 1000, "search[status]": "pending")
  end

  def burs_by_topic
    bulk_update_requests.group_by { |bur| bur.forum_topic.id }.sort_by { |_, bur| -bur.count }
  end

  def latest_burs
    bulk_update_requests.filter { |bur| bur.created_at > 24.hours.ago }
  end

  def about_to_expire
    bulk_update_requests.filter { |bur| bur.created_at < 40.days.ago }
  end

  def about_to_expire_link
    "#{@booru.url}/bulk_update_requests?search[status]=pending&search[created_at]=<#{40.days.ago.iso8601}"
  end

  def pending_link_for_topic(topic)
    "#{@booru.url}/bulk_update_requests?search[forum_topic_id]=#{topic.id}&search[status]=pending"
  end
end
