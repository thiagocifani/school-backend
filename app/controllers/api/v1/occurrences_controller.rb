module Api
  module V1
    class OccurrencesController < BaseController
      before_action :set_occurrence, only: [:show, :update, :destroy]
      before_action :set_diary, only: [:index, :create]
      
      def index
        if @diary
          @occurrences = @diary.occurrences.includes(:student, :teacher, :lesson)
        else
          @occurrences = Occurrence.includes(:student, :teacher, :diary, :lesson)
          @occurrences = @occurrences.where(student_id: params[:student_id]) if params[:student_id]
          @occurrences = @occurrences.where(teacher_id: params[:teacher_id]) if params[:teacher_id]
          @occurrences = @occurrences.where(occurrence_type: params[:occurrence_type]) if params[:occurrence_type]
        end
        
        @occurrences = @occurrences.order(date: :desc)
        
        render json: @occurrences.map { |occurrence| occurrence_json(occurrence) }
      end
      
      def show
        render json: occurrence_json(@occurrence)
      end
      
      def create
        @occurrence = Occurrence.new(occurrence_params)
        @occurrence.diary = @diary if @diary
        @occurrence.teacher = current_user.teacher if current_user.teacher?
        
        if @occurrence.save
          render json: occurrence_json(@occurrence), status: :created
        else
          render json: { errors: @occurrence.errors.full_messages }, 
                 status: :unprocessable_entity
        end
      end
      
      def update
        if @occurrence.update(occurrence_params)
          render json: occurrence_json(@occurrence)
        else
          render json: { errors: @occurrence.errors.full_messages }, 
                 status: :unprocessable_entity
        end
      end
      
      def destroy
        @occurrence.destroy
        head :no_content
      end
      
      private
      
      def set_occurrence
        @occurrence = Occurrence.find(params[:id])
      end
      
      def set_diary
        @diary = Diary.find(params[:diary_id]) if params[:diary_id]
      end
      
      def occurrence_params
        params.require(:occurrence).permit(:student_id, :teacher_id, :diary_id, :lesson_id, 
                                          :date, :occurrence_type, :title, :description, 
                                          :severity, :notified_guardians)
      end
      
      def occurrence_json(occurrence)
        {
          id: occurrence.id,
          student: {
            id: occurrence.student.id,
            name: occurrence.student.name,
            registrationNumber: occurrence.student.registration_number
          },
          teacher: {
            id: occurrence.teacher.id,
            name: occurrence.teacher.name
          },
          diary: occurrence.diary ? {
            id: occurrence.diary.id,
            name: occurrence.diary.name,
            subject: {
              id: occurrence.diary.subject.id,
              name: occurrence.diary.subject.name
            }
          } : nil,
          lesson: occurrence.lesson ? {
            id: occurrence.lesson.id,
            lessonNumber: occurrence.lesson.lesson_number,
            topic: occurrence.lesson.topic,
            date: occurrence.lesson.date
          } : nil,
          date: occurrence.date,
          occurrenceType: occurrence.occurrence_type,
          title: occurrence.title,
          description: occurrence.description,
          severity: occurrence.severity,
          notifiedGuardians: occurrence.notified_guardians,
          createdAt: occurrence.created_at,
          updatedAt: occurrence.updated_at
        }
      end
    end
  end
end