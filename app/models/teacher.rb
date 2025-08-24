class Teacher < ApplicationRecord
  enum :status, { active: 0, inactive: 1 }
  
  belongs_to :user
  has_many :school_classes, foreign_key: :main_teacher_id
  has_many :class_subjects
  has_many :subjects, through: :class_subjects
  has_many :occurrences
  has_many :salaries
  has_many :diaries, dependent: :destroy
  has_many :lessons, through: :diaries
  
  validates :salary, numericality: { greater_than: 0 }, allow_nil: true
  validates :status, presence: true
  
  delegate :name, :email, :phone, to: :user
  
  scope :active, -> { where(status: :active) }
  
  def active_diaries
    diaries.active
  end
  
  def current_term_diaries
    current_term = AcademicTerm.where(active: true).first
    return diaries.none unless current_term
    
    diaries.where(academic_term: current_term)
  end
end