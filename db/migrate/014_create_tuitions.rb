class CreateTuitions < ActiveRecord::Migration[8.0]
  def change
    create_table :tuitions do |t|
      t.references :student, null: false, foreign_key: true
      t.decimal :amount, precision: 10, scale: 2
      t.date :due_date
      t.date :paid_date
      t.integer :status # enum: pending, paid, overdue, cancelled
      t.integer :payment_method # enum: cash, card, transfer, pix
      t.decimal :discount, precision: 10, scale: 2
      t.decimal :late_fee, precision: 10, scale: 2
      t.text :observation
      t.timestamps
    end
  end
end