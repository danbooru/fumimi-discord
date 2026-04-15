class Fumimi::TagCategory
  def self.color(category)
    case category
    when 0
      Fumimi::Colors::BLUE
    when 1
      Fumimi::Colors::RED
    when 3
      Fumimi::Colors::PURPLE
    when 4
      Fumimi::Colors::GREEN
    when 5
      Fumimi::Colors::YELLOW
    else
      raise NotImplementedError, category
    end
  end

  def self.name(category)
    case category
    when 0
      "general"
    when 1
      "artist"
    when 3
      "copyright"
    when 4
      "character"
    when 5
      "meta"
    else
      raise NotImplementedError, category
    end
  end

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
end
