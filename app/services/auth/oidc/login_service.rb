# frozen_string_literal: true

module Auth
  module Oidc
    class LoginService < BaseService
      def initialize(code:, state:)
        @code = code
        @state = state

        super()
      end

      def call
        check_setup
        check_state
        check_code
        query_provider_metadata
        query_oidc_access_token
        check_userinfo
        find_user

        unless result.user.active_organizations.pluck(:authentication_methods).flatten.uniq.include?(Organizations::AuthenticationMethods::OIDC)
          return result.single_validation_failure!(
            error_code: "login_method_not_authorized",
            field: Organizations::AuthenticationMethods::OIDC
          )
        end

        UserDevices::RegisterService.call!(user: result.user)
        generate_token
      rescue ValidationError => e
        result.single_validation_failure!(error_code: e.message)
        result
      end

      private

      attr_reader :code, :state

      def find_user
        user = User.find_by(email: result.email)

        if user.blank? || user.memberships.active.none?
          raise ValidationError, "user_does_not_exist"
        end

        result.user = user
      end

      def generate_token
        result.token = Auth::TokenService.encode(user: result.user, login_method: Organizations::AuthenticationMethods::OIDC)

        result
      rescue => e
        result.service_failure!(code: "token_encoding_error", message: e.message)
      end
    end
  end
end
