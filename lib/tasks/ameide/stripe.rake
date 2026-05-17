# frozen_string_literal: true

require_relative "../../ameide/stripe_provider_seeder"

namespace :ameide do
  desc "Idempotently seed the Stripe payment provider (gated by AMEIDE_STRIPE_SEED=true)"
  task seed_stripe_provider: :environment do
    Ameide::StripeProviderSeeder.call(logger: ->(message) { pp message })
  end
end
