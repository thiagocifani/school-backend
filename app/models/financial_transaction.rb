class FinancialTransaction < ApplicationRecord
  # Polymorphic association for flexible references
  belongs_to :reference, polymorphic: true, optional: true
  
  # Association with Cora invoices
  has_one :cora_invoice, -> { where(reference_type: 'FinancialTransaction') }, 
          foreign_key: 'reference_id', 
          class_name: 'CoraInvoice'
  
  # Enums for better type safety and readability
  enum :transaction_type, {
    tuition: 0,      # Mensalidade de aluno
    salary: 1,       # Salário de professor
    expense: 2,      # Despesa geral
    income: 3        # Receita adicional
  }
  
  enum :status, {
    pending: 0,      # Pendente
    paid: 1,         # Pago
    overdue: 2,      # Em atraso
    cancelled: 3     # Cancelado
  }
  
  enum :payment_method, {
    cash: 0,         # Dinheiro
    card: 1,         # Cartão
    transfer: 2,     # Transferência
    pix: 3,          # PIX
    boleto: 4        # Boleto
  }
  
  # Validations
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :due_date, presence: true
  validates :description, presence: true, length: { maximum: 500 }
  validates :transaction_type, presence: true
  validates :status, presence: true
  
  # Monetary fields
  validates :discount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :late_fee, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  
  # Scopes for filtering and reporting
  scope :by_type, ->(type) { where(transaction_type: type) }
  scope :by_status, ->(status) { where(status: status) }
  scope :by_date_range, ->(start_date, end_date) { where(due_date: start_date..end_date) }
  scope :paid_between, ->(start_date, end_date) { 
    where(status: :paid, paid_date: start_date..end_date) 
  }
  scope :pending_until, ->(date) { where(status: :pending, due_date: ..date) }
  scope :overdue, -> { where(status: :overdue).or(where(status: :pending, due_date: ..Date.current)) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_month, ->(year, month) { 
    start_date = Date.new(year, month, 1)
    end_date = start_date.end_of_month
    where(due_date: start_date..end_date)
  }
  
  # Financial calculations
  scope :receivables, -> { where(transaction_type: [:tuition, :income]) }
  scope :payables, -> { where(transaction_type: [:salary, :expense]) }
  
  # Callbacks
  before_save :calculate_final_amount
  before_save :update_status_based_on_due_date
  after_update :sync_with_cora, if: :saved_change_to_status?
  
  # Virtual attributes
  def final_amount
    amount + (late_fee || 0) - (discount || 0)
  end
  
  def overdue?
    pending? && due_date < Date.current
  end
  
  def days_overdue
    return 0 unless overdue?
    (Date.current - due_date).to_i
  end
  
  def can_be_paid?
    pending? || overdue?
  end
  
  def can_be_cancelled?
    pending? || overdue?
  end
  
  # Type-specific helpers
  def tuition?
    transaction_type == 'tuition'
  end
  
  def salary?
    transaction_type == 'salary'
  end
  
  def expense?
    transaction_type == 'expense'
  end
  
  def income?
    transaction_type == 'income'
  end
  
  def receivable?
    tuition? || income?
  end
  
  def payable?
    salary? || expense?
  end
  
  # Formatting helpers
  def formatted_amount
    "R$ #{amount.to_f.to_s.gsub('.', ',')}"
  end
  
  def formatted_final_amount
    "R$ #{final_amount.to_f.to_s.gsub('.', ',')}"
  end
  
  def status_badge_class
    case status
    when 'pending' then 'bg-yellow-100 text-yellow-800'
    when 'paid' then 'bg-green-100 text-green-800'
    when 'overdue' then 'bg-red-100 text-red-800'
    when 'cancelled' then 'bg-gray-100 text-gray-800'
    else 'bg-gray-100 text-gray-800'
    end
  end
  
  def type_icon
    case transaction_type
    when 'tuition' then 'graduation-cap'
    when 'salary' then 'users'
    when 'expense' then 'arrow-down'
    when 'income' then 'arrow-up'
    else 'circle'
    end
  end
  
  # Class methods for reporting
  def self.cash_flow_summary(start_date = Date.current.beginning_of_month, end_date = Date.current.end_of_month)
    transactions = by_date_range(start_date, end_date)
    
    {
      period: "#{start_date.strftime('%d/%m/%Y')} - #{end_date.strftime('%d/%m/%Y')}",
      receivables: {
        total: transactions.receivables.sum(:amount),
        paid: transactions.receivables.paid.sum(&:final_amount),
        pending: transactions.receivables.pending.sum(:amount)
      },
      payables: {
        total: transactions.payables.sum(:amount),
        paid: transactions.payables.paid.sum(&:final_amount),
        pending: transactions.payables.pending.sum(:amount)
      },
      net_flow: transactions.receivables.paid.sum(&:final_amount) - 
                transactions.payables.paid.sum(&:final_amount),
      transactions_count: transactions.count
    }
  end
  
  def self.monthly_breakdown(year = Date.current.year)
    (1..12).map do |month|
      month_transactions = by_month(year, month)
      {
        month: month,
        month_name: Date::MONTHNAMES[month],
        receivables: month_transactions.receivables.sum(:amount),
        payables: month_transactions.payables.sum(:amount),
        net: month_transactions.receivables.sum(:amount) - 
             month_transactions.payables.sum(:amount)
      }
    end
  end
  
  # Factory methods for different transaction types
  def self.create_tuition(student:, amount:, due_date:, description: nil)
    transaction = create!(
      transaction_type: :tuition,
      amount: amount,
      due_date: due_date,
      description: description || "Mensalidade #{student.name} - #{due_date.strftime('%m/%Y')}",
      reference: student
    )
    
    # Automatically create Cora invoice for tuition (boleto)
    begin
      CoraInvoice.create_for_financial_transaction(transaction)
    rescue => e
      Rails.logger.error "Failed to create Cora invoice for tuition #{transaction.id}: #{e.message}"
    end
    
    transaction
  end
  
  def self.create_salary(teacher:, amount:, due_date:, description: nil)
    transaction = create!(
      transaction_type: :salary,
      amount: amount,
      due_date: due_date,
      description: description || "Salário #{teacher.user.name} - #{due_date.strftime('%m/%Y')}",
      reference: teacher,
      payment_method: :pix  # Salários sempre via PIX
    )
    
    # Automatically create Cora invoice for salary (PIX)
    begin
      CoraInvoice.create_for_financial_transaction(transaction)
    rescue => e
      Rails.logger.error "Failed to create Cora invoice for salary #{transaction.id}: #{e.message}"
    end
    
    transaction
  end
  
  def self.create_expense(amount:, due_date:, description:, reference: nil)
    create!(
      transaction_type: :expense,
      amount: amount,
      due_date: due_date,
      description: description,
      reference: reference
    )
  end
  
  def self.create_income(amount:, due_date:, description:, reference: nil)
    create!(
      transaction_type: :income,
      amount: amount,
      due_date: due_date,
      description: description,
      reference: reference
    )
  end
  
  # Mark as paid
  def mark_as_paid!(payment_method: :pix, paid_date: Date.current)
    update!(
      status: :paid,
      payment_method: payment_method,
      paid_date: paid_date
    )
  end
  
  # Generate recurrence (for monthly transactions)
  def generate_next_month
    next_due_date = due_date + 1.month
    
    self.class.create!(
      transaction_type: transaction_type,
      amount: amount,
      due_date: next_due_date,
      description: description.gsub(due_date.strftime('%m/%Y'), next_due_date.strftime('%m/%Y')),
      reference: reference,
      discount: discount,
      observation: observation
    )
  end
  
  private
  
  def calculate_final_amount
    # This is handled by the virtual attribute, but we could store it if needed
  end
  
  def update_status_based_on_due_date
    if pending? && due_date < Date.current
      self.status = :overdue
    end
  end
  
  def sync_with_cora
    return unless external_id.present?
    
    if paid? && cora_invoice.present?
      cora_invoice.mark_as_paid!
    end
  end
end