require "test_helper"
require "danbooru"

class DanbooruTest < ActiveSupport::TestCase
  setup do
    @booru = Danbooru.new
  end

  context "Danbooru:" do
    context "Danbooru#initialize" do
      should "take default params from the environment" do
        assert_equal(ENV.fetch("BOORU_URL", nil), @booru.url.to_s)
        assert_equal(ENV.fetch("BOORU_USER", nil), @booru.user)
        assert_equal(ENV.fetch("BOORU_API_KEY", nil), @booru.api_key)
      end

      should "create classes and getters for every resource" do
        assert_equal(true, @booru.respond_to?(:favorites))
        assert_kind_of(Danbooru::Resource::Favorites, @booru.send(:favorites))
      end
    end

    context "Danbooru#logged_in?" do
      should "return true when logged in" do
        assert_equal(true, @booru.logged_in?)
      end

      should "return false when logged in incorrectly" do
        @booru = Danbooru.new(api_key: "wrong")
        assert_equal(false, @booru.logged_in?)
      end

      should "return false when not logged in" do
        @booru = Danbooru.new(api_key: nil)
        assert_equal(false, @booru.logged_in?)
      end
    end
  end

  context "Danbooru::HTTP" do
    should "work without authentication" do
      response = Danbooru::HTTP.new(@booru.url).get("/post_versions")

      assert_equal(403, response.code)
      assert_nothing_raised { JSON.parse(response.body) }
    end

    should "work with authentication" do
      response = Danbooru::HTTP.new(@booru.url, user: @booru.user, pass: @booru.api_key).get("/post_versions")

      assert_equal(200, response.code)
      assert_nothing_raised { JSON.parse(response.body) }
    end

    should "maintain a persistent connection" do
      http = Danbooru::HTTP.new(@booru.url)
      response1 = http.get("/")
      response2 = http.get("/")

      assert_equal(response1.connection.object_id, response2.connection.object_id)
    end

    should "log debug info" do
      @io = StringIO.new
      @logger = Logger.new(@io, level: :debug)

      response = Danbooru::HTTP.new(@booru.url, log: @logger).get("/")
      assert_match(/code=200 method=GET/, @io.string)
    end
  end

  context "Danbooru::Resource:" do
    context "the #request method" do
      setup do
        # XXX resource = Danbooru.new["posts"]
        @booru = Danbooru.new
        @resource = Danbooru::Resource.new("posts", @booru)
      end

      should "work" do
        response = @resource.request(:get, "/")
        assert_equal(true, response.succeeded?)
      end

      should "retry on failure until success" do
        mock_resp = mock
        mock_resp.stubs(:code).returns(429, 429, 200, 200)
        mock_resp.stubs(:body).returns("[]")
        mock_resp.stubs(:mime_type).returns("application/json")

        @booru.http.expects(:request).times(2).returns(mock_resp)
        Retriable.expects(:sleep).times(1)

        response = @resource.request(:get, "/", {}, tries: 2)
        assert_equal(true, response.succeeded?)
      end

      should "return the error response after retries are exhausted" do
        mock_resp = mock
        mock_resp.stubs(:code).returns(429)
        mock_resp.stubs(:body).returns("{}")
        mock_resp.stubs(:mime_type).returns("application/json")

        @booru.http.expects(:request).times(3).returns(mock_resp)
        response = @resource.request(:get, "/", {}, tries: 3)

        assert_equal(true, response.failed?)
      end
    end
  end

  context "Danbooru#source:" do
    context "the #index method" do
      should "return an error for unsupported sites" do
        source = @booru.source.index(url: "http://www.example.com")

        assert_kind_of(Danbooru::Response, source)
        assert_equal(true, source.failed?)
        assert_equal("400 Bad Request: Unsupported site", source.error)
      end
    end
  end

  context "Danbooru#tags:" do
    context "the #search method" do
      should "work" do
        tags = @booru.tags.search(name: "tagme")

        assert_equal(1, tags.count)
        assert_equal("tagme", tags.first.name)
      end
    end
  end

  context "Danbooru#posts:" do
    should "work" do
      assert_kind_of(Danbooru::Resource::Posts, @booru.posts)
      assert_equal(@booru, @booru.posts.booru)
    end

    context "the #first method" do
      should "return the first post" do
        assert_equal(1, @booru.posts.first.id)
      end
    end

    context "the #all method" do
      should "work with a block" do
        @booru.posts.all(tags: "id:1,2", limit: 1) do |post|
          assert_equal(true, post.id <= 2)
        end
      end

      should "work without a block" do
        posts = @booru.posts.all(tags: "id:1,2", limit: 1).to_a
        assert_equal([2, 1], posts.map(&:id))
      end
    end

    context "the #index method" do
      should "work" do
        post = @booru.posts.index(tags: "id:1").first
        assert_equal(1, post.id)
      end
    end

    context "the #show method" do
      should "work" do
        post = @booru.posts.show(1)

        assert_kind_of(Danbooru::Response, post)
        assert_kind_of(Danbooru::Model::Post, post.model)
        assert_equal(false, post.failed?)
        assert_equal(1, post.id)
      end
    end
  end
end
