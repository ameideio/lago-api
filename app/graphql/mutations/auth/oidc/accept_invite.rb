# frozen_string_literal: true

module Mutations
  module Auth
    module Oidc
      class AcceptInvite < BaseMutation
        graphql_name "OidcAcceptInvite"
        description "Accepts a membership invite with OIDC"

        input_object_class Types::Auth::Oidc::AcceptInviteInput

        type Types::Payloads::LoginUserType

        def resolve(code:, invite_token:, state:)
          result = ::Auth::Oidc::AcceptInviteService.call(code:, invite_token:, state:)

          result.success? ? result : result_error(result)
        end
      end
    end
  end
end
