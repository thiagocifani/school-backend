module Api
  module V1
    class EducationLevelsController < BaseController
      before_action :set_education_level, only: [:show, :update, :destroy]
      
      def index
        @education_levels = EducationLevel.order(:name)
        render json: @education_levels.map { |level| education_level_json(level) }
      end
      
      def show
        render json: education_level_json(@education_level)
      end
      
      def create
        @education_level = EducationLevel.new(education_level_params)
        
        if @education_level.save
          render json: education_level_json(@education_level), status: :created
        else
          render json: { errors: @education_level.errors.full_messages }, 
                 status: :unprocessable_entity
        end
      end
      
      def update
        if @education_level.update(education_level_params)
          render json: education_level_json(@education_level)
        else
          render json: { errors: @education_level.errors.full_messages }, 
                 status: :unprocessable_entity
        end
      end
      
      def destroy
        if @education_level.grade_levels.exists?
          render json: { error: 'Cannot delete education level with associated grade levels' }, 
                 status: :unprocessable_entity
        elsif @education_level.destroy
          head :no_content
        else
          render json: { error: 'Cannot delete education level' }, 
                 status: :unprocessable_entity
        end
      end
      
      private
      
      def set_education_level
        @education_level = EducationLevel.find(params[:id])
      end
      
      def education_level_params
        params.require(:education_level).permit(:name, :description, :age_range)
      end
      
      def education_level_json(level)
        {
          id: level.id,
          name: level.name,
          description: level.description,
          ageRange: level.age_range
        }
      end
    end
  end
end