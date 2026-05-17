# frozen_string_literal: true

module Ameide
  # Isolated, Ameide-namespaced helper that idempotently seeds the Stripe
  # payment provider for a single-tenant on-prem/SaaS Lago deployment.
  #
  # This file is ADDITIVE and never touches upstream code, so `git merge
  # upstream/main` stays conflict-free. It mirrors the idiom of upstream's
  # `signup:seed_organization` rake task (ENV-driven, idempotent) but delegates
  # the actual write to the first-class upstream service
  # `PaymentProviders::StripeService#create_or_update`, which is itself
  # idempotent (FindService by org+code; secret_key only set on create).
  module StripeProviderSeeder
    GATE_ENV = "AMEIDE_STRIPE_SEED"
    SECRET_ENV = "STRIPE_SECRET_KEY"
    DEFAULT_CODE = "stripe"

    module_function

    # @return [Symbol] :disabled, :missing_secret, :no_organization, :seeded
    def call(logger: default_logger)
      unless ENV[GATE_ENV] == "true"
        logger.call("[ameide:seed_stripe_provider] #{GATE_ENV} != 'true' — skipping (no-op).")
        return :disabled
      end

      secret_key = ENV[SECRET_ENV].to_s
      if secret_key.strip.empty?
        logger.call("[ameide:seed_stripe_provider] #{SECRET_ENV} is blank/unset — skipping (no-op).")
        return :missing_secret
      end

      organization = resolve_organization
      unless organization
        logger.call(
          "[ameide:seed_stripe_provider] Could not resolve a target organization " \
          "(set LAGO_ORG_NAME or ensure exactly one Organization exists) — skipping (no-op)."
        )
        return :no_organization
      end

      code = ENV.fetch("AMEIDE_STRIPE_PROVIDER_CODE", DEFAULT_CODE)

      # BaseService#initialize ignores its argument (only reads CurrentContext),
      # so a nil/system actor is safe outside the GraphQL layer.
      result = PaymentProviders::StripeService.new.create_or_update(
        organization_id: organization.id,
        code:,
        name: "Stripe",
        secret_key:,
        success_redirect_url: ENV["AMEIDE_STRIPE_SUCCESS_URL"]
      )

      unless result.success?
        # Never log the secret; only the failure code/messages.
        raise "[ameide:seed_stripe_provider] StripeService failed: #{result.error}"
      end

      logger.call(
        "[ameide:seed_stripe_provider] Stripe provider ensured for organization " \
        "##{organization.id} (code=#{code})."
      )
      :seeded
    end

    # Resolve THE organization the same way signup:seed_organization keys off:
    # by LAGO_ORG_NAME. For single-tenant deployments where the org already
    # exists (the common case for an additive seed), fall back to the sole
    # Organization. We only ever `find` — never create.
    def resolve_organization
      org_name = ENV["LAGO_ORG_NAME"].to_s
      return Organization.find_by(name: org_name) unless org_name.strip.empty?

      Organization.first if Organization.count == 1
    end

    def default_logger
      ->(message) { Rails.logger.info(message) }
    end
  end
end
