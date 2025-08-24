module Api
  module V1
    module Admin
      class GuardiansController < BaseController
        before_action :set_guardian, only: [:show, :update, :destroy, :students]
        
        def index
          @guardians = Guardian.includes(:user, :students)
          @guardians = @guardians.joins(:user).where('users.name ILIKE ?', "%#{params[:search]}%") if params[:search].present?
          @guardians = @guardians.joins(:user).where('users.email ILIKE ?', "%#{params[:email]}%") if params[:email].present?
          
          @guardians = @guardians.page(params[:page]).per(params[:per_page] || 20)
          
          render json: {
            guardians: @guardians.map { |guardian| guardian_data(guardian) },
            meta: {
              current_page: @guardians.current_page,
              next_page: @guardians.next_page,
              prev_page: @guardians.prev_page,
              total_pages: @guardians.total_pages,
              total_count: @guardians.total_count
            }
          }
        end
        
        def show
          render json: { guardian: detailed_guardian_data(@guardian) }
        end
        
        def create
          ActiveRecord::Base.transaction do
            # Create user first
            @user = User.new(user_params)
            @user.role = 'guardian'
            @user.password = params[:password] || '123456'
            @user.password_confirmation = @user.password
            
            if @user.save
              # Create guardian
              @guardian = Guardian.new(guardian_params)
              @guardian.user = @user
              
              if @guardian.save
                render json: { 
                  guardian: detailed_guardian_data(@guardian),
                  message: 'Responsável criado com sucesso!'
                }, status: :created
              else
                render json: { 
                  errors: @guardian.errors.full_messages 
                }, status: :unprocessable_entity
              end
            else
              render json: { 
                errors: @user.errors.full_messages 
              }, status: :unprocessable_entity
            end
          end
        end
        
        def update
          ActiveRecord::Base.transaction do
            if @guardian.user.update(user_params) && @guardian.update(guardian_params)
              render json: { 
                guardian: detailed_guardian_data(@guardian),
                message: 'Responsável atualizado com sucesso!'
              }
            else
              errors = @guardian.errors.full_messages + @guardian.user.errors.full_messages
              render json: { 
                errors: errors 
              }, status: :unprocessable_entity
            end
          end
        end
        
        def destroy
          @guardian.user.destroy # This will cascade delete guardian due to dependent: :destroy
          render json: { message: 'Responsável excluído com sucesso!' }
        end
        
        def students
          render json: {
            guardian: guardian_data(@guardian),
            students: @guardian.students.map do |student|
              guardian_student = @guardian.guardian_students.find_by(student: student)
              {
                id: student.id,
                name: student.name,
                registration_number: student.registration_number,
                school_class: student.school_class&.name,
                relationship: guardian_student&.relationship,
                status: student.status
              }
            end
          }
        end
        
        private
        
        def set_guardian
          @guardian = Guardian.find(params[:id])
        end
        
        def user_params
          params.require(:guardian).permit(:name, :email, :phone, :cpf)
        end
        
        def guardian_params
          params.require(:guardian).permit(
            :birth_date, :rg, :profession, :marital_status,
            :address, :neighborhood, :complement, :zip_code, :emergency_phone
          )
        end
        
        def guardian_data(guardian)
          {
            id: guardian.id,
            name: guardian.user.name,
            email: guardian.user.email,
            phone: guardian.user.phone,
            cpf: guardian.user.cpf,
            birth_date: guardian.birth_date,
            age: guardian.age,
            rg: guardian.rg,
            profession: guardian.profession,
            marital_status: guardian.marital_status,
            address: guardian.address,
            neighborhood: guardian.neighborhood,
            complement: guardian.complement,
            zip_code: guardian.zip_code,
            emergency_phone: guardian.emergency_phone,
            students_count: guardian.students.count,
            created_at: guardian.created_at,
            updated_at: guardian.updated_at
          }
        end
        
        def detailed_guardian_data(guardian)
          guardian_data(guardian).merge(
            students: guardian.students.map do |student|
              guardian_student = guardian.guardian_students.find_by(student: student)
              {
                id: student.id,
                name: student.name,
                registration_number: student.registration_number,
                school_class: student.school_class ? {
                  id: student.school_class.id,
                  name: student.school_class.name
                } : nil,
                relationship: guardian_student&.relationship,
                status: student.status
              }
            end
          )
        end
      end
    end
  end
end