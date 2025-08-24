module Api
  module V1
    class FinancesController < BaseController
      def dashboard
        month = params[:month] || Date.current.strftime('%Y-%m')
        start_date = Date.parse("#{month}-01")
        end_date = start_date.end_of_month
        
        render json: financial_dashboard_data(start_date, end_date)
      end
      
      def tuitions
        @tuitions = Tuition.includes(:student)
        
        if params[:status]
          @tuitions = @tuitions.where(status: params[:status])
        end
        
        if params[:month]
          year, month = params[:month].split('-').map(&:to_i)
          @tuitions = @tuitions.for_month(month, year)
        end
        
        @tuitions = @tuitions.order(:due_date)
        
        render json: @tuitions.map { |tuition| tuition_data(tuition) }
      end
      
      def update_tuition
        @tuition = Tuition.find(params[:id])
        
        if @tuition.update(tuition_params)
          render json: tuition_data(@tuition)
        else
          render json: { errors: @tuition.errors.full_messages },
                 status: :unprocessable_entity
        end
      end
      
      def salaries
        @salaries = Salary.includes(:teacher)
        
        if params[:status]
          @salaries = @salaries.where(status: params[:status])
        end
        
        if params[:month]
          year, month = params[:month].split('-').map(&:to_i)
          @salaries = @salaries.for_month(month, year)
        end
        
        @salaries = @salaries.order(:year, :month)
        
        render json: @salaries.map { |salary| salary_data(salary) }
      end
      
      def update_salary
        @salary = Salary.find(params[:id])
        
        if @salary.update(salary_params)
          render json: salary_data(@salary)
        else
          render json: { errors: @salary.errors.full_messages },
                 status: :unprocessable_entity
        end
      end
      
      def financial_accounts
        @accounts = FinancialAccount.all
        
        if params[:account_type]
          @accounts = @accounts.where(account_type: params[:account_type])
        end
        
        if params[:month]
          start_date = Date.parse("#{params[:month]}-01")
          end_date = start_date.end_of_month
          @accounts = @accounts.for_period(start_date, end_date)
        end
        
        @accounts = @accounts.order(:date)
        
        render json: @accounts.map { |account| financial_account_data(account) }
      end
      
      def create_financial_account
        @account = FinancialAccount.new(financial_account_params)
        
        if @account.save
          render json: financial_account_data(@account), status: :created
        else
          render json: { errors: @account.errors.full_messages },
                 status: :unprocessable_entity
        end
      end
      
      def reports
        start_date = Date.parse(params[:start_date])
        end_date = Date.parse(params[:end_date])
        
        render json: financial_reports(start_date, end_date)
      end
      
      private
      
      def tuition_params
        params.require(:tuition).permit(:status, :payment_method, :paid_date, 
                                       :discount, :observation)
      end
      
      def salary_params
        params.require(:salary).permit(:status, :payment_date, :bonus, :deductions)
      end
      
      def financial_account_params
        params.require(:financial_account).permit(:description, :amount, :account_type,
                                                 :category, :date, :status)
      end
      
      def financial_dashboard_data(start_date, end_date)
        tuitions = Tuition.where(due_date: start_date..end_date)
        salaries = Salary.where(month: start_date.month, year: start_date.year)
        
        monthly_receivable = tuitions.sum(:amount)
        monthly_received = tuitions.paid.sum { |t| t.total_amount }
        monthly_payable = salaries.sum { |s| s.total_amount }
        monthly_paid = salaries.paid.sum { |s| s.total_amount }
        
        {
          monthly_receivable: monthly_receivable,
          monthly_received: monthly_received,
          monthly_payable: monthly_payable,
          monthly_paid: monthly_paid,
          balance: monthly_received - monthly_paid,
          pending_tuitions: tuitions.pending_payment.includes(:student)
                                   .limit(10)
                                   .map { |t| tuition_summary(t) },
          upcoming_salaries: salaries.pending.includes(:teacher)
                                   .limit(10)
                                   .map { |s| salary_summary(s) },
          recent_transactions: recent_financial_transactions.map { |t| transaction_summary(t) }
        }
      end
      
      def tuition_data(tuition)
        {
          id: tuition.id,
          amount: tuition.amount,
          due_date: tuition.due_date,
          paid_date: tuition.paid_date,
          status: tuition.status,
          payment_method: tuition.payment_method,
          discount: tuition.discount,
          late_fee: tuition.late_fee,
          total_amount: tuition.total_amount,
          days_overdue: tuition.days_overdue,
          observation: tuition.observation,
          student: {
            id: tuition.student.id,
            name: tuition.student.name,
            registration_number: tuition.student.registration_number,
            class: tuition.student.school_class&.full_name
          }
        }
      end
      
      def salary_data(salary)
        {
          id: salary.id,
          amount: salary.amount,
          month: salary.month,
          year: salary.year,
          month_year: salary.month_year,
          payment_date: salary.payment_date,
          status: salary.status,
          bonus: salary.bonus,
          deductions: salary.deductions,
          total_amount: salary.total_amount,
          teacher: {
            id: salary.teacher.id,
            name: salary.teacher.name,
            email: salary.teacher.email
          }
        }
      end
      
      def financial_account_data(account)
        {
          id: account.id,
          description: account.description,
          amount: account.amount,
          account_type: account.account_type,
          category: account.category,
          date: account.date,
          status: account.status,
          reference_type: account.reference_type,
          reference_id: account.reference_id
        }
      end
      
      def tuition_summary(tuition)
        {
          id: tuition.id,
          student: {
            name: tuition.student.name,
            class: tuition.student.school_class&.full_name
          },
          amount: tuition.total_amount,
          due_date: tuition.due_date,
          days_overdue: tuition.days_overdue
        }
      end
      
      def salary_summary(salary)
        {
          id: salary.id,
          teacher: {
            name: salary.teacher.name
          },
          amount: salary.total_amount,
          month_year: salary.month_year
        }
      end
      
      def recent_financial_transactions
        FinancialAccount.paid
                       .order(date: :desc)
                       .limit(10)
      end
      
      def transaction_summary(transaction)
        {
          id: transaction.id,
          description: transaction.description,
          amount: transaction.amount,
          type: transaction.account_type,
          date: transaction.date,
          category: transaction.category
        }
      end
      
      def financial_reports(start_date, end_date)
        {
          period: "#{start_date} - #{end_date}",
          income: {
            total: FinancialAccount.income.paid.for_period(start_date, end_date).sum(:amount),
            by_category: income_by_category(start_date, end_date)
          },
          expenses: {
            total: FinancialAccount.expense.paid.for_period(start_date, end_date).sum(:amount),
            by_category: expenses_by_category(start_date, end_date)
          },
          balance: FinancialAccount.balance_for_period(start_date, end_date),
          tuitions: {
            total_due: Tuition.where(due_date: start_date..end_date).sum(:amount),
            total_paid: Tuition.paid.where(due_date: start_date..end_date).sum { |t| t.total_amount },
            overdue_count: Tuition.overdue.where(due_date: start_date..end_date).count
          },
          salaries: {
            total_due: Salary.where("DATE(year || '-' || month || '-01') BETWEEN ? AND ?", start_date, end_date).sum(:amount),
            total_paid: Salary.paid.where("DATE(year || '-' || month || '-01') BETWEEN ? AND ?", start_date, end_date).sum(:amount)
          }
        }
      end
      
      def income_by_category(start_date, end_date)
        FinancialAccount.income.paid.for_period(start_date, end_date)
                       .group(:category)
                       .sum(:amount)
      end
      
      def expenses_by_category(start_date, end_date)
        FinancialAccount.expense.paid.for_period(start_date, end_date)
                       .group(:category)
                       .sum(:amount)
      end
    end
  end
end