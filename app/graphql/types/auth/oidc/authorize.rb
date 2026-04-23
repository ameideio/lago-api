# frozen_string_literal: true

module Types
  module Auth
    module Oidc
      class Authorize < Types::BaseObject
        graphql_name "OidcAuthorize"

        field :url, String, null: false
      end
    end
  end
end
