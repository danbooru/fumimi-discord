require "danbooru/model/wiki_page"
require "fumimi/model"

class Fumimi::Model::WikiPage < Danbooru::Model::WikiPage
  include Fumimi::Model

  def self.render_wiki_page(channel, title, booru)
    title = title.tr(" ", "_")

    wiki_page = booru.wiki_pages.show(title)
    tag = wiki_page.tag rescue nil

    post = tag.example_post if tag&.post_count.to_i.positive?

    channel.send_embed { |embed| embed(embed, channel, title, wiki_page, post) }
  end

  def self.embed(embed, channel, title, wiki_page = nil, post = nil)
    embed.title = title.tr("_", " ")

    if wiki_page.succeeded?
      embed.url = wiki_page.try(:url)
      embed.description = wiki_page.try(:pretty_body)
    else
      embed.description = "There is currently no wiki page for the tag #{title}."
    end

    return unless post

    embed.image = post.embed_image(channel.name)

    embed.author = Discordrb::Webhooks::EmbedAuthor.new(
      name: post.shortlink,
      url: post.url
    )
  end
end
