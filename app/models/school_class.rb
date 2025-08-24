class SchoolClass < ApplicationRecord
  enum :period, { morning: 0, afternoon: 1, evening: 2 }
  
  belongs_to :academic_term
  belongs_to :grade_level
  belongs_to :main_teacher, class_name: 'Teacher', optional: true
  has_many :students
  has_many :class_subjects, dependent: :destroy
  has_many :subjects, through: :class_subjects
  has_many :teachers, through: :class_subjects
  has_many :lessons, through: :class_subjects
  
  validates :name, presence: true
  validates :section, presence: true
  validates :max_students, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 50 }
  validates :period, presence: true
  validates :name, uniqueness: { scope: [:section, :academic_term_id] }
  
  def full_name
    "#{name} #{section}".strip
  end
  
  def current_students_count
    students.where(status: :active).count
  end
  
  def has_capacity?
    current_students_count < max_students
  end
end