module Api
  module V1
    class TeachersController < BaseController
      before_action :set_teacher, only: [:show, :update, :destroy]
      
      def index
        @teachers = Teacher.includes(:user)
        @teachers = @teachers.joins(:user).where("users.name ILIKE ?", "%#{params[:search]}%") if params[:search]
        
        render json: @teachers.map { |teacher| teacher_json(teacher) }
      end
      
      def show
        render json: teacher_json(@teacher, include_details: true)
      end
      
      def create
        user_attrs = params[:teacher][:user_attributes]&.permit(:name, :email, :phone, :cpf, :password) || {}
        teacher_attrs = params.require(:teacher).permit(:salary, :hire_date, :specialization, :status)
        
        User.transaction do
          @user = User.create!(user_attrs.merge(role: :teacher))
          @teacher = @user.create_teacher!(teacher_attrs)
        end
        
        render json: teacher_json(@teacher), status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, 
               status: :unprocessable_entity
      end
      
      def update
        user_attrs = params[:teacher][:user_attributes]&.permit(:name, :email, :phone, :cpf, :password) || {}
        teacher_attrs = params.require(:teacher).permit(:salary, :hire_date, :specialization, :status)
        
        User.transaction do
          @teacher.user.update!(user_attrs) if user_attrs.present?
          @teacher.update!(teacher_attrs) if teacher_attrs.present?
        end
        
        render json: teacher_json(@teacher)
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, 
               status: :unprocessable_entity
      end
      
      def destroy
        @teacher.user.destroy
        head :no_content
      end
      
      private
      
      def set_teacher
        @teacher = Teacher.find(params[:id])
      end
      
      def teacher_json(teacher, include_details: false)
        data = {
          id: teacher.id,
          user: {
            id: teacher.user.id,
            name: teacher.user.name,
            email: teacher.user.email,
            phone: teacher.user.phone,
            cpf: teacher.user.cpf,
            role: teacher.user.role
          },
          salary: teacher.salary,
          hireDate: teacher.hire_date,
          status: teacher.status,
          specialization: teacher.specialization
        }
        
        data
      end
    end
  end
end