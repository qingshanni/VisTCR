require 'fileutils'
require 'inifile'
require 'csv'
require 'rserve'


class SamplesController < ApplicationController
  # GET /samples
  # GET /samples.json
  def index
    respond_to do |format|
      if current_user
        format.html # index.html.erb
      else
        format.html { redirect_to root_path}
      end
    end
 end

  # GET /samples/1
  # GET /samples/1.json
  def show
    @sample = Sample.find(params[:id])
    @seq_num = @sample.read_fastqc_result(1)["data_table"].split("\t")[9]
    render :partial => 'sample_details'
  end

  # GET /samples/new
  # GET /samples/new.json
  def new
    @pid = params[:pid] #project id
    @sample = Sample.new
    render :partial => 'form_new'
  end

  # GET /samples/1/edit
  def edit
    @sample = Sample.find(params[:id])
    render :partial => 'form_edit'
  end

  # POST /samples
  # POST /samples.json
  def create

    ####  check files
    @flag        = TRUE
    @flag_txt    = ""
    dir_path     = "./public/samples/tmp"  
    if Dir.exist?(dir_path)
      FileUtils.remove_dir dir_path
    end
    FileUtils.mkdir(dir_path)


    if !params[:use_ref].nil?
      ref_method   = params[:ref_method]
      file = File.join(dir_path, "ref_file")
      if ref_method == "1"
        ref_file = params[:ref_file].tempfile.path
      else
        ref_file = "./public/sup/ref_file" 
      end
      FileUtils.cp ref_file, file
      rr       = self.check_ref_file(file)
      @flag     = @flag && rr["flag"] 
      @flag_txt = rr["flag_txt"] 
    end

    if @flag
      fastq_file = params[:fastq_file].tempfile.path
      file = File.join(dir_path, "sample.fastq")
      FileUtils.cp fastq_file, file

      rr   = compute_fastqc(file) 
      @flag = @flag && rr["flag"] 
      @flag_txt = rr["flag_txt"]
      
      if @flag
        ###  split data: fastq, template, ref cell, delete contiminant

        @sample = Sample.new(params[:sample])
        @sample.user_id    = current_user.id
        @sample.project_id = params[:pid].to_i 
        @sample.org_file_name = params[:fastq_file].original_filename
        @sample.use_ref    = 1 unless params[:use_ref].nil?  
        @sample.save

        sid = "F" + DateTime.now.strftime("%Y%m%d") + format("%08d", @sample.id) 
        @sample.update_attributes(:sid => sid)
        dir_path1 = "public/samples/" + @sample.id.to_s 
        if Dir.exist?(dir_path1)
          FileUtils.remove_dir dir_path1
        end
        FileUtils.mv  dir_path, dir_path1
      end
    end
 end

  # PUT /samples/1
  # PUT /samples/1.json
  def update
    @sample = Sample.find(params[:id])
    @sample.update_attributes(params[:sample])
 end

  def delete_recorder 
    @sample = Sample.find(params[:id])
    @sample.destroy
    dir_path = "public/samples/" + params[:id] 
    if Dir.exist?(dir_path)
      FileUtils.remove_dir dir_path
    end
 
    render  :text=>'Delete success !' 
  end


  def jqgrid_list 
    
    index_columns ||= [:id,:sid,:title, :created_at]
    current_page  = params[:page] ? params[:page].to_i : 1
    rows_per_page = params[:rows] ? params[:rows].to_i : 20 

    conditions={:page => current_page, :per_page => rows_per_page}
    conditions[:order] = params["sidx"] + " " + params["sord"] unless (params[:sidx].blank? || params[:sord].blank?)
    
    if params[:_search] == "true"
      conditions[:conditions]=filter_by_conditions(index_columns)
    end

    if params[:id].to_i > 0
      @project = Project.find(params[:id])
      @entries = @project.samples.paginate(conditions)
    else
      @entries = current_user.samples.paginate(conditions)
    end
   
   total_entries = @entries.total_entries
   total_pages   = total_entries/rows_per_page.to_i + 1


   @responce = {:page => current_page,:total=>total_pages , :records =>total_entries , :rows=>@entries} 

    respond_to do |format|
      format.json { render json: @responce }
    end

  end


  ################################################################################################
  ####   Sequencing Qualify  ####################################################################

  def qc_analysis

    @sample = Sample.find(params[:id])
    id       = params[:id]
    @item     = params[:item].to_i


    ##  param for different tasks
    case @item 
    when 2
    when 3 
      @title      = "Quality Score distribution" 
      @fig_render = "fig_sequence_quality"
      decimal    = 0 
    when 4 
      @title      = "Base Sequence Content" 
      @fig_render = "fig_base_sequence_content"
      decimal    = 2 
    when 5
      @title      = "GC base Sequence Content" 
      @fig_render = "fig_base_sequence_content"
      decimal    = 2 
    when 6
    when 7
    when 8
      @title      = "GC base Sequence Content" 
      @fig_render = "fig_seq_length_distribution"
      decimal    = 0 
    when 9 
    else
    end

    ###########  center 
    @url  = "/samples/json_qc_fig_data.json?id=" + params[:id] + "&item=" + params[:item] 
    @fig_flag  = true
    case @item
    when 1,10
      @fig_flag = false
    end


    ##########  east
    r = @sample.read_fastqc_result(@item)
    @status     = r["status"]
    d = r["data_table"]
    data = CSV.parse(d, {:col_sep => "\t"}) 

    #write to file for download 
    @url_download = "samples/" + @sample.id.to_s + "/qc_data.csv"
    CSV.open( "public/" + @url_download, "wb") do |csv|
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

    #qc help
    d = File.read("public/fastaqc_help") 
    d.gsub!("\n"," ")
    d = d.split("####")
    if @item == 1
      qc_help = " " 
    else
      qc_help = d[@item-2]
    end
    @data_east = {:title => "Data Details",:head => data_head,:body=> data_body,:url_download => @url_download, :help=>qc_help}


    #    @fig_render = "display_qc_result"

end


def json_qc_fig_data
  @sample = Sample.find(params[:id])
  r     = @sample.read_fastqc_result(params[:item].to_i)
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

 def download_sample_data
   sample = Sample.find(params[:id])
   send_file Rails.root.join('public','samples', params[:id],'sample.fastq'), :filename=> sample.title.gsub(/\s/,'_') + '.fastq'
 end

 def download_ref_file
   sample = Sample.find(params[:id])
   send_file Rails.root.join('public','samples', params[:id],'ref_file'), :filename=> sample.title.gsub(/\s/,'_') + '.txt'
 end

 def download_ref_file_default
   send_file Rails.root.join('public','sup', 'ref_file'), :filename=>   'ref_file.txt'
 end

  def check_ref_file(file)
    vset = ["TRBV1","TRBV2","TRBV3","TRBV4","TRBV5","TRBV12-1","TRBV12-2","TRBV13-1","TRBV13-2","TRBV13-3","TRBV14","TRBV15","TRBV16","TRBV17","TRBV19","TRBV20","TRBV21","TRBV23","TRBV24","TRBV26","TRBV29","TRBV30","TRBV31"]
    jset = ["TRBJ1-1","TRBJ1-2","TRBJ1-3","TRBJ1-4","TRBJ1-5","TRBJ2-1","TRBJ2-2","TRBJ2-3","TRBJ2-5","TRBJ2-6","TRBJ2-7"]
    ref  = IniFile.load(file)
    n_cell     = ref["number"]["cell"]
    n_cont     = ref["number"]["contaminate"]
    n_template = ref["number"]["template"]

    if n_cell > 0
      for i in 1..n_cell
        t        = "cell_" + i.to_s
        cell     = ref[t]
        flag_txt = ""
        flag     = vset.include?( cell["V"])
        if(!flag ) 
          flag_txt = "V name of " + t + " is wrong or missing"
          return {"flag" => flag, "flag_txt" =>  flag_txt }
        end

        flag     =  jset.include?( cell["J"])
        if(!flag ) 
          flag_txt = "J name of " + t + " is wrong or missing"
          return {"flag" => flag, "flag_txt" =>  flag_txt }
        end

        flag  = (cell["number"].class == Fixnum)
        if(!flag ) 
          flag_txt = "Cell number of " + t + " is wrong or missing"
          return {"flag" => flag, "flag_txt" =>  flag_txt }
        end
      end
      ##### write file for R read
      CSV.open(file + "_cell", "wb",{:col_sep => "\t"}) do |csv|
        csv << ["name", "V", "J","CDR3", "number"]
        for i in 1..n_cell
          cell     = ref["cell_" + i.to_s]
          csv << [cell["name"], cell["V"], cell["J"], cell["CDR3"],cell["number"]]
        end
      end
    end

    if n_cont > 0
      for i in 1..n_cont
        t        = "contaminate_" + i.to_s
        cont     = ref[t]
        flag_txt = ""
        flag     = vset.include?( cont["V"])
        if(!flag ) 
          flag_txt = "V name of " + t + " is wrong or missing"
          return {"flag" => flag, "flag_txt" =>  flag_txt }
        end

        flag     =  jset.include?( cell["J"])
        if(!flag ) 
          flag_txt = "J name of " + t + " is wrong or missing"
          return {"flag" => flag, "flag_txt" =>  flag_txt }
        end
      end
      CSV.open(file + "_contaminate", "wb",{:col_sep => "\t"}) do |csv|
        csv << ["V", "J", "CDR3"]
        for i in 1..n_cont
          cont     = ref["contaminate_" + i.to_s]
          csv << [cont["V"], cont["J"], cont["CDR3"]]
        end
      end
    end

    if n_template > 0
      for i in 1..n_template
        tp = "template_" + i.to_s
        tmpl  = ref[tp] 
        flag   = vset.include?( tmpl["V"])
        if(!flag ) 
          flag_txt = "V name of "+ tp +" is wrong or missing"
          return {"flag" => flag, "flag_txt" =>  flag_txt }
        end

        flag   = !(tmpl["barcode"].nil? || tmpl["amplify_sequence"].nil?)
        if(!flag ) 
          flag_txt = "barcode or amplify sequence of "+ tp +" is missing"
          return {"flag" => flag, "flag_txt" =>  flag_txt }
        end
      end

      CSV.open(file + "_template", "wb",{:col_sep => "\t"}) do |csv|
        csv << ["v", "barcode", "amplify_seq"]
        for i in 1..n_template
          tmpl     = ref["template_" + i.to_s]
          csv << [tmpl["V"], tmpl["barcode"], tmpl["amplify_sequence"]]
        end
      end

    end
    return {"flag" => flag, "flag_txt" =>  flag_txt }
  end

  def compute_fastqc(file)
    dir_path = File.dirname(file)  
    cmd      = "./tools/FastQC/fastqc -o " + dir_path + " -f fastq " + " -q " + file 
    system(cmd)
    rfile    = dir_path + '/sample_fastqc.zip'
    if File.exist?(rfile)
      return {"flag" => true, "flag_txt" => ""}
    else
      return {"flag" => false, "flag_txt" => " Fastq file is wrong, please check it !"}
    end
  end

  def separate_data(dir_path)
    con =  Rserve::Connection.new();
    con.assign("dir_path", dir_path);
    r = con.eval("separate_data(dir_path) ")
    con.close
  end

end
