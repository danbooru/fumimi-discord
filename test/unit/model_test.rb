require "test_helper"
require "danbooru"

class DanbooruModelTest < ActiveSupport::TestCase
  setup do
    @booru = Danbooru.new
  end

  context "Danbooru::Model:" do
    context "the #update method" do
      should "work" do
        post = @booru.posts.show(1)

        post.update(rating: "e")
        assert_equal("e", post.rating)

        post.update(rating: "s")
        assert_equal("s", post.rating)
      end
    end

    should "have an #url" do
      assert_match(%r{/posts/1$}, @booru.posts.show(1).url)
    end

    should "have a #shortlink" do
      assert_equal("post #1", @booru.posts.show(1).shortlink)
    end

    should "be converted by #to_json" do
      response = @booru.artists.show(1)
      artist = response.model
      json = JSON.parse(artist.to_json)

      assert_equal(response.json, artist.as_json.deep_stringify_keys)
      assert_equal(response.to_json, artist.to_json)

      assert_equal(1, json["id"])
      assert_match(/\Ahttp:/, json["urls"][0]["url"])
    end
  end
end
