class AcademicTerm < ApplicationRecord
  enum :term_type, { bimester: 0, quarter: 1, semester: 2 }
  
  has_many :school_classes, dependent: :destroy
  has_many :grades, dependent: :destroy
  
  validates :name, presence: true
  validates :start_date, :end_date, :year, presence: true
  validates :start_date, uniqueness: { scope: [:end_date, :year] }
  
  scope :active, -> { where(active: true) }
  scope :current_year, -> { where(year: Date.current.year) }
end