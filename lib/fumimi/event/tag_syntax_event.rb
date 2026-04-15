require "fumimi/event"

class Fumimi::Event::TagSyntaxEvent < Fumimi::Event
  def self.pattern
    /\[\[ ([^\]]+) \]\]/x
  end

  def embeds_for(matches)
    users, tags = matches.partition { |m| m.start_with?("user:") }

    user_embeds_for(users) + tag_embeds_for(tags)
  end

  def user_embeds_for(matches)
    users = matches.map { |username| @booru.users.index(name: username.delete_prefix("user:")) }
    users.map(&:embed)
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
