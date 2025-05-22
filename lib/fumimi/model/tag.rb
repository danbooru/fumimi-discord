require "fumimi/model"

class Fumimi::Model::Tag < Fumimi::Model
  def self.render_tag_preview(channel, title, booru)
    tags = booru.tags.search(name_or_alias_matches: title)
    tag = tags.max_by(&:post_count) || tags.first

    channel.send_embed { |embed| embed(embed, channel, booru, title, tag) }
  end

  def self.embed(embed, channel, booru, title, tag)
    embed.description = ""
    embed.description << "-# Aliased from `#{title}`.\n\n" if tag&.resolved_name != title.tr(" ", "_")

    title = tag&.resolved_name || title
    embed.title = title.tr("_", " ")

    if tag.try(:wiki_page).present?
      embed.url = tag&.wiki_page.try(:url)
      embed.description << tag&.wiki_page.try(:pretty_body)
    else
      embed.url = "#{booru.url}/posts?tags=#{CGI.escape(title)}"
      embed.description << "There is currently no wiki page for the tag `#{title}`."
    end

    post = tag&.example_post
    return embed unless post

    embed.image = post.embed_image(channel.name)

    embed.author = Discordrb::Webhooks::EmbedAuthor.new(
      name: post.shortlink,
      url: post.url
    )
  end

  def resolved_name
    try(:antecedent_alias).try(:consequent_name) || name
  end

  def example_post
    return if post_count.to_i.zero?

    search = case category
             when 1 # artist
               "#{name} rating:general order:score filetype:jpg limit:1 status:any"
             when 3 # copy
               "#{name} everyone rating:general order:score filetype:jpg limit:1 status:any copytags:<5 -parody -crossover"
             when 4 # char
               "#{name} solo chartags:<5 rating:general order:score filetype:jpg limit:1 status:any"
             else # meta or general
               "#{name} rating:general -animated -6+girls -comic order:score limit:1 status:any"
             end

    response = booru.posts.index(tags: search)
    response.first unless response.failed?
  end
end
