class CoraInvoice < ApplicationRecord
  # Associations
  belongs_to :reference, polymorphic: true
  has_many :cora_webhooks, foreign_key: "invoice_id", primary_key: "invoice_id"

  # Enums
  enum :status, {
    draft: "DRAFT",
    open: "OPEN",
    paid: "PAID",
    late: "LATE",
    cancelled: "CANCELLED"
  }

  enum :invoice_type, {
    tuition: "tuition",        # Mensalidade de aluno
    salary_payment: "salary",   # Pagamento de salário
    general_expense: "expense", # Despesa geral
    income: "income"           # Receita adicional
  }

  # Validations
  validates :invoice_id, presence: true, uniqueness: true
  validates :amount, presence: true, numericality: {greater_than: 0}
  validates :status, presence: true
  validates :due_date, presence: true
  validates :customer_name, presence: true, length: {maximum: 60}
  validates :customer_document, presence: true
  validates :customer_email, presence: true, length: {maximum: 60}
  validates :invoice_type, presence: true
  validates :reference_type, presence: true
  validates :reference_id, presence: true

  # Scopes
  scope :pending, -> { where(status: ["DRAFT", "OPEN"]) }
  scope :overdue, -> { where(status: "LATE") }
  scope :paid, -> { where(status: "PAID") }
  scope :for_tuitions, -> { where(invoice_type: "tuition") }
  scope :for_salaries, -> { where(invoice_type: "salary") }
  scope :for_expenses, -> { where(invoice_type: "expense") }
  scope :for_incomes, -> { where(invoice_type: "income") }

  # Callbacks
  before_validation :set_defaults, on: :create
  after_update :handle_payment_notification, if: :saved_change_to_status?

  # Class methods - Updated for FinancialTransaction
  def self.create_for_financial_transaction(financial_transaction)
    case financial_transaction.transaction_type
    when 'tuition'
      create_for_tuition_transaction(financial_transaction)
    when 'salary'
      create_for_salary_transaction(financial_transaction)
    when 'expense'
      create_for_expense_transaction(financial_transaction)
    when 'income'
      create_for_income_transaction(financial_transaction)
    else
      raise ArgumentError, "Unsupported transaction type: #{financial_transaction.transaction_type}"
    end
  end

  def self.create_for_tuition_transaction(transaction)
    student = transaction.reference
    guardian = student&.guardians&.first

    return nil unless guardian&.user

    create!(
      amount: transaction.amount,
      due_date: transaction.due_date,
      customer_name: guardian.user.name,
      customer_document: guardian.user.cpf || "000.000.000-00",
      customer_email: guardian.user.email,
      invoice_type: "tuition",
      reference: transaction
    )
  end

  def self.create_for_salary_transaction(transaction)
    teacher = transaction.reference

    return nil unless teacher&.user

    create!(
      amount: transaction.amount,
      due_date: transaction.due_date,
      customer_name: teacher.user.name,
      customer_document: teacher.user.cpf || "000.000.000-00",
      customer_email: teacher.user.email,
      invoice_type: "salary",
      reference: transaction
    )
  end

  def self.create_for_expense_transaction(transaction)
    # For general expenses, we'll use admin user as default
    admin_user = User.where(role: "admin").first

    create!(
      amount: transaction.amount,
      due_date: transaction.due_date,
      customer_name: admin_user&.name || "Administração Escolar",
      customer_document: admin_user&.cpf || "000.000.000-00",
      customer_email: admin_user&.email || "admin@escola.com",
      invoice_type: "expense",
      reference: transaction
    )
  end

  def self.create_for_income_transaction(transaction)
    # For income, we might use the school itself as the customer
    admin_user = User.where(role: "admin").first

    create!(
      amount: transaction.amount,
      due_date: transaction.due_date,
      customer_name: admin_user&.name || "Escola - Receita",
      customer_document: admin_user&.cpf || "000.000.000-00",
      customer_email: admin_user&.email || "admin@escola.com",
      invoice_type: "income",
      reference: transaction
    )
  end

  # Legacy methods for backward compatibility
  def self.create_for_tuition(tuition)
    student = tuition.student
    guardian = student.guardians.first

    return nil unless guardian&.user

    create!(
      amount: tuition.amount,
      due_date: tuition.due_date,
      customer_name: guardian.user.name,
      customer_document: guardian.user.cpf || "000.000.000-00",
      customer_email: guardian.user.email,
      invoice_type: "tuition",
      reference: tuition
    )
  end

  def self.create_for_salary(salary)
    teacher = salary.teacher

    create!(
      amount: salary.amount,
      due_date: Date.current,
      customer_name: teacher.user.name,
      customer_document: teacher.user.cpf || "000.000.000-00",
      customer_email: teacher.user.email,
      invoice_type: "salary",
      reference: salary
    )
  end

  def self.create_for_expense(financial_account)
    # For general expenses, we'll use admin user as default
    admin_user = User.where(role: "admin").first

    create!(
      amount: financial_account.amount,
      due_date: Date.current,
      customer_name: admin_user&.name || "Administração Escolar",
      customer_document: admin_user&.cpf || "000.000.000-00",
      customer_email: admin_user&.email || "admin@escola.com",
      invoice_type: "expense",
      reference: financial_account
    )
  end

  # Instance methods
  def amount_in_cents
    (amount * 100).to_i
  end

  def overdue?
    due_date < Date.current && !paid?
  end

  def days_overdue
    return 0 unless overdue?
    (Date.current - due_date).to_i
  end

  def can_be_cancelled?
    draft? || open?
  end

  def mark_as_paid!
    update!(
      status: "PAID",
      paid_at: Time.current
    )
  end

  def formatted_amount
    "R$ #{amount.to_f.to_s.tr(".", ",")}"
  end

  def student_name
    return nil unless tuition? && reference.is_a?(Tuition)
    reference.student.name
  end

  def teacher_name
    return nil unless salary_payment? && reference.is_a?(Salary)
    reference.teacher.user.name
  end

  private

  def set_defaults
    self.status ||= "DRAFT"
    self.invoice_id ||= generate_invoice_id
  end
  
  def generate_invoice_id
    # Generate a unique invoice ID
    "CORA_#{Time.current.strftime('%Y%m%d')}_#{SecureRandom.hex(4).upcase}"
  end

  def handle_payment_notification
    if paid? && reference
      case invoice_type
      when "tuition"
        reference.update!(
          status: "paid",
          payment_method: "cora_boleto",
          paid_date: paid_at&.to_date || Date.current
        )
      when "salary"
        reference.update!(
          status: "paid",
          payment_date: paid_at&.to_date || Date.current
        )
      when "expense"
        reference.update!(status: "paid") if reference.respond_to?(:status=)
      end
    end
  end
end
