require "test_helper"

class SsoSessionsControllerTest < ActionDispatch::IntegrationTest
  OIDC_PROVIDER = :oidc_test

  setup do
    set_omniauth_auth(provider: OIDC_PROVIDER, uid: "idp-uid-123", email: "newuser@example.com", name: "New User")
  end

  teardown do
    clear_omniauth_auth
  end

  test "OIDC callback creates session for new user" do
    assert_difference [ -> { User.count }, -> { Session.count } ], +1 do
      get sso_callback_url(provider: OIDC_PROVIDER)
    end

    assert_redirected_to root_url
    assert cookies[:session_token].present?
    assert_equal OIDC_PROVIDER.to_s, Session.find_by(token: parsed_cookies.signed[:session_token]).sso_provider
  end

  test "OIDC callback stores id token hint on the session" do
    set_omniauth_auth(
      provider: OIDC_PROVIDER,
      uid: "idp-uid-token-1",
      email: "idtoken@example.com",
      id_token: "jwt-id-token"
    )

    get sso_callback_url(provider: OIDC_PROVIDER)

    session = Session.find_by(token: parsed_cookies.signed[:session_token])
    assert_equal "jwt-id-token", session.oidc_id_token
  end

  test "OIDC callback creates session for existing user matched by email" do
    user = users(:jz)
    set_omniauth_auth(provider: OIDC_PROVIDER, uid: "idp-uid-jz", email: user.email_address, name: user.name)

    assert_no_difference -> { User.count } do
      get sso_callback_url(provider: OIDC_PROVIDER)
    end

    assert_redirected_to root_url
    assert cookies[:session_token].present?
    assert_equal OIDC_PROVIDER.to_s, user.reload.sso_provider
    assert_equal "idp-uid-jz", user.sso_uid
  end

  test "OIDC callback creates session for returning SSO user" do
    user = users(:jz)
    user.update!(sso_provider: OIDC_PROVIDER.to_s, sso_uid: "idp-uid-jz")
    set_omniauth_auth(provider: OIDC_PROVIDER, uid: "idp-uid-jz", email: user.email_address, name: user.name)

    assert_no_difference -> { User.count } do
      get sso_callback_url(provider: OIDC_PROVIDER)
    end

    assert_redirected_to root_url
    assert cookies[:session_token].present?
  end

  test "first SSO login from a room invite grants membership to that room" do
    room = rooms(:watercooler)
    invite_url = room_url(room, invite: room.sso_invite_token)

    get invite_url
    assert_redirected_to new_session_url

    assert_difference -> { room.memberships.count }, +1 do
      get sso_callback_url(provider: OIDC_PROVIDER)
    end

    assert_redirected_to invite_url
    assert room.users.exists?(email_address: "newuser@example.com")
  end

  test "SSO login from a room invite grants membership to returning SSO user" do
    user = users(:jz)
    room = rooms(:watercooler)
    invite_url = room_url(room, invite: room.sso_invite_token)

    user.update!(sso_provider: OIDC_PROVIDER.to_s, sso_uid: "idp-uid-jz")
    user.sessions.create!(user_agent: "Existing browser", ip_address: "127.0.0.1")
    set_omniauth_auth(provider: OIDC_PROVIDER, uid: "idp-uid-jz", email: user.email_address, name: user.name)

    get invite_url
    assert_redirected_to new_session_url

    assert_difference -> { room.memberships.count }, +1 do
      get sso_callback_url(provider: OIDC_PROVIDER)
    end

    assert_redirected_to invite_url
    assert room.users.exists?(id: user.id)
  end

  test "SSO login grants invited room membership from OmniAuth origin" do
    room = rooms(:watercooler)
    invite_url = room_url(room, invite: room.sso_invite_token)

    assert_difference -> { room.memberships.count }, +1 do
      get sso_callback_url(provider: OIDC_PROVIDER), env: { "omniauth.origin" => invite_url }
    end

    assert room.users.exists?(email_address: "newuser@example.com")
  end

  test "first SSO login from an account join link creates user and returns through join link" do
    join_link = join_url(accounts(:signal).join_code)

    with_sso_join_enabled do
      get join_link
      assert_redirected_to new_session_url

      assert_difference -> { User.count }, +1 do
        get sso_callback_url(provider: OIDC_PROVIDER)
      end
    end

    assert_redirected_to join_link

    follow_redirect!
    assert_redirected_to root_url
    assert User.exists?(email_address: "newuser@example.com")
  end

  test "first SSO login does not return through an invalid account join link" do
    with_sso_join_enabled do
      get join_url("not")
      assert_response :not_found

      get sso_callback_url(provider: OIDC_PROVIDER)
    end

    assert_redirected_to root_url
  end

  test "first SSO login ignores invalid room invite token" do
    room = rooms(:watercooler)
    invite_url = room_url(room, invite: "invalid-token")

    get invite_url
    assert_redirected_to new_session_url

    assert_no_difference -> { room.memberships.count } do
      get sso_callback_url(provider: OIDC_PROVIDER)
    end

    assert_redirected_to invite_url
    assert_not room.users.exists?(email_address: "newuser@example.com")
  end

  test "callback blocks deactivated user" do
    user = users(:jz)
    user.update!(status: :deactivated, sso_provider: OIDC_PROVIDER.to_s, sso_uid: "idp-uid-jz")
    set_omniauth_auth(provider: OIDC_PROVIDER, uid: "idp-uid-jz", email: user.email_address)

    get sso_callback_url(provider: OIDC_PROVIDER)

    assert_redirected_to new_session_url
    assert_equal "Your account has been deactivated.", flash[:alert]
  end

  test "OIDC callback redirects to login when omniauth.auth is missing" do
    clear_omniauth_auth

    get sso_callback_url(provider: OIDC_PROVIDER)

    assert_redirected_to new_session_url
  end

  test "failure redirects to login with error message" do
    get sso_failure_url(message: "invalid_credentials", strategy: "oidc")

    assert_redirected_to new_session_url
    assert_match "SSO authentication failed", flash[:alert]
    assert_match "Invalid credentials", flash[:alert]
  end

  test "failure shows detailed message when provided" do
    get sso_failure_url(message: "invalid_credentials", strategy: "oidc", detail: "Issuer mismatch")

    assert_redirected_to new_session_url
    assert_match "Issuer mismatch", flash[:alert]
  end

  test "failure truncates large detail message" do
    get sso_failure_url(message: "invalid_credentials", strategy: "oidc", detail: ("a" * 1000))

    assert_redirected_to new_session_url
    assert_operator flash[:alert].length, :<=, 400
  end

  private
    def with_sso_join_enabled(&)
      with_env(
        "OIDC_PROVIDERS" => "test",
        "OIDC_TEST_ISSUER" => "https://idp.example.test/realms/campfire",
        "OIDC_TEST_CLIENT_ID" => "test-client-id",
        "OIDC_TEST_CLIENT_SECRET" => "test-client-secret",
        "OIDC_TEST_REDIRECT_URI" => "https://campfire.example.test/auth/#{OIDC_PROVIDER}/callback",
        "DISABLE_PASSWORD_REGISTRATION" => "true",
        &
      )
    end
end
