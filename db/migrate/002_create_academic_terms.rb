class CreateAcademicTerms < ActiveRecord::Migration[8.0]
  def change
    create_table :academic_terms do |t|
      t.string :name # "1º Bimestre 2024"
      t.date :start_date
      t.date :end_date
      t.integer :term_type # enum: bimester, quarter, semester
      t.integer :year
      t.boolean :active, default: false
      t.timestamps
    end
  end
end