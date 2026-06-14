require "test_helper"

class RoomsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :david
  end

  test "index redirects to the user's last room" do
    get rooms_url
    assert_redirected_to room_url(users(:david).rooms.last)
  end

  test "show" do
    get room_url(users(:david).rooms.last)
    assert_response :success
  end

  test "show sends an enforced content security policy" do
    get room_url(users(:david).rooms.last)

    policy = response.headers["Content-Security-Policy"]
    nonce = css_select("meta[name='csp-nonce']").first["content"]

    assert_response :success
    assert_not_empty policy
    assert_nil response.headers["Content-Security-Policy-Report-Only"]
    assert_includes policy, "default-src 'self'"
    assert_includes policy, "base-uri 'self'"
    assert_includes policy, "frame-ancestors 'none'"
    assert_includes policy, "object-src 'none'"
    assert_includes policy, "img-src 'self' https: data: blob:"
    assert_includes policy, "connect-src 'self' https: ws: wss:"
    assert_includes policy, "style-src 'self' 'unsafe-inline'"
    assert_includes policy, "script-src 'self' 'nonce-#{nonce}'"
    assert_not_empty css_select("script")
    assert_empty css_select("script").reject { |script| script["nonce"] == nonce }
  end

  test "show grants membership with a valid invite token for signed-in users" do
    sign_in :jz
    room = rooms(:watercooler)

    assert_no_difference -> { Session.count } do
      assert_difference -> { room.memberships.count }, +1 do
        get room_url(room, invite: room.sso_invite_token)
      end
    end

    assert_response :success
    assert room.users.exists?(id: users(:jz).id)
  end

  test "show does not grant membership with an invalid invite token for signed-in users" do
    sign_in :jz
    room = rooms(:watercooler)

    assert_no_difference -> { room.memberships.count } do
      get room_url(room, invite: "invalid-token")
    end

    assert_redirected_to root_url
    assert_not room.users.exists?(id: users(:jz).id)
  end

  test "shows records the last room visited in a cookie" do
    get room_url(users(:david).rooms.last)
    assert response.cookies[:last_room] = users(:david).rooms.last.id
  end

  test "destroy" do
    assert_turbo_stream_broadcasts :rooms, count: 1 do
      assert_difference -> { Room.count }, -1 do
        delete room_url(rooms(:designers))
      end
    end
  end

  test "destroy only allowed for creators or those who can administer" do
    sign_in :jz

    assert_no_difference -> { Room.count } do
      delete room_url(rooms(:designers))
      assert_response :forbidden
    end

    rooms(:designers).update! creator: users(:jz)

    assert_difference -> { Room.count }, -1 do
      delete room_url(rooms(:designers))
    end
  end
end
