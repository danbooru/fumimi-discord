class Fumimi::Model::PostCount < Fumimi::Model
  def count
    raise Danbooru::Exceptions::TimeoutError if counts.posts.nil?

    counts.posts
  end

  def to_i
    count
  end

  def pretty
    count.to_fs(:delimited)
  end
end
