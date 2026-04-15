require "fumimi/class_register"
require "fumimi/exception_handler"

# Abstract base class for message-triggered Discord events.
#
# Events are triggered when a Discord message matches a specific regex pattern.
# Subclasses must implement {.pattern} and {#embeds_for} to define when they
# trigger and what embeds to send in response.
#
# The event system automatically discovers and registers all subclasses via the
# {Fumimi::ClassRegister} mixin, so no explicit registration is needed beyond
# extending this class.
#
# Lifecycle:
# 1. User sends a message in Discord
# 2. Bot checks if message matches the event's {.pattern}
# 3. If matched, creates a new event instance and calls {#safe_handle_event}
# 4. Safe event handler calls {#respond_to_event} within an exception wrapper
# 5. {#respond_to_event} extracts matches and calls {#embeds_for} to generate embeds
# 6. Embeds are sent as a reply to the original message
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

  # Generates embeds to send in response to matched pattern.
  #
  # This method is called with all unique, flattened matches from the message.
  # It should return an array of embeds or an empty array if no embeds should be sent.
  #
  # @param matches [Array<String>] the captured groups from {.pattern} matches
  # @return [Array<Discordrb::Webhooks::Embed>] embeds to send, or empty array
  # @raise [NotImplementedError] if not overridden by subclass
  #
  # @example
  #   def embeds_for(matches)
  #     matches.map { |id| Fumimi::PostReport.new(id).embed }
  #   end
  def embeds_for(matches)
    raise NotImplementedError, "Must implement embeds for pattern results."
  end

  # Processes the event by matching the pattern and sending embeds.
  #
  # Returns early if no matches are found or if {#embeds_for} returns empty.
  # Code blocks (triple backticks) and inline code (backticks) are stripped before
  # pattern matching to avoid matching inside code.
  #
  # @return [Object] result of channel.send_embed call, or nil if no embeds
  # @raise [Danbooru::Exceptions::BadRequestError] caught and converted to empty embeds
  def respond_to_event
    text = @event.text.gsub(/```.*?```/m, "").gsub(/`.*?`/m, "") # remove code blocks
    matches = text.scan(self.class.pattern).flatten.uniq
    return unless matches

    @log.info("command='#{self.class.pattern.inspect}' args=`#{text}` user_id=#{@event.user.id} username='#{@event.user.username}' channel='##{@event.channel.name}'") # rubocop:disable Layout/LineLength

    begin
      embeds = embeds_for(matches)
    rescue Danbooru::Exceptions::BadRequestError # IDs are too long, like "post #1111111111111111111"
      embeds = []
    end
    return if embeds.blank?

    @event.channel.send_embed("", embeds, nil, false,
                              { replied_user: false }, # don't ping who you're replying to
                              @event.message)
  end

  ## Internal methods

  # Initializes an event instance with message and configuration.
  #
  # @param event [Discordrb::Events::MessageEvent] the Discord message event
  # @param cache [Zache] optional cache instance (defaults to new Zache)
  # @param log [Logger] optional logger instance
  # @param booru [Danbooru::Client] optional Danbooru API client
  # @param _opts [Hash] additional options (ignored)
  def initialize(event, cache: nil, log: nil, booru: nil, **_opts)
    @event = event
    @cache = cache || Zache.new
    @booru = booru
    @log = log
  end

  # Registers an event class to listen for messages matching its pattern.
  #
  # Called by {register_all} for each subclass. Sets up a Discord message listener
  # that triggers {#safe_handle_event} when the pattern matches.
  #
  # @param command [Class] the event subclass to register
  # @param bot [Discordrb::Bot] the Discord bot instance
  # @param opts [Hash] keyword arguments including cache, logger, booru client
  # @return [Proc] the message handler registered with the bot
  def self.register(command, bot:, **opts)
    opts[:cache] ||= Zache.new

    # start listening to the pattern
    bot.message(contains: command.pattern) do |event|
      kommand = command.new(event, **opts)
      kommand.safe_handle_event
    end
  end

  # Wraps event handling with exception handling and error logging.
  #
  # Calls {#respond_to_event} within an exception handler that sanitizes
  # errors and sends appropriate error messages to the channel.
  #
  # @return [Object] result of {#respond_to_event}
  def safe_handle_event
    execute_and_rescue_errors(@event, wait_message: false) do
      respond_to_event
    end
  end
end
