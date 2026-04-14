require "fumimi/class_register"
require "fumimi/exception_handler"

# Abstract class for a fumimi event.
#
# Required implementations:
# * self.pattern
# * embeds_for
#
class Fumimi::Event
  include Fumimi::ClassRegister
  include Fumimi::ExceptionHandler

  # The regex pattern that will trigger a reply.
  #   Example: "/forum #[0-9]+/i"
  def self.pattern
    raise NotImplementedError, "Must implement a pattern."
  end

  def embeds_for(matches)
    raise NotImplementedError, "Must implement embeds for pattern results."
  end

  # Utility alias for event.channel
  def channel
    @event.channel
  end

  def user
    @event&.user
  end

  def respond_to_event
    text = @event.text.gsub(/```.*?```/m, "").gsub(/`.*?`/m, "") # remove code blocks
    matches = text.scan(self.class.pattern).flatten.uniq
    return unless matches

    @log.info("command='#{self.class.pattern.inspect}' args=`#{text}` user_id=#{user.id} username='#{user.username}' channel='##{channel.name}'") # rubocop:disable Layout/LineLength

    begin
      embeds = embeds_for(matches)
    rescue Danbooru::Exceptions::BadRequestError
      # usually IDs that are too long
      embeds = []
    end
    return if embeds.blank?

    @event.channel.send_embed(
      "",
      embeds,
      nil,
      false,
      { replied_user: false }, # don't ping who you're replying to
      @event.message
    )
  end

  ## Internal methods

  def initialize(event, cache: nil, log: nil, booru: nil)
    @event = event
    @cache = cache || Zache.new
    @booru = booru
    @log = log
  end

  # Registers all classes that inherit this class as commands
  def self.register(command, **opts)
    bot = opts[:bot]
    log = opts[:log]
    opts[:cache] ||= Zache.new
    init_opts = opts.slice(:cache, :log, :booru)

    log.debug("Registering pattern #{command.pattern.inspect}.")
    # start listening to the pattern
    bot.message(contains: command.pattern) do |event|
      kommand = command.new(event, **init_opts)
      kommand.safe_handle_event
    end
  end

  # makes sure that fumimi exceptions are invoked to sanitize errors
  def safe_handle_event
    execute_and_rescue_errors(@event) do
      respond_to_event
    end
  end
end
