module Api
  module V1
    class AttendancesController < BaseController
      def index
        @attendances = Attendance.includes(:student, lesson: { diary: [:subject, :school_class] })
        
        if params[:lesson_id]
          @attendances = @attendances.where(lesson_id: params[:lesson_id])
        elsif params[:student_id]
          @attendances = @attendances.where(student_id: params[:student_id])
        elsif params[:date]
          @attendances = @attendances.joins(:lesson).where(lessons: { date: params[:date] })
        elsif params[:class_id]
          @attendances = @attendances.joins(lesson: { diary: :school_class })
                                   .where(school_classes: { id: params[:class_id] })
        end
        
        @attendances = @attendances.joins(:student, :lesson).order('lessons.date DESC, students.name ASC')
        
        render json: @attendances.map { |attendance| attendance_data(attendance) }
      end
      
      def update
        @attendance = Attendance.find(params[:id])
        
        if @attendance.update(attendance_params)
          render json: attendance_data(@attendance)
        else
          render json: { errors: @attendance.errors.full_messages }, 
                 status: :unprocessable_entity
        end
      end
      
      def bulk_update
        Attendance.transaction do
          params[:attendances].each do |attendance_params|
            attendance = Attendance.find(attendance_params[:id])
            attendance.update!(
              status: attendance_params[:status],
              observation: attendance_params[:observation]
            )
          end
        end
        
        render json: { message: 'Presenças atualizadas com sucesso' }
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.message }, status: :unprocessable_entity
      end
      
      def report
        start_date = Date.parse(params[:start_date])
        end_date = Date.parse(params[:end_date])
        
        if params[:student_id]
          student = Student.find(params[:student_id])
          attendances = student.attendances.for_period(start_date, end_date)
                              .includes(lesson: [:class_subject])
          
          render json: student_attendance_report(student, attendances, start_date, end_date)
        elsif params[:class_id]
          school_class = SchoolClass.find(params[:class_id])
          attendances = Attendance.joins(lesson: :class_subject)
                                 .where(class_subjects: { school_class_id: school_class.id })
                                 .for_period(start_date, end_date)
                                 .includes(:student, lesson: :class_subject)
          
          render json: class_attendance_report(school_class, attendances, start_date, end_date)
        end
      end
      
      private
      
      def attendance_params
        params.require(:attendance).permit(:status, :observation)
      end
      
      def attendance_data(attendance)
        {
          id: attendance.id,
          status: attendance.status,
          observation: attendance.observation,
          student: {
            id: attendance.student.id,
            name: attendance.student.name,
            registration_number: attendance.student.registration_number
          },
          lesson: {
            id: attendance.lesson.id,
            date: attendance.lesson.date,
            topic: attendance.lesson.topic,
            subject: attendance.lesson.subject&.name,
            class: attendance.lesson.school_class&.full_name
          }
        }
      end
      
      def student_attendance_report(student, attendances, start_date, end_date)
        by_subject = attendances.group_by { |a| a.lesson.subject }
        
        {
          student: {
            id: student.id,
            name: student.name,
            class: student.school_class&.full_name
          },
          period: "#{start_date} - #{end_date}",
          summary: {
            total_classes: attendances.count,
            present: attendances.present.count,
            absent: attendances.absent.count,
            late: attendances.late.count,
            justified: attendances.justified.count
          },
          by_subject: by_subject.map do |subject, subject_attendances|
            total = subject_attendances.count
            present = subject_attendances.count(&:present?)
            
            {
              subject: subject.name,
              total_classes: total,
              present: present,
              absent: total - present,
              percentage: total > 0 ? (present.to_f / total * 100).round(2) : 0
            }
          end
        }
      end
      
      def class_attendance_report(school_class, attendances, start_date, end_date)
        by_student = attendances.group_by(&:student)
        
        {
          class: {
            id: school_class.id,
            name: school_class.full_name
          },
          period: "#{start_date} - #{end_date}",
          students: by_student.map do |student, student_attendances|
            total = student_attendances.count
            present = student_attendances.count(&:present?)
            
            {
              student: {
                id: student.id,
                name: student.name,
                registration_number: student.registration_number
              },
              total_classes: total,
              present: present,
              absent: total - present,
              percentage: total > 0 ? (present.to_f / total * 100).round(2) : 0
            }
          end.sort_by { |s| s[:student][:name] }
        }
      end
    end
  end
end