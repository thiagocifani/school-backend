module Api
  module V1
    class TuitionsController < BaseController
      before_action :set_tuition, only: [:show, :update, :destroy, :pay, :generate_boleto]
      
      def index
        @tuitions = Tuition.includes(:student => :school_class)
        @tuitions = @tuitions.where(student_id: params[:student_id]) if params[:student_id]
        @tuitions = @tuitions.where(status: params[:status]) if params[:status]
        
        if params[:due_month] && params[:due_year]
          start_date = Date.new(params[:due_year].to_i, params[:due_month].to_i, 1)
          end_date = start_date.end_of_month
          @tuitions = @tuitions.where(due_date: start_date..end_date)
        end
        
        if params[:overdue] == 'true'
          @tuitions = @tuitions.where(status: :pending).where('due_date < ?', Date.current)
        end
        
        @tuitions = @tuitions.order(:due_date).page(params[:page])
        
        render json: @tuitions, include: { student: { include: :school_class } }
      end
      
      def show
        render json: @tuition, include: { student: { include: :school_class } }
      end
      
      def create
        @tuition = Tuition.new(tuition_params)
        
        if @tuition.save
          render json: @tuition, include: { student: { include: :school_class } }, status: :created
        else
          render json: { errors: @tuition.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      def update
        if @tuition.update(tuition_params)
          render json: @tuition, include: { student: { include: :school_class } }
        else
          render json: { errors: @tuition.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      def destroy
        @tuition.destroy
        head :no_content
      end
      
      def pay
        payment_data = {
          status: :paid,
          paid_date: params[:paid_date] || Date.current,
          payment_method: params[:payment_method],
          discount: params[:discount] || 0,
          late_fee: params[:late_fee] || 0
        }
        
        # Calcular taxa de atraso automaticamente se não informada
        if payment_data[:late_fee] == 0 && @tuition.due_date < Date.current
          days_late = (Date.current - @tuition.due_date).to_i
          payment_data[:late_fee] = (@tuition.amount * 0.02 * days_late / 30).round(2) # 2% ao mês
        end
        
        if @tuition.update(payment_data)
          render json: @tuition, include: { student: { include: :school_class } }
        else
          render json: { errors: @tuition.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      def bulk_generate
        month = params[:month].to_i
        year = params[:year].to_i
        amount = params[:amount].to_f
        
        unless (1..12).include?(month) && year > 0 && amount > 0
          return render json: { error: 'Parâmetros inválidos' }, status: :bad_request
        end
        
        # Data de vencimento - dia 10 do mês
        due_date = Date.new(year, month, 10)
        
        # Evitar duplicatas
        existing_tuitions = Tuition.joins(:student)
                                   .where(due_date: due_date.beginning_of_month..due_date.end_of_month)
                                   .pluck(:student_id)
        
        students_to_process = Student.active.where.not(id: existing_tuitions)
        
        tuitions_created = []
        
        students_to_process.each do |student|
          tuition = Tuition.create!(
            student: student,
            amount: amount,
            due_date: due_date,
            status: :pending,
            discount: 0,
            late_fee: 0
          )
          tuitions_created << tuition
        end
        
        render json: {
          message: "#{tuitions_created.count} mensalidades geradas para #{month}/#{year}",
          tuitions: tuitions_created
        }, include: { student: { include: :school_class } }
      end
      
      def statistics
        month = params[:month]&.to_i
        year = params[:year]&.to_i
        
        scope = Tuition.all
        
        if month && year
          start_date = Date.new(year, month, 1)
          end_date = start_date.end_of_month
          scope = scope.where(due_date: start_date..end_date)
        elsif year
          scope = scope.where('EXTRACT(year FROM due_date) = ?', year)
        end
        
        stats = {
          total_pending: scope.where(status: :pending).sum(:amount),
          total_paid: scope.where(status: :paid).sum('amount + late_fee - discount'),
          total_overdue: scope.where(status: :pending).where('due_date < ?', Date.current).sum(:amount),
          count_pending: scope.where(status: :pending).count,
          count_paid: scope.where(status: :paid).count,
          count_overdue: scope.where(status: :pending).where('due_date < ?', Date.current).count,
          monthly_total: scope.sum(:amount)
        }
        
        render json: stats
      end
      
      def overdue_report
        @overdue_tuitions = Tuition.includes(student: :school_class)
                                   .where(status: :pending)
                                   .where('due_date < ?', Date.current)
                                   .order(:due_date)
        
        render json: @overdue_tuitions, include: { student: { include: :school_class } }
      end
      
      # Generate boleto for tuition via Cora API
      def generate_boleto
        # Check if boleto already exists
        cora_invoice = CoraInvoice.find_by(reference: @tuition)
        if cora_invoice&.boleto_url.present?
          return render json: {
            success: true,
            boleto_url: cora_invoice.boleto_url,
            pix_qr_code: cora_invoice.pix_qr_code,
            pix_qr_code_url: cora_invoice.pix_qr_code_url,
            invoice: invoice_json(cora_invoice)
          }
        end
        
        begin
          # Create Cora invoice if it doesn't exist
          cora_invoice = cora_invoice || CoraInvoice.create_for_tuition(@tuition)
          
          # Generate boleto via Cora API
          cora_service = CoraApiService.new
          cora_response = cora_service.create_invoice(cora_invoice)
          
          render json: {
            success: true,
            message: 'Boleto gerado com sucesso',
            boleto_url: cora_invoice.boleto_url,
            pix_qr_code: cora_invoice.pix_qr_code,
            pix_qr_code_url: cora_invoice.pix_qr_code_url,
            invoice: invoice_json(cora_invoice)
          }
        rescue => e
          Rails.logger.error "Failed to generate boleto: #{e.message}"
          render json: { error: 'Erro ao gerar boleto' }, status: :unprocessable_entity
        end
      end
      
      private
      
      def set_tuition
        @tuition = Tuition.find(params[:id])
      end
      
      def tuition_params
        params.require(:tuition).permit(:student_id, :amount, :due_date, :discount, :late_fee, 
                                       :payment_method, :observation, :status)
      end
      
      def invoice_json(invoice)
        {
          id: invoice.id,
          invoice_id: invoice.invoice_id,
          status: invoice.status,
          boleto_url: invoice.boleto_url,
          pix_qr_code: invoice.pix_qr_code,
          pix_qr_code_url: invoice.pix_qr_code_url,
          paid_at: invoice.paid_at
        }
      end
    end
  end
end