class Guardian < ApplicationRecord
  belongs_to :user
  has_many :guardian_students, dependent: :destroy
  has_many :students, through: :guardian_students
  
  enum :marital_status, { single: 0, married: 1, divorced: 2, widowed: 3 }
  
  validates :address, presence: true
  validates :rg, uniqueness: true, allow_blank: true
  
  delegate :name, :email, :phone, :cpf, to: :user
  
  accepts_nested_attributes_for :user
  
  def age
    return nil unless birth_date
    ((Date.current - birth_date) / 365.25).floor
  end
end