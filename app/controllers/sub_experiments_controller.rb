require 'fileutils'
require 'csv'


class SubExperimentsController < ApplicationController
  # GET /sub_experiments
  # GET /sub_experiments.json
  def index
    respond_to do |format|
      if current_user
        format.html # index.html.erb
      else
        format.html { redirect_to root_path}
      end
    end
 end


  # GET /sub_experiments/1
  # GET /sub_experiments/1.json
  def show
    @sub_experiment = SubExperiment.find(params[:id])
    render :partial => 'display_board', :locals => {:sub_experiment => @sub_experiment} 

  end

  # GET /sub_experiments/new
  # GET /sub_experiments/new.json
  def new
    @sub_experiment = SubExperiment.new
    render :partial => 'form'
  end

  # GET /sub_experiments/1/edit
  def edit
    @sub_experiment = SubExperiment.find(params[:id])
    render :partial => 'form_edit' 
  end

  # PUT /sub_experiments/1
  # PUT /sub_experiments/1.json
  def update
    @sub_experiment = SubExperiment.find(params[:id])
    @sub_experiment.update_attributes(params[:sub_experiment])
    @experiment = Experiment.find(session[:experiment_id])
    @sub_experiments = @experiment.sub_experiments

    respond_to do |format|
      format.js
    end
  end

  # DELETE /sub_experiments/1
  # DELETE /sub_experiments/1.json
  def destroy
    @sub_experiment = SubExperiment.find(params[:id])

    dir_path = "public/sub_experiment/" + @sub_experiment.id.to_s 
    if Dir.exist?(dir_path)
      FileUtils.remove_dir dir_path
    end
    @sub_experiment.destroy
  end


  def jqgrid_list 
    id = params[:id].to_i
    if id > 0
      session[:experiment_id]= id 

      index_columns ||= [:title, :created_at]
      current_page = params[:page] ? params[:page].to_i : 1
      rows_per_page = params[:rows] ? params[:rows].to_i : 20 

      conditions={:page => current_page, :per_page => rows_per_page}
      conditions[:order] = params["sidx"] + " " + params["sord"] unless (params[:sidx].blank? || params[:sord].blank?)

      if params[:_search] == "true"
        conditions[:conditions]=filter_by_conditions(index_columns)
      end

      exp = Experiment.find(params[:id])
      subs = exp.sub_experiments.paginate(conditions)

      total_entries=subs.total_entries
      total_pages = total_entries/rows_per_page.to_i + 1

      @entries = []
      subs.each do |sub|
        file_flag = 'No'
        file_flag = 'Yes' if sub.sample_id > 0
        clone_flag = 'No'
        clone_flag = 'Yes' if sub.ex_clone 

        @entries << {:id=>sub.id,:name=>sub.sample_name,:name_org=>sub.sample_name_org,:file=>file_flag,:clone=>clone_flag}
      end

      @responce = {:page => current_page,:total=>total_pages , :records =>total_entries , :rows=>@entries} 
    else
      @responce = {:page => 1,:total=>1 , :records =>0 , :rows=>[]} 
    end

    respond_to do |format|
      format.json { render json: @responce }
    end

  end

  def form_upload_sample_file
    @sub_experiment = SubExperiment.find(params[:id])

    if @sub_experiment.sample_id > 0
      render  :text => "exist"
    else
      render :partial => 'form_upload_sample'
    end
  end


  ##########  unused function ###############################
  def upload_sample_file
    @sub_experiment = SubExperiment.find(params[:id])

    dir_path = "public/sub_experiment/" + @sub_experiment.id.to_s 

    if @sub_experiment.sample_id > 0
      FileUtils.remove_dir dir_path
    end
    unless Dir.exist?(dir_path)
      Dir.mkdir(dir_path)
    end

    pt   = params[:sub_experiment][:file]  
    file = File.join(dir_path, "sample.fastq")
    FileUtils.cp pt.tempfile.path, file

#  ... # YOUR PARSING JOB
#date analysis
    @flag = @sub_experiment.extract_cdr3

    if @flag 
      @sub_experiment.compute_fastqc
      @sub_experiment.update_attributes(:file_flag=>true)
    else
      FileUtils.remove_dir dir_path
    end
  end

  ##########  unused function ###############################
  def del_sample_file 
    @sub_experiment = SubExperiment.find(params[:id])

    dir_path = "public/sub_experiment/" + @sub_experiment.id.to_s 
    if @sub_experiment.sample_id > 0
      FileUtils.remove_dir dir_path
      @sub_experiment.update_attributes(:file_flag=>false)
      render :js=>"$('#grid_sub_experiment').jqGrid().trigger('reloadGrid');alert('File has been deleted!')"
    else
      render :js=>"alert('There no file uploaded!')"
    end
  end

  def download_sample_file
    @sub_experiment = SubExperiment.find(params[:id])
    file = "public/sub_experiment/" + @sub_experiment.id + "/sample.fastq"

    if @sub_experiment.sample_id > 0
      send_file(file,:filename => 'sample.fastq') 
#      data = File.read(file) 
#      send_data data, :filename => 'sample.fastq'
    else
      render :js => "alert('There is no file available.')"

    end
  end

  def sample_details
    @sub_experiment = SubExperiment.find(params[:id])
    @experiment     = @sub_experiment.experiment
    @factor_name    = @experiment.factor_name.split(',')
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



    dir_path = File.join("public","sub_experiment",@sub_experiment.id.to_s)
    if @sub_experiment.sample_id > 0
      dir_path = "sub_experiment/" + @sub_experiment.id.to_s + "/" 

      file =  "public/sub_experiment/" + @sub_experiment.id.to_s + "/fastqc_data.txt"
      data = File.read(file) 
      data = data.split("\n")
      data = data[6].split("\t")
      @raw_reads = data[1]
    end
    if @sub_experiment.ex_clone
      @sample_desc   = @sub_experiment.sample_detail
    end

   @down_url = {:cdata=> dir_path + "cdr3_extract.csv",:fastqc=> dir_path + "fastqc_data.txt"};
   render :partial => 'sample_details'
  end


###############################################################################################
 

 def form_new_sample
   @experiment     = Experiment.find(params[:id]) 
   @sub_experiment = SubExperiment.new 
   @sub_experiment.experiment_id = @experiment.id
   @samples = current_user.samples.map{|d| [d.sid + '  ' + d.title, d.id] }




   @action         =  "new_sample"
   @factor_name    =  @experiment.factor_name.split(',')
   @factor = []
   @factor_name.each_with_index do |v,i| 
     @factor << "factor" + (i+1).to_s 
   end

   @factor_type    = []
   @factor_sel     = []
   @factor_name.each_with_index do |v,i|
      t = @experiment["factor" + (i+1).to_s]
      t = t.split(',')
      t = t.map{|s| [s,s]}
      @factor_type << t 
      @factor_sel   << '' 
   end
   render :partial => "form_rename_sample"
 end

 def new_sample
   experiment = Experiment.find(params[:exp_id])
   par = {}
   par["sample_name"] = params[:name]
   par["sample_name_org"]=params[:name_org]
   par["sample_id"]  = params[:sample_id]
   experiment.factor_num.times do |i|
     par["factor" + (i+1).to_s] = params["factor" + (i+1).to_s]
   end

   sub_experiment               = SubExperiment.new(par)
   sub_experiment.experiment_id = experiment.id
   sub_experiment.save
   ###  mkdir and copy qc file
   dir_path  = "public/sub_experiment/" + sub_experiment.id.to_s
   file_path = "public/samples/" + sub_experiment.sample_id.to_s + "/sample_fastqc/fastqc_data.txt"
   if Dir.exist?(dir_path)
     FileUtils.remove_dir dir_path
   end
   Dir.mkdir(dir_path)
   FileUtils.cp  file_path,  dir_path + "/fastqc_data.txt" 

 end

 #####  edit_sub_experiment
 def form_rename_sample
   @sub_experiment =  SubExperiment.find(params[:id])
   @experiment     =  @sub_experiment.experiment
   @samples = current_user.samples.map{|d| [d.sid + '  ' + d.title, d.id] }
   @action         =  "rename_sample"
   @factor_name    =  @experiment.factor_name.split(',')
   @factor = []
   @factor_name.each_with_index do |v,i| 
     @factor << "factor" + (i+1).to_s 
   end

   @factor_type    = []
   @factor_sel     = []
   @factor_name.each_with_index do |v,i|
      t = @experiment["factor" + (i+1).to_s]
      t = t.split(',')
      t = t.map{|s| [s,s]}
      @factor_type << t 
      @factor_sel   << @sub_experiment["factor" + (i+1).to_s]
   end


   render :partial => "form_rename_sample"
 end

 #####  edit_sub_experiment
 def rename_sample
   @sub_experiment = SubExperiment.find(params[:id])
   experiment     =  @sub_experiment.experiment
   par = {}
   par["sample_name"]     = params[:name]
   par["sample_name_org"] = params[:name_org]
   par["sample_id"]       = params[:sample_id]
   experiment.factor_num.times do |i|
     par["factor" + (i+1).to_s] = params["factor" + (i+1).to_s]
   end

   if params[:sample_id].to_i != @sub_experiment.sample_id 
     ###  mkdir and copy qc file
     dir_path  = "public/sub_experiment/" + @sub_experiment.id.to_s
     file_path = "public/samples/" +  params[:sample_id] + "/sample_fastqc/fastqc_data.txt"
     if Dir.exist?(dir_path)
       FileUtils.remove_dir dir_path
     end
     Dir.mkdir(dir_path)
     FileUtils.cp  file_path,  dir_path + "/fastqc_data.txt" 

     ####  set clone 
     par["ex_clone"] = false
   end

   @sub_experiment.update_attributes(par)
 end

 def del_sample
   @sub_experiment = SubExperiment.find(params[:id])
   dir_path = "public/sub_experiment/" + @sub_experiment.id.to_s 
   if Dir.exist?(dir_path) 
      FileUtils.remove_dir dir_path
   end
   @sub_experiment.destroy

   render :text => "OK"
 end


################################################################################################
####   Sequencing Qualify  ####################################################################

 def qc_analysis

   @sub_experiment = SubExperiment.find(params[:id])
   @experiment     = @sub_experiment.experiment
   id       = params[:id]
   @item     = params[:item].to_i

   if @sub_experiment.sample_id > 0 || @sub_experiment.ex_clone == true

     ##  param for different tasks
     case @item 
     when 2
     when 3 
       @title      = "Quality Score distribution" 
       @fig_render = "fig_sequence_quality"
       decimal    = 0 
       help = "SQ_SQ"
     when 4 
       @title      = "Base Sequence Content" 
       @fig_render = "fig_base_sequence_content"
       decimal    = 2 
       help = "SQ_BSC"
     when 5
       @title      = "GC base Sequence Content" 
       @fig_render = "fig_base_sequence_content"
       decimal    = 2 
       help = "SQ_GC"
     when 6
     when 7
     when 8
       @title      = "GC base Sequence Content" 
       @fig_render = "fig_seq_length_distribution"
       decimal    = 0 
       help = "SQ_LEN"
     when 9 
     else
     end

     ###########  center 
     @url  = "/sub_experiments/json_qc_fig_data.json?id=" + params[:id] + "&item=" + params[:item] 
     @fig_flag  = true
     case @item
     when 1,10
       @fig_flag = false
     end


    ##########  east
     r = @sub_experiment.read_fastqc_result(@item)
     @status     = r["status"]
     d = r["data_table"]
     data = CSV.parse(d, {:col_sep => "\t"}) 

    #write to file for download 
     url_download = "sub_experiment/" + @sub_experiment.id.to_s + "/qc_data.csv"
     CSV.open( "public/" + url_download, "wb") do |csv|
       data.each{|d| csv << d }
     end


     data_head   = data[0]
     data_body_t = data[1..-1]
     data_body   = []
     data_body_t.each do |dd|
        t =  dd[1..-1].map{|d| format("%." + decimal.to_s + "f",d.to_f)}
        t.unshift(dd[0])
        data_body << t
     end
=begin
     #qc help
     d = File.read("public/fastaqc_help") 
     d.gsub!("\n"," ")
     d = d.split("####")
     if @item == 1
       qc_help = " " 
     else
       qc_help = d[@item-2]
     end
=end
      
     @data_east = {:title => "Data Details",:head => data_head,:body=> data_body,:url_download => url_download, :help=>read_help(help)}


#    @fig_render = "display_qc_result"

   else
     render :js => "alert('There is no file for the sample selected.Please upload sample file firstly!')"
   end
 end

 def json_qc_fig_data
   @sub_experiment = SubExperiment.find(params[:id])
   file  =  "public/sub_experiment/" + params[:id] + "/sample_fastqc/fastqc_data.txt"
   r     = @sub_experiment.read_fastqc_result(params[:item].to_i)
   d    = r["data_table"]

   data = CSV.parse(d, {:col_sep => "\t"}) 
   data_head = data[0]
   data_body = data[1..-1]
   n_row = data_body.size
   n_col = data_head.size


   x_axis_label = []
   n_row.times do |j|
      x_axis_label << data_body[j][0]
   end

   data = []
   (n_col-1).times do |i|
       data_line = []
       n_row.times do |j|
          data_line << [j, data_body[j][i+1].to_f] 
       end
       data << {:key=>data_head[i+1],:values=>data_line}
   end

   title  = ""
   xlabel = ""
   ylabel = ""
   yscale = [] 
   
   case params[:item].to_i 
   when 2
     title  = "Quality score across all bases(Sanger / illumina 1.0 encoding)"
     xlabel = "Position in read(bp)"
     yscale = [0,42] 
   when 3 
     title  = "Quality score distribution over all sequences" 
     xlabel = "Mean Sequence Quality(Phred Score)"
   when 4 
     title  = "Sequence content across all bases" 
     xlabel = "Position in read(bp)"
     yscale = [0,100] 
   when 5
     title  = "GC content across all bases" 
     xlabel = "Position in read(bp)"
     yscale = [0,100] 
   when 6
     title  = "GC content across all sequence" 
     xlabel = "Position in read(bp)"
   when 7
     title  = "N content across all bases" 
     xlabel = "Position in read(bp)"
     yscale = [0,100] 
   when 8
     title  = "Distribution of sequence lengths over all sequences" 
     xlabel = "Position in read(bp)"
   when 9 
     title  = "Sequence Duplication Levels" 
     xlabel = "Sequence Duplication level"
     yscale = [0,100] 
   else

   end
   data_send = {:data=>data,:title => title,:xlabel=>xlabel,:ylabel=>ylabel,:yscale=>yscale,:xaxislabel=>x_axis_label}

    respond_to do |format|
      format.json { render json: data_send }
    end
 end




  #################################################################################################
 #  Single Sample TCR analysis  
 def single_sample_tcr_analysis
   @sub_experiment = SubExperiment.find(params[:id])
   task  = params[:task]

   unless @sub_experiment.ex_clone 
     render :js => "alert('There is no clone file for the sample selected !')"
     return
   end

   @url_fig_data       = "/sub_experiments/json_fig_single_sample_tcr_analysis.json?id=" + params[:id] + "&task=" + task
   @east_content       = 'east_content_data'

   cut_disp = 0.005
   n_disp = 100
   cfile     = "public/fig_data"

   case  task
   #TRBV Usage
   when  'v'  
     values       = @sub_experiment.seg_usage_statistics('v') 
     data_head    = ["TRBV Segment","Count", "Frequency"] 
     url_download = "sub_experiment/" + @sub_experiment.id.to_s + "/trbv_data.csv"
     CSV.open( "public/" + url_download, "wb") do |csv|
       csv << data_head 
       values.each{|d| csv << d }
     end
     data_body   = values.map{|dd|  [dd[0],dd[1].to_s, format("%3.2e",dd[2])]}  
     @data_east           = {:title=> "Data details",:head =>data_head,:body=>data_body,:url_download=> url_download ,:help => read_help("SSTA_VJ_V")}
     @center_content     = 'fig_single_bar'

     # for figure
     fig_data  = {:xlabel=>" ",  :ylable=>"Frequency", :data  => [{:key=>"Frequency",:values=>values.map{|d| [d[0],d[2]]}}]}     
     open(cfile, 'w') { |f| f << fig_data.to_json }

     
   #TRBJ Usage
   when 'j' 
     values       = @sub_experiment.seg_usage_statistics('j') 
     data_head    = ["TRBV Segment","Count", "Frequency"] 
     url_download = "sub_experiment/" + @sub_experiment.id.to_s + "/trbj_data.csv"
     CSV.open( "public/" + url_download, "wb") do |csv|
       csv << data_head 
       values.each{|d| csv << d }
     end
     data_body   = values.map{|dd|  [dd[0],dd[1].to_s, format("%3.2e",dd[2])]}  
     @data_east           = {:title=> "Data details",:head =>data_head,:body=>data_body,:url_download=> url_download ,:help => read_help("SSTA_VJ_J")}
     @center_content     = 'fig_single_bar'

      # for figure
     fig_data  = {:xlabel=>" ",  :ylable=>"Frequency", :data  => [{:key=>"Frequency",:values=>values.map{|d| [d[0],d[2]]}}]}     
     open(cfile, 'w') { |f| f << fig_data.to_json }

    
   #TRBV and J Usage
   when 'vj'
     @center_content  = "fig_vj_usage" 

     data         = @sub_experiment.get_vj_segment_statics   
     data_head    = ["V Segment","J Segment","Count", "Frequency"]
     
     n = data[:row_labels].size
     m = data[:col_labels].size

     ##### write pairs value
     values   = []
     (0...n).to_a.each do |i|
       (0...m).to_a.each do |j|
         values << [data[:row_labels][i], data[:col_labels][j],  data[:mx_i][i,j], data[:mx][i,j]]  if data[:mx_i][i,j] >0
       end
     end
     url_download = "sub_experiment/" + @sub_experiment.id.to_s + "/trbvj_data.csv"
     CSV.open( "public/" + url_download, "wb") do |csv|
       csv << data_head 
       values.each{|d| csv << d }
     end

     ##### write matrix value
     data_head1    = [' '] + data[:col_labels] 
     url_download_mx = "sub_experiment/" + @sub_experiment.id.to_s + "/trbvj_data_matrix.csv"
     CSV.open( "public/" + url_download_mx, "wb") do |csv|
       csv << data_head1 
       data[:row_labels].each_with_index{|d,i| csv <<  [d] +  (0...m).to_a.map{|j| data[:mx][i,j]} }
     end

     data_body   = values.map{|d| [d[0],d[1],d[2].to_s, format("%3.2e",d[3])]} 
     @data_east  = {:title=> "Data details",:head =>data_head,:body=>data_body,:url_download=> url_download,:url_download_mx=> url_download_mx ,:help =>read_help("SSTA_VJ_VJ")}

     # for figure
     open(cfile, 'w') { |f| f << data.to_json }


   #CDR3 nt length distribution
   when 'cdr3_nt'
     @center_content  = "fig_cdr3_spectratype" 
     data         = @sub_experiment.get_cdr3_spectratype('nt')   
     data_head    = ["J Segment","CDR3 Length(nt)","Count", "Frequency"]
     
     n = data[:row_labels].size
     m = data[:col_labels].size

     values   = []
     (0...n).to_a.each do |i|
       (0...m).to_a.each do |j|
         values << [data[:row_labels][i],  data[:col_labels][j], data[:mx_i][i][j], data[:mx][i][j]]  if data[:mx_i][i][j] >0
       end
     end

     url_download = "sub_experiment/" + @sub_experiment.id.to_s + "/cdr3_nt_data.csv"
     CSV.open( "public/" + url_download, "wb") do |csv|
       csv << data_head 
       values.each{|d| csv << d }
     end
     data_body   = values.map{|d| [d[0],d[1],d[2].to_s, format("%3.2e",d[3])]} 
     @data_east       = {:title=> "Data details",:head =>data_head,:body=>data_body,:url_download=> url_download ,:help => read_help("SSTA_CS_LENNT")}


     #for figure
     fig_data = data[:mx].each_with_index.map{|dd,i| {:key=>data[:row_labels][i],:values=>dd.each_with_index.map{|d,j| [data[:col_labels][j],d]} }}
     open(cfile, 'w') { |f| f << fig_data.to_json }



  #CDR3 aa length distribution
   when 'cdr3_aa'
     @center_content  = "fig_cdr3_spectratype" 
     data         = @sub_experiment.get_cdr3_spectratype('aa')   
     data_head    = ["J Segment","CDR3 Length(aa)","Count", "Frequency"]
     
     n = data[:row_labels].size
     m = data[:col_labels].size

     values   = []
     (0...n).to_a.each do |i|
       (0...m).to_a.each do |j|
         values << [data[:row_labels][i],  data[:col_labels][j], data[:mx_i][i][j], data[:mx][i][j]]  if data[:mx_i][i][j] >0
       end
     end

     url_download = "sub_experiment/" + @sub_experiment.id.to_s + "/cdr3_aa_data.csv"
     CSV.open( "public/" + url_download, "wb") do |csv|
       csv << data_head 
       values.each{|d| csv << d }
     end
     data_body   = values.map{|d| [d[0],d[1],d[2].to_s, format("%3.2e",d[3])]} 
     @data_east       = {:title=> "Data details",:head =>data_head,:body=>data_body,:url_download=> url_download ,:help => read_help("SSTA_CS_LENAA")}


     #for figure
     fig_data = data[:mx].each_with_index.map{|dd,i| {:key=>data[:row_labels][i],:values=>dd.each_with_index.map{|d,j| [data[:col_labels][j],d]} }}
     open(cfile, 'w') { |f| f << fig_data.to_json }



  #Cumulative clonotype distribution (nt)
   when 'ccd_nt'
     ccd         = @sub_experiment.get_cumulative_clonotype('nt')   

     data_head   = ["No.", "Clone", "Fraction of unique clones","Cumulative Count" , "Cumulative Frequency"] 
     url_download = "sub_experiment/" + @sub_experiment.id.to_s + "/ccd_nt_data.csv"
     CSV.open( "public/" + url_download, "wb") do |csv|
       csv << data_head 
       ccd.each{|d| csv << d }
     end
     
     data_body   = ccd.reverse[0..(n_disp-1)].map{|d|  [d[0].to_s,d[1],format("%3.2e",d[2]),d[3].to_s,format("%3.2e",d[4])] }  
     @data_east       = {:title=> "Data details(" + data_body.length.to_s + "/" + ccd.length.to_s + ")",:head =>data_head,:body=>data_body,:url_download=> url_download ,:help => read_help("SSTA_CD_CFNT")}
     @center_content  = "fig_cumulative_clonotype" 

     #for figure
     ccd_filter  = @sub_experiment.filter_data_by_dist(ccd.map{|d| [d[2],d[4]]},cut_disp)   
     fig_data   = [{:key=>"Cumulative Clonotype",:values=>ccd_filter}]
     open(cfile, 'w') { |f| f << fig_data.to_json }




  #Cumulative clonotype distribution (aa)
   when 'ccd_aa'
     ccd         = @sub_experiment.get_cumulative_clonotype('aa')   

     data_head   = ["No.", "Clone", "Fraction of unique clones","Cumulative Count" , "Cumulative Frequency"] 
     url_download = "sub_experiment/" + @sub_experiment.id.to_s + "/ccd_nt_data.csv"
     CSV.open( "public/" + url_download, "wb") do |csv|
       csv << data_head 
       ccd.each{|d| csv << d }
     end
     
     data_body   = ccd.reverse[0..(n_disp-1)].map{|d|  [d[0].to_s,d[1],format("%3.2e",d[2]),d[3].to_s,format("%3.2e",d[4])] }  
     @data_east       = {:title=> "Data details(" + data_body.length.to_s + "/" + ccd.length.to_s + ")",:head =>data_head,:body=>data_body,:url_download=> url_download ,:help => read_help("SSTA_CD_CFAA")}
     @center_content  = "fig_cumulative_clonotype" 

     #for figure
     ccd_filter  = @sub_experiment.filter_data_by_dist(ccd.map{|d| [d[2],d[4]]},cut_disp)   
     fig_data   = [{:key=>"Cumulative Clonotype",:values=>ccd_filter}]
     open(cfile, 'w') { |f| f << fig_data.to_json }

  #Clonotypes Frequency plots (nt)
   when 'cfp_nt'
     clds     = @sub_experiment.get_clonotypes_frequency('nt')   

     data_head   = ["clone id","sequence","Count", "Frequency"] 
     url_download = "sub_experiment/" + @sub_experiment.id.to_s + "/cfp_nt_data.csv"
     CSV.open( "public/" + url_download, "wb") do |csv|
       csv << data_head 
       clds.each{|d| csv << [d[0],d[2],d[3],d[1]]}
     end
     data_body   = clds[0..(n_disp-1)].map{|dd| [dd[0].to_s,dd[2], dd[3].to_s,format("%3.2e",dd[1])]}  
     @data_east       = {:title=> "Data details(" + data_body.length.to_s + "/" + clds.length.to_s + ")",:head =>data_head,:body=>data_body,:url_download=> url_download ,:help => read_help("SSTA_CD_CFNT")}
     @center_content  = "fig_clonotypes_frequency" 

     #for figure
     clds_log = clds.map{|d| [Math.log10(d[0]),Math.log10(d[1])]}
     clds_log_filter = @sub_experiment.filter_data_by_dist(clds_log,cut_disp) 
     fig_data = [{:key=>"Clonotypes Frequency",:values=>clds_log_filter.map{|d| {:x=>d[0],:y=>d[1]}}}]
     open(cfile, 'w') { |f| f << fig_data.to_json }



  #Clonotypes Frequency plots (aa)
   when 'cfp_aa'
     clds     = @sub_experiment.get_clonotypes_frequency('aa')   

     data_head   = ["clone id","sequence","Count", "Frequency"] 
     url_download = "sub_experiment/" + @sub_experiment.id.to_s + "/cfp_nt_data.csv"
     CSV.open( "public/" + url_download, "wb") do |csv|
       csv << data_head 
       clds.each{|d| csv << [d[0],d[2],d[3],d[1]]}
     end
     data_body   = clds[0..(n_disp-1)].map{|dd| [dd[0].to_s,dd[2], dd[3].to_s,format("%3.2e",dd[1])]}  
     @data_east       = {:title=> "Data details(" + data_body.length.to_s + "/" + clds.length.to_s + ")",:head =>data_head,:body=>data_body,:url_download=> url_download ,:help => read_help("SSTA_CD_CFAA")}
     @center_content  = "fig_clonotypes_frequency" 

     #for figure
     clds_log = clds.map{|d| [Math.log10(d[0]),Math.log10(d[1])]}
     clds_log_filter = @sub_experiment.filter_data_by_dist(clds_log,cut_disp) 
     fig_data = [{:key=>"Clonotypes Frequency",:values=>clds_log_filter.map{|d| {:x=>d[0],:y=>d[1]}}}]
     open(cfile, 'w') { |f| f << fig_data.to_json }


   when 'cvg'
     clds     = @sub_experiment.get_convergent   
     clds_log = clds.map{|d| [Math.log10(d[0]),Math.log10(d[1]),d[2],d[3],d[4],d[5]]}
     clds_log_filter = @sub_experiment.filter_data_by_dist(clds_log,cut_disp) 
     clds_filter     = clds_log_filter.map{|d| [(10**d[0]).round, 10**d[1], d[2],d[3],d[4],d[5]] }  

     data_head   = ["clone id","sequence","Count","Frequency","NT count","NT Sequence"] 
     url_download = "sub_experiment/" + @sub_experiment.id.to_s + "/cfp_aa_data.csv"
     CSV.open( "public/" + url_download, "wb") do |csv|
       csv << data_head 
       clds.each{|d| csv << [d[0],d[2],d[3],d[1],d[5],d[4]]}
     end
     data_body   = clds[0..(n_disp-1)].map{|dd| [dd[0].to_s,dd[2],dd[3].to_s, format("%3.2e",dd[1]),dd[5].to_s,dd[4]]}  
     @data_east       = {:title=> "Data details(" + data_body.length.to_s + "/" + clds.length.to_s + ")",:head =>data_head,:body=>data_body,:url_download=> url_download ,:help => read_help("SSTA_CD_CA")}
     @center_content  = "fig_clonotypes_frequency" 

     #for figure
     clds_log = clds.map{|d| [Math.log10(d[0]),Math.log10(d[1]),d[5]]}
     clds_log_filter = @sub_experiment.filter_data_by_dist(clds_log,cut_disp) 
     fig_data  = [{:key=>"Clonotypes Frequency",:values=>clds_log_filter.map{|d| {:x=>d[0],:y=>d[1],:size=>d[2]}}}]
     open(cfile, 'w') { |f| f << fig_data.to_json }


   else

   end

 end
  def json_fig_single_sample_tcr_analysis 
     cfile     = "public/fig_data"
     data_send = ""
     open(cfile) { |f| data_send = f.read }

    respond_to do |format|
      format.json { render json: data_send  if data_send.class == Hash
                    render text: data_send  if data_send.class == String }
    end

 end

  def download_sub_exp_data
    sp        = SubExperiment.find(params[:id])
    ex_method = sp.experiment.extract_method
    dir_path   = File.join(Rails.root,"public","sub_experiment",params[:id].to_s) 
    case params[:type] 
    when 'clone'
      case ex_method
      when 'mitcr'
        fn       = File.join(dir_path,'mitcr.csv')
        send_file(fn, :filename => "mitcr.csv")
      when 'mixcr'
        fn       = File.join(dir_path,'mixcr.csv')
        send_file(fn, :filename => "mixcr.csv")
      when 'dcnt'
        fn       = File.join(dir_path,'clone.csv')
        send_file(fn, :filename => "decombinator.csv")
      else
      end

    when 'qc'
      fn       = File.join(dir_path,'fastqc_data.txt')
      send_file(fn, :filename => "fastqc_data.txt")
    else 
    end
  end

end
