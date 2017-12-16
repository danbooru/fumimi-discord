require "danbooru/model/post"
require "fumimi/model"

class Fumimi::Model::Post < Danbooru::Model::Post
  include Fumimi::Model

  NSFW_BLUR = ENV["FUMIMI_NSFW_BLUR"] || 50
  CENSORED_TAGS = ENV["FUMIMI_CENSORED_TAGS"].to_s.split

  def send_embed(channel)
    channel.send_embed do |embed|
      embed(embed, channel)
    end
  end

  def embed(embed, channel)
    embed.author = Discordrb::Webhooks::EmbedAuthor.new({
      name: "@#{uploader_name}",
      url: "#{booru.url}/users/#{uploader_id}"
    })

    embed.title = shortlink
    embed.url = url
    embed.image = embed_image(channel.name)
    embed.color = border_color
    embed.footer = embed_footer

    embed
  end

  def embed_image_url
    if file_ext.match?(/jpe?g|png|gif/i)
      file_url
    else
      preview_file_url
    end
  end

  def embed_thumbnail(channel_name)
    if is_censored? || is_unsafe?(channel_name)
      Discordrb::Webhooks::EmbedThumbnail.new(url: "https://rsz.io/#{booru.url.host}#{preview_file_url}?blur=#{NSFW_BLUR}")
    else
      Discordrb::Webhooks::EmbedThumbnail.new(url: absolute_preview_file_url.to_s)
    end
  end

  def embed_image(channel_name)
    if is_censored? || is_unsafe?(channel_name)
      # XXX gifs don't work here.
      Discordrb::Webhooks::EmbedImage.new(url: "https://rsz.io/#{booru.url.host}#{embed_image_url}?blur=#{NSFW_BLUR}")
    else
      Discordrb::Webhooks::EmbedImage.new(url: "#{booru.url}#{embed_image_url}")
    end
  end

  def is_unsafe?(channel_name)
    nsfw_channel = (channel_name =~ /^nsfw/i)
    rating != "s" && !nsfw_channel
  end

  def is_censored?
    tag_string.split.grep(/^(#{CENSORED_TAGS.join("|")})$/).any?
  end

  def border_color
    if is_flagged
      0xC41C19 # red
    elsif pool_string =~ /pool:series/
      0xAA00AA # purple
    elsif parent_id
      0xC0C000 # yellow
    elsif has_active_children
      0x00FF00 # green
    elsif is_pending
      0x0000FF # blue
    elsif is_deleted
      0xFFFFFF # white
    end
  end

  def embed_footer
    file_info = "#{image_width}x#{image_height} (#{file_size.to_s(:human_size, precision: 4)} #{file_ext})"
    timestamp = "#{created_at.strftime("%F")} at #{created_at.strftime("%l:%M %p")}"

    Discordrb::Webhooks::EmbedFooter.new({
      text: "#{file_info} | #{timestamp}"
    })
  end
end
