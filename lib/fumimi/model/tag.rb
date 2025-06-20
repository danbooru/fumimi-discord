require "fumimi/model"

class Fumimi::Model::Tag < Fumimi::Model
  def embed(embed, channel, **options)
    searched_tag = options[:searched_tag]

    embed.description = ""
    embed.description << "-# Category: #{category_name.capitalize} | Post Count: #{post_count.to_fs(:delimited)}\n"
    embed.description << "-# This tag has been deprecated.\n" if is_deprecated
    embed.description << "-# Aliased from `#{searched_tag.downcase.strip}`.\n" if alias_search?(searched_tag)
    embed.description << "\n#{wiki_preview}"

    embed.title = name.tr("_", " ")
    embed.url = embed_url

    embed.image = example_post.embed_image(channel) if example_post.present?
    embed.author = embed_author

    # embed.color = embed_border

    embed
  end

  def alias_search?(searched_tag)
    found_name = name.downcase.strip
    searched_name = searched_tag.strip.tr(" ", "_").downcase

    found_name != searched_name
  end

  def category_name
    case category
    when 1
      "artist"
    when 3
      "copyright"
    when 4
      "character"
    when 5
      "meta"
    else
      "general"
    end
  end

  def embed_border
    case category
    when 1
      Fumimi::Colors::RED
    when 3
      Fumimi::Colors::PURPLE
    when 4
      Fumimi::Colors::GREEN
    when 5
      Fumimi::Colors::YELLOW
    else
      Fumimi::Colors::BLUE
    end
  end

  def embed_url
    if try(:wiki_page).present?
      wiki_page.url
    else
      "#{api.booru.url}/posts?tags=#{CGI.escape(name.tr(" ", "_"))}"
    end
  end

  def wiki_preview
    if try(:wiki_page).present?
      wiki_page.pretty_body
    else
      Fumimi::Model::WikiPage.empty_wiki_for(name)
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
    return @example_post if defined? @example_post

    @example_post ||= example_post_from_wiki || example_post_narrow || example_post_wide
  end

  def example_post_from_wiki
    return unless (wiki_body = try(:wiki_page)&.body).present?

    post_ids = wiki_body.scan(/!post #(\d+)/)
    return if post_ids.blank?

    tag_string = "id:#{post_ids.join(",")} #{always_present_tags} order:custom"
    return if tag_string.split.include? "-#{name}"

    response = booru.posts.index(limit: 1, tags: tag_string)
    response.first unless response.failed?
  end

  def example_post_narrow
    return if final_narrow_search.strip == final_wide_search.strip
    return if final_narrow_search.split.include? "-#{name}"

    response = booru.posts.index(limit: 1, tags: "#{name} #{final_narrow_search}")
    response.first unless response.failed?
  end

  def example_post_wide
    return if final_wide_search.split.include? "-#{name}"

    response = booru.posts.index(limit: 1, tags: "#{name} #{final_wide_search}")
    response.first unless response.failed?
  end

  def final_narrow_search
    tag_string = "#{narrow_search_tags} #{always_present_tags} order:score"
    tag_string = "#{tag_string} age:<1y" if post_count.to_i > 250_000 # otherwise the search is going to be too slow
    tag_string
  end

  def final_wide_search
    "#{wide_search_tags} #{always_present_tags} order:score"
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
      "solo chartags:<5 -alternate_* -cosplay -fusion -character_doll -character_hair_ornament -character_print -crossover -very_wide_shot" # rubocop:disable Layout/LineLength
    else # meta or general
      "-6+girls -6+boys -comic -very_wide_shot"
    end
  end

  def wide_search_tags
    case category
    when 1 # artist
      ""
    when 3 # copy
      "everyone copytags:<5"
    when 4 # char
      "solo chartags:<5"
    else # meta or general # rubocop:disable Lint/DuplicateBranch
      ""
    end
  end
end
