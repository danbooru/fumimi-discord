require "test_helper"

class SockpuppetMonitorTest < ApplicationTest
  def setup
    @channel = channel_mock
    @fumimi = default_fumimi.tap { |f| f.stubs(:sockpuppet_channel).returns(@channel) }
    @monitor = Fumimi::SockpuppetMonitor.new(fumimi: @fumimi)
  end

  def test_no_sockpuppets_found
    VCR.use_cassette("sockpuppet_monitor_no_sockpuppets") do
      user_event = @fumimi.mod_booru.user_events.index("search[id]": 8_567_373, only: "id,category,session_id,user[id,name]").first
      @monitor.handle_event(user_event)

      assert_empty(@channel.embeds)
    end
  end

  def test_sockpuppet_not_previously_banned
    VCR.use_cassette("sockpuppet_monitor_not_previously_banned") do
      user_event = @fumimi.mod_booru.user_events.index("search[id]": 8_566_891, only: "id,category,session_id,user[id,name]").first
      @monitor.handle_event(user_event)
      embed = @channel.embeds.first

      assert_equal(1, @channel.embeds.length)
      assert_equal("Artorine", embed.title)
      assert_equal("https://danbooru.donmai.us/users/1548352", embed.url)
      assert_match(/Sock of Akanabe/, embed.description)
      assert_match(/No previous ban detected/, embed.description)
    end
  end

  def test_sockpuppet_previously_banned
    VCR.use_cassette("sockpuppet_monitor_previously_banned") do
      user_event = @fumimi.mod_booru.user_events.index("search[id]": 8_551_821, only: "id,category,session_id,user[id,name]").first
      @monitor.handle_event(user_event)
      embed = @channel.embeds.first

      assert_equal(1, @channel.embeds.length)
      assert_equal("besekberkah", embed.title)
      assert_equal("https://danbooru.donmai.us/users/1546591", embed.url)
      assert_match(/Sock of hanisann04/, embed.description)
      assert_match(/were already banned/, embed.description)
      assert_match(%r{/bans\?search\[user_id\]=1546581}, embed.description)
    end
  end

  def test_same_user_not_reported_twice
    user = stub(id: 1_548_352, name: "Artorine", url: "https://danbooru.donmai.us/users/1548352", is_banned: false)
    sockpuppet = stub(id: 999_999, name: "Akanabe", is_banned: false)
    user_event = stub(id: 8_566_891, category: "login", session_id: "abc123", user: user)

    @monitor.stubs(:sockpuppet_users).returns([sockpuppet])

    @monitor.handle_event(user_event)
    @monitor.handle_event(user_event)

    assert_equal(1, @channel.embeds.length)
  end
end
