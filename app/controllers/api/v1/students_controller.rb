module Api
  module V1
    class StudentsController < BaseController
      before_action :set_student, only: [:show, :update, :destroy]

      def index
        @students = Student.includes(:school_class, :guardians)
        @students = @students.where(school_class_id: params[:class_id]) if params[:class_id]
        @students = @students.where("name ILIKE ?", "%#{params[:search]}%") if params[:search]

        render json: @students.map { |student| student_data(student) }
      end

      def show
        render json: student_data(@student, include_details: true)
      end

      def create
        @student = Student.new(student_params)

        if @student.save
          render json: student_data(@student), status: :created
        else
          render json: {errors: @student.errors.full_messages},
            status: :unprocessable_entity
        end
      end

      def update
        if @student.update(student_params)
          render json: student_data(@student)
        else
          render json: {errors: @student.errors.full_messages},
            status: :unprocessable_entity
        end
      end

      def destroy
        @student.destroy
        head :no_content
      end

      private

      def set_student
        @student = Student.find(params[:id])
      end

      def student_params
        params.require(:student).permit(:name, :birth_date, :registration_number,
          :status, :school_class_id, :cpf, :gender, :birth_place,
          :has_sibling_enrolled, :sibling_name,
          :has_specialist_monitoring, :specialist_details,
          :has_medication_allergy, :medication_allergy_details,
          :has_food_allergy, :food_allergy_details,
          :has_medical_treatment, :medical_treatment_details,
          :uses_specific_medication, :specific_medication_details,
          guardians_attributes: [:id, :name, :email, :phone, :cpf, :birth_date, :rg, 
            :profession, :marital_status, :address, :neighborhood, :complement, 
            :zip_code, :emergency_phone, :relationship, :_destroy])
      end

      def student_data(student, include_details: false)
        data = {
          id: student.id,
          name: student.name,
          birth_date: student.birth_date,
          registration_number: student.registration_number,
          status: student.status,
          cpf: student.cpf,
          gender: student.gender,
          birth_place: student.birth_place,
          age: student.age,
          # Medical and family info
          has_sibling_enrolled: student.has_sibling_enrolled,
          sibling_name: student.sibling_name,
          has_specialist_monitoring: student.has_specialist_monitoring,
          specialist_details: student.specialist_details,
          has_medication_allergy: student.has_medication_allergy,
          medication_allergy_details: student.medication_allergy_details,
          has_food_allergy: student.has_food_allergy,
          food_allergy_details: student.food_allergy_details,
          has_medical_treatment: student.has_medical_treatment,
          medical_treatment_details: student.medical_treatment_details,
          uses_specific_medication: student.uses_specific_medication,
          specific_medication_details: student.specific_medication_details,
          school_class: student.school_class ? {
            id: student.school_class.id,
            name: student.school_class.full_name
          } : nil,
          guardians: student.guardians.map do |guardian|
            {
              id: guardian.id,
              name: guardian.name,
              email: guardian.email,
              phone: guardian.phone,
              cpf: guardian.cpf,
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
              relationship: guardian.guardian_students.find_by(student: student)&.relationship
            }
          end
        }

        if include_details
          data.merge!(
            recent_grades: student.grades.includes(:class_subject, :academic_term)
                                 .order(created_at: :desc).limit(10)
                                 .map { |grade| grade_data(grade) },
            attendance_summary: attendance_summary(student),
            recent_occurrences: student.occurrences.includes(:teacher)
                                      .order(created_at: :desc).limit(5)
                                      .map { |occurrence| occurrence_data(occurrence) }
          )
        end

        data
      end

      def grade_data(grade)
        {
          id: grade.id,
          value: grade.value,
          grade_type: grade.grade_type,
          date: grade.date,
          subject: grade.subject.name,
          term: grade.academic_term.name
        }
      end

      def occurrence_data(occurrence)
        {
          id: occurrence.id,
          date: occurrence.date,
          type: occurrence.occurrence_type,
          title: occurrence.title,
          severity: occurrence.severity,
          teacher: occurrence.teacher.name
        }
      end

      def attendance_summary(student)
        current_term = AcademicTerm.active.first
        return {} unless current_term

        attendances = student.attendances.for_period(current_term.start_date, current_term.end_date)
        total = attendances.count
        present = attendances.present.count

        {
          total_classes: total,
          present: present,
          absent: total - present,
          percentage: (total > 0) ? (present.to_f / total * 100).round(2) : 0
        }
      end
    end
  end
end

