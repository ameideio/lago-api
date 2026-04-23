# frozen_string_literal: true

class AddOidcAuthenticationMethodToOrganizations < ActiveRecord::Migration[8.0]
  def up
    change_column_default :organizations, :authentication_methods, from: %w[email_password google_oauth], to: %w[email_password google_oauth oidc]

    safety_assured do
      execute <<~SQL
        UPDATE organizations
        SET authentication_methods = array_append(authentication_methods, 'oidc')
        WHERE NOT ('oidc' = ANY(authentication_methods))
      SQL
    end
  end

  def down
    change_column_default :organizations, :authentication_methods, from: %w[email_password google_oauth oidc], to: %w[email_password google_oauth]

    safety_assured do
      execute <<~SQL
        UPDATE organizations
        SET authentication_methods = array_remove(authentication_methods, 'oidc')
      SQL
    end
  end
end
