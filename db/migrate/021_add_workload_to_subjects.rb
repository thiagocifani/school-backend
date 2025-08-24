class AddWorkloadToSubjects < ActiveRecord::Migration[8.0]
  def change
    add_column :subjects, :workload, :integer
    
    # Update code validation
    change_column :subjects, :code, :string, null: false
    
    add_index :subjects, :workload
  end
end