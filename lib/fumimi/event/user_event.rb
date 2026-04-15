require "fumimi/event"

class Fumimi::Event::UserEvent < Fumimi::Event
  def self.pattern
    shortlink_pattern = /user #([0-9]+)/i

    link_pattern = %r{\b(?!https?://\w+\.donmai\.us/users/\d+/\w+)https?://(?!testbooru)\w+\.donmai\.us/users/(\d+)\b[^[:space:]]*}i # rubocop:disable Layout/LineLength

    Regexp.union(shortlink_pattern, link_pattern)
  end

  def embeds_for(matches)
    matches.filter_map do |id|
      user = @booru.users.show(id)
      user.embed if user.succeeded?
    end
  end
end
