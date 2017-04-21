class CreateExperiments < ActiveRecord::Migration
  def change
    create_table :experiments do |t|
      t.integer :user_id
      t.string :title
      t.text :description
      t.integer :factor_num 
      t.text :factor_name
      t.text :factor1
      t.text :factor2
      t.text :factor3
      t.text :factor4
      t.text :factor5
      t.text :factor6
      t.text :factor7
      t.text :factor8
      t.text :factor9
      t.text :factor10

      # Mitcr params
        t.string :mitcr_pset     ,:default => 'flex'  
        t.string :mitcr_species  ,:default => 'hs' 
        t.string :mitcr_gene     ,:default => 'TRB' 
        t.string :mitcr_cysphe   ,:default => '1' 
        t.string :mitcr_ec       ,:default => '2' 
        t.string :mitcr_quality  ,:default => '25' 
        t.string :mitcr_lq       ,:default => 'map' 
        t.string :mitcr_pcrec    ,:default => 'ete' 

      t.timestamps
    end
  end
end

