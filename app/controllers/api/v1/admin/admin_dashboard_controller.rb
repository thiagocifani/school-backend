module Api
  module V1
    module Admin
      class AdminDashboardController < BaseController
        
        def index
          render json: {
            overview: system_overview,
            recent_activities: recent_activities,
            alerts: system_alerts,
            quick_stats: quick_stats
          }
        end
        
        def system_stats
          render json: {
            users: user_statistics,
            students: student_statistics,
            academic: academic_statistics,
            financial: financial_statistics,
            system: system_information
          }
        end
        
        private
        
        def system_overview
          {
            total_users: User.count,
            total_students: Student.count,
            active_students: Student.active.count,
            total_teachers: Teacher.count,
            total_guardians: Guardian.count,
            total_classes: SchoolClass.count,
            pending_tuitions: Tuition.where(status: 'pending').count,
            overdue_tuitions: Tuition.where(status: 'overdue').count
          }
        end
        
        def recent_activities
          activities = []
          
          # Recent student registrations
          Student.includes(:school_class).order(created_at: :desc).limit(5).each do |student|
            activities << {
              type: 'student_created',
              description: "Novo aluno cadastrado: #{student.name}",
              details: "Turma: #{student.school_class&.name || 'Não definida'}",
              timestamp: student.created_at,
              icon: 'user-plus'
            }
          end
          
          # Recent user registrations
          User.where(created_at: 1.week.ago..).order(created_at: :desc).limit(5).each do |user|
            activities << {
              type: 'user_created',
              description: "Novo usuário: #{user.name} (#{user.role})",
              details: "Email: #{user.email}",
              timestamp: user.created_at,
              icon: 'user'
            }
          end
          
          # Recent payments
          if defined?(Tuition)
            Tuition.where(status: 'paid', paid_date: 1.week.ago..).includes(:student).limit(5).each do |tuition|
              activities << {
                type: 'payment_received',
                description: "Pagamento recebido: #{tuition.student.name}",
                details: "Valor: R$ #{tuition.amount}",
                timestamp: tuition.paid_date,
                icon: 'dollar-sign'
              }
            end
          end
          
          activities.sort_by { |a| a[:timestamp] }.reverse.first(15)
        end
        
        def system_alerts
          alerts = []
          
          # Overdue tuitions alert
          overdue_count = Tuition.where(status: 'overdue').count if defined?(Tuition)
          if overdue_count && overdue_count > 0
            alerts << {
              type: 'warning',
              title: 'Mensalidades em Atraso',
              message: "#{overdue_count} mensalidades estão em atraso",
              action: 'Ver mensalidades',
              link: '/admin/finances/tuitions?status=overdue'
            }
          end
          
          # Students without guardians
          students_without_guardians = Student.joins(:guardian_students).having('COUNT(guardian_students.id) = 0').count
          if students_without_guardians > 0
            alerts << {
              type: 'error',
              title: 'Alunos sem Responsáveis',
              message: "#{students_without_guardians} alunos não têm responsáveis cadastrados",
              action: 'Ver alunos',
              link: '/admin/students?filter=without_guardians'
            }
          end
          
          # Users with default passwords
          default_password_users = User.where(encrypted_password: User.new(password: '123456').encrypted_password).count
          if default_password_users > 0
            alerts << {
              type: 'info',
              title: 'Usuários com Senha Padrão',
              message: "#{default_password_users} usuários ainda usam a senha padrão",
              action: 'Ver usuários',
              link: '/admin/users?filter=default_password'
            }
          end
          
          alerts
        end
        
        def quick_stats
          current_month = Date.current.beginning_of_month
          
          {
            new_students_this_month: Student.where(created_at: current_month..).count,
            new_users_this_month: User.where(created_at: current_month..).count,
            payments_this_month: defined?(Tuition) ? Tuition.where(paid_date: current_month..).count : 0,
            active_classes: SchoolClass.joins(:students).distinct.count
          }
        end
        
        def user_statistics
          {
            total: User.count,
            by_role: User.group(:role).count,
            active_last_month: User.where(updated_at: 1.month.ago..).count,
            new_this_month: User.where(created_at: Date.current.beginning_of_month..).count
          }
        end
        
        def student_statistics
          {
            total: Student.count,
            active: Student.active.count,
            inactive: Student.inactive.count,
            transferred: Student.transferred.count,
            by_class: SchoolClass.joins(:students).group('school_classes.name').count,
            average_age: Student.where.not(birth_date: nil).average('EXTRACT(year FROM age(birth_date))').to_f.round(1),
            with_guardians: Student.joins(:guardians).distinct.count,
            without_guardians: Student.left_joins(:guardians).where(guardians: { id: nil }).count
          }
        end
        
        def academic_statistics
          {
            total_classes: SchoolClass.count,
            total_subjects: Subject.count,
            total_lessons: Lesson.count,
            attendance_rate: calculate_overall_attendance_rate,
            grades_average: Grade.average(:value)&.round(2)
          }
        end
        
        def financial_statistics
          if defined?(Tuition) && defined?(Salary)
            current_month = Date.current.beginning_of_month
            
            {
              pending_tuitions: Tuition.where(status: 'pending').sum(:amount),
              received_this_month: Tuition.where(status: 'paid', paid_date: current_month..).sum(:amount),
              overdue_amount: Tuition.where(status: 'overdue').sum(:amount),
              pending_salaries: Salary.where(status: 'pending').sum(:amount),
              paid_salaries_this_month: Salary.where(status: 'paid', payment_date: current_month..).sum(:amount)
            }
          else
            {
              pending_tuitions: 0,
              received_this_month: 0,
              overdue_amount: 0,
              pending_salaries: 0,
              paid_salaries_this_month: 0
            }
          end
        end
        
        def system_information
          {
            rails_version: Rails.version,
            ruby_version: RUBY_VERSION,
            database_size: calculate_database_size,
            uptime: calculate_uptime,
            environment: Rails.env
          }
        end
        
        def calculate_overall_attendance_rate
          total_attendances = Attendance.count
          return 0 if total_attendances == 0
          
          present_attendances = Attendance.where(status: 'present').count
          (present_attendances.to_f / total_attendances * 100).round(2)
        end
        
        def calculate_database_size
          result = ActiveRecord::Base.connection.execute("SELECT pg_size_pretty(pg_database_size(current_database())) as size").first
          result['size']
        rescue
          'N/A'
        end
        
        def calculate_uptime
          if File.exist?(Rails.root.join('tmp/pids/server.pid'))
            pid_file_time = File.mtime(Rails.root.join('tmp/pids/server.pid'))
            uptime_seconds = Time.current - pid_file_time
            
            days = (uptime_seconds / 86400).to_i
            hours = ((uptime_seconds % 86400) / 3600).to_i
            minutes = ((uptime_seconds % 3600) / 60).to_i
            
            "#{days}d #{hours}h #{minutes}m"
          else
            'N/A'
          end
        end
      end
    end
  end
end