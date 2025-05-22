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

    @example_post ||= example_post_from_wiki || example_post_narrow || example_post_wide
  end

  def example_post_from_wiki
    return unless (wiki_body = try(:wiki_page)&.body).present?

    post_ids = wiki_body.scan(/!post #(\d+)/)
    return if post_ids.blank?

    tag_string = "id:#{post_ids.join(",")} #{always_present_tags} order:custom"
    return if tag_string.split.include? name

    response = booru.posts.index(limit: 1, tags: tag_string)
    response.first unless response.failed?
  end

  def example_post_narrow
    tag_string = "#{narrow_search_tags} #{always_present_tags} order:score"
    return if tag_string.split.include? name

    response = booru.posts.index(limit: 1, tags: "#{name} #{tag_string}")
    response.first unless response.failed?
  end

  def example_post_wide
    tag_string = "#{wide_search_tags} #{always_present_tags} order:score"
    return if tag_string.split.include? name

    response = booru.posts.index(limit: 1, tags: "#{name} #{tag_string}")
    response.first unless response.failed?
  end

  def always_present_tags
    "status:any rating:general -animated -flash" # discord rich embeds don't allow video previews
  end

  def narrow_search_tags
    case category
    when 1 # artist
      ""
    when 3 # copy
      "everyone copytags:<5 -parody -crossover"
    when 4 # char
      "solo chartags:<5 -alternate_* -cosplay -fusion -character_doll -character_hair_ornament -character_print -crossover" # rubocop:disable Layout/LineLength
    else # meta or general
      "-6+girls -6+boys -comic"
    end
  end

  def wide_search_tags
    case category
    when 1 # artist
      ""
    when 3 # copy
      "#{name} everyone copytags:<5"
    when 4 # char
      "#{name} solo chartags:<5"
    else # meta or general # rubocop:disable Lint/DuplicateBranch
      ""
    end
  end
end
