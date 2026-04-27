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
end
