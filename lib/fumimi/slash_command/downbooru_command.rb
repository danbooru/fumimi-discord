require "fumimi/slash_command"

class Fumimi::SlashCommand::DownbooruCommand < Fumimi::SlashCommand
  def self.name
    "downbooru"
  end

  def self.description
    "Check whether Danbooru is up."
  end

  def embeds
    begin
      @booru.posts.index({ limit: 1 }, { timeout: 2 })
    rescue Timeout::Error
      raise Danbooru::Exceptions::DownbooruError
    end

    [ok_embed]
  end

  def ok_embed
    embed = Fumimi::DiscordEmbed.new
    embed.title = "All good! Site's up!"
    embed.image = "https://i.imgur.com/ik5HdCp.png"
    embed
  end
end
