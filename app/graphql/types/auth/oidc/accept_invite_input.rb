# frozen_string_literal: true

module Types
  module Auth
    module Oidc
      class AcceptInviteInput < BaseInputObject
        graphql_name "OidcAcceptInviteInput"

        description "Accept Invite with OIDC input arguments"

        argument :code, String, required: true
        argument :invite_token, String, required: true
        argument :state, String, required: true
      end
    end
  end
end
