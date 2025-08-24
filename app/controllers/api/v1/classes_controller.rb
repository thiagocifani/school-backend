module Api
  module V1
    class ClassesController < BaseController
      before_action :set_class, only: [:show, :update, :destroy]
      
      def index
        @classes = SchoolClass.includes(:grade_level, :academic_term, :main_teacher, :class_subjects)
        @classes = @classes.where(academic_term_id: params[:academic_term_id]) if params[:academic_term_id]
        @classes = @classes.where(period: params[:period]) if params[:period]
        
        render json: @classes.map { |school_class| class_json(school_class) }
      end
      
      def show
        render json: class_json(@class, include_details: true)
      end
      
      def create
        @class = SchoolClass.new(class_params.except(:class_subjects_attributes))
        
        SchoolClass.transaction do
          if @class.save
            create_class_subjects(params[:school_class][:class_subjects_attributes] || [])
            render json: class_json(@class), status: :created
          else
            render json: { errors: @class.errors.full_messages }, 
                   status: :unprocessable_entity
          end
        end
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, 
               status: :unprocessable_entity
      end
      
      def update
        SchoolClass.transaction do
          if @class.update(class_params.except(:class_subjects_attributes))
            @class.class_subjects.destroy_all
            create_class_subjects(params[:school_class][:class_subjects_attributes] || [])
            render json: class_json(@class)
          else
            render json: { errors: @class.errors.full_messages }, 
                   status: :unprocessable_entity
          end
        end
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, 
               status: :unprocessable_entity
      end
      
      def destroy
        if @class.students.exists?
          render json: { error: 'Cannot delete class with enrolled students' }, 
                 status: :unprocessable_entity
        elsif @class.destroy
          head :no_content
        else
          render json: { error: 'Cannot delete class' }, 
                 status: :unprocessable_entity
        end
      end
      
      private
      
      def set_class
        @class = SchoolClass.find(params[:id])
      end
      
      def class_params
        params.require(:school_class).permit(
          :name, :section, :grade_level_id, :academic_term_id, 
          :main_teacher_id, :max_students, :period
        )
      end
      
      def create_class_subjects(subjects_attributes)
        return unless subjects_attributes.is_a?(Array)
        
        subjects_attributes.each do |subject_attrs|
          next if subject_attrs['subject_id'].blank? || subject_attrs['teacher_id'].blank?
          
          @class.class_subjects.create!(
            subject_id: subject_attrs['subject_id'],
            teacher_id: subject_attrs['teacher_id'],
            weekly_hours: subject_attrs['weekly_hours'] || 2
          )
        end
      end
      
      def class_json(school_class, include_details: false)
        data = {
          id: school_class.id,
          name: school_class.name,
          section: school_class.section,
          maxStudents: school_class.max_students,
          studentsCount: school_class.students.count,
          period: school_class.period
        }
        
        if school_class.grade_level
          data[:gradeLevel] = {
            id: school_class.grade_level.id,
            name: school_class.grade_level.name,
            order: school_class.grade_level.order,
            educationLevel: {
              id: school_class.grade_level.education_level.id,
              name: school_class.grade_level.education_level.name
            }
          }
        end
        
        if school_class.academic_term
          data[:academicTerm] = {
            id: school_class.academic_term.id,
            name: school_class.academic_term.name,
            termType: school_class.academic_term.term_type,
            year: school_class.academic_term.year
          }
        end
        
        if school_class.main_teacher
          data[:mainTeacher] = {
            id: school_class.main_teacher.id,
            user: {
              id: school_class.main_teacher.user.id,
              name: school_class.main_teacher.user.name,
              email: school_class.main_teacher.user.email
            }
          }
        end
        
        if school_class.class_subjects.any?
          data[:subjects] = school_class.class_subjects.includes(:subject, :teacher).map do |cs|
            {
              id: cs.id,
              weeklyHours: cs.weekly_hours,
              subject: {
                id: cs.subject.id,
                name: cs.subject.name,
                code: cs.subject.code
              },
              teacher: {
                id: cs.teacher.id,
                user: {
                  id: cs.teacher.user.id,
                  name: cs.teacher.user.name
                }
              }
            }
          end
        end
        
        if include_details
          data[:students] = school_class.students.map do |student|
            {
              id: student.id,
              name: student.name,
              registrationNumber: student.registration_number,
              status: student.status
            }
          end
        end
        
        data
      end
    end
  end
end