module Api
  module V1
    module Admin
      class UsersController < BaseController
        before_action :set_user, only: [:show, :update, :destroy, :change_role, :reset_password]
        
        def index
          @users = User.all
          @users = @users.where(role: params[:role]) if params[:role].present?
          @users = @users.where('name ILIKE ? OR email ILIKE ?', "%#{params[:search]}%", "%#{params[:search]}%") if params[:search].present?
          
          @users = @users.page(params[:page]).per(params[:per_page] || 20)
          
          render json: {
            users: @users.map { |user| user_data(user) },
            meta: {
              current_page: @users.current_page,
              next_page: @users.next_page,
              prev_page: @users.prev_page,
              total_pages: @users.total_pages,
              total_count: @users.total_count
            }
          }
        end
        
        def show
          render json: { user: detailed_user_data(@user) }
        end
        
        def create
          @user = User.new(user_params)
          @user.password = params[:password] || '123456'
          @user.password_confirmation = @user.password
          
          if @user.save
            render json: { 
              user: detailed_user_data(@user),
              message: 'Usuário criado com sucesso!'
            }, status: :created
          else
            render json: { 
              errors: @user.errors.full_messages 
            }, status: :unprocessable_entity
          end
        end
        
        def update
          if @user.update(user_params)
            render json: { 
              user: detailed_user_data(@user),
              message: 'Usuário atualizado com sucesso!'
            }
          else
            render json: { 
              errors: @user.errors.full_messages 
            }, status: :unprocessable_entity
          end
        end
        
        def destroy
          if @user.id == current_user.id
            render json: { error: 'Você não pode excluir sua própria conta' }, status: :forbidden
            return
          end
          
          @user.destroy
          render json: { message: 'Usuário excluído com sucesso!' }
        end
        
        def change_role
          if @user.id == current_user.id && params[:role] != 'admin'
            render json: { error: 'Você não pode alterar seu próprio nível de acesso' }, status: :forbidden
            return
          end
          
          if @user.update(role: params[:role])
            render json: { 
              user: detailed_user_data(@user),
              message: 'Nível de acesso alterado com sucesso!'
            }
          else
            render json: { 
              errors: @user.errors.full_messages 
            }, status: :unprocessable_entity
          end
        end
        
        def reset_password
          new_password = params[:password] || generate_random_password
          
          if @user.update(password: new_password, password_confirmation: new_password)
            render json: { 
              message: 'Senha redefinida com sucesso!',
              new_password: new_password
            }
          else
            render json: { 
              errors: @user.errors.full_messages 
            }, status: :unprocessable_entity
          end
        end
        
        private
        
        def set_user
          @user = User.find(params[:id])
        end
        
        def user_params
          params.require(:user).permit(:name, :email, :phone, :cpf, :role)
        end
        
        def user_data(user)
          {
            id: user.id,
            name: user.name,
            email: user.email,
            phone: user.phone,
            cpf: user.cpf,
            role: user.role,
            created_at: user.created_at,
            updated_at: user.updated_at,
            last_sign_in_at: user.respond_to?(:last_sign_in_at) ? user.last_sign_in_at : nil
          }
        end
        
        def detailed_user_data(user)
          data = user_data(user)
          
          case user.role
          when 'teacher'
            if user.teacher
              data[:teacher_info] = {
                id: user.teacher.id,
                salary: user.teacher.salary,
                hire_date: user.teacher.hire_date
              }
            end
          when 'guardian'
            if user.guardian
              data[:guardian_info] = {
                id: user.guardian.id,
                address: user.guardian.address,
                emergency_phone: user.guardian.emergency_phone,
                students_count: user.guardian.students.count
              }
            end
          end
          
          data
        end
        
        def generate_random_password
          SecureRandom.alphanumeric(8)
        end
      end
    end
  end
end