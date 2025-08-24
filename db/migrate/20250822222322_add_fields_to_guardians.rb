class AddFieldsToGuardians < ActiveRecord::Migration[8.0]
  def change
    add_column :guardians, :birth_date, :date
    add_column :guardians, :rg, :string
    add_column :guardians, :profession, :string
    add_column :guardians, :marital_status, :integer, default: 0 # enum: single, married, divorced, widowed
    add_column :guardians, :neighborhood, :string
    add_column :guardians, :complement, :string
    add_column :guardians, :zip_code, :string
    
    add_index :guardians, :rg, unique: true
  end
end
