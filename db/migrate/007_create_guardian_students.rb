class CreateGuardianStudents < ActiveRecord::Migration[8.0]
  def change
    create_table :guardian_students do |t|
      t.references :guardian, null: false, foreign_key: true
      t.references :student, null: false, foreign_key: true
      t.string :relationship # pai, mãe, avô, etc
      t.timestamps
    end
  end
end