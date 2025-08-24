class ClassSubject < ApplicationRecord
  belongs_to :school_class
  belongs_to :subject
  belongs_to :teacher
  has_many :lessons, dependent: :destroy
  has_many :grades, dependent: :destroy
  
  validates :weekly_hours, presence: true, numericality: { greater_than: 0 }
  validates :subject_id, uniqueness: { scope: :school_class_id }
end