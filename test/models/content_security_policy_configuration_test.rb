require "test_helper"

class ContentSecurityPolicyConfigurationTest < ActiveSupport::TestCase
  test "form action sources parses comma and whitespace separated env values" do
    env = {
      "CSP_FORM_ACTION_SOURCES" => "https://auth.example.test, https://*.bloxweaver.com\nhttps://idp.example.test"
    }

    assert_equal [
      "https://auth.example.test",
      "https://*.bloxweaver.com",
      "https://idp.example.test"
    ], ContentSecurityPolicyConfiguration.form_action_sources(env:)
  end

  test "form action sources ignores blanks and duplicates" do
    env = { "CSP_FORM_ACTION_SOURCES" => " https://auth.example.test,, https://auth.example.test " }

    assert_equal [ "https://auth.example.test" ], ContentSecurityPolicyConfiguration.form_action_sources(env:)
  end
end
