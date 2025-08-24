class Occurrence < ApplicationRecord
  belongs_to :student
  belongs_to :teacher
  belongs_to :diary, optional: true
  belongs_to :lesson, optional: true
  
  enum :occurrence_type, { disciplinary: 0, medical: 1, positive: 2, other: 3 }
  enum :severity, { low: 0, medium: 1, high: 2 }
  
  validates :date, presence: true
  validates :title, presence: true
  validates :description, presence: true
  
  scope :recent, -> { order(created_at: :desc) }
  scope :for_student, ->(student) { where(student: student) }
  scope :for_period, ->(start_date, end_date) { where(date: start_date..end_date) }
  scope :for_diary, ->(diary) { where(diary: diary) }
  scope :for_lesson, ->(lesson) { where(lesson: lesson) }
  
  after_create :notify_guardians_if_severe
  
  def school_class
    if diary.present?
      diary.school_class
    else
      student.school_class
    end
  end
  
  def subject
    diary&.subject
  end
  
  private
  
  def notify_guardians_if_severe
    return unless high? || disciplinary?
    
    # TODO: Implement guardian notification logic
    update(notified_guardians: true)
  end
end