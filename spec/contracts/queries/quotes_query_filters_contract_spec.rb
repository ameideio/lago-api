# frozen_string_literal: true

require "rails_helper"

RSpec.describe Queries::QuotesQueryFiltersContract do
  subject(:result) { described_class.new.call(filters.to_h) }

  let(:filters) { {} }

  context "when filtering by customer" do
    let(:filters) { {customer: ["00000000-0000-0000-0000-000000000000"]} }

    it "is valid" do
      expect(result.success?).to be(true)
    end

    context "when customer filter is invalid" do
      context "when filter is a string" do
        let(:filters) { {customer: "wrong"} }

        it "is invalid" do
          expect(result.success?).to be(false)
          expect(result.errors.to_h).to include({customer: ["must be an array"]})
        end
      end

      context "when filter is an array with invalid values" do
        let(:filters) { {customer: ["wrong"]} }

        it "is invalid" do
          expect(result.success?).to be(false)
          expect(result.errors.to_h).to include({customer: {0 => ["is in invalid format"]}})
        end
      end
    end
  end

  context "when filtering by status" do
    context "when filter is valid" do
      let(:filters) { {status: ["draft"]} }

      it "is valid" do
        expect(result.success?).to be(true)
      end
    end

    context "when status filter is invalid" do
      context "when filter is a string" do
        let(:filters) { {status: "wrong"} }

        it "is invalid" do
          expect(result.success?).to be(false)
          expect(result.errors.to_h).to include({status: ["must be an array"]})
        end
      end

      context "when filter is an array with invalid values" do
        let(:filters) { {status: ["wrong"]} }

        it "is invalid" do
          expect(result.success?).to be(false)
          expect(result.errors.to_h).to include({status: {0 => ["must be one of: draft, approved, voided"]}})
        end
      end
    end
  end

  context "when filtering by number" do
    context "when filter is valid" do
      let(:filters) { {number: ["QT-2025-0001"]} }

      it "is valid" do
        expect(result.success?).to be(true)
      end
    end

    context "when number filter is invalid" do
      context "when filter is a string" do
        let(:filters) { {number: "wrong"} }

        it "is invalid" do
          expect(result.success?).to be(false)
          expect(result.errors.to_h).to include({number: ["must be an array"]})
        end
      end

      context "when filter is an array with invalid values" do
        let(:filters) { {number: ["wrong"]} }

        it "is invalid" do
          expect(result.success?).to be(false)
          expect(result.errors.to_h).to include({number: {0 => ["is in invalid format"]}})
        end
      end
    end
  end

  context "when filtering by version" do
    context "when filter is valid" do
      let(:filters) { {version: [1]} }

      it "is valid" do
        expect(result.success?).to be(true)
      end
    end

    context "when version filter is invalid" do
      context "when filter is a string" do
        let(:filters) { {version: "wrong"} }

        it "is invalid" do
          expect(result.success?).to be(false)
          expect(result.errors.to_h).to include({version: ["must be an array"]})
        end
      end

      context "when filter is an array with invalid values" do
        let(:filters) { {version: ["wrong"]} }

        it "is invalid" do
          expect(result.success?).to be(false)
          expect(result.errors.to_h).to include({version: {0 => ["must be an integer"]}})
        end
      end
    end
  end

  context "when filtering by from_date and to_date" do
    context "when filters are valid" do
      let(:filters) { {from_date: 2.days.ago, to_date: Time.current} }

      it "is valid" do
        expect(result.success?).to be(true)
      end
    end

    context "when from_date is invalid" do
      let(:filters) { {from_date: "invalid date"} }

      it "is invalid" do
        expect(result.success?).to be(false)
        expect(result.errors.to_h).to include({from_date: ["must be a time"]})
      end
    end

    context "when to_date is invalid" do
      let(:filters) { {to_date: "invalid date"} }

      it "is invalid" do
        expect(result.success?).to be(false)
        expect(result.errors.to_h).to include({to_date: ["must be a time"]})
      end
    end
  end

  context "when filtering by owners" do
    context "when filter is valid" do
      let(:filters) { {owners: ["00000000-0000-0000-0000-000000000000"]} }

      it "is valid" do
        expect(result.success?).to be(true)
      end
    end

    context "when owners filter is invalid" do
      context "when filter is a string" do
        let(:filters) { {owners: "wrong"} }

        it "is invalid" do
          expect(result.success?).to be(false)
          expect(result.errors.to_h).to include({owners: ["must be an array"]})
        end
      end

      context "when filter is an array with invalid values" do
        let(:filters) { {owners: ["wrong"]} }

        it "is invalid" do
          expect(result.success?).to be(false)
          expect(result.errors.to_h).to include({owners: {0 => ["is in invalid format"]}})
        end
      end
    end
  end
end
