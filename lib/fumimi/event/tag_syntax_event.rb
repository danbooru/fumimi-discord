require "fumimi/event"

class Fumimi::Event::TagSyntaxEvent < Fumimi::Event
  # Matches [[tag]], [[pool:name]], and [[pool:name with spaces]].
  def self.pattern
    /\[\[\s*([^\]]+?)\s*\]\]/
  end

  def embeds_for(matches)
    users, rest = matches.partition { |m| m.start_with?("user:") }
    pools, tags = rest.partition { |m| m.start_with?("pool:") }

    user_embeds_for(users) + pool_embeds_for(pools) + tag_embeds_for(tags)
  end

  def user_embeds_for(matches)
    users = matches.map { |username| @booru.users.index(name: username.delete_prefix("user:")) }
    users.map(&:embed)
  end

  def pool_embeds_for(matches)
    matches = matches.map { |p| p.delete_prefix("pool:").tr(" ", "_") }

    pools = matches.map do |id_or_name|
      query_parameters = id_or_name =~ /\d+/ ? { "search[id]": id_or_name } : { "search[name_ilike]": id_or_name }
      @booru.pools.index(**query_parameters).first
    end

    pools.compact.uniq(&:id).sort_by { |pool| matches.index(pool.id) || matches.index(pool.name) || Float::INFINITY }
    pools.map(&:embed)
  end

  def tag_embeds_for(matches)
    matches.map do |tag_name|
      tag = @booru.tags.index("search[name_or_alias_matches]": tag_name, "search[order]": "count").to_a.first
      if tag.present?
        tag.searched_term = tag_name
        next tag.embed(nsfw_channel: @event.channel.nsfw?)
      end

      wiki_page = @booru.wiki_pages.index("search[title_normalize]": tag_name).to_a.first
      next wiki_page.embed if wiki_page.present?

      Fumimi::Model::WikiPage.fallback_embed(tag_name, @booru)
    end
  end
end
