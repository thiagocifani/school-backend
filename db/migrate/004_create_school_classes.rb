class CreateSchoolClasses < ActiveRecord::Migration[8.0]
  def change
    create_table :school_classes do |t|
      t.string :name # "Infantil 1", "1º Ano A"
      t.integer :grade_level # 0: Infantil 1, 1: Infantil 2, etc
      t.string :section # "A", "B", "C"
      t.references :academic_term, foreign_key: true
      t.references :main_teacher, foreign_key: { to_table: :teachers }, null: true
      t.integer :max_students, default: 25
      t.timestamps
    end
  end
end