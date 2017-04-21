class CreateSubExperiments < ActiveRecord::Migration
  def change
    create_table :sub_experiments do |t|
      t.integer :user_id
      t.integer :experiment_id
      t.string  :description
      t.integer :sample_id, :default => -1     # Samples id
      t.boolean :ex_clone, :default => false   # Is clone extracted ?  

      t.string :sample_name
      t.string :sample_name_org
      t.string :factor1
      t.string :factor2
      t.string :factor3
      t.string :factor4
      t.string :factor5
      t.string :factor6
      t.string :factor7
      t.string :factor8
      t.string :factor9
      t.string :factor10

      t.timestamps
    end
  end
end
