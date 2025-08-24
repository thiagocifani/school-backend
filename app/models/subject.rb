class Subject < ApplicationRecord
  has_many :class_subjects, dependent: :destroy
  has_many :school_classes, through: :class_subjects
  has_many :teachers, through: :class_subjects
  has_many :grades, through: :class_subjects
  
  validates :name, presence: true, uniqueness: true
  validates :code, presence: true, uniqueness: true, format: { with: /\A[A-Z]{2,5}\z/, message: "deve ter 2-5 letras maiúsculas" }
  validates :workload, numericality: { greater_than: 0 }, allow_nil: true
  
  scope :ordered, -> { order(:name) }
  
  before_validation :upcase_code
  
  private
  
  def upcase_code
    self.code = code&.upcase
  end
end