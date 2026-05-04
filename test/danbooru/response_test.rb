require "test_helper"

class ResponseTest < ApplicationTest
  def test_invalid_api_key_raises_access_denied
    booru = Danbooru.new(user: "invalid-user", api_key: "invalid-api-key")

    assert_raises(Danbooru::Exceptions::AccessDeniedError) do
      booru.posts.index(limit: 1)
    end
  end
end
