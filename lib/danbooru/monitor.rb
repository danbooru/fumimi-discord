class Danbooru
  # Polls a Danbooru resource endpoint at a fixed interval and calls a block for each new item,
  # or pushes each new item to a channel.
  #
  # @example
  #   monitor = Danbooru::Monitor.new(resource: booru.posts) { |post| puts post.to_json }
  #   monitor.start
  #
  #   monitor = Danbooru::Monitor.new(resource: booru.posts)
  #   monitor.channel.each { |post| puts post.to_json }
  class Monitor
    attr_reader :resource, :params, :interval, :last_id, :last_polled_at

    delegate :shutdown, :running?, to: :task, allow_nil: true

    # @param resource [Danbooru::Resource] The resource to poll.
    # @param params [Hash] Additional query params for the resource index calls.
    # @param id [Integer, nil] Starting ID. If nil, starts from the latest record.
    # @param interval [Integer] Seconds between polls (default: 30).
    # @param log [Logger] Logger instance.
    # @yield [item] Called for each new item, in ascending ID order.
    def initialize(resource:, params: {}, id: nil, interval: 30, log: Logger.new(nil), &on_item)
      @resource = resource
      @params = params
      @last_id = id
      @interval = interval
      @log = log
      @on_item = on_item
      @last_polled_at = nil
      @task = nil
    end

    # Start the monitor.
    # @return [Monitor]
    def start
      task.execute unless running?
      self
    end

    # Stop the monitor asynchronously, returning immediately without waiting for the background thread to finish.
    # @return [Monitor]
    def shutdown
      task.shutdown if running?
      self
    end

    # Stop the monitor synchronously, waiting for the background thread to finish before returning.
    # @return [Monitor]
    def stop
      shutdown
      task.wait_for_termination if running?
      self
    end

    # Run the monitor and stop it when the block finishes.
    # @return [Monitor]
    def run
      start
      yield self if block_given?
      stop
    end

    # Poll the resource once and deliver new items to the block.
    # @return [void]
    def poll
      @last_id ||= @resource.index(**@params, limit: 1).first&.id
      page = "a#{@last_id}" if @last_id.present?
      items = @resource.index(page: page, **@params)

      @last_id = items.map(&:id).max || @last_id
      @last_polled_at = Time.now
      items.to_a.sort_by(&:id).each { |item| @on_item&.call(item) }

      nil
    rescue StandardError => e
      @log.error(e)
    end

    # @return [Concurrent::TimerTask] The timer task running the monitor.
    def task
      @task ||= Concurrent::TimerTask.new(execution_interval: @interval.to_i, run_now: true, interval_type: :fixed_rate) { poll }
    end

    # @return [Concurrent::Channel] A channel that produces new items as they are polled.
    def channel
      start
      @channel ||= Concurrent::Channel.new(capacity: 1000).tap do |ch|
        @on_item = ->(item) { ch << item }
      end
    end
  end
end
