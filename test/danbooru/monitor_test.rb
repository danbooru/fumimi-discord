require "test_helper"

class MonitorTest < ApplicationTest
  def test_run_delivers_items
    received = []
    monitor = setup_monitor(received:)

    monitor.run do
      deadline = 3.seconds.from_now
      sleep 0.25 while received.empty? && Time.now < deadline

      assert_not_empty(received)
      assert_equal(received.sort_by(&:id), received)
      assert_equal(received.last.id, monitor.last_id)
    end
  end

  def test_channel_receives_polled_items
    monitor = setup_monitor

    monitor.run do
      ch = monitor.channel
      post = ch.receive

      assert_equal(1, post.id)
    end
  end

  def setup_monitor(resource = :posts, received: [])
    Danbooru::Monitor.new(resource: default_fumimi.booru.send(resource), id: 0) { |item| received << item }
  end
end
