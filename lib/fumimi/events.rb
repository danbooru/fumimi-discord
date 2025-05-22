require "active_support"

module Fumimi::Events
  extend ActiveSupport::Concern

  def self.respond(name, regex, &block)
    @@messages ||= []
    @@messages << { name: name, regex: regex }

    define_method(:"do_#{name}") do |event, *args|
      matches = event.text.scan(/(?<!`)#{regex}(?!`)/)

      matches.each do |match|
        log.info("Received command '#{match}' from user ##{event&.user&.id} '#{event&.user&.username}' in channel '##{event&.channel&.name}'") # rubocop:disable Layout/LineLength
        instance_exec(event, match, &block)
      end

      nil
    end
  end

  respond(:post_id, /post #[0-9]+/i) do |event, text|
    post_id = text[/[0-9]+/].to_i

    post = booru.posts.show(post_id)
    post.send_embed(event.channel)
  end

  respond(:forum_id, /forum #[0-9]+/i) do |event, text|
    forum_post_id = text[/[0-9]+/].to_i

    forum_post = booru.forum_posts.show(forum_post_id)
    Fumimi::Model::ForumPost.render_forum_posts(event.channel, [forum_post])
  end

  respond(:topic_id, /topic #[0-9]+/i) do |event, text|
    topic_id = text[/[0-9]+/]

    forum_post = booru.forum_posts.search(topic_id: topic_id).to_a.last
    Fumimi::Model::ForumPost.render_forum_posts(event.channel, [forum_post])
  end

  respond(:comment_id, /comment #[0-9]+/i) do |event, text|
    id = text[/[0-9]+/]

    comment = booru.comments.show(id)
    Fumimi::Model::Comment.render_comments(event.channel, [comment])
  end

  respond(:tag_link, /\[\[ [^\]]+ \]\]/x) do |event, text|
    title = text[/[^\[\]]+/]

    event.channel.start_typing
    Fumimi::Model::Tag.render_tag_preview(event.channel, title, booru)
  end

  respond(:search_link, /{{ [^\}]+ }}/x) do |event, text|
    search = text[/[^{}]+/]
    limit = text[/limit:(\d+)/, 1].to_i

    event.channel.start_typing
    posts = booru.posts.index(limit: limit.clamp(1, 3), tags: search)

    posts.each do |post|
      post.send_embed(event.channel)
    end
  end

  respond(:artist_id, /artist #[0-9]+/i) do |event, text|
    id = text[/[0-9]+/]
    event << "https://danbooru.donmai.us/artists/#{id}"
  end

  respond(:note_id, /note #[0-9]+/i) do |event, text|
    id = text[/[0-9]+/]

    note = booru.notes.show(id)
    event << "https://danbooru.donmai.us/posts/#{note.post_id}#note-#{note.id}"
  end

  respond(:pixiv_id, /pixiv #[0-9]+/i) do |event, text|
    id = text[/[0-9]+/]
    event << "https://www.pixiv.net/member_illust.php?mode=medium&illust_id=#{id}"
  end

  respond(:pool_id, /pool #[0-9]+/i) do |event, text|
    id = text[/[0-9]+/]
    event << "https://danbooru.donmai.us/pools/#{id}"
  end

  respond(:user_id, /user #[0-9]+/i) do |event, text|
    id = text[/[0-9]+/]

    event.channel.start_typing

    user = booru.users.show(id)
    user.send_embed(event.channel)
  end

  respond(:issue_id, /issue #[0-9]+/i) do |event, text|
    issue_id = text[/[0-9]+/]
    event.send_message "https://github.com/danbooru/danbooru/issues/#{issue_id}"
  end

  respond(:pull_id, /pull #[0-9]+/i) do |event, text|
    pull_id = text[/[0-9]+/]
    event.send_message "https://github.com/danbooru/danbooru/pull/#{pull_id}"
  end

  def do_convert_post_links(event)
    post_ids = []
    message = event.message.content.gsub(%r{\b(?!https?://\w+\.donmai\.us/posts/\d+/\w+)https?://(?!testbooru)\w+\.donmai\.us/posts/(\d+)\b[^[:space:]]*}i) do |link| # rubocop:disable Layout/LineLength
      post_ids << ::Regexp.last_match(1).to_i
      "<#{link}>"
    end
    post_ids.uniq!

    return unless post_ids.present?

    event.message.delete
    log.info("Converting post links in message '#{event.message.content}' from user ##{event&.user&.id} '#{event&.user&.username}' to post embeds") # rubocop:disable Layout/LineLength
    event.send_message("<@#{event.author.id}> posted: #{message}")

    posts = booru.posts.index(tags: "id:#{post_ids.join(",")} order:custom")
    posts.first(3).each { |post| post.send_embed(event.channel) }
  end

  def do_convert_user_links(event)
    user_ids = []
    event.message.content.gsub(%r{\b(?!https?://\w+\.donmai\.us/users/\d+/\w+)https?://(?!testbooru)\w+\.donmai\.us/users/(\d+)\b[^[:space:]]*}i) do |link| # rubocop:disable Layout/LineLength
      user_ids << ::Regexp.last_match(1).to_i
      "<#{link}>"
    end
    user_ids.uniq!

    return unless user_ids.present?

    log.info("Converting user links in message '#{event.message.content}' from user ##{event&.user&.id} '#{event&.user&.username}' to user embeds") # rubocop:disable Layout/LineLength
    user_ids.each do |user_id|
      user = booru.users.show(user_id)

      next unless user.succeeded?

      user.send_embed(event.channel)
    end
  end
end
