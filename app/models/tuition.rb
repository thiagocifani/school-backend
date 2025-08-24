class Tuition < ApplicationRecord
  belongs_to :student
  
  enum :status, { pending: 0, paid: 1, overdue: 2, cancelled: 3 }
  enum :payment_method, { cash: 0, card: 1, transfer: 2, pix: 3 }
  
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :due_date, presence: true
  
  scope :pending_payment, -> { where(status: [:pending, :overdue]) }
  scope :overdue, -> { where(due_date: ..Date.current, status: :pending) }
  scope :for_month, ->(month, year) { 
    where(due_date: Date.new(year, month, 1)..Date.new(year, month, -1))
  }
  
  before_save :calculate_late_fee, if: :paid_date_changed?
  before_save :mark_as_overdue, if: :should_mark_overdue?
  
  def total_amount
    amount + (late_fee || 0) - (discount || 0)
  end
  
  def days_overdue
    return 0 unless overdue?
    (Date.current - due_date).to_i
  end
  
  private
  
  def calculate_late_fee
    return unless paid_date && paid_date > due_date
    
    days_late = (paid_date - due_date).to_i
    self.late_fee = (amount * 0.02 * days_late / 30).round(2) # 2% ao mês
  end
  
  def should_mark_overdue?
    pending? && due_date < Date.current
  end
  
  def mark_as_overdue
    self.status = :overdue
  end
end