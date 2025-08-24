class Grade < ApplicationRecord
  belongs_to :student
  belongs_to :class_subject, optional: true
  belongs_to :academic_term
  belongs_to :diary, optional: true
  belongs_to :lesson, optional: true
  
  validates :value, presence: true, numericality: { 
    greater_than_or_equal_to: 0, 
    less_than_or_equal_to: 10 
  }
  validates :grade_type, presence: true
  validates :date, presence: true
  
  validate :must_have_class_subject_or_diary
  validate :student_must_belong_to_diary_class, if: :diary_id?
  
  scope :for_term, ->(term) { where(academic_term: term) }
  scope :for_subject, ->(subject) { joins(:class_subject).where(class_subjects: { subject: subject }) }
  scope :for_diary, ->(diary) { where(diary: diary) }
  scope :for_lesson, ->(lesson) { where(lesson: lesson) }
  
  def subject
    if diary.present?
      diary.subject
    else
      class_subject.subject
    end
  end
  
  def teacher
    if diary.present?
      diary.teacher
    else
      class_subject.teacher
    end
  end
  
  def school_class
    if diary.present?
      diary.school_class
    else
      class_subject.school_class
    end
  end
  
  private
  
  def must_have_class_subject_or_diary
    if class_subject.blank? && diary.blank?
      errors.add(:base, 'deve ter uma disciplina ou diário associado')
    end
  end

  def student_must_belong_to_diary_class
    if diary.present? && student.present?
      unless diary.students.include?(student)
        errors.add(:student, 'deve pertencer à turma do diário')
      end
    end
  end
end
