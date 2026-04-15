# frozen_string_literal: true

require "fumimi/model"

class Fumimi::Model::Pool < Fumimi::Model
  delegate :embed_thumbnail, to: :example_post, allow_nil: true

  def embed_author
    { name: example_post.shortlink, url: example_post.url } if example_post.present?
  end

  def embed_title
    "Pool ##{id}: #{name.tr("_", " ")} #{"(deleted)" if is_deleted}".strip
  end

  def embed_color
    return Fumimi::Colors::WHITE if is_deleted

    case category
    when "collection"
      Fumimi::Colors::BLUE
    when "series"
      Fumimi::Colors::PURPLE
    end
  end

  def embed_description
    <<~EOF
      -# Category: #{category.titleize} | Post Count: #{post_count.to_fs(:delimited)}

      #{pretty_description}
      #{start_reading_message}
    EOF
  end

  def pretty_description
    Fumimi::DText.dtext_to_markdown(description, max_lines: 20, wiki_page: true) if description
  end

  def start_reading_message
    return "" unless category == "series"
    return unless post_ids.length

    "### [Start Reading Here](https://danbooru.donmai.us/posts/#{post_ids.first}?q=ordpool:#{id})"
  end

  def example_post
    return @example_post if instance_variable_defined?(:@example_post)

    tags = "ordpool:#{id}"
    tags = "#{tags} status:any" if category == "series"
    tags = "#{tags} rating:g" unless nsfw_channel?

    @example_post = booru.posts.index(limit: 1, tags: tags).first
    @example_post.nsfw_channel = nsfw_channel? if @example_post
    @example_post
  end
  # def embed_description
  #   description = "-# Category: #{category_name} | Post Count: #{post_count.to_fs(:delimited)}\n"
  #   description += "-# This tag has been deprecated.\n" if is_deprecated
  #   description += "-# First result for `#{searched_term&.downcase&.strip}`.\n" if wildcard_search?
  #   description += "-# Aliased from `#{searched_term&.downcase&.strip}`.\n" if alias_search?
  #   description += "\n#{wiki_preview}"
  #   description
  # end
  #
  # def category_name
  #   Fumimi::TagCategory.name(category).titleize
  # end
  #
  # def searched_term=(value)
  #   @searched_term = value.tr(" ", "_").strip.downcase
  # end
  #
  # def wildcard_search?
  #   searched_term&.include? "*"
  # end
  #
  # def alias_search?
  #   !wildcard_search? && searched_term && searched_term != name
  # end
  #
  # def embed_title
  #   name.tr("_", " ")
  # end
  #
  # def embed_author
  #   { name: example_post.shortlink, url: example_post.url } if example_post.present?
  # end
  #
  # def embed_url
  #   wiki_page&.url || "#{api.booru.url}/posts?tags=#{CGI.escape(name.tr(" ", "_"))}"
  # end
  #
  # def wiki_preview
  #   wiki_page&.embed_description || Fumimi::Model::WikiPage.empty_wiki_for(name)
  # end
  #
  # def example_post
  #   return @example_post if instance_variable_defined?(:@example_post)
  #
  #   @example_post = searches_for_tag_preview
  #                   .lazy.map { |tag| booru.posts.index(limit: 1, tags: tag) }
  #                        .reject(&:failed?)
  #                   .map(&:first)
  #                   .first
  #   @example_post.nsfw_channel = nsfw_channel? if @example_post
  #   @example_post
  # end
  #
  # def wiki_page
  #   # bypass openstruct
  #   attributes.wiki_page if attributes.respond_to?(:wiki_page)
  # end
  #
  # def embed_border
  #   Fumimi::TagCategory.color(category)
  # end
  #
  # # A list of incrementally widening post searches that try to find the best post to embed for a tag preview.
  # def searches_for_tag_preview
  #   tag_searches = []
  #
  #   always_present_preview_tags = "status:any -video -ugoira -flash" # videos can't be embedded on discord
  #   always_present_preview_tags += " rating:g" unless nsfw_channel?
  #
  #   # first try to grab one of the embedded posts
  #   if (linked_posts = wiki_page&.linked_post_ids).present?
  #     tag_searches << "id:#{linked_posts.join(",")} order:custom"
  #   end
  #
  #   # then try with a narrow search
  #   tag_searches << "#{Fumimi::TagCategory.narrow_search_tags(category)} order:score -flash"
  #
  #   # and if that fails, broaden the search one last time
  #   tag_searches << "#{Fumimi::TagCategory.wide_search_tags(category)} order:score -flash"
  #
  #   tag_searches
  #     # make sure all searches have the tag, to filter out counterexamples from example posts etc
  #     .map { |search| "#{name} #{search} #{always_present_preview_tags}" }
  #     # filter out the searches that explicitly exclude it
  #     .filter { |s| !s.include? "-#{name}" }
  #     .compact.uniq
  # end
end
