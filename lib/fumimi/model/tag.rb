require "fumimi/model"

class Fumimi::Model::Tag < Fumimi::Model
  attr_reader :searched_term

  delegate :embed_image, :embed_is_nsfw?, to: :example_post, allow_nil: true

  def searched_term=(value)
    @searched_term = value.tr(" ", "_").strip.downcase
  end

  def alias_search?
    searched_term && searched_term != name
  end

  def embed_description
    description = "-# Category: #{category_name} | Post Count: #{post_count.to_fs(:delimited)}\n"
    description += "-# This tag has been deprecated.\n" if is_deprecated
    description += "-# Aliased from `#{searched_term&.downcase&.strip}`.\n" if alias_search?
    description += "\n#{wiki_preview}"
    description
  end

  def embed_title
    name.tr("_", " ")
  end

  def embed_author
    { name: example_post.shortlink, url: example_post.url } if example_post.present?
  end

  def embed_url
    wiki_page&.url || "#{api.booru.url}/posts?tags=#{CGI.escape(name.tr(" ", "_"))}"
  end

  def wiki_preview
    wiki_page&.embed_description || Fumimi::Model::WikiPage.empty_wiki_for(name)
  end

  def example_post
    @example_post ||= example_post_from_wiki || example_post_narrow || example_post_wide if post_count.to_i > 0
  end

  def wiki_page
    # bypass openstruct
    attributes.wiki_page if attributes.respond_to?(:wiki_page)
  end

  def example_post_from_wiki
    return unless wiki_page&.linked_posts.present?

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

  def category_name
    case category
    when 1
      "Artist"
    when 3
      "Copyright"
    when 4
      "Character"
    when 5
      "Meta"
    else
      "General"
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
end
