class ClassSubject < ApplicationRecord
  belongs_to :school_class
  belongs_to :subject
  belongs_to :teacher
  has_many :grades, dependent: :destroy
  
  validates :weekly_hours, presence: true, numericality: { greater_than: 0 }
  validates :subject_id, uniqueness: { scope: :school_class_id }
  
  # Lessons are now accessed through diaries
  def lessons
    Diary.where(
      school_class: school_class,
      subject: subject,
      teacher: teacher
    ).flat_map(&:lessons)
  end
end