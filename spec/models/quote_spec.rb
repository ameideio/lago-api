# frozen_string_literal: true

require "rails_helper"

RSpec.describe Quote do
  subject(:quote) { create(:quote) }

  describe "enums" do
    it "defines enums" do
      expect(subject).to define_enum_for(:order_type)
        .backed_by_column_of_type(:enum)
        .with_values(
          {
            subscription_creation: "subscription_creation",
            subscription_amendment: "subscription_amendment",
            one_off: "one_off"
          }
        )
        .without_instance_methods
        .validating(allowing_nil: false)
    end
  end

  describe "associations" do
    it "has the expected associations" do
      expect(subject).to belong_to(:organization)
      expect(subject).to belong_to(:customer)
      expect(subject).to belong_to(:subscription).optional

      # TODO: Uncomment when the order form and order associations are implemented
      # expect(subject).to have_one(:order_form).inverse_of(:quote)
      # expect(subject).to have_one(:order).through(:order_form)

      expect(subject).to have_many(:quote_owners).dependent(:destroy)
      expect(subject).to have_many(:owners).through(:quote_owners)
    end
  end

  describe "validations" do
    it "requires subscription_id when order_type is subscription_amendment" do
      subscription = create(:subscription)
      quote = build(:quote, order_type: :subscription_amendment, subscription: nil, organization: subscription.organization, customer: create(:customer, organization: subscription.organization))
      expect(quote).not_to be_valid
      quote.subscription = subscription
      expect(quote).to be_valid
    end
  end

  describe "callbacks" do
    describe "ensure_number" do
      it "assigns a formatted number when sequential_id and created_at are present" do
        quote = build(:quote, sequential_id: 123, number: nil, created_at: Time.zone.local(2020, 1, 2))
        quote.save!
        expect(quote.number).to eq("QT-2020-0123")
      end
    end
  end
end
