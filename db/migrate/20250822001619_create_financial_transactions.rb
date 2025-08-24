class CreateFinancialTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :financial_transactions do |t|
      t.integer :transaction_type, null: false # tuition, salary, expense, income
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.date :due_date, null: false
      t.date :paid_date
      t.integer :status, default: 0 # pending, paid, overdue, cancelled
      t.integer :payment_method # cash, card, transfer, pix, boleto
      t.string :reference_type # polymorphic association
      t.integer :reference_id
      t.text :description, null: false
      t.text :observation
      t.decimal :discount, precision: 10, scale: 2, default: 0
      t.decimal :late_fee, precision: 10, scale: 2, default: 0
      t.string :external_id # ID from external payment system (Cora)
      t.text :metadata # JSON field for additional data

      t.timestamps
    end
    
    add_index :financial_transactions, :transaction_type
    add_index :financial_transactions, :status
    add_index :financial_transactions, :due_date
    add_index :financial_transactions, :paid_date
    add_index :financial_transactions, [:reference_type, :reference_id]
    add_index :financial_transactions, :external_id
  end
end
