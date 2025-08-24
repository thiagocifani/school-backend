class CreateEducationLevels < ActiveRecord::Migration[8.0]
  def change
    create_table :education_levels do |t|
      t.string :name, null: false
      t.text :description
      t.string :age_range
      t.timestamps
    end
    
    add_index :education_levels, :name, unique: true
  end
end