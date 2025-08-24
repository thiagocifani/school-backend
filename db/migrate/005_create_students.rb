class CreateStudents < ActiveRecord::Migration[8.0]
  def change
    create_table :students do |t|
      t.string :name, null: false
      t.date :birth_date
      t.string :registration_number
      t.integer :status, default: 0 # enum: active, inactive, transferred
      t.references :school_class, foreign_key: true, null: true
      t.timestamps
    end
  end
end