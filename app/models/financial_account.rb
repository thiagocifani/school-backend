class FinancialAccount < ApplicationRecord
  enum :account_type, { income: 0, expense: 1 }
  enum :category, { 
    tuition: 0, enrollment_fee: 1, event_fee: 2, # income categories
    salary: 10, utility: 11, maintenance: 12, supply: 13, other_expense: 14 # expense categories
  }
  enum :status, { pending: 0, paid: 1, cancelled: 2 }
  
  belongs_to :reference, polymorphic: true, optional: true
  
  validates :description, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :date, presence: true
  validates :account_type, presence: true
  validates :category, presence: true
  
  scope :for_period, ->(start_date, end_date) { where(date: start_date..end_date) }
  scope :income, -> { where(account_type: :income) }
  scope :expense, -> { where(account_type: :expense) }
  scope :paid, -> { where(status: :paid) }
  
  def self.balance_for_period(start_date, end_date)
    period_records = for_period(start_date, end_date).paid
    income_total = period_records.income.sum(:amount)
    expense_total = period_records.expense.sum(:amount)
    income_total - expense_total
  end
  
  def income?
    account_type == 'income'
  end
  
  def expense?
    account_type == 'expense'
  end
end