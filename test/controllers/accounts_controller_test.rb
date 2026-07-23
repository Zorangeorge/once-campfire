require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :david
  end

  test "edit" do
    get edit_account_url
    assert_response :ok
  end

  test "edit groups administrators separately from members with a divider" do
    get edit_account_url

    assert_response :ok

    # Verify the divider exists between administrator and member sections
    assert_select "turbo-frame#account_users hr.separator.separator--solid.full-width"

    # Verify administrators appear before the divider and members appear after
    # by checking the order of user names in the response body
    administrators = users(:david, :jason).map(&:name)
    members = users(:jz, :kevin).map(&:name)

    response_body = response.body

    # Find positions of divider and user names
    divider_position = response_body.index('hr class="separator separator--solid full-width"')
    assert divider_position, "Divider should exist in the response"

    administrators.each do |name|
      name_position = response_body.index("<strong>#{name}</strong>")
      assert name_position, "Administrator #{name} should appear in the response"
      assert name_position < divider_position, "Administrator #{name} should appear before the divider"
    end

    members.each do |name|
      name_position = response_body.index("<strong>#{name}</strong>")
      assert name_position, "Member #{name} should appear in the response"
      assert name_position > divider_position, "Member #{name} should appear after the divider"
    end
  end

  test "edit shows account join link when SSO is enabled and password registration is disabled" do
    with_sso_join_enabled do
      get edit_account_url

      assert_response :ok
      assert_select "input#invite_url" do |elements|
        assert_equal join_url(accounts(:signal).join_code), elements.first["value"]
      end
    end
  end

  test "update" do
    assert users(:david).administrator?

    put account_url, params: { account: { name: "Different" } }

    assert_redirected_to edit_account_url
    assert_equal accounts(:signal).name, "Different"
  end

  test "non-admins cannot update" do
    sign_in :kevin
    assert users(:kevin).member?

    put account_url, params: { account: { name: "Different" } }
    assert_response :forbidden
  end

  private
    def with_sso_join_enabled(&)
      with_env(
        "OIDC_PROVIDERS" => "test",
        "OIDC_TEST_ISSUER" => "https://idp.example.test/realms/campfire",
        "OIDC_TEST_CLIENT_ID" => "test-client-id",
        "OIDC_TEST_CLIENT_SECRET" => "test-client-secret",
        "OIDC_TEST_REDIRECT_URI" => "https://campfire.example.test/auth/oidc_test/callback",
        "DISABLE_PASSWORD_REGISTRATION" => "true",
        &
      )
    end
end
