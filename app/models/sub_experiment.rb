require 'fileutils'
require 'rserve'

class Array
  def odd_values
    values_at(* each_index.select(&:odd?))
  end
  def even_values
    values_at(* each_index.select(&:even?))
  end
end


class SubExperiment < ActiveRecord::Base
  attr_accessible :user_id,:experiment_id, :description, :sample_id,:ex_clone,:sample_name,:sample_name_org, :factor1,:factor2,:factor3,:factor4,:factor5,:factor6,:factor7,:factor8,:factor9,:factor10
  belongs_to  :experiment
  belongs_to  :user
  after_destroy :del_relate_files
  
  def del_relate_files 
    dir_path = "public/sub_experiment/" + self.id.to_s
    if Dir.exist?(dir_path)
      FileUtils.remove_dir  dir_path 
    end
  end

  def combine_unambiguous_segments(s)
  #  use first 
     seg = s.split(",")
     return seg[0]
  end

  def extract_cdr3(par)
    in_dir  = File.join(Rails.root,"public","samples",self.sample_id.to_s) 
    out_dir = File.join(Rails.root,"public","sub_experiment",self.id.to_s) 
    unless File.exist?(in_dir)
      # change sample_id to -1
      self.sample_id = -1
      self.save
      return false 
    end

    par["in_dir"]  = in_dir
    par["out_dir"] = out_dir 

    flag = false
    case par["method"]
    when "mitcr"
      flag = self.extract_mitcr(par)
    when 'mixcr'
      flag = self.extract_mixcr(par)
    when 'dcnt'
      flag = self.extract_decombinator(par)
    when 'cdr3'

    else
    end

    if flag
      self.ex_clone = true
      self.save
    else
      self.ex_clone =false 
      self.save
    end
    return flag
  end

  def extract_mitcr(par)
    rfile = File.join(par["out_dir"],"mitcr.csv")
    rfile_filter = File.join(par["out_dir"],"clone.csv")
    if File.exist?(rfile)
     File.delete(rfile) 
    end
    if File.exist?(rfile_filter)
     File.delete(rfile_filter) 
    end


    file  = File.join(par["in_dir"],"sample.fastq")
    #    cmd = "mitcr "
    cmd = "java -jar tools/mitcr.jar"
    cmd << " -pset "    + par["mitcr_pset"]
    cmd << " -species " + par["mitcr_species"]
    cmd << " -gene "    + par["mitcr_gene"]
    cmd << " -cysphe "  + par["mitcr_cysphe"]
    cmd << " -ec "      + par["mitcr_ec"]
    cmd << " -quality " + par["mitcr_quality"]
    cmd << " -lq "      + par["mitcr_lq"]
    cmd << " -pcrec "   + par["mitcr_pcrec"]
    cmd << " " + file + " " + rfile 
    system(cmd)
    if File.exist?(rfile)
      data = File.read(rfile) 
      data = CSV.parse(data,{:col_sep => "\t"}) 
      data = data[1..-1]
      #  data structure
      #  0"Read count", 1"Percentage", 2"CDR3 nucleotide sequence", 3"CDR3 nucleotide quality", 4"Min quality", 5"CDR3 amino acid sequence", 6"V alleles", 7"V segments", 8"J alleles", 9"J segments", 10"D alleles", 11"D segments", 12"Last V nucleotide position ", 13"First D nucleotide position", 14"Last D nucleotide position", 15"First J nucleotide position", 16"VD insertions", 17"DJ insertions", 18"Total insertions"

      CSV.open( rfile_filter, "wb",{:col_sep => "\t"}) do |csv|
        csv << ["count","v","j","nt","aa"]
        data[1..-1].each do |d|
          aa = "-"
          if d[5][/~|\*/].nil?
            aa = d[5]
          end
          csv << [d[0].gsub(/\s+/, ""),d[7].gsub(/\s+/, ""),d[9].gsub(/\s+/, ""),d[2].gsub(/\s+/, ""),aa.gsub(/\s+/, "")] 
        end
      end

      return true 
    else
      return false
    end
  end

  def extract_mixcr(par)
    file         = File.join(par["in_dir"],"sample.fastq")
    #    cmd = "mixcr "
    #    Align
    rfile1        = File.join(par["out_dir"],'mixcr.vdjca')
    if File.exist?(rfile1)
     File.delete(rfile1) 
    end
    cmd = "java -jar tools/mixcr.jar align "
    cmd << " -s "       + par["mixcr_species"]
    cmd << " -l "       + par["mixcr_gene"]
    cmd << " -OminSumScore=" + par["mixcr_minimal"]
    cmd << " -OmaxHits="       + par["mixcr_maximal"]
    cmd << " -OrelativeMinVFR3CDR3Score="       + par["mixcr_relativeMin"]
    cmd << " -OvParameters.parameters.mapperKValue="       + par["mixcr_mapperkv"]
    cmd << " -OjParameters.parameters.mapperKValue="       + par["mixcr_mapperkj"]
    cmd << " -OcParameters.parameters.mapperKValue="       + par["mixcr_mapperkc"]
    cmd << " -OvParameters.parameters.floatingLeftBound="       + par["mixcr_leftboundv"]
    cmd << " -OjParameters.parameters.floatingLeftBound="       + par["mixcr_leftboundj"]
    cmd << " -OcParameters.parameters.floatingLeftBound="       + par["mixcr_leftboundc"]
    cmd << " -OvParameters.parameters.floatingRightBound="       + par["mixcr_rightboundv"]
    cmd << " -OjParameters.parameters.floatingRightBound="       + par["mixcr_rightboundj"]
    cmd << " -OcParameters.parameters.floatingRightBound="       + par["mixcr_rightboundc"]
    cmd << " -OvParameters.parameters.minAlignmentLength="       + par["mixcr_minalignmentlengthv"]
    cmd << " -OjParameters.parameters.minAlignmentLength="       + par["mixcr_minalignmentlengthj"]
    cmd << " -OcParameters.parameters.minAlignmentLength="       + par["mixcr_minalignmentlengthc"]
    cmd << " -OvParameters.parameters.maxAdjacentIndels="       + par["mixcr_maxadjacentindelsv"]
    cmd << " -OjParameters.parameters.maxAdjacentIndels="       + par["mixcr_maxadjacentindelsj"]
    cmd << " -OcParameters.parameters.maxAdjacentIndels="       + par["mixcr_maxadjacentindelsc"]
    cmd << " -OvParameters.parameters.absoluteMinScore="       + par["mixcr_absoluteminscorev"]
    cmd << " -OjParameters.parameters.absoluteMinScore="       + par["mixcr_absoluteminscorej"]
    cmd << " -OcParameters.parameters.absoluteMinScore="       + par["mixcr_absoluteminscorec"]
    cmd << " -OvParameters.parameters.relativeMinScore="       + par["mixcr_relativeminscorev"]
    cmd << " -OjParameters.parameters.relativeMinScore="       + par["mixcr_relativeminscorej"]
    cmd << " -OcParameters.parameters.relativeMinScore="       + par["mixcr_relativeminscorec"]
    cmd << " -OvParameters.parameters.maxHits="       + par["mixcr_maxhitsv"]
    cmd << " -OjParameters.parameters.maxHits="       + par["mixcr_maxhitsj"]
    cmd << " -OcParameters.parameters.maxHits="       + par["mixcr_maxhitsc"]
    cmd << " -OdParameters.absoluteMinScore="       + par["mixcr_absolutminscore"]
    cmd << " -OdParameters.relativeMinScore="       + par["mixcr_relativeminscore"]
    cmd << " -OdParameters.maxHits="       + par["mixcr_maxhits"]
#    cmd << " -OdParameters.scoring.type="       + par["mixcr_type"]
#    cmd << " -OdParameters.scoring.gapOpenPenalty="       + par["mixcr_gapopenpenalty"]
#    cmd << " -OdParameters.scoring.gapExtensionPenalty="       + par["mixcr_gapextensionpenalty"]
    cmd << " " + file + " " + rfile1 
    system(cmd)


    f1 = File.join(par["out_dir"],'raw_clones.txt')
    if File.exist?(f1)
     File.delete(f1) 
    end
    cmd = "java -jar tools/mixcr.jar exportAlignments "
    cmd << rfile1 + " " +  f1 
    system(cmd)

    ####  assemble
    rfile2 = File.join(par["out_dir"],'clones.clns')
    if File.exist?(rfile2)
     File.delete(rfile2) 
    end
    cmd = "java -jar tools/mixcr.jar assemble "
    cmd << " -ObadQualityThreshold="       + par["mixcr_badqualitythreshold"]
    cmd << " -OmaxBadPointsPercent="       + par["mixcr_maxbadpointspercent"]
    cmd << " -OaddReadsCountOnClustering="       + par["mixcr_addreadscountonclustering"]
    cmd << " -OcloneClusteringParameters.searchDepth="       + par["mixcr_searchdepth"]
    cmd << " -OcloneClusteringParameters.allowedMutationsInNRegions="       + par["mixcr_allowedMutationsInNRegions"]
    cmd << " -OcloneClusteringParameters.searchParameters="       + par["mixcr_searchParameters"]
    cmd << " -OcloneClusteringParameters.clusteringFilter.specificMutationProbability="       + par["mixcr_clusteringFilter"]
  #  cmd << " -OvloneFactoryParameters.jParameters.featureToAlign="       + par["mixcr_featureToAlignV"]
  #  cmd << " -OjloneFactoryParameters.jParameters.featureToAlign="       + par["mixcr_featureToAlignJ"]
  #  cmd << " -OcloneFactoryParameters.jParameters.featureToAlign="       + par["mixcr_featureToAlignC"]
  #  cmd << " -OvloneFactoryParameters.jParameters.relativeMinScore="       + par["mixcr_relativeMinScoreV"]
  #  cmd << " -OjloneFactoryParameters.jParameters.relativeMinScore="       + par["mixcr_relativeMinScoreJ"]
  #  cmd << " -OcloneFactoryParameters.jParameters.relativeMinScore="       + par["mixcr_relativeMinScoreC"]
    cmd  << " " + rfile1 + " " +  rfile2
    system(cmd)

    rfile3 = File.join(par["out_dir"],'mixcr.csv')
    if File.exist?(rfile3)
     File.delete(rfile3) 
    end
    cmd = "java -jar tools/mixcr.jar exportClones "
    cmd << rfile2 + " " +  rfile3 
    system(cmd)

    rfile_filter = File.join(par["out_dir"],"clone.csv")
    if File.exist?(rfile_filter)
     File.delete(rfile_filter) 
    end

    if File.exist?(rfile3)
      data = File.read(rfile3) 
      data = CSV.parse(data,{:col_sep => "\t"}) 
      data = data[1..-1]


      CSV.open( rfile_filter, "wb",{:col_sep => "\t"}) do |csv|
        csv << ["count","v","j","nt","aa"]
        data[1..-1].each do |d|
          aa = "-"
          if d[31][/~|\*|_/].nil?
            aa = d[31]
          end
          v  = d[4].split(/,|\*/).even_values.join(",")
          j  = d[6].split(/,|\*/).even_values.join(",")
          csv << [d[0].gsub(/\s+/, ""),v.gsub(/\s+/, ""),j.gsub(/\s+/, ""),d[2].gsub(/\s+/, ""),aa.gsub(/\s+/, "")] 
        end
      end
      return true 
    else
      return false
    end
    return true
  end


  def extract_decombinator(par)
    rfile = File.join(par["out_dir"],"decombinator.csv")
    rfile_filter = File.join(par["out_dir"],"clone.csv")
    if File.exist?(rfile)
      File.delete(rfile) 
    end
    if File.exist?(rfile_filter)
      File.delete(rfile_filter) 
    end

    file  = File.join(par["in_dir"],"sample.fastq")
    o_fn  = 'tmp'
    species = par['dcnt_species'] 
    ph  = File.join(Rails.root,"tools","Decombinator") 
    cmd = "python DecombinatorV2_2.py "
    cmd << " -s "       + species 
    cmd << " -i "       + file 
    cmd << " -o "       + o_fn 
    Dir::chdir(ph) 
    system(cmd)
    Dir::chdir(Rails.root) 
    begin
      con =  Rserve::Connection.new();
      con.assign("ph", ph);
      con.assign("o_fn", o_fn);
      con.assign("fnsave", rfile_filter);
      con.assign("species",species);
      r = con.eval(" format_decombinator_result_trb(decombinator_path=ph,o_fn=o_fn,fnsave=fnsave,species=species) ")
      con.close

      if File.exist?(rfile_filter)
        flag = true
      end
    rescue
      flag = false
    end

    return flag 
  end

  def seperate_tmpl_cell_sample(in_dir,out_dir)
    flag = true
    begin
      con =  Rserve::Connection.new();
      con.assign("in_dir", in_dir);
      con.assign("out_dir", out_dir);
      r = con.eval(" seperate_template_cell_sample(in_dir,out_dir) ")
      con.close
    rescue
      flag = false
    end
    return flag
  end



  def compute_fastqc
    dir_path = "public/sub_experiment/" + self.id.to_s 
    file = File.join(dir_path, "sample.fastq")
    cmd = "./tools/FastQC/fastqc -o " + dir_path + " -f fastq " + " -q " + file 
    system(cmd)
  end

  def read_fastqc_result(i)
    # i is qc item no.
    file     =  "public/sub_experiment/" + self.id.to_s + "/fastqc_data.txt"
    data     = File.read(file) 
    data     = data.split(">>")
    d        = data[i*2-1].split("\n#")
    titleall = d[0].split("\t")
    title    = titleall[0]
    status   = titleall[1]
    data_table = d[-1]

    return {"title"=> title, "status"=> status,  "data_table" => data_table }
  end


  def read_clone_data(type)
    if self.sample_id > 0
      fn  = File.join(Rails.root,"public","sub_experiment",self.id.to_s,"clone.csv") 
      con =  Rserve::Connection.new();
      con.assign("fn", fn);
      con.assign("type", type);
      r = con.eval(" read_clone_data(fn,type=type) ").as_list()
      con.close
   else
      r = nil
    end
      return r 
  end

  def sample_detail 
    method = self.experiment.extract_method
    begin
      fn  = File.join(Rails.root,"public","sub_experiment",self.id.to_s,'clone.csv') 
      con =  Rserve::Connection.new();
      con.assign("fn", fn);
      con.assign("method", method);
      r = con.eval(" sample_details_simple(fn,method=method) ").as_list()
      con.close

      name  = r["name"].as_strings()
      value = r["value"].as_integers()
      p name
      p value 
      rr    = Hash.new
      (0...name.length).map{|i| rr[name[i]]= value[i] } 

    rescue
      rr = "Error" 
    end
    return rr 
  end

  def seg_usage_statistics(type)
    begin
      r     = read_clone_data(type)
      name  = r["name"].as_strings()
      count = r["count"].as_integers()
      freq  = r["freq"].as_doubles()

      d = (0...name.length).map{|i| [name[i], count[i],freq[i]] }

    rescue
      d = nil 
    end
    return d 
 
  end

  def get_vj_segment_statics
    r           = read_clone_data('vj')
    row_labels  = r["j"].as_strings()
    col_labels  = r["v"].as_strings()
    mx_i        = r["mx"].as_matrix()
    mx          = r["mx_norm"].as_matrix()
    return  {:row_labels=>row_labels,:col_labels=>col_labels,:mx=>mx, :mx_i=> mx_i } 
  end

  def filter_data_by_dist(dat, cutoff)
    cutoff *= cutoff
    dat_f = [dat[0]]
    dat[1..-1].each do |d|
       d1 = dat_f[-1]
       dat_f  << d   if (d[0]-d1[0]) * (d[0]-d1[0]) + (d[1]-d1[1])*(d[1]-d1[1]) > cutoff
    end
    return dat_f
  end

  def get_cdr3_spectratype(type) 
    # type:   'nt' or 'aa'
    r      = read_clone_data('all') 
    count  = r["count"].as_strings()
    jseg   = r["j"].as_strings()
    case type
    when 'nt'
      seq  = r["nt"].as_strings()
    when 'aa'
      seq  = r["aa"].as_strings()
    else
    end

    tmp      =  Hash.new(0)
    cunt     = 0
    len_arr  = []
    jseg_arr = []
    total = 0.0
    n     = seq.length
    (0...seq.length).each do |i|
      if !jseg[i].include?(",") && seq[i].length > 1
        tmp[jseg[i] + "," + seq[i].length.to_s ]  += count[i].to_i
        total += count[i].to_i
        jseg_arr << jseg[i]
        len_arr  << seq[i].length
        cunt     += count[i].to_i
      end
    end

    jseg_arr.uniq!

    case type
    when 'nt'
      len_min = len_arr.min / 3 * 3 +3 
      len_max = len_arr.max / 3 * 3
      len_arr = len_min.step(len_max,3).to_a
    when 'aa'
      len_min = len_arr.min
      len_max = len_arr.max
      len_arr = (len_min..len_max).to_a
    else
    end

    mx   = jseg_arr.map{|s| len_arr.map{|len| tmp[s + "," + len.to_s]/total}}
    mx_i = jseg_arr.map{|s| len_arr.map{|len| tmp[s + "," + len.to_s]}}

    return  {:row_labels=>jseg_arr, :col_labels=>len_arr, :mx=>mx,:mx_i=> mx_i } 
  end

  def get_cumulative_clonotype(type) 
    r     = read_clone_data(type)
    name  = r["name"].as_strings()
    count = r["count"].as_integers()
    freq  = r["freq"].as_doubles()

    counts  = []
    num    = 0
    (0...name.length).each do |i|
      countall += count[i] 
      num  += 1
      counts << [name[i],num,countall] 
    end

    num     += 0.0
    counts  += 0.0
    cunt_f =  counts.map{|d| [d[1],d[0],d[1]/num,d[2],d[2]/cunt]}  
    return cunt_f

  end

  def get_clonotypes_frequency(type)
    r     = read_clone_data(type)
    name  = r["name"].as_strings()
    count = r["count"].as_integers()
    freq  = r["freq"].as_doubles()
   
    return (0...name.length).map{|i| [i+1,freq[i],name[i],count[i]]}
  end

  def get_convergent 
    r      = read_clone_data('all') 
    count  = r["count"].as_integers()
    aa     = r["aa"].as_strings()
    nt     = r["nt"].as_strings()
    
    tmp_cunt   =  Hash.new(0)  # [0,[]]  0 cunt, [] aa -> nt
    tmp_nt     =  {}  # [0,[]]  0 cunt, [] aa -> nt

    total = 0.0
    (0...aa.length).each do |i|
      if aa[i].length > 1
        tmp_cunt[aa[i]]  += count[i] 
        if  tmp_nt[aa[i]].nil?
          tmp_nt[aa[i]]  =  [nt[i]] 
        else
          tmp_nt[aa[i]]  << nt[i] 
        end
        total += count[i] 
      end
    end
    cunt = tmp_cunt.sort_by {|_key, value| -value}
    tmp_nt.each{|k,v| tmp_nt[k]=tmp_nt[k].uniq}
    frq  = cunt.map{|k,v| [ v/total, k, v, tmp_nt[k].inject{|s,d| s<< ";" <<d } ,tmp_nt[k].length ]}
  
    return frq.each_with_index.map{|d,i| [i+1,d[0],d[1],d[2],d[3],d[4]]}
    # 0 id, 1 frequenct,2 aa seq, 3 cunt,4 nt seqs, 5 nt number

  end

end
