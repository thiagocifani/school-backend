module Api
  module V1
    class ReportsController < BaseController
      
      def student_report
        @student = Student.find(params[:student_id])
        @term = AcademicTerm.find(params[:academic_term_id])
        
        report_data = {
          student: {
            id: @student.id,
            name: @student.name,
            registrationNumber: @student.registration_number,
            schoolClass: @student.school_class ? {
              id: @student.school_class.id,
              name: @student.school_class.name,
              section: @student.school_class.section
            } : nil
          },
          academicTerm: {
            id: @term.id,
            name: @term.name,
            year: @term.year,
            startDate: @term.start_date,
            endDate: @term.end_date
          },
          grades: compile_student_grades(@student, @term),
          attendance: compile_student_attendance(@student, @term),
          occurrences: compile_student_occurrences(@student, @term)
        }
        
        render json: report_data
      end
      
      def attendance_report
        @class = SchoolClass.find(params[:class_id])
        start_date = Date.parse(params[:start_date])
        end_date = Date.parse(params[:end_date])
        
        report_data = {
          schoolClass: {
            id: @class.id,
            name: @class.name,
            section: @class.section
          },
          period: {
            startDate: start_date,
            endDate: end_date
          },
          students: compile_class_attendance(@class, start_date, end_date)
        }
        
        render json: report_data
      end
      
      def financial_report
        start_date = Date.parse(params[:start_date])
        end_date = Date.parse(params[:end_date])
        
        report_data = {
          period: {
            startDate: start_date,
            endDate: end_date
          },
          tuitions: compile_tuitions_report(start_date, end_date),
          salaries: compile_salaries_report(start_date, end_date),
          summary: compile_financial_summary(start_date, end_date)
        }
        
        render json: report_data
      end
      
      def grades_report
        @term = AcademicTerm.find(params[:academic_term_id])
        @class = SchoolClass.find(params[:class_id]) if params[:class_id]
        
        grades = Grade.where(academic_term: @term)
        grades = grades.joins(:student).where(students: { school_class: @class }) if @class
        
        report_data = {
          academicTerm: {
            id: @term.id,
            name: @term.name,
            year: @term.year
          },
          schoolClass: @class ? {
            id: @class.id,
            name: @class.name,
            section: @class.section
          } : nil,
          grades: grades.includes(:student, :diary).map do |grade|
            {
              id: grade.id,
              student: {
                id: grade.student.id,
                name: grade.student.name,
                registrationNumber: grade.student.registration_number
              },
              diary: grade.diary ? {
                id: grade.diary.id,
                name: grade.diary.name,
                subject: {
                  name: grade.diary.subject.name
                }
              } : nil,
              value: grade.value,
              gradeType: grade.grade_type,
              date: grade.date
            }
          end
        }
        
        render json: report_data
      end
      
      private
      
      def compile_student_grades(student, term)
        grades = student.grades.where(academic_term: term).includes(:diary)
        
        grades.group_by { |g| g.diary&.subject&.name || 'Sem matéria' }.map do |subject, subject_grades|
          {
            subject: subject,
            grades: subject_grades.map do |grade|
              {
                id: grade.id,
                value: grade.value,
                gradeType: grade.grade_type,
                date: grade.date,
                observation: grade.observation
              }
            end,
            average: subject_grades.average(:value)&.round(2)
          }
        end
      end
      
      def compile_student_attendance(student, term)
        # Se o aluno não possui turma associada, retorna zeros
        return { totalLessons: 0, presentCount: 0, absentCount: 0, percentage: 0 } if student.school_class_id.blank?

        # Cálculo de presença baseado no período e na turma do aluno
        total_lessons = Lesson.joins(:diary)
                             .where(diaries: { school_class_id: student.school_class_id })
                             .where(date: term.start_date..term.end_date)
                             .count

        present_count = Attendance.joins(:lesson)
                                 .where(student: student)
                                 .where(lessons: { date: term.start_date..term.end_date })
                                 .where(status: :present)
                                 .count

        {
          totalLessons: total_lessons,
          presentCount: present_count,
          absentCount: total_lessons - present_count,
          percentage: total_lessons > 0 ? (present_count.to_f / total_lessons * 100).round(2) : 0
        }
      end
      
      def compile_student_occurrences(student, term)
        student.occurrences
               .where(date: term.start_date..term.end_date)
               .includes(:teacher, :diary)
               .map do |occurrence|
          {
            id: occurrence.id,
            date: occurrence.date,
            title: occurrence.title,
            description: occurrence.description,
            occurrenceType: occurrence.occurrence_type,
            severity: occurrence.severity,
            teacher: {
              name: occurrence.teacher.name
            },
            diary: occurrence.diary ? {
              name: occurrence.diary.name,
              subject: occurrence.diary.subject.name
            } : nil
          }
        end
      end
      
      def compile_class_attendance(school_class, start_date, end_date)
        students = school_class.students.includes(:attendances)
        
        students.map do |student|
          total_lessons = Lesson.joins(:diary)
                               .where(diaries: { school_class: school_class })
                               .where(date: start_date..end_date)
                               .count
          
          present_count = student.attendances
                                .joins(:lesson)
                                .where(lessons: { date: start_date..end_date })
                                .where(status: :present)
                                .count
          
          {
            student: {
              id: student.id,
              name: student.name,
              registrationNumber: student.registration_number
            },
            totalLessons: total_lessons,
            presentCount: present_count,
            absentCount: total_lessons - present_count,
            percentage: total_lessons > 0 ? (present_count.to_f / total_lessons * 100).round(2) : 0
          }
        end
      end
      
      def compile_tuitions_report(start_date, end_date)
        tuitions = Tuition.where(due_date: start_date..end_date)
        
        {
          total: tuitions.sum(:amount),
          paid: tuitions.where(status: :paid).sum(:amount),
          pending: tuitions.where(status: :pending).sum(:amount),
          overdue: tuitions.where(status: :overdue).sum(:amount),
          count: tuitions.count,
          paidCount: tuitions.where(status: :paid).count,
          pendingCount: tuitions.where(status: :pending).count,
          overdueCount: tuitions.where(status: :overdue).count
        }
      end
      
      def compile_salaries_report(start_date, end_date)
        # Convertendo datas para ano/mês para buscar salários
        start_year = start_date.year
        start_month = start_date.month
        end_year = end_date.year
        end_month = end_date.month
        
        salaries = Salary.where(
          "(year = ? AND month >= ?) OR (year > ? AND year < ?) OR (year = ? AND month <= ?)",
          start_year, start_month, start_year, end_year, end_year, end_month
        )
        
        {
          total: salaries.sum(:amount),
          paid: salaries.where(status: :paid).sum(:amount),
          pending: salaries.where(status: :pending).sum(:amount),
          count: salaries.count,
          paidCount: salaries.where(status: :paid).count,
          pendingCount: salaries.where(status: :pending).count
        }
      end
      
      def compile_financial_summary(start_date, end_date)
        tuitions_data = compile_tuitions_report(start_date, end_date)
        salaries_data = compile_salaries_report(start_date, end_date)
        
        {
          income: tuitions_data[:paid],
          expenses: salaries_data[:paid],
          balance: tuitions_data[:paid] - salaries_data[:paid],
          pendingIncome: tuitions_data[:pending],
          pendingExpenses: salaries_data[:pending]
        }
      end
    end
  end
end