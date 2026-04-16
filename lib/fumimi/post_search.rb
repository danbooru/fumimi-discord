# Utility methods for dealing with post searches
class Fumimi::PostSearch
  def self.narrow_search_tags(category)
    case category
    when 1 # artist
      ""
    when 3 # copy
      "everyone copytags:<5 -parody -crossover"
    when 4 # char
      "solo chartags:<5 -cosplay -fusion -character_doll -character_hair_ornament -character_print -crossover -very_wide_shot" # rubocop:disable Layout/LineLength
    else # meta or general
      "-6+girls -6+boys -comic -very_wide_shot"
    end
  end

  def self.wide_search_tags(category)
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

  def self.all_posts_in_search(search, booru)
    [].tap do |posts|
      page = 1
      loop do
        page_posts = booru.posts.index(tags: search, page: page)
        break if page_posts.empty?

        page = "b#{page_posts.map(&:id).min}"
        posts.concat(page_posts)
      end
    end
  end
end
