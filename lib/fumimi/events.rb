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

  def self.respond(name, regex, &block)
    @@regex_listeners ||= []
    @@regex_listeners << { name: name, regex: regex, block: block }
  end

  respond(:post_id, /post #[0-9]+/i) do |event, text|
    post_id = text[/[0-9]+/].to_i

    post = booru.posts.show(post_id)
    post.create_embed(event.channel) if post.succeeded?
  end

  respond(:forum_id, /forum #[0-9]+/i) do |event, text|
    forum_post_id = text[/[0-9]+/].to_i

    forum_post = booru.forum_posts.show(forum_post_id)
    forum_post.create_embed(event.channel) if forum_post.succeeded? && !forum_post.hidden?
  end

  respond(:topic_id, /topic #[0-9]+/i) do |event, text|
    topic_id = text[/[0-9]+/]

    forum_posts = booru.forum_posts.search(topic_id: topic_id)
    forum_post = forum_posts.to_a.last
    forum_post.create_embed(event.channel) if forum_post.present? && !forum_post.hidden?
  end

  respond(:comment_id, /comment #[0-9]+/i) do |event, text|
    id = text[/[0-9]+/]

    comment = booru.comments.show(id)
    comment.create_embed(event.channel) if comment.succeeded?
  end

  respond(:bur_id, /bur #[0-9]+/i) do |event, text|
    id = text[/[0-9]+/]

    bur = booru.bulk_update_requests.show(id)
    bur.create_embed(event.channel) if bur.succeeded?
  end

  respond(:tag_link, /\[\[ [^\]]+ \]\]/x) do |event, text|
    title = text[/[^\[\]]+/]
    next unless title.present?

    event.channel.start_typing

    if title =~ /^user:(.*)/
      user = booru.users.index(name: ::Regexp.last_match(1))
      embed = user.create_embed(event.channel) if user.succeeded?
    elsif (tag = booru.tags.search(name_or_alias_matches: title).max_by(&:post_count)).present?
      embed = tag.create_embed(event.channel, searched_tag: title)
    else
      wiki_page = booru.wiki_pages.search(title_normalize: title).first
      if wiki_page.present?
        embed = wiki_page.create_embed(event.channel)
      else
        embed = Discordrb::Webhooks::Embed.new
        Fumimi::Model::WikiPage.fallback_embed(embed, title, booru)
      end
    end

    embed
  end

  respond(:search_link, /{{ [^\}]+ }}/x) do |event, text|
    search = text[/[^{}]+/]
    limit = (text[/limit:(\d+)/, 1] || 3).to_i

    event.channel.start_typing
    posts = booru.posts.index(limit: limit.clamp(1, 5), tags: search)

    posts.map { |post| post.create_embed(event.channel) }
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
    message = event.message.content.gsub(%r{\b(?!https?://\w+\.donmai\.us/posts/\d+/\w+)https?://(?!testbooru)\w+\.donmai\.us/posts/(\d+)\b[^[:space:]]*}i) do |link| # rubocop:disable Layout/LineLength
      post_ids << ::Regexp.last_match(1).to_i
      "<#{link}>"
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
    event.message.content.gsub(%r{\b(?!https?://\w+\.donmai\.us/users/\d+/\w+)https?://(?!testbooru)\w+\.donmai\.us/users/(\d+)\b[^[:space:]]*}i) do |link| # rubocop:disable Layout/LineLength
      user_ids << ::Regexp.last_match(1).to_i
      "<#{link}>"
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
