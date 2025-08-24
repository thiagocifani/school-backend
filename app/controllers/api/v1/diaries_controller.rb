module Api
  module V1
    class DiariesController < BaseController
      before_action :set_diary, only: [:show, :update, :destroy]
      
      def index
        @diaries = Diary.includes(:teacher, :school_class, :subject, :academic_term, :lessons)
        @diaries = @diaries.where(teacher: current_user.teacher) if current_user.teacher?
        @diaries = @diaries.where(academic_term_id: params[:academic_term_id]) if params[:academic_term_id]
        @diaries = @diaries.where(status: params[:status]) if params[:status]
        
        render json: @diaries.map { |diary| diary_json(diary) }
      end
      
      def show
        render json: diary_json(@diary, include_details: true)
      end
      
      def create
        @diary = Diary.new(diary_params)
        
        if @diary.save
          render json: diary_json(@diary), status: :created
        else
          render json: { errors: @diary.errors.full_messages }, 
                 status: :unprocessable_entity
        end
      end
      
      def update
        if @diary.update(diary_params)
          render json: diary_json(@diary)
        else
          render json: { errors: @diary.errors.full_messages }, 
                 status: :unprocessable_entity
        end
      end
      
      def destroy
        if @diary.lessons.exists?
          render json: { error: 'Não é possível excluir diário com aulas cadastradas' }, 
                 status: :unprocessable_entity
        elsif @diary.destroy
          head :no_content
        else
          render json: { error: 'Não foi possível excluir o diário' }, 
                 status: :unprocessable_entity
        end
      end
      
      def students
        @diary = Diary.find(params[:id])
        students = @diary.students.includes(:guardians)
        
        render json: students.map { |student| student_summary_json(student, @diary) }
      end
      
      def statistics
        @diary = Diary.find(params[:id])
        
        stats = {
          totalLessons: @diary.total_lessons,
          completedLessons: @diary.completed_lessons,
          plannedLessons: @diary.planned_lessons,
          progressPercentage: @diary.progress_percentage,
          totalStudents: @diary.students.count,
          averageAttendance: calculate_average_attendance(@diary),
          gradesCount: @diary.grades.count,
          occurrencesCount: @diary.occurrences.count
        }
        
        render json: stats
      end
      
      private
      
      def set_diary
        @diary = Diary.find(params[:id])
      end
      
      def diary_params
        params.require(:diary).permit(:teacher_id, :school_class_id, :subject_id, 
                                     :academic_term_id, :name, :description, :status)
      end
      
      def diary_json(diary, include_details: false)
        data = {
          id: diary.id,
          name: diary.name,
          description: diary.description,
          status: diary.status,
          teacher: {
            id: diary.teacher.id,
            name: diary.teacher.name,
            email: diary.teacher.email
          },
          schoolClass: {
            id: diary.school_class.id,
            name: diary.school_class.name,
            section: diary.school_class.section
          },
          subject: {
            id: diary.subject.id,
            name: diary.subject.name,
            code: diary.subject.code
          },
          academicTerm: {
            id: diary.academic_term.id,
            name: diary.academic_term.name,
            year: diary.academic_term.year
          },
          totalLessons: diary.total_lessons,
          completedLessons: diary.completed_lessons,
          progressPercentage: diary.progress_percentage,
          studentsCount: diary.students.count
        }
        
        if include_details
          data[:lessons] = diary.lessons.order(:lesson_number).map do |lesson|
            {
              id: lesson.id,
              lessonNumber: lesson.lesson_number,
              date: lesson.date,
              topic: lesson.topic,
              content: lesson.content,
              status: lesson.status,
              durationMinutes: lesson.duration_minutes,
              attendanceSummary: lesson.attendance_summary
            }
          end
          
          data[:students] = diary.students.map do |student|
            student_summary_json(student, diary)
          end
        end
        
        data
      end
      
      def student_summary_json(student, diary)
        {
          id: student.id,
          name: student.name,
          registrationNumber: student.registration_number,
          average: diary.student_average(student),
          attendancePercentage: diary.student_attendance_percentage(student),
          gradesCount: diary.student_grades(student).count,
          occurrencesCount: diary.occurrences.where(student: student).count
        }
      end
      
      def calculate_average_attendance(diary)
        total_students = diary.students.count
        return 0 if total_students.zero?
        
        total_percentage = diary.students.sum { |student| diary.student_attendance_percentage(student) }
        (total_percentage / total_students).round(1)
      end
    end
  end
end