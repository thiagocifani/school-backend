class CreateFinancialAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :financial_accounts do |t|
      t.string :description
      t.decimal :amount, precision: 10, scale: 2
      t.integer :account_type # enum: income, expense
      t.integer :category # enum: various categories
      t.date :date
      t.integer :status # enum: pending, paid, cancelled
      t.string :reference_type # polymorphic
      t.integer :reference_id
      t.timestamps
    end
  end
end