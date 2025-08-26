class WebhooksController < ApplicationController
    skip_before_action :authenticate_user!
    skip_before_action :verify_authenticity_token
  
    # POST /webhooks/stripe
    def stripe
      payload = request.body.read
      sig_header = request.env['HTTP_STRIPE_SIGNATURE']
      endpoint_secret = Rails.application.credentials.stripe[:webhook_secret]
  
      begin
        event = Stripe::Webhook.construct_event(
          payload, sig_header, endpoint_secret
        )
      rescue JSON::ParserError => e
        render json: { error: 'Invalid payload' }, status: 400
        return
      rescue Stripe::SignatureVerificationError => e
        render json: { error: 'Invalid signature' }, status: 400
        return
      end
  
      case event.type
      when 'payment_intent.succeeded'
        payment_intent = event.data.object
        handle_successful_payment(payment_intent)
      when 'payment_intent.payment_failed'
        payment_intent = event.data.object
        handle_failed_payment(payment_intent)
      else
        render json: { message: 'Unhandled event type' }, status: 200
      end
  
      render json: { message: 'Webhook processed' }, status: 200
    end
  
    private
  
    def handle_successful_payment(payment_intent)
      # Find user or order by metadata
      user = User.find_by(stripe_customer_id: payment_intent.customer)
      # Update subscription, unlock features, etc.
    end
  
    def handle_failed_payment(payment_intent)
      # Notify user, log error
    end
  end