class GradeLevel < ApplicationRecord
  belongs_to :education_level
  has_many :school_classes, dependent: :destroy
  
  validates :name, presence: true
  validates :order, presence: true, numericality: { greater_than: 0 }
  validates :name, uniqueness: { scope: :education_level_id }
  validates :order, uniqueness: { scope: :education_level_id }
  
  scope :ordered, -> { joins(:education_level).order('education_levels.name', :order) }
  
  def full_name
    "#{education_level.name} - #{name}"
  end
end