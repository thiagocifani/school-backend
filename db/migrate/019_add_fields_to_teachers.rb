class AddFieldsToTeachers < ActiveRecord::Migration[8.0]
  def change
    add_column :teachers, :specialization, :string
    add_column :teachers, :status, :integer, default: 0, null: false
    
    add_index :teachers, :status
  end
end