require "fumimi/model"

class Fumimi::Model::Tag < Fumimi::Model
  def self.render_tag_preview(channel, title, booru)
    tags = booru.tags.search(name_or_alias_matches: title)
    tag = tags.max_by(&:post_count) || tags.first

    channel.send_embed { |embed| embed(embed, channel, title, tag) }
  end

  def self.embed(embed, channel, title, tag)
    embed.description = ""
    embed.description << "-# Aliased from `#{title}`.\n\n" if tag&.resolved_name != title.tr(" ", "_")

    embed.title = (tag&.resolved_name || title).tr("_", " ")
    embed.url = tag&.embed_url

    embed.description << tag&.wiki_preview

    post = tag&.example_post
    embed.image = post.embed_image(channel.name) if post.present?

    embed.author = tag&.embed_author
  end

  def resolved_name
    try(:antecedent_alias).try(:consequent_name) || name
  end

  def embed_url
    if try(:wiki_page).present?
      "#{api.booru.url}/wiki_pages/#{wiki_page.id}"
    else
      "#{api.booru.url}/posts?tags=#{CGI.escape(resolved_name)}"
    end
  end

  def wiki_preview
    if try(:wiki_page).present?
      wiki_page.try(:pretty_body)
    else
      "There is currently no wiki page for the tag `#{resolved_name}`."
    end
  end

  def embed_author
    return unless example_post

    Discordrb::Webhooks::EmbedAuthor.new(
      name: example_post.shortlink,
      url: example_post.url
    )
  end

  def example_post
    return if post_count.to_i.zero?

    case category
    when 1 # artist
      search = "#{name} rating:general order:score filetype:jpg limit:1 status:any"
    when 3 # copy
      search = "#{name} everyone rating:general order:score filetype:jpg limit:1 status:any copytags:<5 -parody -crossover"
    when 4 # char
      search = "#{name} solo chartags:<5 rating:general order:score filetype:jpg limit:1 status:any"
    else # meta or general
      search = "#{name} rating:general -animated -6+girls -comic order:score limit:1 status:any"
    end

    @example_post ||= begin
      response = booru.posts.index(tags: search)
      response.first unless response.failed?
    end
  end
end
