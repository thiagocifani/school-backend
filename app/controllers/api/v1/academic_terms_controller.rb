module Api
  module V1
    class AcademicTermsController < BaseController
      before_action :set_academic_term, only: [:show, :update, :destroy, :set_active]
      
      def index
        @academic_terms = AcademicTerm.order(:year, :start_date)
        render json: @academic_terms.map { |term| academic_term_json(term) }
      end
      
      def show
        render json: academic_term_json(@academic_term)
      end
      
      def create
        @academic_term = AcademicTerm.new(academic_term_params)
        
        if @academic_term.save
          render json: academic_term_json(@academic_term), status: :created
        else
          render json: { errors: @academic_term.errors.full_messages }, 
                 status: :unprocessable_entity
        end
      end
      
      def update
        if @academic_term.update(academic_term_params)
          render json: academic_term_json(@academic_term)
        else
          render json: { errors: @academic_term.errors.full_messages }, 
                 status: :unprocessable_entity
        end
      end
      
      def destroy
        if @academic_term.active?
          render json: { error: 'Cannot delete active academic term' }, 
                 status: :unprocessable_entity
        elsif @academic_term.destroy
          head :no_content
        else
          render json: { error: 'Cannot delete academic term' }, 
                 status: :unprocessable_entity
        end
      end
      
      def set_active
        AcademicTerm.transaction do
          AcademicTerm.update_all(active: false)
          @academic_term.update!(active: true)
        end
        
        render json: academic_term_json(@academic_term)
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, 
               status: :unprocessable_entity
      end
      
      private
      
      def set_academic_term
        @academic_term = AcademicTerm.find(params[:id])
      end
      
      def academic_term_params
        params.require(:academic_term).permit(:name, :start_date, :end_date, :term_type, :year, :active)
      end
      
      def academic_term_json(term)
        {
          id: term.id,
          name: term.name,
          startDate: term.start_date,
          endDate: term.end_date,
          termType: term.term_type,
          year: term.year,
          active: term.active
        }
      end
    end
  end
end