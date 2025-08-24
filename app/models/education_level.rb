class EducationLevel < ApplicationRecord
  has_many :grade_levels, dependent: :destroy
  has_many :school_classes, through: :grade_levels
  
  validates :name, presence: true, uniqueness: true
  validates :name, length: { minimum: 2, maximum: 100 }
  
  scope :ordered, -> { order(:name) }
end