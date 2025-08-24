module Api
  module V1
    class DashboardController < BaseController
      
      def index
        dashboard_data = {
          summary: {
            totalStudents: Student.active.count,
            totalTeachers: Teacher.count,
            totalClasses: SchoolClass.count,
            activeDiaries: Diary.where(status: :active).count
          },
          recentActivities: compile_recent_activities,
          upcomingEvents: compile_upcoming_events,
          alerts: compile_alerts,
          quickStats: compile_quick_stats,
          pendingTransactions: compile_pending_transactions,
          financialOverview: compile_financial_overview
        }
        
        render json: dashboard_data
      end
      
      private
      
      def compile_recent_activities
        activities = []
        
        # Aulas recentes
        recent_lessons = Lesson.includes(:diary)
                              .where(status: :completed)
                              .order(date: :desc)
                              .limit(5)
        
        recent_lessons.each do |lesson|
          activities << {
            type: 'lesson_completed',
            title: "Aula #{lesson.lesson_number} concluída",
            description: "#{lesson.diary.subject.name} - #{lesson.diary.school_class.name}",
            date: lesson.date,
            icon: 'book'
          }
        end
        
        # Ocorrências recentes
        recent_occurrences = Occurrence.includes(:student, :teacher)
                                      .order(created_at: :desc)
                                      .limit(3)
        
        recent_occurrences.each do |occurrence|
          activities << {
            type: 'occurrence_created',
            title: occurrence.title,
            description: "#{occurrence.student.name} - #{occurrence.teacher.name}",
            date: occurrence.date,
            icon: 'alert'
          }
        end
        
        # Notas lançadas recentemente
        recent_grades = Grade.includes(:student, :diary)
                            .order(created_at: :desc)
                            .limit(3)
        
        recent_grades.each do |grade|
          activities << {
            type: 'grade_added',
            title: "Nova nota lançada",
            description: "#{grade.student.name} - #{grade.diary.subject.name}: #{grade.value}",
            date: grade.date,
            icon: 'award'
          }
        end
        
        # Ordenar por data e retornar os 10 mais recentes
        activities.sort_by { |a| a[:date] }.reverse.first(10)
      end
      
      def compile_upcoming_events
        events = []
        
        # Aulas planejadas para os próximos dias
        upcoming_lessons = Lesson.includes(:diary)
                                .where(status: :planned)
                                .where(date: Date.current..7.days.from_now)
                                .order(date: :asc)
                                .limit(5)
        
        upcoming_lessons.each do |lesson|
          events << {
            type: 'lesson_planned',
            title: "Aula #{lesson.lesson_number}",
            description: "#{lesson.diary.subject.name} - #{lesson.diary.school_class.name}",
            date: lesson.date,
            time: "#{lesson.diary.school_class.name}", # Placeholder para horário
            icon: 'calendar'
          }
        end
        
        # Mensalidades com vencimento próximo
        upcoming_tuitions = Tuition.includes(:student)
                                  .where(status: :pending)
                                  .where(due_date: Date.current..7.days.from_now)
                                  .order(due_date: :asc)
                                  .limit(5)
        
        upcoming_tuitions.each do |tuition|
          events << {
            type: 'tuition_due',
            title: "Mensalidade vencendo",
            description: "#{tuition.student.name} - R$ #{tuition.amount}",
            date: tuition.due_date,
            icon: 'dollar-sign'
          }
        end
        
        events.sort_by { |e| e[:date] }.first(10)
      end
      
      def compile_alerts
        alerts = []
        
        # Mensalidades em atraso
        overdue_tuitions_count = Tuition.where(status: :overdue).count
        if overdue_tuitions_count > 0
          alerts << {
            type: 'warning',
            title: 'Mensalidades em Atraso',
            message: "#{overdue_tuitions_count} mensalidades estão em atraso",
            count: overdue_tuitions_count,
            action: '/dashboard/finances/tuitions'
          }
        end
        
        # Baixa frequência de alunos
        low_attendance_students = Student.joins(:attendances)
                                        .group('students.id')
                                        .having('COUNT(CASE WHEN attendances.status = ? THEN 1 END) * 100.0 / COUNT(*) < ?', 'present', 75)
                                        .count
        
        if low_attendance_students.any?
          alerts << {
            type: 'warning',
            title: 'Alunos com Baixa Frequência',
            message: "#{low_attendance_students.count} alunos com frequência abaixo de 75%",
            count: low_attendance_students.count,
            action: '/dashboard/students'
          }
        end
        
        # Diários sem aulas planejadas
        empty_diaries_count = Diary.joins("LEFT JOIN lessons ON lessons.diary_id = diaries.id")
                                  .where(status: :active)
                                  .group('diaries.id')
                                  .having('COUNT(lessons.id) = 0')
                                  .count
                                  .length
        
        if empty_diaries_count > 0
          alerts << {
            type: 'info',
            title: 'Diários sem Aulas',
            message: "#{empty_diaries_count} diários ativos não possuem aulas planejadas",
            count: empty_diaries_count,
            action: '/dashboard/diaries'
          }
        end
        
        alerts
      end
      
      def compile_quick_stats
        current_month = Date.current.beginning_of_month..Date.current.end_of_month
        
        {
          thisMonth: {
            lessonsCompleted: Lesson.where(status: :completed, date: current_month).count,
            gradesAdded: Grade.where(created_at: current_month.first..current_month.last).count,
            occurrencesRegistered: Occurrence.where(created_at: current_month.first..current_month.last).count,
            tuitionsPaid: Tuition.where(status: :paid, paid_date: current_month).count
          },
          attendance: {
            overall: calculate_overall_attendance_percentage,
            thisWeek: calculate_week_attendance_percentage
          },
          finances: {
            monthlyRevenue: Tuition.where(status: :paid, paid_date: current_month).sum(:amount),
            pendingAmount: Tuition.where(status: :pending).sum(:amount),
            overdueAmount: Tuition.where(status: :overdue).sum(:amount)
          }
        }
      end
      
      def calculate_overall_attendance_percentage
        total_attendances = Attendance.count
        present_attendances = Attendance.where(status: :present).count
        
        return 0 if total_attendances.zero?
        
        (present_attendances.to_f / total_attendances * 100).round(1)
      end
      
      def calculate_week_attendance_percentage
        week_start = Date.current.beginning_of_week
        week_end = Date.current.end_of_week
        
        week_attendances = Attendance.joins(:lesson)
                                   .where(lessons: { date: week_start..week_end })
        
        total = week_attendances.count
        present = week_attendances.where(status: :present).count
        
        return 0 if total.zero?
        
        (present.to_f / total * 100).round(1)
      end
      
      def compile_pending_transactions
        pending_transactions = FinancialTransaction.pending
                                                  .includes(:reference, :cora_invoice)
                                                  .order(due_date: :asc)
                                                  .limit(10)
        
        pending_transactions.map do |transaction|
          {
            id: transaction.id,
            type: transaction.transaction_type,
            description: transaction.description,
            amount: transaction.amount,
            formatted_amount: transaction.formatted_amount,
            due_date: transaction.due_date,
            days_overdue: transaction.days_overdue,
            reference: build_transaction_reference(transaction),
            cora_invoice: transaction.cora_invoice ? {
              invoice_id: transaction.cora_invoice.invoice_id,
              boleto_url: transaction.cora_invoice.boleto_url,
              pix_qr_code_url: transaction.cora_invoice.pix_qr_code_url,
              status: transaction.cora_invoice.status
            } : nil,
            icon: transaction.type_icon,
            badge_class: transaction.status_badge_class
          }
        end
      end
      
      def compile_financial_overview
        current_month = Date.current.beginning_of_month..Date.current.end_of_month
        
        # Get financial summary for current month
        summary = FinancialTransaction.cash_flow_summary
        
        # Get overdue transactions count
        overdue_count = FinancialTransaction.overdue.count
        overdue_amount = FinancialTransaction.overdue.sum(:amount)
        
        # Recent payments
        recent_payments = FinancialTransaction.paid
                                            .where(paid_date: 30.days.ago..Date.current)
                                            .includes(:reference)
                                            .order(paid_date: :desc)
                                            .limit(5)
                                            .map { |t| build_recent_payment(t) }
        
        {
          monthly_summary: summary,
          overdue: {
            count: overdue_count,
            total_amount: overdue_amount,
            formatted_amount: "R$ #{overdue_amount.to_f.to_s.gsub('.', ',')}"
          },
          recent_payments: recent_payments,
          quick_actions: [
            {
              title: 'Gerar Mensalidades',
              description: 'Criar mensalidades do mês atual',
              action: '/dashboard/finances/bulk-tuitions',
              icon: 'graduation-cap'
            },
            {
              title: 'Gerar Salários',
              description: 'Criar salários do mês atual', 
              action: '/dashboard/finances/bulk-salaries',
              icon: 'users'
            },
            {
              title: 'Relatório Financeiro',
              description: 'Visualizar fluxo de caixa completo',
              action: '/dashboard/finances/cash-flow',
              icon: 'bar-chart'
            }
          ]
        }
      end
      
      private
      
      def build_transaction_reference(transaction)
        return nil unless transaction.reference
        
        case transaction.reference.class.name
        when 'Student'
          student = transaction.reference
          {
            type: 'Student',
            name: student.name,
            registration: student.registration_number,
            class_name: student.school_class&.full_name
          }
        when 'Teacher'
          teacher = transaction.reference
          {
            type: 'Teacher',
            name: teacher.user.name,
            email: teacher.user.email
          }
        else
          {
            type: transaction.reference.class.name,
            name: transaction.reference.try(:name) || "#{transaction.reference.class.name} ##{transaction.reference.id}"
          }
        end
      end
      
      def build_recent_payment(transaction)
        {
          id: transaction.id,
          description: transaction.description,
          amount: transaction.final_amount,
          formatted_amount: transaction.formatted_final_amount,
          paid_date: transaction.paid_date,
          payment_method: transaction.payment_method,
          type: transaction.transaction_type,
          reference: build_transaction_reference(transaction)
        }
      end
    end
  end
end