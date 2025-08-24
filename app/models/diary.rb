class Diary < ApplicationRecord
  belongs_to :teacher
  belongs_to :school_class
  belongs_to :subject
  belongs_to :academic_term
  
  has_many :lessons, dependent: :destroy
  has_many :grades, dependent: :destroy
  has_many :occurrences, dependent: :destroy
  has_many :attendances, through: :lessons
  
  enum :status, { active: 0, completed: 1, archived: 2 }
  
  validates :name, presence: true
  validates :teacher_id, uniqueness: { 
    scope: [:school_class_id, :subject_id, :academic_term_id],
    message: 'já possui um diário para esta turma e matéria neste período'
  }
  
  scope :for_teacher, ->(teacher) { where(teacher: teacher) }
  scope :for_class, ->(school_class) { where(school_class: school_class) }
  scope :for_subject, ->(subject) { where(subject: subject) }
  scope :for_term, ->(term) { where(academic_term: term) }
  
  def students
    school_class.students.active
  end
  
  def total_lessons
    lessons.count
  end
  
  def completed_lessons
    lessons.completed.count
  end
  
  def planned_lessons
    lessons.planned.count
  end
  
  def progress_percentage
    return 0 if total_lessons.zero?
    (completed_lessons.to_f / total_lessons * 100).round(1)
  end
  
  def student_grades(student)
    grades.where(student: student)
  end
  
  def student_average(student)
    student_grades = grades.where(student: student)
    return 0 if student_grades.empty?
    student_grades.average(:value).round(2)
  end
  
  def student_attendance_percentage(student)
    total = lessons.completed.count
    return 0 if total.zero?
    
    present = attendances.joins(:lesson)
                        .where(lessons: { diary: self, status: :completed })
                        .where(student: student, status: :present)
                        .count
    
    (present.to_f / total * 100).round(1)
  end
end