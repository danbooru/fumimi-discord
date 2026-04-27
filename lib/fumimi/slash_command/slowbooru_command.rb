class Fumimi::SlashCommand::SlowbooruCommand < Fumimi::SlashCommand
  def self.name
    "slowbooru"
  end

  def self.description
    "Check whether Danbooru is being slow."
  end

  def embeds
    embed = Fumimi::DiscordEmbed.new
    embed.title = "Site Speed Report"
    embed.description = "Median response: #{"%.2f" % median}s. Slowest response: #{"%.2f" % timed_requests.max}s."
    [embed]
  end

  def timed_requests
    @timed_requests ||= (1..5).each_with_object([]) do |_i, timed_requests|
      start = Time.now
      @booru.posts.index(limit: 1)
      timed_requests << (Time.now - start)

      sleep 1
    rescue Timeout::Error
      raise Danbooru::Exceptions::DownbooruError
    end
  end

  def median
    sorted = timed_requests.sort
    mid = (sorted.length - 1) / 2.0
    (sorted[mid.floor] + sorted[mid.ceil]) / 2.0
  end
end
