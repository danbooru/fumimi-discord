require "fumimi/event"

class Fumimi::Event::PoolEvent < Fumimi::Event
  def self.pattern
    /pool #([0-9]+)/i
  end

  def embeds_for(matches)
    query_parameters = { "search[id]": matches.join(",") }
    pools = @booru.pools.index(**query_parameters)

    pools.sort_by { |pool| matches.index(pool.id) || Float::INFINITY }
    pools.map(&:embed)
  end
end
