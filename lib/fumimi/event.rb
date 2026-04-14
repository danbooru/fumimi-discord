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

  def initialize(event, cache: nil, log: nil, booru: nil, **_opts)
    @event = event
    @cache = cache || Zache.new
    @booru = booru
    @log = log
  end

  # Registers all classes that inherit this class as commands
  def self.register(command, bot:, **opts)
    opts[:cache] ||= Zache.new

    # start listening to the pattern
    bot.message(contains: command.pattern) do |event|
      kommand = command.new(event, **opts)
      kommand.safe_handle_event
    end
  end

  # makes sure that fumimi exceptions are invoked to sanitize errors
  def safe_handle_event
    execute_and_rescue_errors(@event, wait_message: false) do
      respond_to_event
    end
  end
end
