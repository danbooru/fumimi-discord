require "danbooru/resource"

class Danbooru::Resource::Comments < Danbooru::Resource
  def default_params
    super.merge(group_by: :comment)
  end
end
