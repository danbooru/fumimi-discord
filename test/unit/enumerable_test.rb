require "test_helper"

require "benchmark"
require "danbooru/core_ext/enumerable"

class DanbooruTest < ActiveSupport::TestCase
  context "The Enumerable#prefetch method" do
    setup do
      @bomb = 0.step.lazy.map { |i| if i == 5 then throw :bomb else i end }
    end

    should "prefetch the number of elements requested" do
      assert_throws :bomb do
        @bomb.prefetch(5).first
      end
    end

    should "not fetch more elements than requested" do
      assert_nothing_raised do
        assert_equal(0, @bomb.prefetch(0).first)
        assert_equal(0, @bomb.prefetch(4).first)
        @bomb.prefetch(5)
      end
    end

    should_eventually "not fetch more elements than requested when given a block" do
      assert_nothing_raised do
        assert_equal([1, 2, 3, 4], @bomb.prefetch(1) { |x| x + 1 }.take(4).to_a)
      end
    end
  end

  context "The Enumerable#pmap method" do
    setup do
      @input = [3, 2, 1, 0]
      @output = [4, 3, 2, 1]
    end

    should "map over the input correctly" do
      (@input.size + 1).times do |threads|
        assert_equal(@output, @input.pmap(threads) { |x| x + 1 }.to_a)
        assert_equal(@output, @input.pmap(threads).map { |x| x + 1 }.to_a)
      end
    end

    should "use the requested number of threads" do
      thread_ids = @input.pmap(4) { Thread.current.object_id }
      assert_equal(4, thread_ids.count)
    end

    should "run the threads in parallel" do
      time = Benchmark.realtime { (0..5).pmap(5) { sleep 0.1 }.force }
      assert_in_delta(0.1, time, 0.01)
    end

    should "stream the output lazily" do
      assert_equal([3, 2, 1], [3, 2, 1, 0].pmap(4) { |x| 1/x; x }.take(3).to_a)
    end
  end

  context "The Enumerable#to_dtext method" do
    should "work" do
      data = [
        { foo: 1, bar: 2 },
        { foo: 3, bar: 4 },
      ]

      dtext = <<~DTEXT
        [table]
          [thead]
            [tr]
              [th] Foo [/th]
              [th] Bar [/th]
            [/tr]
          [/thead]
          [tbody]
            [tr]
              [td] 1 [/td]
              [td] 2 [/td]
            [/tr]
            [tr]
              [td] 3 [/td]
              [td] 4 [/td]
            [/tr]
          [/tbody]
        [/table]
      DTEXT

      assert_equal(dtext, data.to_dtext)
    end
  end
end
