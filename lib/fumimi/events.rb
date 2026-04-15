require "active_support"

module Fumimi::Events
  extend ActiveSupport::Concern

  # TODO: implement asset #123 etc

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
