module Api
  module V1
    class GradeLevelsController < BaseController
      before_action :set_grade_level, only: [:show, :update, :destroy]
      
      def index
        @grade_levels = GradeLevel.includes(:education_level).order(:education_level_id, :order)
        @grade_levels = @grade_levels.where(education_level_id: params[:education_level_id]) if params[:education_level_id]
        
        render json: @grade_levels.map { |grade| grade_level_json(grade) }
      end
      
      def show
        render json: grade_level_json(@grade_level)
      end
      
      def create
        @grade_level = GradeLevel.new(grade_level_params)
        
        if @grade_level.save
          render json: grade_level_json(@grade_level), status: :created
        else
          render json: { errors: @grade_level.errors.full_messages }, 
                 status: :unprocessable_entity
        end
      end
      
      def update
        if @grade_level.update(grade_level_params)
          render json: grade_level_json(@grade_level)
        else
          render json: { errors: @grade_level.errors.full_messages }, 
                 status: :unprocessable_entity
        end
      end
      
      def destroy
        if @grade_level.school_classes.exists?
          render json: { error: 'Cannot delete grade level with associated classes' }, 
                 status: :unprocessable_entity
        elsif @grade_level.destroy
          head :no_content
        else
          render json: { error: 'Cannot delete grade level' }, 
                 status: :unprocessable_entity
        end
      end
      
      private
      
      def set_grade_level
        @grade_level = GradeLevel.find(params[:id])
      end
      
      def grade_level_params
        params.require(:grade_level).permit(:name, :education_level_id, :order)
      end
      
      def grade_level_json(grade)
        {
          id: grade.id,
          name: grade.name,
          order: grade.order,
          educationLevel: {
            id: grade.education_level.id,
            name: grade.education_level.name,
            description: grade.education_level.description,
            ageRange: grade.education_level.age_range
          }
        }
      end
    end
  end
end