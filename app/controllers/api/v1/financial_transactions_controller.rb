module Api
  module V1
    class FinancialTransactionsController < BaseController
      skip_before_action :authenticate_user!, only: [:cash_flow] # Temporary for testing
      before_action :set_transaction, only: [:show, :update, :destroy, :pay, :generate_cora_invoice]
      
      def index
        @transactions = FinancialTransaction.includes(:cora_invoice)
        
        # Apply filters
        @transactions = apply_filters(@transactions)
        
        # Pagination
        @transactions = @transactions.page(params[:page]).per(params[:per_page] || 25)
        
        render json: {
          transactions: @transactions.map { |transaction| transaction_json(transaction) },
          pagination: pagination_data(@transactions),
          summary: build_summary(@transactions)
        }
      end
      
      def show
        render json: { transaction: transaction_json(@transaction) }
      end
      
      def create
        @transaction = FinancialTransaction.new(transaction_params)
        
        if @transaction.save
          render json: { transaction: transaction_json(@transaction) }, status: :created
        else
          render json: { errors: @transaction.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      def update
        if @transaction.update(transaction_params)
          render json: { transaction: transaction_json(@transaction) }
        else
          render json: { errors: @transaction.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      def destroy
        if @transaction.can_be_cancelled?
          @transaction.update!(status: :cancelled)
          head :no_content
        else
          render json: { error: 'Esta transação não pode ser cancelada' }, status: :unprocessable_entity
        end
      end
      
      # Pay a transaction
      def pay
        unless @transaction.can_be_paid?
          return render json: { error: 'Esta transação não pode ser paga' }, status: :unprocessable_entity
        end
        
        payment_method = params[:payment_method]&.to_sym || :pix
        paid_date = params[:paid_date]&.to_date || Date.current
        
        begin
          @transaction.mark_as_paid!(payment_method: payment_method, paid_date: paid_date)
          render json: { 
            transaction: transaction_json(@transaction),
            message: 'Pagamento realizado com sucesso'
          }
        rescue => e
          render json: { error: "Erro ao processar pagamento: #{e.message}" }, status: :unprocessable_entity
        end
      end
      
      # Generate Cora invoice for transaction
      def generate_cora_invoice
        begin
          # Create Cora invoice based on transaction type
          cora_invoice = create_cora_invoice_for_transaction(@transaction)
          
          # Generate invoice via Cora API
          cora_service = CoraApiService.new
          cora_response = cora_service.create_invoice(cora_invoice)
          
          # Update transaction with external ID
          @transaction.update!(external_id: cora_invoice.invoice_id)
          
          render json: {
            success: true,
            transaction: transaction_json(@transaction.reload),
            cora_invoice: {
              invoice_id: cora_invoice.invoice_id,
              boleto_url: cora_invoice.boleto_url,
              pix_qr_code: cora_invoice.pix_qr_code,
              pix_qr_code_url: cora_invoice.pix_qr_code_url
            }
          }
        rescue => e
          Rails.logger.error "Failed to generate Cora invoice: #{e.message}"
          render json: { error: 'Erro ao gerar fatura no Cora' }, status: :unprocessable_entity
        end
      end
      
      # Bulk create tuitions for all students
      def bulk_create_tuitions
        month = params[:month]&.to_i || Date.current.month
        year = params[:year]&.to_i || Date.current.year
        amount = params[:amount]&.to_f
        
        unless amount&.positive?
          return render json: { error: 'Valor deve ser maior que zero' }, status: :unprocessable_entity
        end
        
        due_date = Date.new(year, month, 10) # Due on 10th of each month
        
        # Check if tuitions for this month already exist
        existing_count = FinancialTransaction.tuition
                                           .where(due_date: due_date.beginning_of_month..due_date.end_of_month)
                                           .count
        
        if existing_count > 0
          return render json: { 
            error: "Mensalidades para #{month}/#{year} já foram criadas (#{existing_count} encontradas)" 
          }, status: :unprocessable_entity
        end
        
        created_transactions = []
        
        Student.active.includes(:guardians).each do |student|
          next unless student.guardians.any?
          
          transaction = FinancialTransaction.create_tuition(
            student: student,
            amount: amount,
            due_date: due_date
          )
          
          created_transactions << transaction
        end
        
        render json: {
          success: true,
          message: "#{created_transactions.size} mensalidades criadas para #{month}/#{year}",
          created_count: created_transactions.size,
          transactions: created_transactions.map { |t| transaction_json(t) }
        }
      end
      
      # Bulk create salaries for all teachers
      def bulk_create_salaries
        month = params[:month]&.to_i || Date.current.month
        year = params[:year]&.to_i || Date.current.year
        
        due_date = Date.new(year, month, 5) # Pay on 5th of each month
        
        # Check if salaries for this month already exist
        existing_count = FinancialTransaction.salary
                                           .where(due_date: due_date.beginning_of_month..due_date.end_of_month)
                                           .count
        
        if existing_count > 0
          return render json: { 
            error: "Salários para #{month}/#{year} já foram criados (#{existing_count} encontrados)" 
          }, status: :unprocessable_entity
        end
        
        created_transactions = []
        
        Teacher.includes(:user).each do |teacher|
          transaction = FinancialTransaction.create_salary(
            teacher: teacher,
            amount: teacher.salary || 3000.00, # Default salary if not set
            due_date: due_date
          )
          
          created_transactions << transaction
        end
        
        render json: {
          success: true,
          message: "#{created_transactions.size} salários criados para #{month}/#{year}",
          created_count: created_transactions.size,
          transactions: created_transactions.map { |t| transaction_json(t) }
        }
      end
      
      # Cash flow dashboard data
      def cash_flow
        start_date = parse_date(params[:start_date]) || Date.current.beginning_of_month
        end_date = parse_date(params[:end_date]) || Date.current.end_of_month
        
        # Summary for the period
        summary = FinancialTransaction.cash_flow_summary(start_date, end_date)
        
        # Daily breakdown
        daily_breakdown = build_daily_breakdown(start_date, end_date)
        
        # Monthly breakdown for the year
        monthly_breakdown = FinancialTransaction.monthly_breakdown(start_date.year)
        
        # Recent transactions
        recent_transactions = FinancialTransaction.recent
                                                .limit(10)
                                                .map { |t| transaction_json(t) }
        
        # Overdue transactions
        overdue_transactions = FinancialTransaction.overdue
                                                 .limit(5)
                                                 .map { |t| transaction_json(t) }
        
        render json: {
          summary: summary,
          daily_breakdown: daily_breakdown,
          monthly_breakdown: monthly_breakdown,
          recent_transactions: recent_transactions,
          overdue_transactions: overdue_transactions
        }
      end
      
      # Statistics endpoint
      def statistics
        year = params[:year]&.to_i || Date.current.year
        month = params[:month]&.to_i
        
        scope = FinancialTransaction.all
        scope = scope.by_month(year, month) if month
        scope = scope.where('EXTRACT(year FROM due_date) = ?', year) unless month
        
        stats = {
          total_transactions: scope.count,
          total_amount: scope.sum(:amount),
          by_type: {
            tuitions: {
              count: scope.tuition.count,
              amount: scope.tuition.sum(:amount),
              paid: scope.tuition.paid.sum(&:final_amount),
              pending: scope.tuition.pending.sum(:amount)
            },
            salaries: {
              count: scope.salary.count,
              amount: scope.salary.sum(:amount),
              paid: scope.salary.paid.sum(&:final_amount),
              pending: scope.salary.pending.sum(:amount)
            },
            expenses: {
              count: scope.expense.count,
              amount: scope.expense.sum(:amount),
              paid: scope.expense.paid.sum(&:final_amount),
              pending: scope.expense.pending.sum(:amount)
            }
          },
          by_status: {
            pending: scope.pending.count,
            paid: scope.paid.count,
            overdue: scope.overdue.count,
            cancelled: scope.cancelled.count
          }
        }
        
        render json: { stats: stats }
      end
      
      private
      
      def set_transaction
        @transaction = FinancialTransaction.find(params[:id])
        authorize @transaction, :show?
      end
      
      def transaction_params
        params.require(:financial_transaction).permit(
          :transaction_type, :amount, :due_date, :description, :observation,
          :discount, :late_fee, :reference_type, :reference_id
        )
      end
      
      def apply_filters(scope)
        scope = scope.by_type(params[:type]) if params[:type].present?
        scope = scope.by_status(params[:status]) if params[:status].present?
        
        if params[:start_date].present? && params[:end_date].present?
          start_date = parse_date(params[:start_date])
          end_date = parse_date(params[:end_date])
          scope = scope.by_date_range(start_date, end_date) if start_date && end_date
        end
        
        if params[:month].present? && params[:year].present?
          scope = scope.by_month(params[:year].to_i, params[:month].to_i)
        end
        
        scope = scope.where('description ILIKE ?', "%#{params[:search]}%") if params[:search].present?
        
        scope
      end
      
      def build_summary(scope)
        {
          total_count: scope.count,
          total_amount: scope.sum(:amount),
          receivables: {
            count: scope.receivables.count,
            amount: scope.receivables.sum(:amount),
            paid: scope.receivables.paid.count,
            pending: scope.receivables.pending.count
          },
          payables: {
            count: scope.payables.count,
            amount: scope.payables.sum(:amount),
            paid: scope.payables.paid.count,
            pending: scope.payables.pending.count
          }
        }
      end
      
      def build_daily_breakdown(start_date, end_date)
        (start_date..end_date).map do |date|
          day_transactions = FinancialTransaction.where(due_date: date)
          paid_transactions = FinancialTransaction.where(paid_date: date)
          
          {
            date: date.strftime('%Y-%m-%d'),
            receivables_due: day_transactions.receivables.sum(:amount),
            payables_due: day_transactions.payables.sum(:amount),
            receivables_paid: paid_transactions.receivables.sum(&:final_amount),
            payables_paid: paid_transactions.payables.sum(&:final_amount),
            net_flow: paid_transactions.receivables.sum(&:final_amount) - 
                     paid_transactions.payables.sum(&:final_amount)
          }
        end
      end
      
      def transaction_json(transaction)
        {
          id: transaction.id,
          transaction_type: transaction.transaction_type,
          amount: transaction.amount,
          final_amount: transaction.final_amount,
          formatted_amount: transaction.formatted_amount,
          formatted_final_amount: transaction.formatted_final_amount,
          due_date: transaction.due_date&.strftime('%Y-%m-%d'),
          paid_date: transaction.paid_date&.strftime('%Y-%m-%d'),
          status: transaction.status,
          payment_method: transaction.payment_method,
          description: transaction.description,
          observation: transaction.observation,
          discount: transaction.discount,
          late_fee: transaction.late_fee,
          days_overdue: transaction.days_overdue,
          can_be_paid: transaction.can_be_paid?,
          can_be_cancelled: transaction.can_be_cancelled?,
          status_badge_class: transaction.status_badge_class,
          type_icon: transaction.type_icon,
          external_id: transaction.external_id,
          reference: reference_json(transaction.reference),
          cora_invoice: transaction.cora_invoice ? cora_invoice_json(transaction.cora_invoice) : nil,
          created_at: transaction.created_at&.iso8601,
          updated_at: transaction.updated_at&.iso8601
        }
      end
      
      def reference_json(reference)
        return nil unless reference
        
        case reference.class.name
        when 'Student'
          {
            type: 'Student',
            id: reference.id,
            name: reference.name,
            registration_number: reference.registration_number,
            class_name: reference.school_class&.full_name
          }
        when 'Teacher'
          {
            type: 'Teacher',
            id: reference.id,
            name: reference.user.name,
            email: reference.user.email
          }
        else
          {
            type: reference.class.name,
            id: reference.id,
            name: reference.try(:name) || reference.try(:description) || "#{reference.class.name} ##{reference.id}"
          }
        end
      end
      
      def create_cora_invoice_for_transaction(transaction)
        # Use the new unified method for FinancialTransaction
        CoraInvoice.create_for_financial_transaction(transaction)
      end
      
      def build_tuition_object(transaction)
        # Create a tuition-like object for Cora integration
        student = transaction.reference
        guardian = student&.guardians&.first
        
        OpenStruct.new(
          id: transaction.id,
          amount: transaction.amount,
          due_date: transaction.due_date,
          student: student,
          student_name: student&.name,
          guardian: guardian
        )
      end
      
      def build_expense_object(transaction)
        OpenStruct.new(
          id: transaction.id,
          amount: transaction.amount,
          description: transaction.description
        )
      end
      
      def cora_invoice_json(cora_invoice)
        {
          id: cora_invoice.id,
          invoice_id: cora_invoice.invoice_id,
          status: cora_invoice.status,
          amount: cora_invoice.amount,
          formatted_amount: cora_invoice.formatted_amount,
          due_date: cora_invoice.due_date&.strftime('%Y-%m-%d'),
          customer_name: cora_invoice.customer_name,
          customer_email: cora_invoice.customer_email,
          invoice_type: cora_invoice.invoice_type,
          # Payment options based on invoice type
          boleto_url: cora_invoice.boleto_url,
          pix_qr_code: cora_invoice.pix_qr_code,
          pix_qr_code_url: cora_invoice.pix_qr_code_url,
          # Additional metadata
          can_be_cancelled: cora_invoice.can_be_cancelled?,
          overdue: cora_invoice.overdue?,
          days_overdue: cora_invoice.days_overdue,
          paid_at: cora_invoice.paid_at&.iso8601,
          created_at: cora_invoice.created_at&.iso8601,
          updated_at: cora_invoice.updated_at&.iso8601
        }
      end
      
      def parse_date(date_string)
        Date.parse(date_string) rescue nil
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