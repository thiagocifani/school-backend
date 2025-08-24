class CreateSalaries < ActiveRecord::Migration[8.0]
  def change
    create_table :salaries do |t|
      t.references :teacher, null: false, foreign_key: true
      t.decimal :amount, precision: 10, scale: 2
      t.integer :month
      t.integer :year
      t.date :payment_date
      t.integer :status # enum: pending, paid
      t.decimal :bonus, precision: 10, scale: 2
      t.decimal :deductions, precision: 10, scale: 2
      t.timestamps
    end
  end
end