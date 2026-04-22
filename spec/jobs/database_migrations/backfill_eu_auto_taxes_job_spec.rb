# frozen_string_literal: true

require "rails_helper"

RSpec.describe DatabaseMigrations::BackfillEuAutoTaxesJob do
  subject(:perform_job) { described_class.perform_now }

  let(:organization) { create(:organization) }
  let(:billing_entity) { create(:billing_entity, organization:, country: "FR", eu_tax_management: true) }

  let(:fr_standard) { create(:tax, organization:, code: "lago_eu_fr_standard") }

  before do
    stub_const("#{described_class}::ORGANIZATION_ID", organization.id)
    create(:tax, organization:, code: "lago_eu_de_standard")
  end

  def apply_tax(customer, tax)
    create(:customer_applied_tax, customer:, tax:)
  end

  context "when customer country differs from currently applied EU standard tax" do
    let(:customer) do
      create(:customer, organization:, billing_entity:, country: "DE", zipcode: "10115", tax_identification_number: nil)
    end

    before { apply_tax(customer, fr_standard) }

    it "re-applies the customer country standard tax" do
      perform_job

      expect(customer.reload.taxes.pluck(:code)).to contain_exactly("lago_eu_de_standard")
    end

    context "when the customer also has a manually applied non-EU tax" do
      let!(:custom_tax) { create(:tax, organization:, code: "custom_local_tax") }

      before { apply_tax(customer, custom_tax) }

      it "preserves the manually applied non-EU tax" do
        perform_job

        expect(customer.reload.taxes.pluck(:code)).to match_array(["lago_eu_de_standard", "custom_local_tax"])
      end
    end
  end

  context "when customer country matches the currently applied EU standard tax" do
    let(:customer) { create(:customer, organization:, billing_entity:, country: "FR") }

    before { apply_tax(customer, fr_standard) }

    it "does not change the applied tax" do
      expect { perform_job }.not_to change { customer.reload.taxes.pluck(:code) }
    end
  end

  context "when billing entity has eu_tax_management disabled" do
    let(:billing_entity) { create(:billing_entity, organization:, country: "FR", eu_tax_management: false) }
    let(:customer) { create(:customer, organization:, billing_entity:, country: "DE") }

    before { apply_tax(customer, fr_standard) }

    it "does not process the customer" do
      expect { perform_job }.not_to change { customer.reload.taxes.pluck(:code) }
    end
  end

  context "when customer has no country" do
    let(:customer) { create(:customer, organization:, billing_entity:, country: nil) }

    before { apply_tax(customer, fr_standard) }

    it "does not process the customer" do
      expect { perform_job }.not_to change { customer.reload.taxes.pluck(:code) }
    end
  end

  context "when customer is on a reverse charge tax" do
    let!(:reverse_charge) { create(:tax, organization:, code: "lago_eu_reverse_charge") }
    let(:customer) { create(:customer, organization:, billing_entity:, country: "DE") }

    before { apply_tax(customer, reverse_charge) }

    it "does not process the customer" do
      expect { perform_job }.not_to change { customer.reload.taxes.pluck(:code) }
    end
  end

  context "when customer is on an exception tax code" do
    let!(:exception_tax) { create(:tax, organization:, code: "lago_eu_fr_exception_corsica") }
    let(:customer) { create(:customer, organization:, billing_entity:, country: "FR", zipcode: "20000") }

    before { apply_tax(customer, exception_tax) }

    it "does not process the customer" do
      expect { perform_job }.not_to change { customer.reload.taxes.pluck(:code) }
    end
  end

  context "when customer already has a pending VIES check" do
    let(:customer) do
      create(:customer, organization:, billing_entity:, country: "DE", tax_identification_number: "DE123456789")
    end

    before do
      apply_tax(customer, fr_standard)
      create(:pending_vies_check, customer:)
    end

    it "does not process the customer" do
      expect { perform_job }.not_to change { customer.reload.taxes.pluck(:code) }
    end
  end

  context "when customer has a tax identification number but no pending VIES check" do
    let(:customer) do
      create(:customer, organization:, billing_entity:, country: "DE", tax_identification_number: "DE123456789")
    end

    before { apply_tax(customer, fr_standard) }

    it "schedules an async VIES check and leaves the tax unchanged for now" do
      expect { perform_job }.to change(PendingViesCheck, :count).by(1)
      expect(customer.reload.taxes.pluck(:code)).to contain_exactly("lago_eu_fr_standard")
    end
  end

  context "when there is more work after the batch" do
    before do
      stub_const("#{described_class}::BATCH_SIZE", 1)

      2.times do
        customer = create(:customer, organization:, billing_entity:, country: "DE", tax_identification_number: nil)
        apply_tax(customer, fr_standard)
      end
    end

    it "enqueues the next batch" do
      expect { perform_job }.to have_enqueued_job(described_class).with(2)
    end
  end

  context "when there is no pending work" do
    it "does not enqueue another batch" do
      expect { perform_job }.not_to have_enqueued_job(described_class)
    end
  end

  context "when the affected customer belongs to another organization" do
    let(:other_organization) { create(:organization) }
    let(:other_billing_entity) do
      create(:billing_entity, organization: other_organization, country: "FR", eu_tax_management: true)
    end
    let(:other_customer) do
      create(:customer, organization: other_organization, billing_entity: other_billing_entity, country: "DE", tax_identification_number: nil)
    end
    let(:other_fr_standard) { create(:tax, organization: other_organization, code: "lago_eu_fr_standard") }

    before do
      create(:tax, organization: other_organization, code: "lago_eu_de_standard")
      apply_tax(other_customer, other_fr_standard)
    end

    it "does not process the customer" do
      expect { perform_job }.not_to change { other_customer.reload.taxes.pluck(:code) }
    end
  end
end
