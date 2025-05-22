require "fumimi/model"

class Fumimi::Model::Tag < Fumimi::Model
  def embed(embed, channel, **options)
    searched_tag = options[:searched_tag]

    embed.description = ""

    embed.description << "-# Aliased from `#{searched_tag.downcase.strip}`.\n\n" if alias_search?(searched_tag)

    embed.title = resolved_name.tr("_", " ")
    embed.url = embed_url

    embed.description << wiki_preview

    embed.image = example_post.embed_image(channel) if example_post.present?

    embed.author = embed_author
  end

  def alias_search?(searched_tag)
    found_name = resolved_name.downcase.strip
    searched_name = searched_tag.strip.tr(" ", "_").downcase

    found_name != searched_name
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
    try(:wiki_page).try(:pretty_body) || Fumimi::Model::WikiPage.empty_wiki_for(name)
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
