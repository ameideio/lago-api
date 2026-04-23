# frozen_string_literal: true

module Mutations
  module Auth
    module Oidc
      class Authorize < BaseMutation
        graphql_name "OidcAuthorize"

        argument :invite_token, String, required: false

        type Types::Auth::Oidc::Authorize

        def resolve(invite_token: nil)
          result = ::Auth::Oidc::AuthorizeService.call(invite_token:)

          result.success? ? result : result_error(result)
        end
      end
    end
  end
end
