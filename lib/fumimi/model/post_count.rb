require "fumimi/model"

class Fumimi::Model::PostCount < Fumimi::Model
  def count
    counts.posts
  end

  def to_i
    count
  end

  def pretty
    count.to_fs(:delimited)
  end
end
