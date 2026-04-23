# frozen_string_literal: true

module Auth
  module Oidc
    class BaseService < BaseService
      OIDC_DISCOVERY_CACHE_KEY = "auth/oidc/discovery"
      OIDC_SCOPES = "openid profile email"
      OIDC_STATE_CACHE_KEY_PREFIX = "auth/oidc/state"
      OIDC_STATE_TTL = 10.minutes
      PROVIDER_METADATA_KEYS = %w[
        authorization_endpoint
        issuer
        token_endpoint
        userinfo_endpoint
      ].freeze

      Result = BaseResult[
        :email,
        :expected_email,
        :invite,
        :oidc_access_token,
        :provider_metadata,
        :state,
        :token,
        :url,
        :user,
        :userinfo
      ]

      private

      def authorize_url_for(state:, login_hint: nil)
        uri = URI(result.provider_metadata.fetch("authorization_endpoint"))
        params = URI.decode_www_form(uri.query || "").to_h

        params.merge!(
          {
            client_id: ENV["LAGO_OIDC_CLIENT_ID"],
            redirect_uri: redirect_uri,
            response_type: "code",
            scope: oidc_scopes,
            state:
          }
        )

        if login_hint.present?
          params[:login_hint] = login_hint
        end

        uri.query = URI.encode_www_form(params)
        uri.to_s
      end

      def check_code
        raise ValidationError, "code_not_found" if code.blank?
      end

      def check_invite
        invite = Invite.pending.find_by(token: invite_token)
        raise ValidationError, "invite_not_found" if invite.blank?

        result.invite = invite
        result.expected_email = invite.email
      end

      def check_setup
        if ENV["LAGO_OIDC_ISSUER"].present? &&
            ENV["LAGO_OIDC_CLIENT_ID"].present? &&
            ENV["LAGO_OIDC_CLIENT_SECRET"].present?
          return
        end

        raise ValidationError, "oidc_auth_missing_setup"
      end

      def check_state
        raise ValidationError, "state_not_found" if state.blank?

        stored_state = Rails.cache.read(oidc_state_cache_key(state))
        raise ValidationError, "state_not_found" if stored_state.blank?

        Rails.cache.delete(oidc_state_cache_key(state))
        result.expected_email = stored_state["email"]
      end

      def check_userinfo
        userinfo_client = LagoHttpClient::Client.new(result.provider_metadata.fetch("userinfo_endpoint"))
        userinfo_headers = {"Authorization" => "Bearer #{result.oidc_access_token}"}
        response = userinfo_client.get(headers: userinfo_headers)
        email = response["email"]

        if email.blank?
          raise ValidationError, "oidc_userinfo_error"
        end

        if result.expected_email.present? && response["email"] != result.expected_email
          raise ValidationError, "oidc_userinfo_error"
        end

        result.email = email
        result.userinfo = response
      rescue LagoHttpClient::HttpError
        raise ValidationError, "oidc_userinfo_error"
      end

      def discovery_url
        "#{ENV["LAGO_OIDC_ISSUER"].chomp("/")}/.well-known/openid-configuration"
      end

      def oidc_scopes
        ENV.fetch("LAGO_OIDC_SCOPES", OIDC_SCOPES)
      end

      def query_oidc_access_token
        params = {
          client_id: ENV["LAGO_OIDC_CLIENT_ID"],
          client_secret: ENV["LAGO_OIDC_CLIENT_SECRET"],
          grant_type: "authorization_code",
          code:,
          redirect_uri: redirect_uri
        }

        token_client = LagoHttpClient::Client.new(result.provider_metadata.fetch("token_endpoint"))
        response = token_client.post_url_encoded(params, {})
        access_token = response["access_token"]

        if access_token.blank?
          raise ValidationError, "oidc_invalid_code"
        end

        result.oidc_access_token = access_token
      rescue LagoHttpClient::HttpError
        raise ValidationError, "oidc_invalid_code"
      end

      def query_provider_metadata
        provider_metadata = Rails.cache.fetch(OIDC_DISCOVERY_CACHE_KEY, expires_in: 5.minutes) do
          LagoHttpClient::Client.new(discovery_url).get
        end

        if PROVIDER_METADATA_KEYS.any? { |key| provider_metadata[key].blank? }
          raise ValidationError, "oidc_auth_missing_setup"
        end

        result.provider_metadata = provider_metadata
      rescue LagoHttpClient::HttpError
        raise ValidationError, "oidc_auth_missing_setup"
      end

      def redirect_uri
        "#{ENV["LAGO_FRONT_URL"]}/auth/oidc/callback"
      end

      def write_state(email: nil)
        generated_state = SecureRandom.uuid
        state_payload = {"email" => email}

        Rails.cache.write(oidc_state_cache_key(generated_state), state_payload, expires_in: OIDC_STATE_TTL)
        result.state = generated_state
      end

      def oidc_state_cache_key(value)
        "#{OIDC_STATE_CACHE_KEY_PREFIX}/#{value}"
      end
    end

    class ValidationError < StandardError; end
  end
end
