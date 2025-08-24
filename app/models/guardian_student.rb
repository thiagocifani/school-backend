class GuardianStudent < ApplicationRecord
  belongs_to :guardian
  belongs_to :student
  
  validates :relationship, presence: true
  validates :guardian_id, uniqueness: { scope: :student_id }
  
  RELATIONSHIPS = %w[pai mãe avô avó tio tia padrasto madrasta responsável].freeze
  
  validates :relationship, inclusion: { in: RELATIONSHIPS }
  
  accepts_nested_attributes_for :guardian
end