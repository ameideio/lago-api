# frozen_string_literal: true

module Auth
  module Oidc
    class AuthorizeService < BaseService
      def initialize(invite_token: nil)
        @invite_token = invite_token

        super()
      end

      def call
        check_setup
        query_provider_metadata

        if invite_token.present?
          check_invite
        end

        write_state(email: result.expected_email)
        result.url = authorize_url_for(state: result.state, login_hint: result.expected_email)

        result
      rescue ValidationError => e
        result.single_validation_failure!(error_code: e.message)
        result
      end

      private

      attr_reader :invite_token
    end
  end
end
