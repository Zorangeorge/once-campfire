require "test_helper"

class Rooms::OpensControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :david
  end

  test "show redirects to get general show" do
    get rooms_open_url(users(:david).rooms.opens.last)
    assert_redirected_to room_url(users(:david).rooms.opens.last)
  end

  test "new" do
    get new_rooms_open_url
    assert_response :success
  end

  test "edit does not expose room SSO invite link when SSO is enabled" do
    with_sso_enabled do
      get edit_rooms_open_url(rooms(:pets))

      assert_response :success
      assert_select "input#invite_url", count: 0
    end
  end

  test "create" do
    assert_turbo_stream_broadcasts :rooms, count: 1 do
      post rooms_opens_url, params: { room: { name: "My New Room" } }
    end

    assert_equal Room.last.memberships.count, User.count
    assert_redirected_to room_url(Room.last)
  end

  test "create forbidden by non-admin when account restricts creation to admins" do
    accounts(:signal).settings.restrict_room_creation_to_administrators = true
    accounts(:signal).save!

    sign_in :jz
    post rooms_opens_url, params: { room: { name: "My New Room" } }
    assert_response :forbidden
  end

  test "only admins or creators can update" do
    sign_in :jz

    assert_turbo_stream_broadcasts :rooms, count: 0 do
      put rooms_open_url(rooms(:hq)), params: { room: { name: "New Name" } }
    end

    assert_response :forbidden
    assert rooms(:hq).reload.name, "HQ"
  end

  test "update" do
    assert_turbo_stream_broadcasts :rooms, count: 1 do
      put rooms_open_url(rooms(:pets)), params: { room: { name: "New Name" } }
    end

    assert_redirected_to room_url(rooms(:pets))
    assert rooms(:pets).reload.name, "New Name"
  end

  test "update a closed room to be open" do
    put rooms_open_url(rooms(:designers)), params: { room: { name: "Doesn't matter" } }
    assert_equal rooms(:designers).memberships.count, User.count
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
