class Attendance < ApplicationRecord
  belongs_to :lesson
  belongs_to :student
  
  enum :status, { present: 0, absent: 1, late: 2, justified: 3 }
  
  validates :lesson_id, uniqueness: { scope: :student_id }
  
  scope :for_period, ->(start_date, end_date) {
    joins(:lesson).where(lessons: { date: start_date..end_date })
  }
  
  scope :for_student_and_subject, ->(student_id, subject_id) {
    joins(lesson: :class_subject)
      .where(student_id: student_id)
      .where(class_subjects: { subject_id: subject_id })
  }
end