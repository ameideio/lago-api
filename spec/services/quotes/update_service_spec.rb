# frozen_string_literal: true

require "rails_helper"

RSpec.describe Quotes::UpdateService do
  subject(:update_service) { described_class.new(quote:, params: update_params) }

  let(:organization) { create(:organization, feature_flags: ["order_forms"]) }
  let(:membership) { create(:membership, organization:) }
  let(:owner) { membership.user }
  let(:quote) { create(:quote, :with_version, organization:) }
  let(:update_params) {
    {
      currency: "USD",
      owners: [owner.id]
    }
  }

  describe ".call" do
    let(:result) { update_service.call }

    context "when draft quote", :premium do
      it "updates the quote" do
        expect(result).to be_success
        expect(result.quote.id).to eq(quote.id)
        expect(result.quote.organization_id).to eq(quote.organization_id)
        expect(result.quote.customer_id).to eq(quote.customer_id)
        expect(result.quote.sequential_id).to eq(quote.sequential_id)
        expect(result.quote.number).to eq(quote.number)
        expect(result.quote.currency).to eq("USD")
        expect(result.quote.owner_ids).to eq([owner.id])
      end
    end

    context "when approved quote", :premium do
      let(:quote) { create(:quote, :with_version, version_trait: :approved, organization:) }

      it "returns validation failure" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::MethodNotAllowedFailure)
        expect(result.error.code).to eq("inappropriate_state")
      end
    end

    context "when voided quote", :premium do
      let(:quote) { create(:quote, :with_version, version_trait: :voided, organization:) }

      it "returns validation failure" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::MethodNotAllowedFailure)
        expect(result.error.code).to eq("inappropriate_state")
      end
    end

    context "when owners include invalid user ids", :premium do
      let(:update_params) { {owners: ["invalid_user_id"]} }

      it "returns validation failure" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:quotes]).to eq(["invalid_owner"])
      end
    end

    context "when quote does not exist", :premium do
      let(:quote) { nil }

      it "returns a not found error" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.message).to eq("quote_not_found")
      end
    end

    context "when license is not premium" do
      it "returns forbidden status" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ForbiddenFailure)
        expect(result.error.code).to eq("feature_unavailable")
      end
    end
  end
end
