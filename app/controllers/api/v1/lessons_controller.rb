module Api
  module V1
    class LessonsController < BaseController
      before_action :set_lesson, only: [:show, :update, :destroy]
      before_action :set_diary, only: [:index, :create]
      
      def index
        @lessons = @diary.lessons.includes(:attendances, :grades, :occurrences)
        @lessons = @lessons.where(status: params[:status]) if params[:status]
        @lessons = @lessons.for_date(Date.parse(params[:date])) if params[:date]
        
        render json: @lessons.order(:lesson_number).map { |lesson| lesson_json(lesson) }
      end
      
      def show
        render json: lesson_json(@lesson, include_details: true)
      end
      
      def create
        @lesson = @diary.lessons.build(lesson_params)
        
        if @lesson.save
          render json: lesson_json(@lesson), status: :created
        else
          render json: { errors: @lesson.errors.full_messages }, 
                 status: :unprocessable_entity
        end
      end
      
      def update
        if @lesson.update(lesson_params)
          render json: lesson_json(@lesson)
        else
          render json: { errors: @lesson.errors.full_messages }, 
                 status: :unprocessable_entity
        end
      end
      
      def destroy
        if @lesson.destroy
          head :no_content
        else
          render json: { error: 'Não foi possível excluir a aula' }, 
                 status: :unprocessable_entity
        end
      end
      
      def attendances
        @lesson = Lesson.find(params[:id])
        attendances = @lesson.attendances.includes(:student)
        
        render json: attendances.map { |attendance| attendance_json(attendance) }
      end
      
      def update_attendances
        @lesson = Lesson.find(params[:id])
        
        Attendance.transaction do
          params[:attendances].each do |attendance_params|
            attendance = @lesson.attendances.find(attendance_params[:id])
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
      
      def complete_lesson
        @lesson = Lesson.find(params[:id])
        
        if @lesson.mark_as_completed!
          render json: { message: 'Aula marcada como concluída' }
        else
          render json: { errors: @lesson.errors.full_messages }, 
                 status: :unprocessable_entity
        end
      end
      
      def cancel_lesson
        @lesson = Lesson.find(params[:id])
        
        if @lesson.mark_as_cancelled!
          render json: { message: 'Aula cancelada' }
        else
          render json: { errors: @lesson.errors.full_messages }, 
                 status: :unprocessable_entity
        end
      end
      
      private
      
      def set_lesson
        @lesson = Lesson.find(params[:id])
      end
      
      def set_diary
        @diary = Diary.find(params[:diary_id])
      end
      
      def lesson_params
        params.require(:lesson).permit(:date, :topic, :content, :homework, 
                                      :duration_minutes, :status)
      end
      
      def lesson_json(lesson, include_details: false)
        data = {
          id: lesson.id,
          lessonNumber: lesson.lesson_number,
          date: lesson.date,
          topic: lesson.topic,
          content: lesson.content,
          homework: lesson.homework,
          durationMinutes: lesson.duration_minutes,
          status: lesson.status,
          diary: {
            id: lesson.diary.id,
            name: lesson.diary.name,
            subject: lesson.diary.subject.name,
            class: "#{lesson.diary.school_class.name} #{lesson.diary.school_class.section}"
          },
          attendanceSummary: lesson.attendance_summary
        }
        
        if include_details
          data[:attendances] = lesson.attendances.includes(:student).map do |attendance|
            attendance_json(attendance)
          end
          
          data[:grades] = lesson.grades.includes(:student).map do |grade|
            {
              id: grade.id,
              student: {
                id: grade.student.id,
                name: grade.student.name
              },
              value: grade.value,
              gradeType: grade.grade_type,
              date: grade.date,
              observation: grade.observation
            }
          end
          
          data[:occurrences] = lesson.occurrences.includes(:student).map do |occurrence|
            {
              id: occurrence.id,
              student: {
                id: occurrence.student.id,
                name: occurrence.student.name
              },
              title: occurrence.title,
              description: occurrence.description,
              occurrenceType: occurrence.occurrence_type,
              severity: occurrence.severity,
              date: occurrence.date
            }
          end
        end
        
        data
      end
      
      def attendance_json(attendance)
        {
          id: attendance.id,
          student: {
            id: attendance.student.id,
            name: attendance.student.name,
            registrationNumber: attendance.student.registration_number
          },
          status: attendance.status,
          observation: attendance.observation
        }
      end
    end
  end
end