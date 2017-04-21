class CreateSamples < ActiveRecord::Migration
  def change
    create_table :samples do |t|
      t.integer :user_id
      t.integer :project_id
      t.string  :sid
      t.string  :title
      t.text    :description
      t.string  :org_file_name
      t.integer  :use_ref, :default => 0

      t.timestamps
    end
  end
end
