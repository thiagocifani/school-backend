module Api
  module V1
    class GradesController < BaseController
      before_action :set_grade, only: [:show, :update, :destroy]
      before_action :set_diary, only: [:index, :create]
      
      def index
        if @diary
          @grades = @diary.grades.includes(:student, :lesson, :academic_term)
        else
          @grades = Grade.includes(:student, :lesson, :academic_term, :diary)
          @grades = @grades.where(student_id: params[:student_id]) if params[:student_id]
          @grades = @grades.where(academic_term_id: params[:academic_term_id]) if params[:academic_term_id]
        end
        
        render json: @grades.map { |grade| grade_json(grade) }
      end
      
      def show
        render json: grade_json(@grade)
      end
      
      def create
        @grade = Grade.new(grade_params)
        @grade.diary = @diary if @diary
        
        if @grade.save
          render json: grade_json(@grade), status: :created
        else
          render json: { errors: @grade.errors.full_messages }, 
                 status: :unprocessable_entity
        end
      end
      
      def update
        if @grade.update(grade_params)
          render json: grade_json(@grade)
        else
          render json: { errors: @grade.errors.full_messages }, 
                 status: :unprocessable_entity
        end
      end
      
      def destroy
        @grade.destroy
        head :no_content
      end
      
      def bulk_create
        ActiveRecord::Base.transaction do
          grades = params[:grades].map do |grade_data|
            grade = Grade.new(grade_data.permit(:student_id, :diary_id, :lesson_id, :academic_term_id, :value, :grade_type, :date, :observation))
            grade.save!
            grade
          end
          
          render json: grades.map { |grade| grade_json(grade) }, status: :created
        end
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.message }, status: :unprocessable_entity
      end
      
      private
      
      def set_grade
        @grade = Grade.find(params[:id])
      end
      
      def set_diary
        @diary = Diary.find(params[:diary_id]) if params[:diary_id]
      end
      
      def grade_params
        params.require(:grade).permit(:student_id, :diary_id, :lesson_id, :academic_term_id, 
                                     :value, :grade_type, :date, :observation)
      end
      
      def grade_json(grade)
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
              id: grade.diary.subject.id,
              name: grade.diary.subject.name,
              code: grade.diary.subject.code
            }
          } : nil,
          lesson: grade.lesson ? {
            id: grade.lesson.id,
            lessonNumber: grade.lesson.lesson_number,
            topic: grade.lesson.topic,
            date: grade.lesson.date
          } : nil,
          academicTerm: {
            id: grade.academic_term.id,
            name: grade.academic_term.name,
            year: grade.academic_term.year
          },
          value: grade.value,
          gradeType: grade.grade_type,
          date: grade.date,
          observation: grade.observation,
          createdAt: grade.created_at,
          updatedAt: grade.updated_at
        }
      end
    end
  end
end