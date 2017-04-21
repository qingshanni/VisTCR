class DelExtractParamFromExperiments < ActiveRecord::Migration
  def up
    remove_column :experiments, :mitcr_pset
    remove_column :experiments, :mitcr_species
    remove_column :experiments, :mitcr_gene
    remove_column :experiments, :mitcr_cysphe
    remove_column :experiments, :mitcr_ec
    remove_column :experiments, :mitcr_quality
    remove_column :experiments, :mitcr_lq
    remove_column :experiments, :mitcr_pcrec
    add_column :experiments, :extract_method, :string, default:"mitcr" 
  end

  def down
    add_column :experiments, :mitcr_pset, :string, default: "flex"
    add_column :experiments, :mitcr_species, :string, default:"hs"
    add_column :experiments, :mitcr_gene, :string, default:"TRB"
    add_column :experiments, :mitcr_cysphe, :string, default:"1"
    add_column :experiments, :mitcr_ec, :string, default:"2"
    add_column :experiments, :mitcr_quality, :string, default:"25"
    add_column :experiments, :mitcr_lq, :string, default:"map"
    add_column :experiments, :mitcr_pcrec, :string, default:"ete"
    remove_column :experiments, :extract_method
  end
end
