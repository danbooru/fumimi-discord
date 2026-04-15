require "active_support"

module Fumimi::Events
  extend ActiveSupport::Concern

  def respond_to_embeds(event)
    text = event.text.gsub(/```.*?```/m, "").gsub(/`.*?`/m, "")

    @@regex_listeners.each do |message|
      message => { name:, regex:, block: }
      matches = text.scan(regex)

      embeds = []
      matches.uniq.each do |match|
        log.info("Received command '#{match}' from user ##{event&.user&.id} '#{event&.user&.username}' in channel '##{event&.channel&.name}'") # rubocop:disable Layout/LineLength
        embeds << instance_exec(event, match, &block)
      end
      embeds = embeds.flatten.compact
      event.channel.send_embed("", embeds) if embeds.present?
    end
  end

  # TODO: implement asset #123 etc

  def self.respond(name, regex, &block)
    @@regex_listeners ||= []
    @@regex_listeners << { name: name, regex: regex, block: block }
  end

  respond(:artist_id, /artist #[0-9]+/i) do |event, text|
    id = text[/[0-9]+/]
    event.channel.send_message("https://danbooru.donmai.us/artists/#{id}")
    nil
  end

  respond(:pixiv_id, /pixiv #[0-9]+/i) do |event, text|
    id = text[/[0-9]+/]
    event.channel.send_message("https://www.pixiv.net/artworks/#{id}")
    nil
  end

  respond(:pool_id, /pool #[0-9]+/i) do |event, text|
    id = text[/[0-9]+/]
    event.channel.send_message("https://danbooru.donmai.us/pools/#{id}")
    nil
  end

  respond(:user_id, /user #[0-9]+/i) do |event, text|
    id = text[/[0-9]+/]

    event.channel.start_typing

    user = booru.users.show(id)
    user.create_embed(event.channel) if user.succeeded?
  end

  respond(:issue_id, /issue #[0-9]+/i) do |event, text|
    issue_id = text[/[0-9]+/]
    event.channel.send_message "https://github.com/danbooru/danbooru/issues/#{issue_id}"
    nil
  end

  respond(:pull_id, /pull #[0-9]+/i) do |event, text|
    pull_id = text[/[0-9]+/]
    event.channel.send_message "https://github.com/danbooru/danbooru/pull/#{pull_id}"
    nil
  end

  def do_convert_post_links(event)
    event.message.suppress_embeds

    post_ids = []
    event.message.content.gsub(%r{\b(?!https?://\w+\.donmai\.us/posts/\d+/\w+)https?://(?!testbooru)\w+\.donmai\.us/posts/(\d+)\b[^[:space:]]*}i) do # rubocop:disable Layout/LineLength
      post_ids << ::Regexp.last_match(1).to_i
    end
    post_ids.uniq!

    return unless post_ids.present?

    log.info("Converting post links in message '#{event.message.content}' from user ##{event&.user&.id} '#{event&.user&.username}' to post embeds") # rubocop:disable Layout/LineLength

    posts = booru.posts.index(tags: "id:#{post_ids.join(",")} order:custom")
    posts = posts.first(3).map { |post| post.create_embed(event.channel) }.compact
    event.channel.send_embed("", posts) if posts.present?
  end

  def do_convert_user_links(event)
    user_ids = []
    event.message.content.gsub(%r{\b(?!https?://\w+\.donmai\.us/users/\d+/\w+)https?://(?!testbooru)\w+\.donmai\.us/users/(\d+)\b[^[:space:]]*}i) do # rubocop:disable Layout/LineLength
      user_ids << ::Regexp.last_match(1).to_i
    end
    user_ids.uniq!

    return unless user_ids.present?

    log.info("Converting user links in message '#{event.message.content}' from user ##{event&.user&.id} '#{event&.user&.username}' to user embeds") # rubocop:disable Layout/LineLength
    users = user_ids.map do |user_id|
      user = booru.users.show(user_id)

      next unless user.succeeded?

      user.create_embed(event.channel)
    end.compact

    event.channel.send_embed("", users) if users.present?
  end
end
