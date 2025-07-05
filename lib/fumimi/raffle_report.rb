class Fumimi::RaffleReport
  def initialize(event, booru, cache, topic_id)
    @event = event
    @booru = booru
    @cache = cache
    @topic_id = topic_id
  end

  def send_embed(embed)
    embed.description = "-# Requested by <@#{@event.user.id}>.\n#{description}"
    embed.title = "Raffle Report for Topic ##{@topic_id}"
    embed.url = forum_topic.url
    embed
  end

  def send_winner_embed(embed, winner_count)
    embed.description = "```\n#{winner_table(winner_count)}\n```"
    embed.title = "Winners for the Raffle in Topic ##{@topic_id}"
    embed.url = forum_topic.url
    embed
  end

  def description
    return "There is no currently active raffle!" if forum_topic.blank?
    return "There's no raffle in topic ##{@topic_id}!" unless forum_topic.title.downcase.include? "raffle"

    <<~EOS
      #{date_info}
      #{candidates.length} users have entered the raffle. Of these, #{valid_candidates.length} are eligible.
      They have submitted a total of #{total_uploads} posts, of which [#{total_pending} are pending](#{pending_link}).
      ```
      #{top_uploader_table}
      ```
    EOS
  end

  def forum_topic
    @forum_topic ||= @booru.forum_topics.show(@topic_id)
  end

  def end_date
    forum_topic.created_at.to_time + 3.days
  end

  def date_info
    if Time.now < end_date
      "This raffle ends: <t:#{end_date.to_i}:R>."
    else
      "This raffle ended: <t:#{end_date.to_i}:R>."
    end
  end

  def forum_posts
    @cache.get(:"raffle_#{@topic_id}_forum_posts", lifetime: cache_lifetime) do
      fp = []
      1.step do |page|
        page_posts = @booru.forum_posts.index("search[topic_id]": @topic_id, page: page)
        fp += page_posts

        break if page_posts.length < 1000
      end

      fp
    end
  end

  def candidates
    @candidates ||= forum_posts.pluck("creator").uniq(&:id)
  end

  def valid_candidates
    @valid_candidates = candidates.select { |c| c.level == 20 && c.created_at < forum_topic.created_at }
  end

  def valid_candidate_map
    valid_candidates.to_h { |c| [c.id, c] }
  end

  def cache_lifetime
    # if the forum topic is locked, the raffle is over, so cache indefinitely
    forum_topic.is_locked ? 2**32 : 30 * 60
  end

  def posts_by_user
    # create a map of posts by user for quick access and sorting
    @cache.get(:"raffle_#{@topic_id}_posts_by_user", lifetime: cache_lifetime) do
      count_map = Hash.new { |h, key| h[key] = Hash.new(0) } # a hash of type Hash[int: Hash[string: int]]
      candidate_ids = valid_candidates.pluck(:id)

      1.step do |page|
        raise Danbooru::Response::TimeoutError if page > 50 # abort if by some unknown reason the bot broke

        page_posts = @booru.posts.index(tags: post_search_string, page: page).to_a.each do |post|
          next unless candidate_ids.include? post.uploader.id
          next if post.uploader.is_banned

          count_map[post.uploader.id][:total] += 1
          if post.is_deleted
            count_map[post.uploader.id][:deleted] += 1
          elsif post.is_pending
            count_map[post.uploader.id][:pending] += 1
          else
            count_map[post.uploader.id][:active] += 1
          end
        end

        break if page_posts.length < 200
      end

      count_map.sort_by { |_id, posts| -posts[:total] }.to_h
    end
  end

  def total_uploads
    posts_by_user.values.pluck(:total).sum
  end

  def total_pending
    posts_by_user.values.pluck(:pending).sum
  end

  def pending_link
    "http://danbooru.donmai.us/modqueue?search[uploader][level]=20&search[uploader][is_banned]=false"
  end

  def post_search_string
    start_str = forum_topic.created_at.iso8601
    end_str = end_date.iso8601
    "order:id date:#{start_str}...#{end_str} (status:pending or approver:any)"
  end

  def top_uploaders
    posts_by_user.first(20).map { |i, _n| valid_candidate_map[i] }
  end

  def top_uploader_table
    # generate the table
    @top_uploader_table ||= begin
      headers = ["Top Users", "Ups", "✔", "?", "Tot"]
      rows = top_uploaders.map do |uploader|
        posts = posts_by_user[uploader.id]
        [uploader.name, posts[:total], posts[:active], posts[:pending], uploader.post_upload_count]
      end
      Fumimi::DiscordTable.new(headers: headers, rows: rows).prettified
    end
  end

  def winner_ids(winner_count)
    chances = valid_candidate_map.keys
    chances << posts_by_user.map do |user_id, count|
      [user_id] * count[:active]
    end
    chances.flatten!
    winners = winner_count.times.map do
      winner = chances.sample
      chances.delete(winner)
      winner
    end
    winners.sort
  end

  def winner_table(winner_count)
    headers = ["Winners", "ID", "Ups", "✔", "?", "Tot"]
    rows = winner_ids(winner_count).map do |winner_id|
      winner = valid_candidate_map[winner_id]
      posts = posts_by_user[winner_id]
      posts = Hash.new(0) if posts.blank?
      [winner.name, winner_id, posts[:total], posts[:active], posts[:pending], winner.post_upload_count]
    end
    Fumimi::DiscordTable.new(headers: headers, rows: rows).prettified
  end
end
