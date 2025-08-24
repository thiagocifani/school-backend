class CreateGradeLevels < ActiveRecord::Migration[8.0]
  def change
    create_table :grade_levels do |t|
      t.string :name, null: false
      t.references :education_level, null: false, foreign_key: true
      t.integer :order, null: false
      t.timestamps
    end
    
    add_index :grade_levels, [:education_level_id, :name], unique: true
    add_index :grade_levels, [:education_level_id, :order], unique: true
  end
end