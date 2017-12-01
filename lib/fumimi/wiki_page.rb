require "danbooru/wiki_page"
require "fumimi/model"

class Fumimi
  class WikiPage < Danbooru::WikiPage
    include Fumimi::Model

    def self.render_wiki_page(channel, title, booru)
      wiki_page = booru.wiki_pages.index(title: title.tr(" ", "_")).first
      tag = booru.tags.search(name: title).first
      post = tag.example_post(booru) if tag && tag.post_count > 0

      channel.send_embed { |embed| embed(embed, channel, title, wiki_page, post) }
    end

    def self.embed(embed, channel, title, wiki_page = nil, post = nil)
      embed.author = Discordrb::Webhooks::EmbedAuthor.new({
        name: title.tr("_", " "),
        url: "https://danbooru.donmai.us/wiki_pages/#{title}"
      })

      embed.description = wiki_page.try(:pretty_body)

      if post
        embed.title = "post ##{post.id}"
        embed.url = "https://danbooru.donmai.us/posts/#{post.id}"
        embed.image = post.embed_image(channel.name)
      end
    end
  end
end
