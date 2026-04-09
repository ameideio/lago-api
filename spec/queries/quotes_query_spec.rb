# frozen_string_literal: true

require "rails_helper"

RSpec.describe QuotesQuery do
  subject(:result) do
    described_class.call(organization:, pagination:, filters:, latest_version_only:)
  end

  let(:returned_ids) { result.quotes.pluck(:id) }
  let(:pagination) { nil }
  let(:latest_version_only) { false }
  let(:filters) { {} }
  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:quote_draft) { create(:quote, :draft, organization:, customer:, sequential_id: 1, version: 1, created_at: 3.days.ago) }
  let(:quote_approved) { create(:quote, :approved, organization:, customer:, sequential_id: 1, version: 2, created_at: 2.days.ago) }
  let(:quote_voided) { create(:quote, :voided, organization:, customer:, sequential_id: 1, version: 3, created_at: 1.day.ago) }

  before do
    quote_draft
    quote_approved
    quote_voided
  end

  it "returns all quotes" do
    expect(returned_ids.count).to eq(3)
    expect(returned_ids).to include(quote_draft.id)
    expect(returned_ids).to include(quote_approved.id)
    expect(returned_ids).to include(quote_voided.id)
  end

  context "with pagination" do
    let(:pagination) { {page: 2, limit: 2} }

    it "applies the pagination" do
      expect(result).to be_success
      expect(result.quotes.count).to eq(1)
      expect(result.quotes.current_page).to eq(2)
      expect(result.quotes.prev_page).to eq(1)
      expect(result.quotes.next_page).to be_nil
      expect(result.quotes.total_pages).to eq(2)
      expect(result.quotes.total_count).to eq(3)
    end
  end

  context "when filtering" do
    describe "customer" do
      context "when filtering by valid customer" do
        let(:other_customer) { create(:customer, organization:) }
        let(:other_quote) { create(:quote, :draft, organization:, customer: other_customer, sequential_id: 2, version: 1) }
        let(:filters) { {customer: [other_customer.id]} }

        before do
          other_quote
        end

        it "returns only one quote" do
          expect(result).to be_success
          expect(returned_ids.count).to eq(1)
          expect(returned_ids).to include(other_quote.id)
        end
      end

      context "when filtering by invalid status" do
        let(:filters) { {status: ["invalid_status"]} }

        it "returns a validation failure" do
          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
        end
      end
    end

    describe "status" do
      context "when filtering by valid status" do
        let(:filters) { {status: ["draft"]} }

        it "returns only one quote" do
          expect(result).to be_success
          expect(returned_ids.count).to eq(1)
          expect(returned_ids).to include(quote_draft.id)
        end
      end

      context "when filtering by invalid status" do
        let(:filters) { {status: ["invalid_status"]} }

        it "returns a validation failure" do
          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
        end
      end
    end

    describe "number" do
      context "when filtering by valid number" do
        let(:other_quote) { create(:quote, :draft, organization:, sequential_id: 2, version: 1) }
        let(:filters) { {number: [other_quote.number]} }

        before do
          other_quote
        end

        it "returns only one quote" do
          expect(result).to be_success
          expect(returned_ids.count).to eq(1)
          expect(returned_ids).to include(other_quote.id)
        end
      end

      context "when filtering by invalid number" do
        let(:filters) { {number: ["invalid_number"]} }

        it "returns a validation failure" do
          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
        end
      end
    end

    describe "version" do
      context "when filtering by valid version" do
        let(:filters) { {version: [quote_draft.version]} }

        it "returns only one quote" do
          expect(result).to be_success
          expect(returned_ids.count).to eq(1)
          expect(returned_ids).to include(quote_draft.id)
        end
      end

      context "when filtering by invalid version" do
        let(:filters) { {version: ["invalid_version"]} }

        it "returns a validation failure" do
          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
        end
      end
    end

    describe "date range" do
      context "when filtering by valid date range" do
        let(:filters) do
          {
            from_date: 2.hours.ago,
            to_date: 1.hour.ago
          }
        end

        it "returns quotes updated within the date range" do
          expect(result).to be_success
          expect(returned_ids.count).to eq(0)
        end
      end

      context "when filtering with invalid date format" do
        let(:filters) do
          {
            from_date: "invalid_date",
            to_date: "invalid_date"
          }
        end

        it "returns a validation failure" do
          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
        end
      end
    end

    describe "owners" do
      context "when filtering by valid owners" do
        let(:membership) { create(:membership, organization:) }
        let(:other_quote) { create(:quote, :draft, organization:, sequential_id: 2, version: 1) }
        let(:filters) { {owners: [membership.user.id]} }

        before do
          QuoteOwner.create!(organization:, quote: other_quote, user: membership.user)
        end

        it "returns only one quote" do
          expect(result).to be_success
          expect(returned_ids.count).to eq(1)
          expect(returned_ids).to include(other_quote.id)
        end
      end

      context "when filtering by invalid owners" do
        let(:filters) { {owners: ["invalid_owner"]} }

        it "returns a validation failure" do
          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
        end
      end
    end
  end

  context "when filtering by latest_version_only" do
    let(:latest_version_only) { true }

    it "returns only the latest version of each quote" do
      expect(result).to be_success
      expect(returned_ids.count).to eq(1)
      expect(returned_ids).to include(quote_voided.id)
    end
  end
end
