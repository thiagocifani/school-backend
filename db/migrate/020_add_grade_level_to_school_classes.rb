class AddGradeLevelToSchoolClasses < ActiveRecord::Migration[8.0]
  def change
    add_reference :school_classes, :grade_level, null: true, foreign_key: true
    add_column :school_classes, :period, :integer, default: 0, null: false
    
    add_index :school_classes, :period
    add_index :school_classes, [:name, :section, :academic_term_id], unique: true, name: 'index_school_classes_on_name_section_term'
  end
end