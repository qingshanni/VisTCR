require 'fileutils'
require 'jqgrid'
require 'json'
include Jqgrid 


class ExperimentsController < ApplicationController
  layout "analysis"
  # GET /experiments
  # GET /experiments.json
=begin
  def index
    respond_to do |format|
      if current_user
        format.html # index.html.erb
      else
        format.html { redirect_to root_path}
      end
    end
  end
=end


  def get_svg_file 
    svg_xml  = params[:svgdata]
    fn = Rails.root.join('app','assets','stylesheets','nv.d3.css')
    
    css = '<defs><style type="text/css" > <![CDATA[' + File.read(fn) + ']]></style></defs>'
    svg_file = css + svg_xml

    p svg_file
    send_data svg_file, :filename => "primers.svg"

  end
  # GET /experiments/1
  # GET /experiments/1.json
  def show
    @experiment       = Experiment.find(params[:id])
    param_factor_num  = @experiment.exp_params.find_by_key('factor_num')
    @factor_num       = param_factor_num.value.to_i
    param_factor_name = @experiment.exp_params.find_by_key('factor_name')
    @col_name         = param_factor_name.value.split(",")


    render :partial => "show_experiment"
  end

  def jqgrid_exp_design_list
    
    index_columns ||= [:sample_name,:sample_name_org,:sample_id,:factor1,:factor2,:factor3,:factor4,:factor5,:factor6,:factor7,:factor8,:factor9,:factor10,:created_at]
    current_page    = params[:page] ? params[:page].to_i : 1
    rows_per_page   = params[:rows] ? params[:rows].to_i : 10000 

    conditions={:page => current_page, :per_page => rows_per_page}
    conditions[:order] = params["sidx"] + " " + params["sord"] unless (params[:sidx].blank? || params[:sord].blank?)
    
    if params[:_search] == "true"
      conditions[:conditions]=filter_by_conditions(index_columns)
    end
    experiment = Experiment.find(params[:exp_id])
    @entries   = experiment.exp_designs.paginate(conditions)
   
   total_entries= @entries.total_entries
   total_pages  = total_entries/rows_per_page.to_i + 1


   @responce = {:page => current_page,:total=>total_pages , :records =>total_entries , :rows=>@entries} 

    respond_to do |format|
      format.json { render json: @responce }
    end



  end

  # GET /experiments/new
  # GET /experiments/new.json
  def new
    @experiment = Experiment.new
    render :partial => 'form_new_experiment'
  end

  # GET /experiments/1/edit
  def edit
    @experiment    = Experiment.find(params[:id])
#    par            = @experiment.read_tcr_extract_param
    render :partial => 'form_edit_experiment'
 end

  # POST /experiments
  # POST /experiments.json
  def create

    file        = params[:design_file].tempfile.path  
    @experiment = Experiment.new(params[:experiment])
    @data       = @experiment.parse_exp_design_data(file)
    if @data
      @experiment.extract_method = params[:extract_method]
      @experiment.user_id = current_user.id
      @experiment.save
      @experiment.update_attributes(@data[:exp_param])
      
      dir_path = "public/experiment/" + @experiment.id.to_s
      if Dir.exist?(dir_path)
        FileUtils.remove_dir dir_path
      end
      Dir.mkdir(dir_path)

   case params[:extract_method]
   when 'mitcr'
     par = {  :method        => 'mitcr',
              :mitcr_pset    => params[:mitcr_pset],
              :mitcr_species => params[:mitcr_species],
              :mitcr_gene    => params[:mitcr_gene],
              :mitcr_cysphe  => params[:mitcr_cysphe],
              :mitcr_ec      => params[:mitcr_ec],
              :mitcr_quality => params[:mitcr_quality],
              :mitcr_lq      => params[:mitcr_lq],
              :mitcr_pcrec   => params[:mitcr_pcrec]
     }

   when 'mixcr'
      par = {  :method        => 'mixcr',
               :mixcr_species => params[:mixcr_species],
               :mixcr_gene    => params[:mixcr_gene],

               :mixcr_minimal => params[:mixcr_minimal],
               :mixcr_maximal => params[:mixcr_maximal],
               :mixcr_relativeMin => params[:mixcr_relativeMin],

               :mixcr_mapperkv => params[:mixcr_mapperkv],
               :mixcr_mapperkj => params[:mixcr_mapperkj],
               :mixcr_mapperkc => params[:mixcr_mapperkc],
               :mixcr_leftboundv => params[:mixcr_leftboundv],
               :mixcr_leftboundj => params[:mixcr_leftboundj],
               :mixcr_leftboundc => params[:mixcr_leftboundc],
               :mixcr_rightboundv => params[:mixcr_rightboundv],
               :mixcr_rightboundj => params[:mixcr_rightboundj],
               :mixcr_rightboundc => params[:mixcr_rightboundc],
               :mixcr_minalignmentlengthv => params[:mixcr_minalignmentlengthv],
               :mixcr_minalignmentlengthj => params[:mixcr_minalignmentlengthj],
               :mixcr_minalignmentlengthc => params[:mixcr_minalignmentlengthc],
               :mixcr_maxadjacentindelsv => params[:mixcr_maxadjacentindelsv],
               :mixcr_maxadjacentindelsj => params[:mixcr_maxadjacentindelsj],
               :mixcr_maxadjacentindelsc => params[:mixcr_maxadjacentindelsc],
               :mixcr_absoluteminscorev => params[:mixcr_absoluteminscorev],
               :mixcr_absoluteminscorej => params[:mixcr_absoluteminscorej],
               :mixcr_absoluteminscorec => params[:mixcr_absoluteminscorec],
               :mixcr_relativeminscorev => params[:mixcr_relativeminscorev],
               :mixcr_relativeminscorej => params[:mixcr_relativeminscorej],
               :mixcr_relativeminscorec => params[:mixcr_relativeminscorec],
               :mixcr_maxhitsv => params[:mixcr_maxhitsv],
               :mixcr_maxhitsj => params[:mixcr_maxhitsj],
               :mixcr_maxhitsc => params[:mixcr_maxhitsc],

               :mixcr_absolutminscore => params[:mixcr_absolutminscore],
               :mixcr_relativeminscore => params[:mixcr_relativeminscore],
               :mixcr_maxhits => params[:mixcr_maxhits],

            #   :mixcr_type => params[:mixcr_type],
            #   :mixcr_gapopenpenalty => params[:mixcr_gapopenpenalty],
            #   :mixcr_gapextensionpenalty => params[:mixcr_gapextensionpenalty],
               :mixcr_badqualitythreshold => params[:mixcr_badqualitythreshold],
               :mixcr_maxbadpointspercent => params[:mixcr_maxbadpointspercent],
               :mixcr_addreadscountonclustering => params[:mixcr_addreadscountonclustering],

               :mixcr_searchdepth => params[:mixcr_searchdepth],
               :mixcr_allowedMutationsInNRegions => params[:mixcr_allowedMutationsInNRegions],
               :mixcr_searchParameters => params[:mixcr_searchParameters],
               :mixcr_clusteringFilter => params[:mixcr_clusteringFilter],

           #    :mixcr_featureToAlignV => params[:mixcr_featureToAlignV],
           #    :mixcr_featureToAlignJ => params[:mixcr_featureToAlignJ],
           #    :mixcr_featureToAlignC => params[:mixcr_featureToAlignC],
           #    :mixcr_relativeMinScoreV => params[:mixcr_relativeMinScoreV],
           #    :mixcr_relativeMinScoreJ => params[:mixcr_relativeMinScoreJ],
           #    :mixcr_relativeMinScoreC => params[:mixcr_relativeMinScoreC]
 
      }
   when 'dcnt'
      par = {  :method        => 'dcnt',
               :dcnt_species => params[:dcnt_species],
               :dcnt_gene    => params[:dcnt_gene]
 
      }


   when 'cdr3'

      par = {  :method          => params[:extract_method],
               :v_cutoff        => params[:v_cutoff],
               :v_max_align_len => params[:v_max_align_len],
               :v_min_align_len => params[:v_min_align_len],
               :j_cutoff        => params[:j_cutoff],
               :j_max_align_len => params[:j_max_align_len],
               :j_min_align_len => params[:j_min_align_len],
            }

   else
   end

      @experiment.write_tcr_extract_param(par)

      @data[:exp_design].each do |ed|
        sample   =  current_user.samples.where(:id => ed[:sample_id])

        if sample.length < 1
          ed[:sample_id] = -1 
        end
        sub_experiment               = SubExperiment.new(ed)
        sub_experiment.experiment_id = @experiment.id
        sub_experiment.user_id       =  current_user.id
        sub_experiment.save
        if sample.length >0 
          ###  mkdir and copy qc file
          dir_path  = "public/sub_experiment/" + sub_experiment.id.to_s
          file_path = "public/samples/" + sub_experiment.sample_id.to_s + "/sample_fastqc/fastqc_data.txt"
          if Dir.exist?(dir_path)
            FileUtils.remove_dir dir_path
          end
          Dir.mkdir(dir_path)
          FileUtils.cp  file_path,  dir_path + "/fastqc_data.txt" 
        end

      end
    end
  end

  # PUT /experiments/1
  # PUT /experiments/1.json
  def update
    @experiment = Experiment.find(params[:id])
    @experiment.update_attributes(params[:experiment])
  end

  # DELETE /experiments/1
  # DELETE /experiments/1.json
  def destroy
    @experiment = Experiment.find(params[:id])
    @experiment.destroy
  end
  
  def delete_recorder 
    @experiment = Experiment.find(params[:id])
    @experiment.destroy
    render  :text=>'Delete success !' 
  end

=begin
  def form_set_experiment
    @experiment = Experiment.find(params[:id])
    render :partial => 'form_set_experiment'
  end

  def set_experiment_params
    @experiment = Experiment.find(params["id"])
    pm = {"mitcr_pset"    => params["mitcr_pset"], 
          "mitcr_species" => params["mitcr_species"], 
          "mitcr_gene"    =>params["mitcr_gene"], 
          "mitcr_cysphe"  =>params["mitcr_cysphe"], 
          "mitcr_ec"      =>params["mitcr_ec"], 
          "mitcr_quality" =>params["mitcr_quality"], 
          "mitcr_lq"      =>params["mitcr_lq"], 
          "mitcr_pcrec"   =>params["mitcr_pcrec"]} 
    @experiment.update_attributes(pm)

    # re-compute mitcr
    sub_experiments = @experiment.sub_experiments
    sub_experiments.each do |sub|
      sub.compute_mitcr
    end
    
  end
=end

  ####################################################################
  def jqgrid_list 
    
    index_columns ||= [:title, :created_at]
    current_page = params[:page] ? params[:page].to_i : 1
    rows_per_page = params[:rows] ? params[:rows].to_i : 20 

    conditions={:page => current_page, :per_page => rows_per_page}
    conditions[:order] = params["sidx"] + " " + params["sord"] unless (params[:sidx].blank? || params[:sord].blank?)
    
    if params[:_search] == "true"
      conditions[:conditions]=filter_by_conditions(index_columns)
    end

    @entries = current_user.experiments.paginate(conditions)
   
   total_entries=@entries.total_entries
   total_pages = total_entries/rows_per_page.to_i + 1


   @responce = {:page => current_page,:total=>total_pages , :records =>total_entries , :rows=>@entries} 

    respond_to do |format|
      format.json { render json: @responce }
    end

  end

  def experiment_detail
    @experiment       = Experiment.find(params[:id])
    @factor_num       = @experiment.factor_num
    @col_name         = @experiment.factor_name.split(",")

    render :partial => "experiment_detail"
  end
  def experiment_detail_design
    @experiment       = Experiment.find(params[:id])
    @experiment.write_exp_design

    @factor_num       = @experiment.factor_num
    @col_name         = @experiment.factor_name.split(",")
    @ex_method        = @experiment.read_tcr_extract_param

    case @experiment.extract_method
    when 'mitcr'
        @clone_method           = "MiTCR" 
        @target_sp              = @ex_method["mitcr_species"] == "hs" ? "Human":"Mouse" 
    when 'mixcr'
        @clone_method           = "MiXCR" 
        @target_sp              = @ex_method["mixcr_species"] == "hsa" ? "Human": "Mouse"
    when 'dcnt'
        @clone_method           = "Decombinator" 
        @target_sp              = @ex_method["dcnt_species"] == "human" ? "Human": "Mouse" 
    when 'cdr3'
        @clone_method           = "CDR3" 
    end

    render :partial => "experiment_detail_design"
  end

  def jqgrid_exp_design_list

    index_columns ||= [:sample_name,:sample_name_org,:sample_id,:factor1,:factor2,:factor3,:factor4,:factor5,:factor6,:factor7,:factor8,:factor9,:factor10,:created_at]
    current_page  = params[:page] ? params[:page].to_i : 1
    rows_per_page = params[:rows] ? params[:rows].to_i : 10000 

    conditions={:page => current_page, :per_page => rows_per_page}
    conditions[:order] = params["sidx"] + " " + params["sord"] unless (params[:sidx].blank? || params[:sord].blank?)

    if params[:_search] == "true"
      conditions[:conditions]=filter_by_conditions(index_columns)
    end
    experiment = Experiment.find(params[:exp_id])
    @entries = experiment.sub_experiments.paginate(conditions)
    @entries.length.times do |i|
        sample_id = @entries[i].sample_id
        sid = "" 
        if sample_id > 0
            sid = Sample.find(sample_id).sid
        end
      @entries[i].description = sid 
    end

    total_entries=@entries.total_entries
    total_pages = total_entries/rows_per_page.to_i + 1


    @responce = {:page => current_page,:total=>total_pages , :records =>total_entries , :rows=>@entries} 

    respond_to do |format|
      format.json { render json: @responce }
    end
  end
######################################################################################################
  #    pairwise analysis
  #
  def form_pairwaise_analysis_params
    @experiment = Experiment.find(params[:id])
    @samples    = []
    @experiment.sub_experiments.each do |sp|
      if sp.ex_clone 
        @samples << [sp.id, sp.sample_name]
      end
    end

    render :partial => 'form_pair_tcr_params'

  end

  def show_pairwaise_analysis_params

    @experiment = Experiment.find(params[:id])

    idx1 = params[:ids1].split(",")
    idx2 = params[:ids2].split(",")
    gps = [["1",idx1],["2",idx2]]
    gpd =   @experiment.group_details(gps)
    @groups ={     :title => @experiment.format_array_title(gpd[:data].length,"Groups",-1)  ,
                   :head  => gpd[:head], 
                   :body  => gpd[:data]}
    render :partial => "show_samples_groups.html.erb"
  end

  def pairwaise_analysis
   samples1 = params[:ids1].split(",").map{|id| SubExperiment.find(id)}
   samples2 = params[:ids2].split(",").map{|id| SubExperiment.find(id)}
   experiment = samples1[0].experiment

   idx1 = params[:ids1].split(",")
   idx2 = params[:ids2].split(",")
   gps = [["1",idx1],["2",idx2]]
   gpd =   experiment.group_details(gps)
   @groups ={     :title => experiment.format_array_title(gpd[:data].length,"Groups",-1)  ,
                   :head  => gpd[:head], 
                   :body  => gpd[:data]}
 



   @pair_names = {:names1=>samples1.map{|sp| sp.sample_name}, :names2=>samples2.map{|sp| sp.sample_name}}

   @url_fig_data       = "/experiments/json_fig_pairwaise_analysis.json?task=" + params[:task]
   @east_content       = 'east_content_data'

   n_disp = 99

   case params[:task]
     # Clonotypes distribution (nt)
   when 'cd_nt'
     r  = experiment.get_clonotypes_frequency_overlay(samples1,samples2,'nt')
     values = r[:dat] 
     @r2 = 'R<sup>2</sup> = '  + format("%4.3f",r[:r2])
     n_disp = values.length-1 if n_disp >= values.length
     data_head    = ["No.",  "sequence","Count 1", "Frequency 1","Count 2", "Frequency 2"] 
     url_download = "sub_experiment/" +  "cd_nt_overlay.csv"
     CSV.open( "public/" + url_download, "wb") do |csv|
       csv << data_head 
       values.each_with_index{|d,i| csv << [i+1,d[0],d[1][0],d[1][1],d[2][0],d[2][1]] }
     end
     data_body   = values[0..n_disp].each_with_index.map{|d,i|  [(i+1),d[0],d[1][0].to_s,format("%3.2e",d[1][1]),d[2][0].to_s,format("%3.2e",d[2][1])]}  
     @data_east           = {:title=> "Data details(" + (n_disp+1).to_s + "/" + values.length.to_s +  ")"  ,:head =>data_head,:body=>data_body,:url_download=> url_download ,:help => read_help("PTA_OA_CDNT")}
     @center_content     = 'fig_clonotypes_distribution'

          
     #Clonotypes distribution (aa)
   when 'cd_aa'
     r = experiment.get_clonotypes_frequency_overlay(samples1,samples2,'aa')
     values = r[:dat] 
     @r2 = 'R<sup>2</sup> = '  + format("%4.3f",r[:r2])
     n_disp = values.length-1 if n_disp >= values.length
     data_head    = ["No.",  "sequence","Count 1", "Frequency 1","Count 2", "Frequency 2"] 
     url_download = "sub_experiment/" +  "cd_aa_overlay.csv"
     CSV.open( "public/" + url_download, "wb") do |csv|
       csv << data_head 
       values.each_with_index{|d,i| csv << [i+1,d[0],d[1][0],d[1][1],d[2][0],d[2][1]] }
     end
     data_body   = values[0..n_disp].each_with_index.map{|d,i|  [(i+1).to_s, d[0],d[1][0].to_s,format("%3.2e",d[1][1]),d[2][0].to_s,format("%3.2e",d[2][1])]}  
     @data_east           = {:title=> "Data details(" + (n_disp+1).to_s + "/" + values.length.to_s +  ")",:head =>data_head,:body=>data_body,:url_download=> url_download ,:help => read_help("PTA_OA_CDAA")}
     @center_content     = 'fig_clonotypes_distribution'


     # Convergent analysis 
   when 'cvg'
     values = experiment.get_clonotypes_convergent_overlay(samples1,samples2)
     n_disp = values.length-1 if n_disp >= values.length
     data_head    = ["No.", "sequence",  "Count 1", "Frequency 1","Count 2", "Frequency 2","NT Count","NT sequences"] 
     url_download = "sub_experiment/" +  "cvg_overlay.csv"
     CSV.open( "public/" + url_download, "wb") do |csv|
       csv << data_head 
       values.each_with_index{|d,i| csv << [i+1,d[0],d[3][0],d[3][1],d[4][0],d[4][1],d[1],d[2].join(";")] }
     end
     data_body   = values[0..n_disp].each_with_index.map{|d,i|  [(i+1).to_s,d[0],d[3][0].to_s,format("%3.2e",d[3][1]),d[4][0].to_s,format("%3.2e",d[4][1]),d[1].to_s,d[2].join(";")]}  
     @data_east           = {:title=> "Data details(" + (n_disp+1).to_s + "/" + values.length.to_s +  ")",:head =>data_head,:body=>data_body,:url_download=> url_download ,:help => read_help("PTA_OA_CA")}
     @center_content     = 'fig_clonotypes_distribution'


     # Clonotypes distribution (nt)
   when 'cd_nt_un'
     dat = experiment.get_clonotypes_frequency_unoverlay(samples1,samples2,'nt')
     n_disp = dat[0].length-1 if n_disp >= dat[0].length
     data_head    = ["ID", "sequence","Count", "Frequency"] 
     url_download = "sub_experiment/" +  "cd_nt_unoverlay1.csv"
     CSV.open( "public/" + url_download, "wb") do |csv|
       csv << data_head 
       dat[0].each_with_index{|d,i| csv << [i+1,d[0],d[1],d[2]] }
     end
     data_body   = dat[0][0..n_disp].each_with_index.map{|d,i|  [i+1,d[0],d[1].to_s,format("%3.2e",d[2])]}  
     @data_east1           = {:title=> "Data details(Group1 " + (n_disp+1).to_s + "/" + dat[0].length.to_s +  ")",:head =>data_head,:body=>data_body,:url_download=> url_download ,:help => read_help("PTA_UA_CDNT")}

     url_download = "sub_experiment/" +  "cd_nt_unoverlay2.csv"
     CSV.open( "public/" + url_download, "wb") do |csv|
       csv << data_head 
       dat[1].each_with_index{|d,i| csv << [i+1,d[0],d[1],d[2]] }
     end
     data_body   = dat[1][0..n_disp].each_with_index.map{|d,i|  [i+1,d[0],d[1].to_s,format("%3.2e",d[2])]}  
     @data_east2           = {:title=> "Data details(Group2  " + (n_disp+1).to_s + "/" + dat[1].length.to_s +  ")",:head =>data_head,:body=>data_body,:url_download=> url_download ,:help => read_help("PTA_UA_CDNT")}

     @center_content     = 'fig_clonotypes_distribution_un'
     @east_content       = 'east_content_data2'

    


     #Clonotypes distribution (aa) 
   when 'cd_aa_un'
     dat = experiment.get_clonotypes_frequency_unoverlay(samples1,samples2,'aa')
     n_disp = dat[0].length-1 if n_disp >= dat[0].length
     data_head    = ["ID", "sequence","Count", "Frequency"] 
     url_download = "sub_experiment/" +  "cd_aa_unoverlay1.csv"
     CSV.open( "public/" + url_download, "wb") do |csv|
       csv << data_head 
       dat[0].each_with_index{|d,i| csv << [i+1,d[0],d[1],d[2]] }
     end
     data_body   = dat[0][0..n_disp].each_with_index.map{|d,i|  [i+1,d[0],d[1].to_s,format("%3.2e",d[2])]}  
     @data_east1           = {:title=> "Data details(Group1  " + (n_disp+1).to_s + "/" + dat[0].length.to_s +  ")",:head =>data_head,:body=>data_body,:url_download=> url_download ,:help => read_help("PTA_UA_CDAA")}

     url_download = "sub_experiment/" +  "cd_aa_unoverlay2.csv"
     CSV.open( "public/" + url_download, "wb") do |csv|
       csv << data_head 
       dat[1].each_with_index{|d,i| csv << [i+1,d[0],d[1],d[2]] }
     end
     data_body   = dat[1][0..n_disp].each_with_index.map{|d,i|  [i+1,d[0],d[1].to_s,format("%3.2e",d[2])]}  
     @data_east2           = {:title=> "Data details(Group2  " + (n_disp+1).to_s + "/" + dat[1].length.to_s +  ")",:head =>data_head,:body=>data_body,:url_download=> url_download ,:help => read_help("PTA_OA_CDAA")}

     @center_content     = 'fig_clonotypes_distribution_un'
     @east_content       = 'east_content_data2'

   else
   end

  end

  def json_fig_pairwaise_analysis


   cut_disp = 0.005
   case params[:task]
     # Clonotypes distribution (nt)

   when 'cd_nt'
     rfile = "public/sub_experiment/" +  "cd_nt_overlay.csv"
     data  = File.read(rfile) 
     data  = CSV.parse(data) 

     sub_experiment = SubExperiment.new
     clds_log = data[1..-1].map{|d| [Math.log10(d[2].to_f),Math.log10(d[4].to_f)]}
     clds_log_filter = clds_log  #sub_experiment.filter_data_by_dist(clds_log,0.001) 
     v = clds_log_filter.map{|d| {:x=>d[0],:y=>d[1],:size=>5}} 
     v << {:x=>v[-1][:x],:y=>v[-1][:y],:size=>1}
     data_send = [{:key=>"Clonotypes distribution",:values=> v }]





     #Clonotypes distribution (aa)
   when 'cd_aa'
     rfile = "public/sub_experiment/" +  "cd_aa_overlay.csv"
     data  = File.read(rfile) 
     data  = CSV.parse(data) 

     sub_experiment = SubExperiment.new
     clds_log = data[1..-1].map{|d| [Math.log10(d[2].to_f),Math.log10(d[4].to_f)]}
     clds_log_filter = clds_log  #sub_experiment.filter_data_by_dist(clds_log,cut_disp) 
     v = clds_log_filter.map{|d| {:x=>d[0],:y=>d[1],:size=>5}} 
     v << {:x=>v[-1][:x],:y=>v[-1][:y],:size=>1}
     data_send = [{:key=>"Clonotypes distribution",:values=> v }]



     # Convergent analysis 
   when 'cvg'
     rfile = "public/sub_experiment/" +  "cvg_overlay.csv"
     data  = File.read(rfile) 
     data  = CSV.parse(data) 

     sub_experiment  = SubExperiment.new
     clds_log        = data[1..-1].map{|d| [Math.log10(d[2].to_f),Math.log10(d[4].to_f),d[6].to_f]}
     clds_log_filter = clds_log  #sub_experiment.filter_data_by_dist(clds_log,cut_disp) 
     data_send       = [{:key=>"Clonotypes distribution",:values=>clds_log_filter.map{|d| {:x=>d[0],:y=>d[1],:size=>d[2]}}}]
     
     # Clonotypes distribution (nt)
   when 'cd_nt_un'
     rfile = "public/sub_experiment/" +  "cd_nt_unoverlay1.csv"
     data  = File.read(rfile) 
     data  = CSV.parse(data) 

     sub_experiment   = SubExperiment.new
     clds_log         = data[1..-1].map{|d| [Math.log10(d[0].to_f),Math.log10(d[3].to_f)]}
     clds_log_filter1 = sub_experiment.filter_data_by_dist(clds_log,cut_disp) 

     rfile = "public/sub_experiment/" +  "cd_nt_unoverlay2.csv"
     data  = File.read(rfile) 
     data  = CSV.parse(data) 

     clds_log = data[1..-1].map{|d| [Math.log10(d[0].to_f),Math.log10(d[3].to_f)]}
     clds_log_filter2 = sub_experiment.filter_data_by_dist(clds_log,cut_disp) 


     data_send = [{:key=>"Group1",:values=>clds_log_filter1.map{|d| {:x=>d[0],:y=>d[1]}}},
                  {:key=>"Group2",:values=>clds_log_filter2.map{|d| {:x=>d[0],:y=>d[1]}}}]
 

     #Clonotypes distribution (aa) 
   when 'cd_aa_un'
     rfile = "public/sub_experiment/" +  "cd_aa_unoverlay1.csv"
     data  = File.read(rfile) 
     data  = CSV.parse(data) 

     sub_experiment = SubExperiment.new
     clds_log       = data[1..-1].map{|d| [Math.log10(d[0].to_f),Math.log10(d[3].to_f)]}
     clds_log_filter1 = sub_experiment.filter_data_by_dist(clds_log,cut_disp) 

     rfile = "public/sub_experiment/" +  "cd_aa_unoverlay2.csv"
     data  = File.read(rfile) 
     data  = CSV.parse(data) 

     clds_log = data[1..-1].map{|d| [Math.log10(d[0].to_f),Math.log10(d[3].to_f)]}
     clds_log_filter2 = sub_experiment.filter_data_by_dist(clds_log,cut_disp) 


     data_send = [{:key=>"Group1",:values=>clds_log_filter1.map{|d| {:x=>d[0],:y=>d[1]}}},
                  {:key=>"Group2",:values=>clds_log_filter2.map{|d| {:x=>d[0],:y=>d[1]}}}]
 
   else
   end

   
   respond_to do |format|
      format.json { render json: data_send }
    end
  end


  ##############################################################
  #    whole tcr repertoire analysis
  def form_whole_tcr_analysis
    @experiment = Experiment.find(params[:id])
    @task       = params[:task]

   case @task 
   when 'mac'
     factors   = @experiment.factor_name.split(',')
     @factor_collection = (1..factors.length).map{|i| [factors[i-1],"factor" + i.to_s]}
     @factor_collection.unshift(["Sample name","sample_name"])

     @s_type = {:collect=> [['CDR3: amino acid','aa'],['CDR3: nucleotides acid ','nt']],:selected=>'aa' }
     render :partial => 'form_description_statistics'
 
   when 'csh'
     factors   = @experiment.factor_name.split(',')
     @factor_collection = (1..factors.length).map{|i| [factors[i-1],"factor" + i.to_s]}
     @factor_collection.unshift(["Sample name","sample_name"])

     @s_type = {:collect=> [['CDR3: amino acid','aa'],['CDR3: nucleotides acid ','nt'],['V segment','v'],['J segment','j']],:selected=>'aa' }
     render :partial => 'form_description_statistics'

   when 'ct'
     factors   = @experiment.factor_name.split(',')
     @factor_collection = (1..factors.length).map{|i| [factors[i-1],"factor" + i.to_s]}
     @factor_collection.unshift(["Sample name","sample_name"])

     @s_type = {:collect=> [['CDR3: amino acid','aa'],['CDR3: nucleotides acid ','nt']],:selected=>'aa' }
     render :partial => 'form_description_statistics'
    when 'oa'
     factors   = @experiment.factor_name.split(',')
     @factor_collection = (1..factors.length).map{|i| [factors[i-1],"factor" + i.to_s]}
     @factor_collection.unshift(["Sample name","sample_name"])

     @s_type = {:collect=> [['CDR3: amino acid','aa'],['CDR3: nucleotides acid ','nt']],:selected=>'aa' }
     @s_method = {:collect=> [['clonotype','ct'],['clonotype (normalize)','ctm'],['clone reads','cr'],['clone reads (normalize)','crm']],:selected=>'ct' }
 
     render :partial => 'form_overlap_analysis'
 
   when 'sig'
     factors   = @experiment.factor_name.split(',')
     @factor_collection = (1..factors.length).map{|i| [factors[i-1],"factor" + i.to_s]}
     @factor_collection.unshift(["Sample name","sample_name"])

     @s_type = {:collect=> [['CDR3: amino acid','aa'],['CDR3: nucleotides acid ','nt'],['V segment','v'],['J segment','j']],:selected=>'aa' }
     @s_method = {:collect=> [['Horn-Morisita','horn'],['Morisita Index','morisita'],['Jaccard Index','jaccard'],['Canberra Index','canberra'],['Bray-Curtis','bray'],['kulczynski','kulczynski'],['Raup-Crick index','raup'],['binomial','binomal'],['Cao Index','cao']],:selected=>'horn' }
     render :partial => 'form_sample_similarity_matrix'
 
   when 'sm'
    factors   = @experiment.factor_name.split(',')
     @factor_collection = (1..factors.length).map{|i| [factors[i-1],"factor" + i.to_s]}
     @factor_collection.unshift(["Sample name","sample_name"])

     @s_type = {:collect=> [['CDR3: amino acid','aa'],['CDR3: nucleotides acid ','nt'],['V segment','v'],['J segment','j']],:selected=>'aa' }
     @s_method = {:collect=> [['Horn-Morisita','horn'],['Morisita Index','morisita'],['Jaccard Index','jaccard'],['Canberra Index','canberra'],['Bray-Curtis','bray'],['kulczynski','kulczynski'],['Raup-Crick index','raup'],['binomial','binomal'],['Cao Index','cao']],:selected=>'horn' }
 
     render :partial => 'form_sample_similarity_matrix'


     #### Cluster analysis 
   when 'cl'
     factors   = @experiment.factor_name.split(',')
     @factor_collection = (1..factors.length).map{|i| [factors[i-1],"factor" + i.to_s]}
     @factor_collection.unshift(["Sample name","sample_name"])

     @s_type = {:collect=> [['CDR3: amino acid','aa'],['CDR3: nucleotides acid ','nt'],['V segment','v'],['J segment','j']],:selected=>'aa' }
     @s_method = {:collect=> [['Horn-Morisita','horn'],['Morisita Index','morisita'],['Jaccard Index','jaccard'],['Canberra Index','canberra'],['Bray-Curtis','bray'],['kulczynski','kulczynski'],['Raup-Crick index','raup'],['binomial','binomal'],['Cao Index','cao']],:selected=>'horn' }
 

     render :partial => 'form_sample_cluster_analysis'

 
     ####Pairwise similarity analysis
   when 'ps'
     @samples = @experiment.sub_experiments.where(:ex_clone => true)
     @s_type = {:collect=> [['CDR3: amino acid','aa'],['CDR3: nucleotides acid ','nt'],['V segment','v'],['J segment','j']],:selected=>'aa' }
     @s_method = {:collect=> [['Horn-Morisita','horn'],['Morisita Index','morisita'],['Jaccard Index','jaccard'],['Canberra Index','canberra'],['Bray-Curtis','bray'],['kulczynski','kulczynski'],['Raup-Crick index','raup'],['binomial','binomal'],['Cao Index','cao']],:selected=>'horn' }
 
     render :partial => 'form_pairwise_similarity_analysis'

     
     #### Bio-diversity index 
   when 'bdi'
     @s_type = {:collect=> [['CDR3: amino acid','aa'],['CDR3: nucleotides acid ','nt'],['V segment','v'],['J segment','j']],:selected=>'aa' }
     factors   = @experiment.factor_name.split(',')
     @factor_collection = (1..factors.length).map{|i| [factors[i-1],"factor" + i.to_s]}
     @factor_collection.unshift(["Sample name","sample_name"])

     @s_method = {:collect=> [['Shannon index','shan'],['Simpsons index','smp'],['Inverse Simpson index','ismp'],['Gini simpson index','gsi'],['Berger-Parker index','bpi'],['Renyi entropy','renyi']],:selected=>'shan' }
     render :partial => 'form_diversity_index'
    

     ####Significant Test
   when 'st'
     @s_type = {:collect=> [['CDR3: amino acid','aa'],['CDR3: nucleotides acid ','nt'],['V segment','v'],['J segment','j']],:selected=>'aa' }
     factors   = @experiment.factor_name.split(',')
     factor_collection = (1..factors.length).map{|i| [factors[i-1], "factor" + i.to_s]}
     @factor   = {:collect=> factor_collection,:selected=>factor_collection[0][1]}
     @s_method = {:collect=> [['Shannon index','shan'],['Simpsons index','smp'],['Inverse Simpson index','ismp'],['Gini simpson index','gsi'],['Berger-Parker index','bpi'],['Renyi entropy','renyi']],:selected=>'shan' }
     render :partial => 'form_dv_sig_test'


     ####Pairwise diversity analysis
   when 'pda'
     @samples = @experiment.sub_experiments.where(:ex_clone => true)
     @s_method = {:collect=> [['Shannon index','shan'],['Simpsons index','smp'],['Inverse Simpson index','ismp'],['Gini simpson index','gsi'],['Berger-Parker index','bpi'],['Renyi entropy','renyi']],:selected=>'shan' }
     @s_type = {:collect=> [['CDR3: amino acid','aa'],['CDR3: nucleotides acid ','nt'],['V segment','v'],['J segment','j']],:selected=>'aa' }
 
     render :partial => 'form_pairwise_diversity_analysis'


   end


  end

  def whole_tcr_analysis
    @experiment = Experiment.find(params[:id])
    @task       = params[:task]
    @err        = false 

   case @task 
   when 'mac'
     gps = @experiment.get_group_samples_id_by_factor(params[:factor_ids])
     r   = @experiment.top_proportion(gps,params[:s_type])   
     url_file   = 'top_proportion.csv'
     @data_east = {:title => @experiment.format_array_title(r[:data].length,"Top Proportion",-1)  ,
                   :head  => r[:head], 
                   :body  => r[:data],
                   :help  => read_help("WTRA_DS_MAC"),
                   :url_download => File.join(@experiment.file_download_root,url_file)}
     @east_content  =  "east_content_data.html.erb" 
     @experiment.write_file_for_download({:head=>r[:head],:data=>r[:data],:fn=>url_file})

     gpd =   @experiment.group_details(gps)
     @groups ={     :title => @experiment.format_array_title(gpd[:data].length,"Groups",-1)  ,
                   :head  => gpd[:head], 
                   :body  => gpd[:data]}


     @center_content2 = "show_samples_groups.html.erb" 
     @center_content = "fig_top_proportion.html.erb" 

     ####  for plot
     cfile = "public/experiment/" + params[:id] +  "/top_data"
     open(cfile, 'w') { |f| f << r[:data_fig].to_json }
     @url_fig_data = "/experiments/json_whole_tcr_analysis.json?id=" + params[:id] + "&task=" + params[:task]

   when 'csh'
     gps = @experiment.get_group_samples_id_by_factor(params[:factor_ids])
     r   = @experiment.clone_space(gps,params[:s_type])   
     url_file   = 'clone_space.csv'
     @data_east = {:title => @experiment.format_array_title(r[:data].length,"Top Proportion",-1)  ,
                   :head  => r[:head], 
                   :body  => r[:data],
                   :help  => read_help("WTRA_DS_CSH"),
                   :url_download => File.join(@experiment.file_download_root,url_file)}
     @east_content  =  "east_content_data.html.erb" 
     @experiment.write_file_for_download({:head=>r[:head],:data=>r[:data],:fn=>url_file})

     gpd =   @experiment.group_details(gps)
     @groups ={     :title => @experiment.format_array_title(gpd[:data].length,"Groups",-1)  ,
                   :head  => gpd[:head], 
                   :body  => gpd[:data]}


     @center_content2 = "show_samples_groups.html.erb" 
     @center_content = "fig_top_proportion.html.erb" 

     ####  for plot
     cfile = "public/experiment/" + params[:id] +  "/clone_space_data"
     open(cfile, 'w') { |f| f << r[:data_fig].to_json }
     @url_fig_data = "/experiments/json_whole_tcr_analysis.json?id=" + params[:id] + "&task=" + params[:task]


   when 'ct'
     gps = @experiment.get_group_samples_id_by_factor(params[:factor_ids])
     r   = @experiment.clonotype_tracking(gps,params[:s_type])   
     url_file   = 'clonotype_tracking.csv'
     @data_east = {:title => @experiment.format_array_title(r[:data].length,"Colonotype tracking",100)  ,
                   :head  => r[:head], 
                   :body  => r[:data],
                   :help  => read_help("WTRA_DS_CT"),
                   :url_download => File.join(@experiment.file_download_root,url_file)}
     @east_content  =  "east_content_data.html.erb" 
     @experiment.write_file_for_download({:head=>r[:head],:data=>r[:data],:fn=>url_file})

     gpd =   @experiment.group_details(gps)
     @groups ={     :title => @experiment.format_array_title(gpd[:data].length,"Groups",-1)  ,
                   :head  => gpd[:head], 
                   :body  => gpd[:data]}


     @center_content2 = "show_samples_groups.html.erb" 
     @center_content  = "fig_clonotype_tracking.html.erb" 

     ####  for plot
     cfile = "public/experiment/" + params[:id] +  "/clonotype_tracking"
     open(cfile, 'w') { |f| f << r[:data_fig].to_json }
     @url_fig_data = "/experiments/json_whole_tcr_analysis.json?id=" + params[:id] + "&task=" + params[:task]

   when 'oa'
     gps  = @experiment.get_group_samples_id_by_factor(params[:factor_ids])
     r    = @experiment.overlap_analysis(params[:s_type],params[:s_method],gps)

     url_file   = 'overlap.csv'
     @data_east = {:title => @experiment.format_array_title(r[:data].length,"Similarity",-1)  ,
                   :head  => r[:head], 
                   :body  => r[:data],
                   :help  => read_help("WTRA_DS_OA"),
                   :url_download => File.join(@experiment.file_download_root,url_file)}
     @east_content  =  "east_content_data.html.erb" 
     @experiment.write_file_for_download({:head=>r[:head],:data=>r[:data],:fn=>url_file})

     gpd =   @experiment.group_details(gps)
     @groups ={     :title => @experiment.format_array_title(gpd[:data].length,"Groups",-1)  ,
                   :head  => gpd[:head], 
                   :body  => gpd[:data]}

     @center_content2 = "show_samples_groups.html.erb" 
     @center_content     = 'fig_similarity_matrix'

     ####  for plot
     cfile = "public/experiment/" + params[:id] +  "/oa_data"
     open(cfile, 'w') { |f| f << r[:data_fig].to_json }
     @url_fig_data = "/experiments/json_whole_tcr_analysis.json?id=" + params[:id] + "&task=" + params[:task]


    # similarity within groups 
   when 'sig'
     gps        = @experiment.get_group_samples_id_by_factor(params[:factor_ids])
     data_sim   = @experiment.get_similarity_within_group(params[:s_type],params[:s_method],gps)
     url_file   = 'sim.csv'
     @data_east = {:title => @experiment.format_array_title(data_sim[:data].length,"Similarity",-1)  ,
                   :head  => data_sim[:head], 
                   :body  => data_sim[:data],
                   :help  => read_help("WTRA_SA_SIG"),
                   :url_download => File.join(@experiment.file_download_root,url_file)}
     @east_content  =  "east_content_data.html.erb" 
     @experiment.write_file_for_download({:head=>data_sim[:head],:data=>data_sim[:data],:fn=>url_file})

     gpd =   @experiment.group_details(gps)
     @groups ={     :title => @experiment.format_array_title(gpd[:data].length,"Groups",-1)  ,
                   :head  => gpd[:head], 
                   :body  => gpd[:data]}


     @center_content2 = "show_samples_groups.html.erb" 
     @center_content = "fig_similarity_within_group.html.erb" 



     ####  for plot
     cfile = "public/experiment/" + params[:id] +  "/sim_data"
     r  = {:xlabel=>"Groups",:ylable=>"Mean similarity",:data=>[{:key=>"Similarity within groups",:values=> data_sim[:data].each_with_index.map{|v,i| [(i+1).to_s, v[1] ]}}]}
     open(cfile, 'w') { |f| f << r.to_json }
     @url_fig_data = "/experiments/json_whole_tcr_analysis.json?id=" + params[:id] + "&task=" + params[:task]

     #  Samples similarity matrix
   when 'sm'
     gps         = @experiment.get_group_samples_id_by_factor(params[:factor_ids])
     r    = @experiment.get_samples_similarity_matrix(params[:s_type],params[:s_method],gps)

     url_file   = 'similarity.csv'
     @data_east = {:title => @experiment.format_array_title(r[:data].length,"Similarity",-1)  ,
                   :head  => r[:head], 
                   :body  => r[:data],
                   :help  => read_help("WTRA_SA_SSM"),
                   :url_download => File.join(@experiment.file_download_root,url_file)}
     @east_content  =  "east_content_data.html.erb" 
     @experiment.write_file_for_download({:head=>r[:head],:data=>r[:data],:fn=>url_file})

     gpd =   @experiment.group_details(gps)
     @groups ={     :title => @experiment.format_array_title(gpd[:data].length,"Groups",-1)  ,
                   :head  => gpd[:head], 
                   :body  => gpd[:data]}

     @center_content2 = "show_samples_groups.html.erb" 
     @center_content     = 'fig_similarity_matrix'

     ####  for plot
     cfile = "public/experiment/" + params[:id] +  "/sm_data"
     open(cfile, 'w') { |f| f << r[:data_fig].to_json }
     @url_fig_data = "/experiments/json_whole_tcr_analysis.json?id=" + params[:id] + "&task=" + params[:task]



     #### Cluster analysis 
   when 'cl'
     gps         = @experiment.get_group_samples_id_by_factor(params[:factor_ids])
     @par        = {:sim => params[:sim].to_i, :cluster=> params[:cluster].to_i,  :s_method => params[:s_method], :s_type=>params[:s_type]} 
     r     = @experiment.get_cluster_result(gps,@par)
     cfile = "public/experiment/" + params[:id] +  "/clust_data"
     open(cfile, 'w') { |f| f << r.to_json }

     @url_fig_data = "/experiments/json_whole_tcr_analysis.json?id=" + params[:id] + "&task=" + params[:task]
     @east_content       = 'blank'
     @center_content     = 'fig_clust'

     gpd =   @experiment.group_details(gps)
     @groups ={     :title => @experiment.format_array_title(gpd[:data].length,"Groups",-1)  ,
                   :head  => gpd[:head], 
                   :body  => gpd[:data]}

     @center_content2 = "show_samples_groups.html.erb" 
 
     ####Pairwise similarity analysis
   when 'ps'
     r  = @experiment.pairwise_analysis(params)

     d1 = r[:org][:s1].each_with_index.map{|row,i| row.map{|s| s.map{|id| SubExperiment.find(id).sample_name}.join(",")} + [r[:v][0][i]] }
     d2 = r[:org][:s2].each_with_index.map{|row,i| row.map{|s| s.map{|id| SubExperiment.find(id).sample_name}.join(",")} + [r[:v][1][i]] }

     t_method = "t Test (parametric)"
     t_method = "Wilcoxon Test (non-parametric)" if params[:t_method] == "1"
     paired = "Yes"
     paired = "No"  if params[:paired] == "0" 


     @data = {:desc=>[d1,d2],:head=>["Sample 1","Sample 2","similarity"],:p=>r[:p],:t_method=>t_method,:paired=>paired }
     @east_content    = "blank"
     @center_content  = "fig_box_plot"
     @center_content2 = "show_pairwise_analysis"

     ####  for plot
     cfile = "public/experiment/" + params[:id] +  "/psa_data"
     r1  = {:d=> [["Group 1",r[:v][0]],["Group 2",r[:v][1]]],:ylabel=> "Pairwise similarity" }
     open(cfile, 'w') { |f| f << r1.to_json }

     @url_fig_data = "/experiments/json_whole_tcr_analysis.json?id=" + params[:id] + "&task=" + params[:task]


     
     #### Bio-diversity index 
   when 'bdi'
     gps         = @experiment.get_group_samples_id_by_factor(params[:factor_ids])
     par = {:s_type=>params[:s_type],:s_method=>params[:s_method],:q_value=>params[:q_value].to_f}
     data_div   = @experiment.get_samples_diversity(par,gps)
     url_file   = 'diversity.csv'
     @data_east = {:title => @experiment.format_array_title(data_div[:data].length, "Diversity",-1)  ,
                   :head  => data_div[:head], 
                   :body  => data_div[:data],
                   :help  => read_help("WTRA_DA_BDI"),
                   :url_download => File.join(@experiment.file_download_root,url_file)}
     @east_content  =  "east_content_data.html.erb" 
     @experiment.write_file_for_download({:head=>data_div[:head],:data=>data_div[:data],:fn=>url_file})

     gpd =   @experiment.group_details(gps)
     @groups ={     :title => @experiment.format_array_title(gpd[:data].length,"Groups",-1)  ,
                   :head  => gpd[:head], 
                   :body  => gpd[:data]}
     @center_content2 = "show_samples_groups.html.erb" 
     @center_content     = 'fig_diversity_index'

     ####  for plot
     cfile = "public/experiment/" + params[:id] +  "/diversity_data"
     r  = {:xlabel=>"Groups",:ylabel=>"Mean diversity",:data=>[{:key=>"Diversity index",:values=> data_div[:data]}]}
     open(cfile, 'w') { |f| f << r.to_json }

     @url_fig_data = "/experiments/json_whole_tcr_analysis.json?id=" + params[:id] + "&task=" + params[:task]

     ####Significant Test
   when 'st'
     samples = @experiment.sub_experiments.select{|s| s.sample_id > 0}
     id_fac  = samples.map{|s| [s.id, s[ params[:factor] ]] }
     par     = {:s_type=>params[:s_type],:s_method=>params[:s_method],:q=>params[:q_value].to_f}
     r   = @experiment.diversity_significant_test(par,id_fac)

     values = (0...id_fac.length).to_a.map{|i| [samples[i].sample_name, r[:data][:facs][i], r[:data][:v][i]]} 
     headt  = ["Sample name","","Diversity"]
     flag   = r[:flag]
     url_file = "diversity.csv"
     @data_east = {:title => @experiment.format_array_title(values.length,"Diverstity",-1)  ,
                   :head  => headt, 
                   :body  => values,
                   :help  => read_help("WTRA_DA_ST"),
                   :url_download => File.join(@experiment.file_download_root,url_file)}
     @east_content  =  "blank" 
     @center_content2  =  "blank" 
     @experiment.write_file_for_download({:head=>headt,:data=>values,:fn=>url_file})

     if flag  ### data right
       #### for show result
       @data = {:p=>r[:data][:p] }
       @center_content     = 'show_diversity_sig_test'
     else
       @err = true
       @center_content     = 'blank'
       @str_err = r[:msg]
     end

     ####Pairwise diversity analysis
   when 'pda'
     r  = @experiment.pairwise_diversity_analysis(params)
     d1 = params[:s1].split(";").each_with_index.map{|ss,i| [ss.split(",").map{|id|  SubExperiment.find(id).sample_name }.join(";")] + [r[:v][0][i]] } 
     d2 = params[:s2].split(";").each_with_index.map{|ss,i| [ss.split(",").map{|id|  SubExperiment.find(id).sample_name }.join(";")] + [r[:v][1][i]]} 

     t_method = "t Test (parametric)"
     t_method = "Wilcoxon Test (non-parametric)" if params[:t_method] == "1"
     paired = "Yes"
     paired = "No"  if params[:paired] == "0" 
     @data = {:desc=>[d1,d2],:head=>["Samples","Diversity"],:p=>r[:p],:t_method=>t_method,:paired=>paired }
     @east_content    = "blank"
     @center_content  = "fig_box_plot"
     @center_content2 = "show_pairwise_analysis"

     ####  for plot
     cfile = "public/experiment/" + params[:id] +  "/pda_data"
     r1  = {:d=> [["Group 1",r[:v][0]],["Group 2",r[:v][1]]],:ylabel=> "Diversity" }
     open(cfile, 'w') { |f| f << r1.to_json }

     @url_fig_data = "/experiments/json_whole_tcr_analysis.json?id=" + params[:id] + "&task=" + params[:task]

   end



  end


  def json_whole_tcr_analysis
    @experiment = Experiment.find(params[:id])
    @task       = params[:task]

   case @task 
   when 'mac'
     cfile = "public/experiment/" + params[:id] +  "/top_data"
     data_send = ""
     open(cfile) { |f| data_send = f.read }
   when 'csh'
     cfile = "public/experiment/" + params[:id] +  "/clone_space_data"
     data_send = ""
     open(cfile) { |f| data_send = f.read }
    when 'ct'
     cfile = "public/experiment/" + params[:id] +  "/clonotype_tracking"
     data_send = ""
     open(cfile) { |f| data_send = f.read }
    when 'oa' 
     cfile = "public/experiment/" + params[:id] +  "/oa_data"
     data_send = ""
     open(cfile) { |f| data_send = f.read }

     #  Similarity within groups 
   when 'sig'
     cfile = "public/experiment/" + params[:id] +  "/sim_data"
     data_send = ""
     open(cfile) { |f| data_send = f.read }


     #  Samples similarity matrix
   when 'sm'
     cfile = "public/experiment/" + params[:id] +  "/sm_data"
     data_send = ""
     open(cfile) { |f| data_send = f.read }


     #### Cluster analysis 
   when 'cl'
     cfile = "public/experiment/" + params[:id] +  "/clust_data"
     data_send = ""
     open(cfile) { |f| data_send = f.read }

 
     ####Pairwise similarity analysis
   when 'ps'
     cfile = "public/experiment/" + params[:id] +  "/psa_data"
     data_send = ""
     open(cfile) { |f| data_send = f.read }


     
     #### Bio-diversity index 
   when 'bdi'
     cfile = "public/experiment/" + params[:id] +  "/diversity_data"
     data_send = ""
     open(cfile) { |f| data_send = f.read }

     ####Significant Test
   when 'st'


     ####Pairwise diversity analysis
   when 'pda'
     cfile = "public/experiment/" + params[:id] +  "/pda_data"
     data_send = ""
     open(cfile) { |f| data_send = f.read }



   end

   respond_to do |format|
      format.json { render json: data_send  if data_send.class == Hash
                    render text: data_send  if data_send.class == String }
    end

  end


  def extract_clone
    experiment = Experiment.find(params[:id]) 
    sub_experiments  = experiment.sub_experiments.where("sample_id > 0 and  ex_clone = false")
    par = experiment.read_tcr_extract_param
    if sub_experiments.length > 0 
      sub_experiments.each do |sub_exp|
        flag = sub_exp.extract_cdr3(par)
        unless flag
          @msg =  " Error in parse sample " + sub_exp.sample_name  
          return
        end
      end
      @msg =  "Extract clone complete !"
    else
      @msg =  "No file need to be computed !"
    end

  end
end
