class Salary < ApplicationRecord
  belongs_to :teacher
  
  enum :status, { pending: 0, paid: 1 }
  
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :month, presence: true, inclusion: { in: 1..12 }
  validates :year, presence: true
  validates :teacher_id, uniqueness: { scope: [:month, :year] }
  
  scope :for_month, ->(month, year) { where(month: month, year: year) }
  scope :pending_payment, -> { where(status: :pending) }
  
  def total_amount
    amount + (bonus || 0) - (deductions || 0)
  end
  
  def month_year
    Date.new(year, month, 1).strftime("%B %Y")
  end
end