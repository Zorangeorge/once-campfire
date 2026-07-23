require "test_helper"

class Rooms::ClosedsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :david
  end

  test "show redirects to get general show" do
    get rooms_open_url(users(:david).rooms.closeds.last)
    assert_redirected_to room_url(users(:david).rooms.closeds.last)
  end

  test "new" do
    get new_rooms_closed_url
    assert_response :success
  end

  test "edit exposes room SSO invite link when SSO is enabled" do
    with_sso_enabled do
      get edit_rooms_closed_url(rooms(:watercooler))

      assert_response :success
      assert_select "input#invite_url[value=?]", room_url(rooms(:watercooler), invite: rooms(:watercooler).sso_invite_token)
    end
  end

  test "edit does not expose room SSO invite link when SSO is disabled" do
    with_env("OIDC_PROVIDERS" => nil) do
      get edit_rooms_closed_url(rooms(:watercooler))
    end

    assert_response :success
    assert_select "input#invite_url", count: 0
  end

  test "create" do
    assert_turbo_stream_broadcasts [ users(:david), :rooms ], count: 1 do
    assert_turbo_stream_broadcasts [ users(:kevin), :rooms ], count: 1 do
    assert_turbo_stream_broadcasts [ users(:jason), :rooms ], count: 1 do
      post rooms_closeds_url, params: { room: { name: "My New Room" }, user_ids: [ users(:david).id, users(:kevin).id, users(:jason).id ] }
    end
    end
    end

    new_room = Room.last
    assert_equal new_room.memberships.count, 3
    assert_redirected_to room_url(Room.last)
  end

  test "create forbidden by non-admin when account restricts creation to admins" do
    accounts(:signal).settings.restrict_room_creation_to_administrators = true
    accounts(:signal).save!

    sign_in :jz
    post rooms_closeds_url, params: { room: { name: "My New Room" }, user_ids: [ users(:david).id, users(:kevin).id, users(:jason).id ] }
    assert_response :forbidden
  end


  test "update with membership revisions" do
    assert_difference -> { rooms(:designers).reload.users.count }, -1 do
      put rooms_closed_url(rooms(:designers)), params: {
        room: { name: "New Name" }, user_ids: rooms(:designers).users.without(users(:jason)).collect(&:id)
      }
    end

    assert_redirected_to room_url(rooms(:designers))
    assert rooms(:designers).reload.name, "New Name"
  end

  test "update an open room to be closed" do
    put rooms_closed_url(rooms(:pets)), params: { room: { name: "Doesn't matter" }, user_ids: [ users(:david).id, users(:jason).id ] }
    assert_equal rooms(:pets).memberships.count, 2
  end

  test "only admins or creators can update" do
    sign_in :jz

    assert_turbo_stream_broadcasts :rooms, count: 0 do
      put rooms_closed_url(rooms(:designers)), params: { room: { name: "New Name" } }
    end

    assert_response :forbidden
    assert rooms(:designers).reload.name, "Designers"
  end

  test "remove yourself" do
    assert_difference -> { users(:david).rooms.count }, -1 do
      put rooms_closed_url(rooms(:designers), params: { room: { name: "Designers" }, user_ids: [ users(:jason).id, users(:jz).id ] })

      assert_redirected_to room_url(rooms(:designers))
      follow_redirect!
      assert_redirected_to root_url
    end
  end

  private
    def with_sso_enabled(&)
      with_env(
        "OIDC_PROVIDERS" => "test",
        "OIDC_TEST_ISSUER" => "https://idp.example.test/realms/campfire",
        "OIDC_TEST_CLIENT_ID" => "test-client-id",
        "OIDC_TEST_CLIENT_SECRET" => "test-client-secret",
        "OIDC_TEST_REDIRECT_URI" => "https://campfire.example.test/auth/oidc_test/callback",
        &
      )
    end
end
