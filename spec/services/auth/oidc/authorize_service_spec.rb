# frozen_string_literal: true

require "rails_helper"

RSpec.describe Auth::Oidc::AuthorizeService, cache: :memory do
  subject(:service) { described_class.new(invite_token:) }

  let(:invite_token) { nil }
  let(:provider_metadata) do
    {
      "authorization_endpoint" => "https://keycloak.example.com/realms/ameide/protocol/openid-connect/auth",
      "issuer" => "https://keycloak.example.com/realms/ameide",
      "token_endpoint" => "https://keycloak.example.com/realms/ameide/protocol/openid-connect/token",
      "userinfo_endpoint" => "https://keycloak.example.com/realms/ameide/protocol/openid-connect/userinfo"
    }
  end
  let(:http_client) { instance_double(LagoHttpClient::Client) }

  before do
    Rails.cache.clear
    stub_const(
      "ENV",
      ENV.to_h.merge(
        "LAGO_OIDC_ISSUER" => "https://keycloak.example.com/realms/ameide",
        "LAGO_OIDC_CLIENT_ID" => "billing-client",
        "LAGO_OIDC_CLIENT_SECRET" => "billing-secret",
        "LAGO_FRONT_URL" => "https://billing.example.com"
      )
    )

    allow(LagoHttpClient::Client).to receive(:new).and_return(http_client)
    allow(http_client).to receive(:get).and_return(provider_metadata)
  end

  describe "#call" do
    it "returns an authorize url" do
      result = service.call

      expect(result).to be_success
      expect(result.url).to include(provider_metadata["authorization_endpoint"])
      expect(result.url).to include("client_id=billing-client")
      expect(result.url).to include("redirect_uri=https%3A%2F%2Fbilling.example.com%2Fauth%2Foidc%2Fcallback")
      expect(result.url).to include("scope=openid+profile+email")
      expect(result.url).to include("state=")
    end

    context "when setup is missing" do
      before do
        stub_const(
          "ENV",
          ENV.to_h.merge(
            "LAGO_OIDC_ISSUER" => "",
            "LAGO_OIDC_CLIENT_ID" => "",
            "LAGO_OIDC_CLIENT_SECRET" => "",
            "LAGO_FRONT_URL" => "https://billing.example.com"
          )
        )
      end

      it "returns a failure result" do
        result = service.call

        expect(result).not_to be_success
        expect(result.error.messages.values.flatten).to include("oidc_auth_missing_setup")
      end
    end

    context "with invite token" do
      let(:invite) { create(:invite, email: "foo@bar.com") }
      let(:invite_token) { invite.token }

      it "adds the invite email as login hint" do
        result = service.call

        expect(result).to be_success
        expect(result.url).to include("login_hint=foo%40bar.com")
      end
    end
  end
end
