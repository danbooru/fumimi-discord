require "fumimi/model"

class Fumimi::Model::WikiPage < Fumimi::Model
  def embed_title
    title.tr("_", " ")
  end

  def embed_description
    Fumimi::DText.dtext_to_markdown(body, max_lines: 20, wiki_page: true)
  end

  def self.fallback_embed(embed, title, booru)
    embed.title = title.tr("_", " ")
    embed.description = empty_wiki_for(title)
    embed.url = "#{booru.url}/posts?tags=#{CGI.escape(title.tr(" ", "_"))}"
    embed
  end

  def linked_posts
    body.scan(/!post #(\d+)/)
  end

  def self.empty_wiki_for(name)
    "There is currently no wiki page for the tag `#{name}`."
  end
end
