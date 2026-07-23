class ContentSecurityPolicyConfiguration
  FORM_ACTION_SOURCES_ENV_KEY = "CSP_FORM_ACTION_SOURCES".freeze

  class << self
    def form_action_sources(env: ENV)
      parse_sources(env[FORM_ACTION_SOURCES_ENV_KEY])
    end

    private
      def parse_sources(raw_sources)
        raw_sources.to_s.split(/[\s,]+/).reject(&:blank?).uniq
      end
  end
end
