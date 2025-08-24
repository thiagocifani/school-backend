module Api
  module V1
    class PaymentsController < BaseController
      before_action :set_invoice, only: [:show, :destroy]
      
      def index
        @invoices = CoraInvoice.includes(:reference)
        
        # Filter by type if provided
        @invoices = @invoices.where(invoice_type: params[:type]) if params[:type].present?
        
        # Filter by status if provided
        @invoices = @invoices.where(status: params[:status]) if params[:status].present?
        
        # Filter by reference type if provided
        @invoices = @invoices.where(reference_type: params[:reference_type]) if params[:reference_type].present?
        
        @invoices = @invoices.order(created_at: :desc).page(params[:page])
        
        render json: {
          invoices: @invoices.map { |invoice| invoice_json(invoice) },
          pagination: pagination_data(@invoices)
        }
      end
      
      def show
        render json: { invoice: invoice_json(@invoice) }
      end
      
      # Create boleto for tuition
      def create_tuition_boleto
        tuition = Tuition.find(params[:tuition_id])
        authorize tuition, :show? # Ensure user can access this tuition
        
        # Check if invoice already exists
        existing_invoice = CoraInvoice.find_by(reference: tuition)
        if existing_invoice
          return render json: { invoice: invoice_json(existing_invoice) }
        end
        
        begin
          invoice = CoraInvoice.create_for_tuition(tuition)
          cora_service = CoraApiService.new
          cora_response = cora_service.create_invoice(invoice)
          
          render json: { 
            invoice: invoice_json(invoice),
            boleto_url: invoice.boleto_url,
            pix_qr_code: invoice.pix_qr_code
          }
        rescue => e
          Rails.logger.error "Failed to create tuition boleto: #{e.message}"
          render json: { error: 'Erro ao gerar boleto' }, status: :unprocessable_entity
        end
      end
      
      # Create PIX payment for salary
      def create_salary_pix
        salary = Salary.find(params[:salary_id])
        authorize salary, :show? # Ensure user can access this salary
        
        begin
          invoice = CoraInvoice.create_for_salary(salary)
          cora_service = CoraApiService.new
          
          # Create PIX payment directly
          pix_response = cora_service.create_pix_payment(salary, salary.teacher)
          
          if pix_response
            invoice.update!(
              status: 'PAID',
              paid_at: Time.current,
              pix_qr_code: pix_response['qr_code']
            )
            
            render json: { 
              success: true,
              message: 'Pagamento PIX realizado com sucesso',
              invoice: invoice_json(invoice)
            }
          else
            render json: { error: 'Erro ao processar pagamento PIX' }, status: :unprocessable_entity
          end
        rescue => e
          Rails.logger.error "Failed to create salary PIX: #{e.message}"
          render json: { error: 'Erro ao processar pagamento PIX' }, status: :unprocessable_entity
        end
      end
      
      # Create payment for general expense
      def create_expense_payment
        financial_account = FinancialAccount.find(params[:financial_account_id])
        authorize financial_account, :show?
        
        begin
          invoice = CoraInvoice.create_for_expense(financial_account)
          cora_service = CoraApiService.new
          cora_response = cora_service.create_invoice(invoice)
          
          render json: { 
            invoice: invoice_json(invoice),
            boleto_url: invoice.boleto_url,
            pix_qr_code: invoice.pix_qr_code
          }
        rescue => e
          Rails.logger.error "Failed to create expense payment: #{e.message}"
          render json: { error: 'Erro ao gerar pagamento' }, status: :unprocessable_entity
        end
      end
      
      # Cancel invoice
      def cancel
        invoice = CoraInvoice.find(params[:id])
        authorize invoice, :update?
        
        unless invoice.can_be_cancelled?
          return render json: { error: 'Esta fatura não pode ser cancelada' }, status: :unprocessable_entity
        end
        
        begin
          cora_service = CoraApiService.new
          if cora_service.cancel_invoice(invoice.invoice_id)
            invoice.update!(status: 'CANCELLED')
            render json: { success: true, message: 'Fatura cancelada com sucesso' }
          else
            render json: { error: 'Erro ao cancelar fatura' }, status: :unprocessable_entity
          end
        rescue => e
          Rails.logger.error "Failed to cancel invoice: #{e.message}"
          render json: { error: 'Erro ao cancelar fatura' }, status: :unprocessable_entity
        end
      end
      
      # Get payment stats for dashboard
      def stats
        current_month = Date.current.beginning_of_month..Date.current.end_of_month
        
        stats = {
          total_invoices: CoraInvoice.count,
          pending_amount: CoraInvoice.pending.sum(:amount),
          paid_amount: CoraInvoice.paid.where(paid_at: current_month).sum(:amount),
          overdue_count: CoraInvoice.overdue.count,
          by_type: {
            tuitions: CoraInvoice.for_tuitions.count,
            salaries: CoraInvoice.for_salaries.count,
            expenses: CoraInvoice.for_expenses.count
          },
          recent_payments: CoraInvoice.paid
                                     .order(paid_at: :desc)
                                     .limit(5)
                                     .map { |invoice| invoice_json(invoice) }
        }
        
        render json: { stats: stats }
      end
      
      private
      
      def set_invoice
        @invoice = CoraInvoice.find(params[:id])
        authorize @invoice, :show?
      end
      
      def invoice_json(invoice)
        {
          id: invoice.id,
          invoice_id: invoice.invoice_id,
          amount: invoice.amount,
          formatted_amount: invoice.formatted_amount,
          status: invoice.status,
          invoice_type: invoice.invoice_type,
          due_date: invoice.due_date,
          paid_at: invoice.paid_at,
          customer_name: invoice.customer_name,
          customer_email: invoice.customer_email,
          boleto_url: invoice.boleto_url,
          pix_qr_code: invoice.pix_qr_code,
          pix_qr_code_url: invoice.pix_qr_code_url,
          overdue: invoice.overdue?,
          days_overdue: invoice.days_overdue,
          reference: reference_json(invoice.reference),
          created_at: invoice.created_at,
          updated_at: invoice.updated_at
        }
      end
      
      def reference_json(reference)
        return nil unless reference
        
        case reference.class.name
        when 'Tuition'
          {
            type: 'Tuition',
            id: reference.id,
            student_name: reference.student.name,
            due_date: reference.due_date,
            month: reference.due_date.strftime('%m/%Y')
          }
        when 'Salary'
          {
            type: 'Salary',
            id: reference.id,
            teacher_name: reference.teacher.user.name,
            month: reference.month,
            year: reference.year
          }
        when 'FinancialAccount'
          {
            type: 'FinancialAccount',
            id: reference.id,
            description: reference.description,
            category: reference.category
          }
        else
          { type: reference.class.name, id: reference.id }
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