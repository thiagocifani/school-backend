class CoraWebhook < ApplicationRecord
  # Associations
  belongs_to :cora_invoice, foreign_key: 'invoice_id', primary_key: 'invoice_id', optional: true
  
  # Enums
  enum status: {
    pending: 'pending',
    processed: 'processed',
    failed: 'failed',
    ignored: 'ignored'
  }
  
  # Validations
  validates :webhook_id, presence: true, uniqueness: true
  validates :event_type, presence: true
  validates :payload, presence: true
  validates :status, presence: true
  
  # Scopes
  scope :unprocessed, -> { where(status: 'pending') }
  scope :for_event, ->(event) { where(event_type: event) }
  scope :recent, -> { order(created_at: :desc) }
  
  # Callbacks
  before_validation :set_defaults, on: :create
  after_create :process_webhook, unless: :processed?
  
  # Class methods
  def self.create_from_payload(webhook_data)
    create!(
      webhook_id: webhook_data['id'] || SecureRandom.uuid,
      event_type: webhook_data['event_type'] || webhook_data['type'],
      invoice_id: extract_invoice_id(webhook_data),
      payload: webhook_data
    )
  end
  
  def self.extract_invoice_id(payload)
    payload.dig('data', 'invoice', 'id') || 
    payload.dig('invoice', 'id') ||
    payload['invoice_id']
  end
  
  # Instance methods
  def process_webhook
    return if processed?
    
    begin
      case event_type
      when 'invoice.paid', 'payment.confirmed'
        handle_payment_confirmation
      when 'invoice.late'
        handle_late_invoice
      when 'invoice.cancelled'
        handle_cancelled_invoice
      else
        update!(status: 'ignored')
        return
      end
      
      update!(
        status: 'processed',
        processed_at: Time.current
      )
    rescue => e
      Rails.logger.error "Webhook processing failed: #{e.message}"
      update!(status: 'failed')
    end
  end
  
  def retry_processing
    return unless failed?
    
    update!(status: 'pending')
    process_webhook
  end
  
  def invoice_data
    payload.dig('data', 'invoice') || payload['invoice'] || {}
  end
  
  private
  
  def set_defaults
    self.status ||= 'pending'
    self.webhook_id ||= SecureRandom.uuid
  end
  
  def handle_payment_confirmation
    return unless cora_invoice
    
    cora_invoice.mark_as_paid!
    Rails.logger.info "Invoice #{invoice_id} marked as paid via webhook"
  end
  
  def handle_late_invoice
    return unless cora_invoice
    
    cora_invoice.update!(status: 'LATE')
    Rails.logger.info "Invoice #{invoice_id} marked as late via webhook"
  end
  
  def handle_cancelled_invoice
    return unless cora_invoice
    
    cora_invoice.update!(status: 'CANCELLED')
    Rails.logger.info "Invoice #{invoice_id} marked as cancelled via webhook"
  end
end
