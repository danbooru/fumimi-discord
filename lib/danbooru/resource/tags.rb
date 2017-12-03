require "danbooru/resource"

class Danbooru::Resource::Tags < Danbooru::Resource
  def default_params
    super.merge("search[hide_empty]": "no")
  end
end
