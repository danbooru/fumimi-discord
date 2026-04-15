require "fumimi/class_register"
require "fumimi/exception_handler"

# Abstract base class for message-triggered Discord events.
#
# Events are triggered when a Discord message matches a subclass pattern.
# Subclasses must implement {.pattern} and {#embeds_for} to define when they
# trigger and what embeds to send in response. Subclasses may also opt into
# automatic URL matching for a resource type via {.model_for_link_capture}.
#
# The event system automatically discovers and registers all subclasses via the
# {Fumimi::ClassRegister} mixin, so no explicit registration is needed beyond
# extending this class.
#
# Lifecycle:
# 1. User sends a message in Discord
# 2. {.respond_to_all_matches} strips code blocks and inline code from message text
# 3. Each subclass scans the cleaned text with its {.total_pattern}
# 4. Matching subclasses are instantiated and asked to {#respond_to_matches}
# 5. {#respond_to_matches} runs {#messages_for} and {#embeds_for} inside exception handling
# 6. If {.delete_link_embed?} is true, the original link embed is suppressed
# 7. {.send_combined_message} sends one combined reply with up to 10 embeds
#
# Example:
#   class MyEvent < Fumimi::Event
#     def self.pattern
#       /post #(\d+)/i
#     end
#
#     def embeds_for(matches)
#       matches.map { |post_id| create_embed_for_post(post_id) }
#     end
#   end
#
class Fumimi::Event
  include Fumimi::ClassRegister
  include Fumimi::ExceptionHandler

  # The regex pattern that will trigger a reply.
  #
  # Messages are scanned for matches of this pattern. Code blocks and inline code
  # are stripped before pattern matching to avoid false positives.
  #
  # @return [Regexp] the pattern to match in messages
  # @raise [NotImplementedError] if not overridden by subclass
  #
  # @example
  #   def self.pattern
  #     /post #(\d+)/i
  #   end
  def self.pattern
    raise NotImplementedError, "Must implement a pattern."
  end

  # Returns the full regex used when scanning message text for this subclass.
  #
  # If {.model_for_link_capture} is set, this unions {.pattern} with a URL
  # matcher for that model (for example, /posts/:id links).
  #
  # @return [Regexp]
  def self.total_pattern
    return pattern unless model_for_link_capture

    model = model_for_link_capture.strip("/")
    model_pattern = %r{\b(?!https?://\w+\.donmai\.us/#{model}/\d+/\w+)https?://(?!testbooru)\w+\.donmai\.us/#{model}/(\d+)\b[^[:space:]]*}i # rubocop:disable Layout/LineLength

    Regexp.union(pattern, model_pattern)
  end

  # Generates embeds to send in response to matched pattern.
  #
  # This method is called with all unique, flattened matches from the message.
  # It should return an array of embeds or an empty array if no embeds should be sent.
  #
  # @param matches [Array<String>] the captured groups from {.pattern} matches
  # @return [Array<Discordrb::Webhooks::Embed>] embeds to send, or empty array
  #
  # @example
  #   def embeds_for(matches)
  #     matches.map { |id| Fumimi::PostReport.new(id).embed }
  #   end
  def embeds_for(matches)
  end

  # Generates messages to send in response to matched pattern.
  #
  # This method is called with all unique, flattened matches from the message.
  # It should return an array of messages or an empty array if no messages should be sent.
  #
  # @param matches [Array<String>] the captured groups from {.pattern} matches
  # @return [Array<String>] messages to send, or empty array
  #
  # @example
  #   def messages_for(matches)
  #     matches.map { |id| "You typed #{id}" }
  #   end
  def messages_for(matches)
  end

  # Opts into automatic URL matching for a given Danbooru resource.
  #
  # Return a path segment like "posts", "users", or "/posts".
  # Default is nil, meaning only {.pattern} matching is used.
  #
  # @return [String, nil]
  def self.model_for_link_capture
    nil
  end

  # Whether matching this event should suppress embeds on the original message.
  #
  # This is primarily useful for link-based events where the bot posts a richer
  # replacement embed and wants to hide Discord's automatic URL preview.
  #
  # @return [Boolean]
  def self.delete_link_embed?
    false
  end

  # Executes this event instance for a precomputed set of regex matches.
  #
  # This method wraps execution in {Fumimi::ExceptionHandler}, logs context,
  # and returns two arrays: plain messages and embed objects.
  #
  # @param matches [Array<String>] unique captures for this subclass pattern
  # @return [Array<(Array<String>, Array<Discordrb::Webhooks::Embed>)>]
  def respond_to_matches(matches)
    execute_and_rescue_errors(@event, wait_message: false) do
      @log.info("command='#{self.class.name.demodulize}' args=`#{matches}` user_id=#{@event.user.id} username='#{@event.user.username}' channel='##{@event.channel.name}'") # rubocop:disable Layout/LineLength

      messages = messages_for(matches)
      begin
        embeds = embeds_for(matches)
      rescue Danbooru::Exceptions::BadRequestError
        embeds = []
      end

      [messages.to_a, embeds.to_a]
    end
  end

  ## Internal methods

  # Initializes an event instance with message and configuration.
  #
  # @param event [Discordrb::Events::MessageEvent] the Discord message event
  # @param cache [Zache] optional cache instance (defaults to new Zache)
  # @param log [Logger] optional logger instance
  # @param booru [Danbooru] optional Danbooru API client
  # @param _opts [Hash] additional options (ignored)
  def initialize(event, cache: nil, log: nil, booru: nil, **_opts)
    @event = event
    @cache = cache || Zache.new
    @booru = booru
    @log = log
  end

  # Registers all tracked subclasses with the provided options.
  #
  # This installs one Discord message listener that delegates to
  # {.respond_to_all_matches}.
  #
  # @param opts [Hash] keyword arguments passed to subclass initializers
  # @return [void]
  def self.register_all(**opts)
    bot = opts[:bot]
    opts[:cache] ||= Zache.new
    total_regex = Regexp.union(subclasses.map(&:total_pattern))

    bot.message(contains: total_regex) do |event|
      respond_to_all_matches(event, **opts)
    end
  end

  # Runs all registered event subclasses against one message event.
  #
  # The message text is sanitized by removing fenced and inline code first.
  # Every subclass receives unique flattened captures from its own total pattern.
  #
  # @param event [Discordrb::Events::MessageEvent]
  # @param opts [Hash] keyword args forwarded to event subclass constructors
  # @return [void]
  def self.respond_to_all_matches(event, **opts)
    text = event.text.gsub(/```.*?```/m, "").gsub(/`.*?`/m, "")

    messages, embeds = subclasses.each_with_object([[], []]) do |subclass, (messages, embeds)|
      matches = text.scan(subclass.total_pattern).flatten.compact.uniq
      next unless matches.present?

      next if embeds.length > 10

      event.message.suppress_embeds if subclass.delete_link_embed?

      kommand = subclass.new(event, **opts)
      submessages, subembeds = kommand.respond_to_matches(matches)
      messages.concat(submessages)
      embeds.concat(subembeds)
    end

    send_combined_message(event, messages:, embeds:)
  end

  # Sends a single combined Discord response for collected event outputs.
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
      event.message # message reference
    )
  end
end
