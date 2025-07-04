require "spec_helper"

shared_examples "Checkout Session API" do
  it "creates PaymentIntent with payment mode" do
    line_items = [{
                    name: "T-shirt",
                    quantity: 2,
                    amount: 500,
                    currency: "usd",
                  }]
    session = Stripe::Checkout::Session.create(
      payment_method_types: ["card"],
      line_items: line_items,
      success_url: "https://example.com/success"
    )

    expect(session.payment_intent).to_not be_empty
    payment_intent = Stripe::PaymentIntent.retrieve(session.payment_intent)
    expect(payment_intent.amount).to eq(1000)
    expect(payment_intent.currency).to eq("usd")
    expect(payment_intent.customer).to eq(session.customer)
  end

  context "when creating a payment" do
    it "requires line_items" do
      expect do
        session = Stripe::Checkout::Session.create(
          customer: "customer_id",
          success_url: "localhost/nada",
          payment_method_types: ["card"],
        )
      end.to raise_error(Stripe::InvalidRequestError, /line_items/i)

    end
  end

  it "creates SetupIntent with setup mode" do
    session = Stripe::Checkout::Session.create(
      mode: "setup",
      payment_method_types: ["card"],
      success_url: "https://example.com/success"
    )

    expect(session.setup_intent).to_not be_empty
    setup_intent = Stripe::SetupIntent.retrieve(session.setup_intent)
    expect(setup_intent.payment_method_types).to eq(["card"])
  end

  context "when creating a subscription" do
    it "requires line_items" do
      expect do
        session = Stripe::Checkout::Session.create(
          customer: "customer_id",
          success_url: "localhost/nada",
          payment_method_types: ["card"],
          mode: "subscription",
        )
      end.to raise_error(Stripe::InvalidRequestError, /line_items/i)

    end
  end

  context "retrieve a checkout session" do
    let(:checkout_session1) { stripe_helper.create_checkout_session }
    let(:test_helper) { StripeMock.create_test_helper }

    it "can be retrieved by id" do
      checkout_session1

      checkout_session = Stripe::Checkout::Session.retrieve(checkout_session1.id)

      expect(checkout_session.id).to eq(checkout_session1.id)
    end

    it "cannot retrieve a checkout session that doesn't exist" do
      expect { Stripe::Checkout::Session.retrieve("nope") }.to raise_error { |e|
        expect(e).to be_a Stripe::InvalidRequestError
        expect(e.param).to eq("checkout_session")
        expect(e.http_status).to eq(404)
      }
    end

    it "can expand setup_intent" do
      initial_session = Stripe::Checkout::Session.create(
        mode: "setup",
        success_url: "https://example.com",
        payment_method_types: ["card"]
      )

      checkout_session = Stripe::Checkout::Session.retrieve(id: initial_session.id, expand: ["setup_intent"])

      expect(checkout_session.setup_intent).to be_a_kind_of(Stripe::SetupIntent)
    end

    it "can expand subscription" do
      initial_session = test_helper.create_checkout_session(
        mode: "subscription",
        customer_email: "jonny@appleseed.com",
        customer_source: stripe_helper.generate_card_token,
        plan: stripe_helper.create_plan(product: stripe_helper.create_product.id).id,
      )
      payment_method = Stripe::PaymentMethod.create(type: "card")
      initial_subscription = test_helper.complete_checkout_session(initial_session, payment_method)

      checkout_session = Stripe::Checkout::Session.retrieve(id: initial_session.id, expand: ["subscription"])

      expect(checkout_session.subscription).to be_a_kind_of(Stripe::Subscription)
      subscription = checkout_session.subscription
      expect(subscription.id).to eq(initial_subscription)
      expect(subscription.customer).to eq(initial_session.customer)
    end
  end
end
