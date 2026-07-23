# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.base_uri    :self
    policy.font_src    :self, :data
    policy.form_action :self, -> { ContentSecurityPolicyConfiguration.form_action_sources }
    policy.frame_ancestors :none
    policy.img_src     :self, :https, :data, :blob
    policy.media_src   :self, :https, :data, :blob
    policy.object_src  :none
    policy.script_src  :self
    policy.style_src   :self
    policy.style_src_attr :none
    policy.connect_src :self, :https, :ws, :wss
    policy.worker_src  :self, :blob
    policy.manifest_src :self
  end

  # Generate nonces for importmap, custom CSS, and any other tags Rails marks as nonced.
  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src style-src]
end
