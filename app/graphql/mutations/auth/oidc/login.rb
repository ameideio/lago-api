# frozen_string_literal: true

module Mutations
  module Auth
    module Oidc
      class Login < BaseMutation
        graphql_name "OidcLogin"

        argument :code, String, required: true
        argument :state, String, required: true

        type Types::Payloads::LoginUserType

        def resolve(code:, state:)
          result = ::Auth::Oidc::LoginService.call(code:, state:)

          result.success? ? result : result_error(result)
        end
      end
    end
  end
end
