require 'csv'

module Api
  module V1
    module Admin
      class StudentsController < BaseController
        before_action :set_student, only: [:show, :update, :destroy, :report]
        
        def index
          @students = Student.includes(:school_class, :guardians)
          @students = @students.where(school_class_id: params[:class_id]) if params[:class_id].present?
          @students = @students.where(status: params[:status]) if params[:status].present?
          @students = @students.where('name ILIKE ?', "%#{params[:search]}%") if params[:search].present?
          
          @students = @students.page(params[:page]).per(params[:per_page] || 20)
          
          render json: {
            students: @students.map { |student| student_data(student) },
            meta: {
              current_page: @students.current_page,
              next_page: @students.next_page,
              prev_page: @students.prev_page,
              total_pages: @students.total_pages,
              total_count: @students.total_count
            }
          }
        end
        
        def show
          render json: { student: detailed_student_data(@student) }
        end
        
        def create
          @student = Student.new(student_params)
          
          if @student.save
            render json: { 
              student: detailed_student_data(@student),
              message: 'Aluno criado com sucesso!'
            }, status: :created
          else
            render json: { 
              errors: @student.errors.full_messages 
            }, status: :unprocessable_entity
          end
        end
        
        def update
          if @student.update(student_params)
            render json: { 
              student: detailed_student_data(@student),
              message: 'Aluno atualizado com sucesso!'
            }
          else
            render json: { 
              errors: @student.errors.full_messages 
            }, status: :unprocessable_entity
          end
        end
        
        def destroy
          @student.destroy
          render json: { message: 'Aluno excluído com sucesso!' }
        end
        
        def report
          @term = AcademicTerm.find(params[:term_id]) if params[:term_id]
          @term ||= AcademicTerm.where(active: true).first
          
          report_data = ReportGenerator.new(@student, @term).generate_student_report
          
          respond_to do |format|
            format.json { render json: report_data }
            format.pdf do
              pdf = PdfExporter.new.export_student_report(report_data)
              send_data pdf, 
                        filename: "boletim_#{@student.name.parameterize}.pdf",
                        type: 'application/pdf'
            end
          end
        end
        
        def bulk_import
          # TODO: Implement CSV/Excel import functionality
          render json: { message: 'Funcionalidade em desenvolvimento' }
        end
        
        def export
          @students = Student.includes(:school_class, :guardians)
          @students = @students.where(school_class_id: params[:class_id]) if params[:class_id].present?
          
          respond_to do |format|
            format.csv do
              csv_data = generate_csv(@students)
              send_data csv_data, 
                        filename: "alunos_#{Date.current.strftime('%Y%m%d')}.csv",
                        type: 'text/csv'
            end
            format.json do
              render json: {
                students: @students.map { |student| detailed_student_data(student) }
              }
            end
          end
        end
        
        private
        
        def set_student
          @student = Student.find(params[:id])
        end
        
        def student_params
          params.require(:student).permit(
            :name, :birth_date, :registration_number, :status, :school_class_id,
            :cpf, :gender, :birth_place,
            guardians_attributes: [
              :id, :name, :email, :phone, :cpf, :birth_date, :rg, :profession,
              :marital_status, :address, :neighborhood, :complement, :zip_code,
              :emergency_phone, :relationship, :_destroy
            ]
          )
        end
        
        def student_data(student)
          {
            id: student.id,
            name: student.name,
            birth_date: student.birth_date,
            age: student.age,
            registration_number: student.registration_number,
            status: student.status,
            cpf: student.cpf,
            gender: student.gender,
            birth_place: student.birth_place,
            school_class: student.school_class ? {
              id: student.school_class.id,
              name: student.school_class.name
            } : nil,
            guardians_count: student.guardians.count,
            created_at: student.created_at,
            updated_at: student.updated_at
          }
        end
        
        def detailed_student_data(student)
          student_data(student).merge(
            guardians: student.guardians.map do |guardian|
              guardian_student = guardian.guardian_students.find_by(student: student)
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
                relationship: guardian_student&.relationship
              }
            end,
            grades: student.grades.includes(:class_subject).map do |grade|
              {
                id: grade.id,
                value: grade.value,
                grade_type: grade.grade_type,
                date: grade.date,
                subject: grade.class_subject.subject.name
              }
            end,
            attendance_stats: calculate_attendance_stats(student),
            occurrences_count: student.occurrences.count
          )
        end
        
        def calculate_attendance_stats(student)
          total = student.attendances.count
          present = student.attendances.where(status: 'present').count
          
          {
            total_classes: total,
            present: present,
            absent: total - present,
            percentage: total > 0 ? (present.to_f / total * 100).round(2) : 0
          }
        end
        
        def generate_csv(students)
          CSV.generate(headers: true) do |csv|
            csv << [
              'ID', 'Nome', 'Matrícula', 'CPF', 'Data Nascimento', 'Idade',
              'Gênero', 'Local Nascimento', 'Status', 'Turma',
              'Responsáveis', 'Email Responsável', 'Telefone Responsável'
            ]
            
            students.each do |student|
              guardian = student.guardians.first
              csv << [
                student.id,
                student.name,
                student.registration_number,
                student.cpf,
                student.birth_date,
                student.age,
                student.gender,
                student.birth_place,
                student.status,
                student.school_class&.name,
                guardian&.user&.name,
                guardian&.user&.email,
                guardian&.user&.phone
              ]
            end
          end
        end
      end
    end
  end
end