# frozen_string_literal: true

class ValidateAddQuotes < ActiveRecord::Migration[8.0]
  def change
    validate_foreign_key :quotes, :quote_versions
  end
end
