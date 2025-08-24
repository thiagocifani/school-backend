class Lesson < ApplicationRecord
  belongs_to :diary
  has_many :attendances, dependent: :destroy
  has_many :grades, dependent: :destroy
  has_many :occurrences, dependent: :destroy
  
  enum :status, { planned: 0, completed: 1, cancelled: 2 }
  
  validates :date, presence: true
  validates :topic, presence: true
  validates :lesson_number, presence: true, uniqueness: { scope: :diary_id }
  validates :duration_minutes, presence: true, numericality: { greater_than: 0 }
  
  after_create :create_attendances_for_students
  before_validation :set_lesson_number, on: :create
  
  delegate :school_class, :subject, :teacher, :academic_term, to: :diary
  
  scope :for_date, ->(date) { where(date: date) }
  scope :for_week, ->(start_date) { where(date: start_date.beginning_of_week..start_date.end_of_week) }
  scope :for_month, ->(date) { where(date: date.beginning_of_month..date.end_of_month) }
  
  def students
    diary.students
  end
  
  def attendance_summary
    total = attendances.count
    present = attendances.where(status: :present).count
    absent = attendances.where(status: :absent).count
    late = attendances.where(status: :late).count
    justified = attendances.where(status: :justified).count
    
    {
      total: total,
      present: present,
      absent: absent,
      late: late,
      justified: justified,
      present_percentage: total > 0 ? (present.to_f / total * 100).round(1) : 0
    }
  end
  
  def mark_as_completed!
    update!(status: :completed)
  end
  
  def mark_as_cancelled!
    update!(status: :cancelled)
  end
  
  private
  
  def create_attendances_for_students
    diary.students.each do |student|
      attendances.create!(student: student, status: :present)
    end
  end
  
  def set_lesson_number
    return if lesson_number.present?
    
    last_lesson = diary.lessons.order(:lesson_number).last
    self.lesson_number = last_lesson ? last_lesson.lesson_number + 1 : 1
  end
end