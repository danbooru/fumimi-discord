require "fumimi/class_register"
require "fumimi/exception_handler"

# Base class for message-triggered Discord events.
#
# Subclasses are auto-registered and define matching behavior with {.pattern}.
# They can return text and embeds for each match set.
#
class Fumimi::Event
  include Fumimi::ClassRegister
  include Fumimi::ExceptionHandler

  # Regex used to find matches in a message.
  #
  # @return [Regexp]
  # @raise [NotImplementedError]
  def self.pattern
    raise NotImplementedError, "Must implement a pattern."
  end

  # Full regex for this event, including optional model-link capture.
  #
  # @return [Regexp]
  def self.total_pattern
    return pattern unless model_for_link_capture

    model = model_for_link_capture.strip("/")
    model_pattern = %r{\b(?!https?://\w+\.donmai\.us/#{model}/\d+/\w+)https?://(?!testbooru)\w+\.donmai\.us/#{model}/(\d+)\b[^[:space:]]*}i

    Regexp.union(pattern, model_pattern)
  end

  # Embed responses for the matched values.
  #
  # @param matches [Array<String>]
  # @return [Array<Discordrb::Webhooks::Embed>]
  def embeds_for(matches)
  end

  # Text responses for the matched values.
  #
  # @param matches [Array<String>]
  # @return [Array<String>]
  def messages_for(matches)
  end

  # Optional Danbooru model path used for auto URL capture.
  #
  # @return [String, nil]
  def self.model_for_link_capture
    nil
  end

  # Whether to suppress Discord's default link preview on the source message.
  #
  # @return [Boolean]
  def self.delete_link_embed?
    false
  end

  # Executes this event for a set of already-found matches.
  #
  # @param matches [Array<String>]
  # @return [Array<(Array<String>, Array<Discordrb::Webhooks::Embed>)>]
  def respond_to_matches(matches)
    @log.info("command='#{self.class.name.demodulize}' args=`#{matches}` user_id=#{@event.user.id} username='#{@event.user.username}' channel='##{@event.channel.name}'") # rubocop:disable Layout/LineLength

    messages = messages_for(matches)
    begin
      embeds = embeds_for(matches)
    rescue Danbooru::Exceptions::BadRequestError
      embeds = []
    end

    [messages.to_a, embeds.to_a]
  end

  ## Internal methods

  # @param event [Discordrb::Events::MessageEvent]
  # @param fumimi [Fumimi]
  def initialize(event, fumimi:)
    @event = event
    @fumimi = fumimi
    @booru = fumimi.booru
    @log = fumimi.log
    @cache = fumimi.cache
  end

  # Installs one message listener that dispatches to all event subclasses.
  #
  # @param fumimi [Fumimi]
  # @return [void]
  def self.register_all(fumimi:)
    total_regex = Regexp.union(subclasses.map(&:total_pattern))

    fumimi.bot.message(contains: total_regex) do |event|
      respond_to_all_matches(event, fumimi:)
    end
  end

  # Runs all event subclasses against one message.
  #
  # @param event [Discordrb::Events::MessageEvent]
  # @param fumimi [Fumimi]
  # @return [void]
  def self.respond_to_all_matches(event, fumimi:)
    text = event.text.gsub(/```.*?```/m, "").gsub(/`.*?`/m, "")

    messages, embeds = subclasses.each_with_object([[], []]) do |subclass, (messages, embeds)|
      matches = text.scan(subclass.total_pattern).flatten.compact.uniq
      next unless matches.present?

      next if embeds.length > 10

      event.message.suppress_embeds if subclass.delete_link_embed? && !event.channel.pm?

      kommand = subclass.new(event, fumimi:)
      kommand.execute_and_rescue_errors(event) do
        submessages, subembeds = kommand.respond_to_matches(matches)
        messages.concat(submessages)
        embeds.concat(subembeds)
      end
    end

    send_combined_message(event, messages:, embeds:)
  end

  # Sends one combined response for all collected messages and embeds.
  #
  # @param event [Discordrb::Events::MessageEvent]
  # @param messages [Array<String>, nil]
  # @param embeds [Array<Discordrb::Webhooks::Embed>, nil]
  # @return [void]
  def self.send_combined_message(event, messages: nil, embeds: nil)
    messages = messages.to_a.join("\n").strip
    embeds = embeds.to_a.flatten.compact
    return unless embeds.present? || messages.present?

    event.channel.send_message(
      messages,
      false,
      embeds.first(10),
      nil,
      { replied_user: false }, # allowed mentions: don't ping who you're replying to
      event.message, # message reference
    )
  end
end
