require "danbooru/resource"

class Danbooru::Resource::Counts < Danbooru::Resource
  def initialize(url, options = {})
    super(url + "/posts", options)
  end

  def default_params
    {}
  end
end
