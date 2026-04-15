require "test_helper"

class PoolEventTest < Minitest::Test
  include TestMocks

  def test_series_pool_event
    embeds = mock_event("pool #8948") => { embeds:, ** }

    assert_equal 1, embeds.length
    pool = embeds.first

    assert_equal "https://danbooru.donmai.us/pools/8948", pool.url
    assert_equal "Pool #8948: Original - Pop Team Epic (bkub)", pool.title

    assert_equal Fumimi::Colors::PURPLE, pool.color

    assert_match(/Start Reading Here/, pool.description)
    assert_match(/-# Category: Series | Post Count: \d+\n/, pool.description)
  end

  def test_collection_pool_event
    embeds = mock_event("pool #109") => { embeds:, ** }

    assert_equal 1, embeds.length
    pool = embeds.first

    assert_equal "https://danbooru.donmai.us/pools/109", pool.url
    assert_equal "Pool #109: Perfect Feet", pool.title

    assert_equal Fumimi::Colors::BLUE, pool.color

    refute_match(/Start Reading Here/, pool.description)
    assert_match(/-# Category: Collection | Post Count: \d+\n/, pool.description)
  end

  def test_deleted_pool_event
    embeds = mock_event("pool #874") => { embeds:, ** }

    assert_equal 1, embeds.length
    pool = embeds.first

    assert_equal "https://danbooru.donmai.us/pools/874", pool.url
    assert_equal "Pool #874: Food Porn (deleted)", pool.title

    assert_equal Fumimi::Colors::WHITE, pool.color
  end

  def test_no_pool
    embeds = mock_event("pool #999999999") => { embeds:, ** }

    assert_equal 0, embeds.length
  end
end
