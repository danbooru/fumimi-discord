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
end
