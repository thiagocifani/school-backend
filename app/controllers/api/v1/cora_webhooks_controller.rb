module Api
  module V1
    class CoraWebhooksController < BaseController
      skip_before_action :authenticate_user!, only: [:receive]
      skip_before_action :verify_authenticity_token, only: [:receive]
      
      # Endpoint to receive webhooks from Cora
      def receive
        # Validate webhook signature (implement based on Cora's documentation)
        unless valid_webhook_signature?
          return render json: { error: 'Invalid signature' }, status: :unauthorized
        end
        
        begin
          webhook_data = params.permit!.to_h
          
          # Log the incoming webhook for debugging
          Rails.logger.info "Received Cora webhook: #{webhook_data}"
          
          # Create webhook record
          webhook = CoraWebhook.create_from_payload(webhook_data)
          
          # Process the webhook asynchronously if needed
          # ProcessCoraWebhookJob.perform_later(webhook.id)
          
          render json: { status: 'received' }, status: :ok
        rescue => e
          Rails.logger.error "Webhook processing error: #{e.message}"
          render json: { error: 'Processing error' }, status: :internal_server_error
        end
      end
      
      # List webhooks for admin
      def index
        authorize_admin!
        
        @webhooks = CoraWebhook.includes(:cora_invoice)
                               .order(created_at: :desc)
                               .page(params[:page])
        
        render json: {
          webhooks: @webhooks.map { |webhook| webhook_json(webhook) },
          pagination: pagination_data(@webhooks)
        }
      end
      
      # Show specific webhook
      def show
        authorize_admin!
        
        @webhook = CoraWebhook.find(params[:id])
        render json: { webhook: webhook_json(@webhook) }
      end
      
      # Retry failed webhook
      def retry
        authorize_admin!
        
        @webhook = CoraWebhook.find(params[:id])
        
        unless @webhook.failed?
          return render json: { error: 'Webhook não está com falha' }, status: :unprocessable_entity
        end
        
        @webhook.retry_processing
        
        render json: { 
          success: true, 
          message: 'Webhook reenviado para processamento',
          webhook: webhook_json(@webhook)
        }
      end
      
      private
      
      def valid_webhook_signature?
        # Implement signature validation based on Cora's webhook documentation
        # This is a placeholder - you'll need to implement the actual validation
        # based on Cora's security requirements
        
        signature = request.headers['X-Cora-Signature']
        return true if Rails.env.development? # Skip validation in development
        
        # In production, validate the signature:
        # expected_signature = generate_signature(request.body.read)
        # signature == expected_signature
        true
      end
      
      def authorize_admin!
        unless current_user&.admin? || current_user&.financial?
          render json: { error: 'Unauthorized' }, status: :unauthorized
        end
      end
      
      def webhook_json(webhook)
        {
          id: webhook.id,
          webhook_id: webhook.webhook_id,
          event_type: webhook.event_type,
          status: webhook.status,
          invoice_id: webhook.invoice_id,
          processed_at: webhook.processed_at,
          payload: webhook.payload,
          cora_invoice: webhook.cora_invoice ? {
            id: webhook.cora_invoice.id,
            status: webhook.cora_invoice.status,
            customer_name: webhook.cora_invoice.customer_name,
            amount: webhook.cora_invoice.amount
          } : nil,
          created_at: webhook.created_at,
          updated_at: webhook.updated_at
        }
      end
      
      def pagination_data(collection)
        {
          current_page: collection.current_page,
          total_pages: collection.total_pages,
          total_count: collection.total_count,
          per_page: collection.limit_value
        }
      end
    end
  end
end