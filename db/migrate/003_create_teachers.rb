class CreateTeachers < ActiveRecord::Migration[8.0]
  def change
    create_table :teachers do |t|
      t.references :user, null: false, foreign_key: true
      t.decimal :salary, precision: 10, scale: 2
      t.date :hire_date
      t.timestamps
    end
  end
end