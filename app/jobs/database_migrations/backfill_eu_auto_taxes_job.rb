# frozen_string_literal: true

module DatabaseMigrations
  class BackfillEuAutoTaxesJob < ApplicationJob
    queue_as :low_priority
    unique :until_executed

    BATCH_SIZE = 500
    ORGANIZATION_ID = "5e6eb312-1e25-40d7-83b8-4ee117b74255"

    def perform(batch_number = 1)
      customer_ids = customers_to_fix.limit(BATCH_SIZE).pluck(:id)

      if customer_ids.empty?
        Rails.logger.info("Finished backfilling EU auto taxes")
        return
      end

      Customer.where(id: customer_ids).find_each { |customer| process_customer(customer) }

      self.class.perform_later(batch_number + 1)
    end

    def lock_key_arguments
      [arguments]
    end

    private

    def customers_to_fix
      Customer
        .joins(applied_taxes: :tax)
        .joins(:billing_entity)
        .where(customers: {organization_id: ORGANIZATION_ID})
        .where(billing_entities: {eu_tax_management: true})
        .where.not(customers: {country: nil})
        .where("taxes.code ~ '^lago_eu_[a-z]{2}_standard$'")
        .where("taxes.code <> CONCAT('lago_eu_', LOWER(customers.country), '_standard')")
        .where("NOT EXISTS (SELECT 1 FROM pending_vies_checks pvc WHERE pvc.customer_id = customers.id)")
        .distinct
    end

    def process_customer(customer)
      result = Customers::EuAutoTaxesService.call(
        customer:,
        new_record: false,
        tax_attributes_changed: true
      )
      return unless result.success?

      preserved_codes = customer.taxes.where.not("code ILIKE 'lago_eu%'").pluck(:code)
      tax_codes = (preserved_codes + [result.tax_code]).uniq

      Customers::ApplyTaxesService.call(customer:, tax_codes:).raise_if_error!
    end
  end
end
