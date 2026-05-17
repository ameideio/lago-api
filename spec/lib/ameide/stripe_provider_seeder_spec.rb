# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("lib/ameide/stripe_provider_seeder")

RSpec.describe Ameide::StripeProviderSeeder do
  subject(:seed) { described_class.call(logger:) }

  let(:logger) { ->(_message) {} }
  let(:organization) { create(:organization, name: "Ameide") }

  let(:env) do
    {
      "AMEIDE_STRIPE_SEED" => gate,
      "STRIPE_SECRET_KEY" => secret_key,
      "LAGO_ORG_NAME" => org_name,
      "AMEIDE_STRIPE_PROVIDER_CODE" => provider_code,
      "AMEIDE_STRIPE_SUCCESS_URL" => nil
    }
  end

  let(:gate) { "true" }
  let(:secret_key) { "sk_test_123" }
  let(:org_name) { "Ameide" }
  let(:provider_code) { nil }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:fetch).and_call_original
    env.each do |key, value|
      allow(ENV).to receive(:[]).with(key).and_return(value)
      allow(ENV).to receive(:fetch).with(key, anything) do |_, default|
        value.nil? ? default : value
      end
    end
  end

  describe "gate disabled" do
    let(:gate) { "false" }

    it "is a graceful no-op and does not touch StripeService" do
      expect(PaymentProviders::StripeService).not_to receive(:new)
      expect(seed).to eq(:disabled)
    end
  end

  describe "blank secret key" do
    let(:secret_key) { "   " }

    it "is a graceful no-op and does not touch StripeService" do
      expect(PaymentProviders::StripeService).not_to receive(:new)
      expect(seed).to eq(:missing_secret)
    end
  end

  describe "no resolvable organization" do
    let(:org_name) { "does-not-exist" }

    it "is a graceful no-op and does not touch StripeService" do
      organization # ensure an org exists but with a different name
      expect(PaymentProviders::StripeService).not_to receive(:new)
      expect(seed).to eq(:no_organization)
    end
  end

  describe "gated on with a valid secret and resolvable org" do
    let(:service) { instance_double(PaymentProviders::StripeService) }
    let(:result) { BaseService::Result.new }

    before do
      organization
      allow(PaymentProviders::StripeService).to receive(:new).and_return(service)
      allow(service).to receive(:create_or_update).and_return(result)
    end

    it "calls StripeService#create_or_update with the expected args" do
      expect(seed).to eq(:seeded)

      expect(service).to have_received(:create_or_update).with(
        organization_id: organization.id,
        code: "stripe",
        name: "Stripe",
        secret_key: "sk_test_123",
        success_redirect_url: nil
      )
    end

    context "with a custom provider code" do
      let(:provider_code) { "stripe-eu" }

      it "passes the overridden code" do
        seed
        expect(service).to have_received(:create_or_update)
          .with(hash_including(code: "stripe-eu"))
      end
    end

    context "when the service fails" do
      let(:result) do
        BaseService::Result.new.tap do |r|
          r.service_failure!(code: "boom", message: "nope")
        rescue BaseService::FailedResult
          nil
        end
      end

      it "raises without leaking the secret" do
        expect { seed }.to raise_error(/StripeService failed/) do |error|
          expect(error.message).not_to include("sk_test_123")
        end
      end
    end
  end
end
