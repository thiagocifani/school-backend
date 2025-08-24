module Api
  module V1
    class CoraInvoicesController < BaseController
      before_action :set_cora_invoice, only: [:show, :generate_pix_voucher, :generate_boleto, :cancel]
      
      def index
        @invoices = CoraInvoice.includes(:reference)
        @invoices = apply_filters(@invoices)
        @invoices = @invoices.page(params[:page]).per(params[:per_page] || 25)
        
        render json: {
          invoices: @invoices.map { |invoice| cora_invoice_json(invoice) },
          pagination: pagination_data(@invoices)
        }
      end
      
      def show
        render json: { invoice: cora_invoice_json(@cora_invoice) }
      end
      
      # Generate PIX voucher for salary payments
      def generate_pix_voucher
        unless @cora_invoice.salary_payment?
          return render json: { error: 'PIX vouchers are only available for salary payments' }, 
                        status: :unprocessable_entity
        end
        
        begin
          # Generate PIX through Cora API
          cora_service = CoraApiService.new
          response = cora_service.generate_pix_voucher(@cora_invoice)
          
          # Update invoice with PIX data
          @cora_invoice.update!(
            pix_qr_code: response[:pix_qr_code],
            pix_qr_code_url: response[:pix_qr_code_url],
            status: 'open'
          )
          
          render json: {
            success: true,
            message: 'Comprovante PIX gerado com sucesso',
            invoice: cora_invoice_json(@cora_invoice.reload),
            pix_data: {
              qr_code: @cora_invoice.pix_qr_code,
              qr_code_url: @cora_invoice.pix_qr_code_url,
              amount: @cora_invoice.formatted_amount,
              recipient: @cora_invoice.customer_name
            }
          }
        rescue => e
          Rails.logger.error "Failed to generate PIX voucher: #{e.message}"
          render json: { error: 'Erro ao gerar comprovante PIX' }, status: :unprocessable_entity
        end
      end
      
      # Generate boleto for tuition payments
      def generate_boleto
        unless @cora_invoice.tuition?
          return render json: { error: 'Boletos are only available for tuition payments' }, 
                        status: :unprocessable_entity
        end
        
        begin
          # Generate boleto through Cora API
          cora_service = CoraApiService.new
          response = cora_service.generate_boleto(@cora_invoice)
          
          # Update invoice with boleto data
          @cora_invoice.update!(
            boleto_url: response[:boleto_url],
            status: 'open'
          )
          
          render json: {
            success: true,
            message: 'Boleto gerado com sucesso',
            invoice: cora_invoice_json(@cora_invoice.reload),
            boleto_data: {
              url: @cora_invoice.boleto_url,
              amount: @cora_invoice.formatted_amount,
              due_date: @cora_invoice.due_date,
              student_name: @cora_invoice.student_name
            }
          }
        rescue => e
          Rails.logger.error "Failed to generate boleto: #{e.message}"
          render json: { error: 'Erro ao gerar boleto' }, status: :unprocessable_entity
        end
      end
      
      # Cancel Cora invoice
      def cancel
        unless @cora_invoice.can_be_cancelled?
          return render json: { error: 'Esta fatura não pode ser cancelada' }, 
                        status: :unprocessable_entity
        end
        
        begin
          # Cancel through Cora API
          cora_service = CoraApiService.new
          cora_service.cancel_invoice(@cora_invoice)
          
          # Update local status
          @cora_invoice.update!(status: 'cancelled')
          
          render json: {
            success: true,
            message: 'Fatura cancelada com sucesso',
            invoice: cora_invoice_json(@cora_invoice.reload)
          }
        rescue => e
          Rails.logger.error "Failed to cancel invoice: #{e.message}"
          render json: { error: 'Erro ao cancelar fatura' }, status: :unprocessable_entity
        end
      end
      
      # Get invoice by financial transaction
      def by_transaction
        transaction = FinancialTransaction.find(params[:transaction_id])
        cora_invoice = transaction.cora_invoice
        
        if cora_invoice
          render json: { invoice: cora_invoice_json(cora_invoice) }
        else
          render json: { error: 'Fatura não encontrada para esta transação' }, 
                 status: :not_found
        end
      end
      
      private
      
      def set_cora_invoice
        @cora_invoice = CoraInvoice.find(params[:id])
      end
      
      def apply_filters(scope)
        scope = scope.where(invoice_type: params[:type]) if params[:type].present?
        scope = scope.where(status: params[:status]) if params[:status].present?
        
        if params[:start_date].present? && params[:end_date].present?
          start_date = Date.parse(params[:start_date]) rescue nil
          end_date = Date.parse(params[:end_date]) rescue nil
          scope = scope.where(due_date: start_date..end_date) if start_date && end_date
        end
        
        scope
      end
      
      def cora_invoice_json(invoice)
        {
          id: invoice.id,
          invoice_id: invoice.invoice_id,
          status: invoice.status,
          amount: invoice.amount,
          formatted_amount: invoice.formatted_amount,
          due_date: invoice.due_date,
          customer_name: invoice.customer_name,
          customer_email: invoice.customer_email,
          customer_document: invoice.customer_document,
          invoice_type: invoice.invoice_type,
          # Payment options
          boleto_url: invoice.boleto_url,
          pix_qr_code: invoice.pix_qr_code,
          pix_qr_code_url: invoice.pix_qr_code_url,
          # Status info
          can_be_cancelled: invoice.can_be_cancelled?,
          overdue: invoice.overdue?,
          days_overdue: invoice.days_overdue,
          paid_at: invoice.paid_at,
          # Reference info
          reference: build_reference_info(invoice),
          # Timestamps
          created_at: invoice.created_at,
          updated_at: invoice.updated_at
        }
      end
      
      def build_reference_info(invoice)
        return nil unless invoice.reference
        
        case invoice.reference.class.name
        when 'FinancialTransaction'
          transaction = invoice.reference
          {
            type: 'FinancialTransaction',
            id: transaction.id,
            description: transaction.description,
            transaction_type: transaction.transaction_type,
            reference: transaction.reference ? {
              type: transaction.reference.class.name,
              name: case transaction.reference.class.name
                    when 'Student'
                      transaction.reference.name
                    when 'Teacher'
                      transaction.reference.user.name
                    else
                      transaction.reference.try(:name) || "#{transaction.reference.class.name} ##{transaction.reference.id}"
                    end
            } : nil
          }
        else
          {
            type: invoice.reference.class.name,
            id: invoice.reference.id,
            name: invoice.reference.try(:name) || "#{invoice.reference.class.name} ##{invoice.reference.id}"
          }
        end
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