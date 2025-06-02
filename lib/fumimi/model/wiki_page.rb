require "fumimi/model"

class Fumimi::Model::WikiPage < Fumimi::Model
  include Fumimi::HasDTextFields

  def embed(embed, channel) # rubocop:disable Lint/UnusedMethodArgument
    embed.title = title.tr("_", " ")
    embed.url = url

    embed.description = pretty_body
  end

  def pretty_body(max_lines: 10)
    super
  end

  def self.fallback_embed(embed, title, booru)
    embed.title = title.tr("_", " ")
    embed.description = empty_wiki_for(title)
    embed.url = "#{booru.url}/posts?tags=#{CGI.escape(title.tr(" ", "_"))}"
    embed
  end

  def self.empty_wiki_for(name)
    "There is currently no wiki page for the tag `#{name}`."
  end
end
