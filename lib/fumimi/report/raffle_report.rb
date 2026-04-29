class Fumimi::Report::RaffleReport
  include Fumimi::HasDiscordEmbed

  def initialize(booru:, cache:, winner_count: 0)
    @booru = booru
    @cache = cache
    @winner_count = winner_count
  end

  def embed_title
    if @winner_count.zero?
      "Raffle Report for Topic ##{forum_topic.id}"
    else
      "Winners for the Raffle in Topic ##{forum_topic.id}"
    end
  end

  def embed_url
    forum_topic.url
  end

  def forum_topic
    @forum_topic ||= Fumimi::Model::ForumTopic.latest_raffle_topic(@booru)
  end

  def embed_description
    if @winner_count.zero?
      raffle_stats
    else
      <<~EOF
        ```
        #{raffle_winners}
        ```
      EOF
    end
  end

  def raffle_stats
    <<~EOS
      #{date_info}
      #{candidates.length} users have entered the raffle. Of these, #{valid_candidates.length} are eligible.
      They have submitted a total of #{total_uploads} posts, of which [#{total_pending} are pending](#{pending_link}).
      ```
      #{top_uploader_table}
      ```
    EOS
  end

  def raffle_winners
    headers = ["Winners", "ID", "Ups", "✔", "?", "Tot"]
    rows = winner_ids.map do |winner_id|
      winner = valid_candidate_map[winner_id]
      posts = posts_by_user[winner_id]
      posts = Hash.new(0) if posts.blank?
      [winner.name, winner_id, posts[:total], posts[:active], posts[:pending], winner.post_upload_count]
    end
    Fumimi::DiscordTable.new(headers: headers, rows: rows).prettified
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
    @cache.fetch(:"#{cache_key}_forum_posts", expires_in: cache_lifetime) { forum_topic.all_posts }
  end

  def candidates
    @candidates ||= forum_posts.pluck("creator").uniq(&:id)
  end

  def valid_candidates
    @valid_candidates ||= candidates.select { |c| c.level == 20 && c.created_at < forum_topic.created_at }
  end

  def valid_candidate_map
    valid_candidates.to_h { |c| [c.id, c] }
  end

  def valid_candidate_ids
    @valid_candidate_ids ||= valid_candidates.pluck(:id)
  end

  def cache_key
    # make sure we get new results if the raffle ends during a cache's lifetime
    :"raffle_#{forum_topic.id}_l#{forum_topic.is_locked}"
  end

  def cache_lifetime
    # if the forum topic is locked, the raffle is over, so cache indefinitely
    30.minutes unless forum_topic.is_locked
  end

  def post_search_string
    start_str = forum_topic.created_at.iso8601
    end_str = end_date.iso8601
    "date:#{start_str}...#{end_str} (status:pending or approver:any)"
  end

  def posts_by_user
    @cache.fetch(:"#{cache_key}_posts_by_user", expires_in: cache_lifetime) do
      all_posts = Fumimi::PostSearch.all_posts_in_search(post_search_string, @booru)
      count_map = Hash.new { |h, key| h[key] = Hash.new(0) }
      all_posts.each { |post| tally_post(post, count_map) }
      count_map.sort_by { |_id, posts| -posts[:total] }.to_h
    end
  end

  def tally_post(post, count_map)
    return unless valid_candidate_ids.include?(post.uploader.id)
    return if post.uploader.is_banned

    status = if post.is_deleted
               :deleted
             else
               post.is_pending ? :pending : :active
             end
    count_map[post.uploader.id][:total] += 1
    count_map[post.uploader.id][status] += 1
  end

  def total_uploads
    posts_by_user.values.pluck(:total).sum
  end

  def total_pending
    posts_by_user.values.pluck(:pending).sum
  end

  def pending_link
    "#{@booru.url}/modqueue?search[uploader][level]=20&search[uploader][is_banned]=false"
  end

  def top_uploaders
    posts_by_user
      .lazy
      .map { |user_id, _| valid_candidate_map[user_id] }
      .compact
      .first(20)
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

  def winner_ids
    chances = valid_candidate_map.keys
    chances << posts_by_user.map do |user_id, count|
      [user_id] * count[:active]
    end
    chances.flatten!
    winners = @winner_count.times.map do
      winner = chances.sample
      chances.delete(winner)
      winner
    end
    winners.sort
  end
end
