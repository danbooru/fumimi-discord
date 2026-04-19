require "fumimi/model"

class Fumimi::Model::WikiPage < Fumimi::Model
  def embed_title
    title.tr("_", " ")
  end

  def embed_description
    Fumimi::DText.dtext_to_markdown(body, max_lines: 20, wiki_page: true)
  end

  def linked_post_ids
    body.scan(/!post #(\d+)/).flatten
  end

  def self.fallback_embed(title, booru)
    embed = Discordrb::Webhooks::Embed.new
    embed.title = title.tr("_", " ")
    embed.description = empty_wiki_for(title)
    embed.url = "#{booru.url}/posts?tags=#{CGI.escape(title.tr(" ", "_"))}"
    embed
  end

  def self.empty_wiki_for(name)
    "There is currently no wiki page for the tag `#{name}`."
  end
end
