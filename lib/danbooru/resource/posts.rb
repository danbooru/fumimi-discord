require "danbooru/resource"

class Danbooru::Resource::Posts < Danbooru::Resource
  def tag(id, tags)
    tags = tags.join(" ") if tags.is_a?(Array)
    update!(id, "post[old_tag_string]": "", "post[tag_string]": tags)
  end
end
