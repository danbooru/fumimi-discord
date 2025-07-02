class Fumimi::RaffleReport
  def initialize(event, booru, topic_id)
    @event = event
    @booru = booru
    @topic_id = topic_id
  end

  def send_embed(embed, cache)
    data = cache.get(:"raffle_report_#{@topic_id}", lifetime: 10 * 60) do
      {
        description: "-# Requested by <@#{@event.user.id}>. Cached for 10 minutes\n#{description}",
        title: title,
        url: @forum_topic.url,
      }
    end

    embed.description = data[:description]
    embed.title = data[:title]
    embed.url = data[:url]
  end

  def title
    "Raffle Report for Topic ##{@topic_id}"
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
    @forum_posts ||= begin
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

  def posts_by_user
    # create a map of posts by user for quick access and sorting
    @posts_by_user ||= begin
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

      count_map
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
    @top_uploaders ||= begin
      # get the top 20 uploaders by total posts (no matter the status)
      top_uploader_map = posts_by_user.sort_by { |_id, posts| -posts[:total] }.first(20).to_h
      top_uploaders = valid_candidates.filter { |c| top_uploader_map.include? c.id }
      top_uploaders.sort_by { |c| top_uploader_map.to_h.pluck(0).index(c.id) }
    end
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
end
