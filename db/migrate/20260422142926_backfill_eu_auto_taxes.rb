# frozen_string_literal: true

class BackfillEuAutoTaxes < ActiveRecord::Migration[8.0]
  def change
    DatabaseMigrations::BackfillEuAutoTaxesJob.perform_later
  end
end
