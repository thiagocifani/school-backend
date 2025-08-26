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
          hire_date: teacher.hire_date,
          status: teacher.status,
          specialization: teacher.specialization
        }
        
        if include_details
          # Turmas onde o professor é professor principal
          main_classes = teacher.school_classes.includes(:grade_level, :students)
          
          # Turmas onde o professor leciona matérias (através de class_subjects)
          subject_classes = SchoolClass.joins(:class_subjects)
                                      .where(class_subjects: { teacher: teacher })
                                      .includes(:grade_level, :students)
                                      .distinct
          
          # Combinar e remover duplicatas
          all_classes = (main_classes + subject_classes).uniq
          
          data[:classes] = all_classes.map do |school_class|
            {
              id: school_class.id,
              name: school_class.name,
              section: school_class.section,
              period: school_class.period,
              max_students: school_class.max_students,
              students_count: school_class.students.count,
              grade_level: school_class.grade_level ? {
                name: school_class.grade_level.name,
                education_level: {
                  name: school_class.grade_level.education_level&.name
                }
              } : nil,
              role: main_classes.include?(school_class) ? 'main_teacher' : 'subject_teacher'
            }
          end
          
          # Matérias que o professor leciona
          data[:subjects] = teacher.class_subjects.includes(:subject, :school_class).map do |class_subject|
            {
              id: class_subject.subject.id,
              name: class_subject.subject.name,
              weekly_hours: class_subject.weekly_hours,
              school_class: {
                id: class_subject.school_class.id,
                name: class_subject.school_class.name,
                grade_level: class_subject.school_class.grade_level ? {
                  name: class_subject.school_class.grade_level.name
                } : nil
              }
            }
          end
        end
        
        data
      end
    end
  end
end