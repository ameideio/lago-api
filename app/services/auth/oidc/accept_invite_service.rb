# frozen_string_literal: true

module Auth
  module Oidc
    class AcceptInviteService < BaseService
      def initialize(invite_token:, code:, state:)
        @invite_token = invite_token
        @code = code
        @state = state

        super()
      end

      def call
        check_setup
        check_state
        check_code
        check_invite
        query_provider_metadata
        query_oidc_access_token
        check_userinfo

        Invites::AcceptService.new.call(
          invite: result.invite,
          email: result.email,
          token: invite_token,
          password: SecureRandom.hex,
          login_method: Organizations::AuthenticationMethods::OIDC
        )
      rescue ValidationError => e
        result.single_validation_failure!(error_code: e.message)
        result
      end

      private

      attr_reader :invite_token, :code, :state
    end
  end
end
