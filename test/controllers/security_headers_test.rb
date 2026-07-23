require "test_helper"

class SecurityHeadersTest < ActionDispatch::IntegrationTest
  test "controller responses prevent content type sniffing" do
    sign_in :david

    get room_url(users(:david).rooms.last)

    assert_response :success
    assert_equal "nosniff", response.headers["X-Content-Type-Options"]
  end

  test "public file responses prevent content type sniffing" do
    get "/robots.txt"

    assert_response :success
    assert_equal "nosniff", response.headers["X-Content-Type-Options"]
  end
end
