# frozen_string_literal: true

require "rails_helper"

RSpec.describe Auth::Oidc::AcceptInviteService, cache: :memory do
  subject(:service) { described_class.new(invite_token:, code:, state:) }

  let(:organization) { create(:organization) }
  let(:invite) { create(:invite, email: "foo@bar.com", organization:) }
  let(:invite_token) { invite.token }
  let(:http_client) { instance_double(LagoHttpClient::Client) }
  let(:provider_metadata) do
    {
      "authorization_endpoint" => "https://keycloak.example.com/realms/ameide/protocol/openid-connect/auth",
      "issuer" => "https://keycloak.example.com/realms/ameide",
      "token_endpoint" => "https://keycloak.example.com/realms/ameide/protocol/openid-connect/token",
      "userinfo_endpoint" => "https://keycloak.example.com/realms/ameide/protocol/openid-connect/userinfo"
    }
  end
  let(:token_response) { {"access_token" => "access_token"} }
  let(:userinfo_response) { {"email" => "foo@bar.com"} }
  let(:code) { "code" }
  let(:state) { SecureRandom.uuid }

  before do
    Rails.cache.clear
    invite_token
    stub_const(
      "ENV",
      ENV.to_h.merge(
        "LAGO_OIDC_ISSUER" => "https://keycloak.example.com/realms/ameide",
        "LAGO_OIDC_CLIENT_ID" => "billing-client",
        "LAGO_OIDC_CLIENT_SECRET" => "billing-secret",
        "LAGO_FRONT_URL" => "https://billing.example.com"
      )
    )

    Rails.cache.write("auth/oidc/state/#{state}", {"email" => "foo@bar.com"})

    allow(LagoHttpClient::Client).to receive(:new).and_return(http_client)
    allow(http_client).to receive(:get).and_return(provider_metadata, userinfo_response)
    allow(http_client).to receive(:post_url_encoded).and_return(token_response)
  end

  describe "#call" do
    it "creates user, membership, authenticates user and marks invite as accepted" do
      result = service.call

      expect(result).to be_success
      expect(result.user.email).to eq("foo@bar.com")
      expect(result.token).to be_present
      expect(invite.reload).to be_accepted

      decoded = Auth::TokenService.decode(token: result.token)
      expect(decoded["login_method"]).to eq(Organizations::AuthenticationMethods::OIDC)
    end

    context "when code is not provided" do
      let(:code) { nil }

      it "returns an error" do
        result = service.call

        expect(result).not_to be_success
        expect(result.error.messages).to eq({base: ["code_not_found"]})
      end
    end

    context "when state is not provided" do
      let(:state) { nil }

      it "returns an error" do
        result = service.call

        expect(result).not_to be_success
        expect(result.error.messages).to eq({base: ["state_not_found"]})
      end
    end

    context "when state is not found" do
      before do
        Rails.cache.clear
      end

      it "returns an error" do
        result = service.call

        expect(result).not_to be_success
        expect(result.error.messages.values.flatten).to include("state_not_found")
      end
    end

    context "when pending invite does not exist" do
      let(:invite) { create(:invite, email: "foo@bar.com", status: :accepted, organization:) }

      it "returns a failure result" do
        result = service.call

        expect(result).not_to be_success
        expect(result.error.messages.values.flatten).to include("invite_not_found")
      end
    end

    context "when oidc userinfo email is different from the state one" do
      let(:userinfo_response) { {"email" => "foo@test.com"} }

      it "returns an error" do
        result = service.call

        expect(result).not_to be_success
        expect(result.error.messages.values.flatten).to include("oidc_userinfo_error")
      end
    end
  end
end
