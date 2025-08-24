module Api
  module V1
    class SubjectsController < BaseController
      before_action :set_subject, only: [:show, :update, :destroy]
      
      def index
        @subjects = Subject.order(:name)
        render json: @subjects.map { |subject| subject_json(subject) }
      end
      
      def show
        render json: subject_json(@subject)
      end
      
      def create
        @subject = Subject.new(subject_params)
        
        if @subject.save
          render json: subject_json(@subject), status: :created
        else
          render json: { errors: @subject.errors.full_messages }, 
                 status: :unprocessable_entity
        end
      end
      
      def update
        if @subject.update(subject_params)
          render json: subject_json(@subject)
        else
          render json: { errors: @subject.errors.full_messages }, 
                 status: :unprocessable_entity
        end
      end
      
      def destroy
        if @subject.class_subjects.exists?
          render json: { error: 'Cannot delete subject with associated classes' }, 
                 status: :unprocessable_entity
        elsif @subject.destroy
          head :no_content
        else
          render json: { error: 'Cannot delete subject' }, 
                 status: :unprocessable_entity
        end
      end
      
      private
      
      def set_subject
        @subject = Subject.find(params[:id])
      end
      
      def subject_params
        params.require(:subject).permit(:name, :code, :description, :workload)
      end
      
      def subject_json(subject)
        {
          id: subject.id,
          name: subject.name,
          code: subject.code,
          description: subject.description,
          workload: subject.workload
        }
      end
    end
  end
end