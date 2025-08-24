module Api
  module V1
    class SalariesController < BaseController
      before_action :set_salary, only: [:show, :update, :destroy, :pay]
      
      def index
        @salaries = Salary.includes(:teacher => :user)
        @salaries = @salaries.where(teacher_id: params[:teacher_id]) if params[:teacher_id]
        @salaries = @salaries.where(month: params[:month]) if params[:month]
        @salaries = @salaries.where(year: params[:year]) if params[:year]
        @salaries = @salaries.where(status: params[:status]) if params[:status]
        
        @salaries = @salaries.order(year: :desc, month: :desc).page(params[:page])
        
        render json: @salaries, include: { teacher: { include: :user } }
      end
      
      def show
        render json: @salary, include: { teacher: { include: :user } }
      end
      
      def create
        @salary = Salary.new(salary_params)
        
        if @salary.save
          render json: @salary, include: { teacher: { include: :user } }, status: :created
        else
          render json: { errors: @salary.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      def update
        if @salary.update(salary_params)
          render json: @salary, include: { teacher: { include: :user } }
        else
          render json: { errors: @salary.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      def destroy
        @salary.destroy
        head :no_content
      end
      
      def pay
        if @salary.update(status: :paid, payment_date: Date.current)
          render json: @salary, include: { teacher: { include: :user } }
        else
          render json: { errors: @salary.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      def bulk_generate
        month = params[:month].to_i
        year = params[:year].to_i
        
        unless (1..12).include?(month) && year > 0
          return render json: { error: 'Mês e ano inválidos' }, status: :bad_request
        end
        
        # Evitar duplicatas
        existing_salaries = Salary.where(month: month, year: year).pluck(:teacher_id)
        teachers_to_process = Teacher.where.not(id: existing_salaries)
        
        salaries_created = []
        
        teachers_to_process.each do |teacher|
          salary = Salary.create!(
            teacher: teacher,
            amount: teacher.salary || 0,
            month: month,
            year: year,
            status: :pending,
            bonus: 0,
            deductions: 0
          )
          salaries_created << salary
        end
        
        render json: {
          message: "#{salaries_created.count} salários gerados para #{month}/#{year}",
          salaries: salaries_created
        }, include: { teacher: { include: :user } }
      end
      
      def statistics
        month = params[:month]&.to_i
        year = params[:year]&.to_i
        
        scope = Salary.all
        scope = scope.where(month: month) if month
        scope = scope.where(year: year) if year
        
        stats = {
          total_pending: scope.where(status: :pending).sum(:amount),
          total_paid: scope.where(status: :paid).sum(:amount),
          count_pending: scope.where(status: :pending).count,
          count_paid: scope.where(status: :paid).count,
          monthly_total: scope.sum(:amount)
        }
        
        render json: stats
      end
      
      private
      
      def set_salary
        @salary = Salary.find(params[:id])
      end
      
      def salary_params
        params.require(:salary).permit(:teacher_id, :amount, :month, :year, :bonus, :deductions, :status)
      end
    end
  end
end