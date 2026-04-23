# frozen_string_literal: true

require "rails_helper"

RSpec.describe Auth::Oidc::LoginService, cache: :memory do
  let(:service) { described_class.new(code:, state:) }
  let(:user) { create(:user, email: "foo@bar.com") }
  let(:organization) { create(:organization) }
  let(:membership) { create(:membership, user:, organization:) }
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
  let(:state) { SecureRandom.uuid }
  let(:code) { "code" }

  before do
    Rails.cache.clear
    membership
    stub_const(
      "ENV",
      ENV.to_h.merge(
        "LAGO_OIDC_ISSUER" => "https://keycloak.example.com/realms/ameide",
        "LAGO_OIDC_CLIENT_ID" => "billing-client",
        "LAGO_OIDC_CLIENT_SECRET" => "billing-secret",
        "LAGO_FRONT_URL" => "https://billing.example.com"
      )
    )

    Rails.cache.write("auth/oidc/state/#{state}", {"email" => nil})

    allow(LagoHttpClient::Client).to receive(:new).and_return(http_client)
    allow(http_client).to receive(:get).and_return(provider_metadata, userinfo_response)
    allow(http_client).to receive(:post_url_encoded).and_return(token_response)
    allow(UserDevices::RegisterService).to receive(:call!)
  end

  describe "#call" do
    it "registers the user device" do
      result = service.call

      expect(UserDevices::RegisterService).to have_received(:call!).with(user: result.user)
    end

    it "authenticates the existing user" do
      result = service.call

      expect(result).to be_success
      expect(result.user.email).to eq("foo@bar.com")
      expect(result.token).to be_present

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

    context "when the login method is not allowed" do
      before do
        organization.disable_oidc_authentication!
      end

      it "returns an error" do
        result = service.call

        expect(result).not_to be_success
        expect(result.error.messages).to match(oidc: ["login_method_not_authorized"])
      end
    end

    context "when the oidc userinfo email is different from the state one" do
      before do
        Rails.cache.write("auth/oidc/state/#{state}", {"email" => "test@bar.com"})
      end

      it "returns an error" do
        result = service.call

        expect(result).not_to be_success
        expect(result.error.messages.values.flatten).to include("oidc_userinfo_error")
      end
    end

    context "when user does not exist" do
      before do
        membership.destroy!
        user.destroy!
      end

      it "returns an error" do
        result = service.call

        expect(result).not_to be_success
        expect(result.error.messages.values.flatten).to include("user_does_not_exist")
      end
    end
  end
end
