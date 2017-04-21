require 'csv'
require 'rserve'
require 'matrix'
require 'xmlsimple'


class Experiment < ActiveRecord::Base
  attr_accessible :description, :title,:user_id,:factor_num,:factor_name,:factor1,:factor2,:factor3,:factor4,:factor5,:factor6,:factor7,:factor8,:factor9,:factor10,:extract_method
  attr_accessor :upload_file  
  has_many :sub_experiments,:dependent => :destroy  
  belongs_to :user

  def file_path_root
    Rails.root.join('public','experiment', self.id.to_s)
  end
  def file_download_root
    File.join('experiment',self.id.to_s)
  end
  def parse_exp_design_data(file_name)

    data  = File.read(file_name) 
    data  = data.gsub(/\n\r|\r\n|\r/,"\n")
    data  = data.gsub(/[\t;]/,",")
    data  = CSV.parse(data) 


    n     = data[0].length

    exp_design = [] 
    all        = {} 
    n.times{|i| all["#{i}"] = []}
 
    data[1..-1].each do |d|
      if d.length != n
        return false
      end
      sample_id = -1
      if d[2].length>8 
        sample_id = d[2][9..-1].to_i
        if sample_id <1
          sample_id = 0
        end
      end
      ed = {:sample_name_org => d[0],:sample_name => d[1],:sample_id =>sample_id } 
      (n-3).times do |i|
        ed["factor#{i+1}"] = d[i+3]
        all["#{i}"].push( d[i+3])  
      end
      exp_design.push(ed)
    end
    note = {}
    (n-3).times do |i|
      note["factor#{i+1}"]= stringarray_to_string(all["#{i}"].uniq,",")
    end
    note[:factor_num] = n-3
    note[:factor_name] = stringarray_to_string(data[0][3..-1],",")
    return {:exp_design=>exp_design,:exp_param => note}

  end



  def write_exp_design
    sub_experiments = self.sub_experiments

    path ="public/experiment/" + self.id.to_s + "/exp_design.csv" 
    CSV.open( path, "wb") do |csv|
      csv << ["Sample_name", "display_name","file_id" , self.factor_name.split(",") ].flatten
      sub_experiments.each do |sub_exp|
        sample_id = sub_exp.sample_id
        sid = ""
        if sample_id > 0
            sid = Sample.find(sample_id).sid
        end
        csv <<  [sub_exp.sample_name, sub_exp.sample_name_org, sid, (1..self.factor_num).map{|i| sub_exp["factor#{i}"]} ].flatten
      end
    end

  end
#################################################################################
#################################################################################
  #  read and write params 
#################################################################################
#################################################################################

  def write_tcr_extract_param(par)
      xml = XmlSimple.xml_out(par)
      fn  = "public/experiment/" + self.id.to_s + "/ex_params.xml"
      open(fn, 'w') { |f| f << xml }
  end

  def read_tcr_extract_param
      fn  = "public/experiment/" + self.id.to_s + "/ex_params.xml"
      par =  XmlSimple.xml_in(fn)
      return par
  end


  ##############################################################################
  def samples_combine_by_group(samples,type)
    #######  combine data by group
    dat    = Hash.new(0) 
    total  = 0
    samples.each do |sp|
      r     = sp.read_clone_data(type)
      name  = r["name"].as_strings()
      count = r["count"].as_integers()

      (0...name.length).each do |i|
        dat[name[i]]  += count[i] 
        total         += count[i] 
      end
    end

    total  += 0.0
    dat.each do |k,v|
      dat[k] = [v,v/total] ### [cunt,frequenct]
    end

    return dat 

  end


  def get_clonotypes_frequency_overlay(samples1,samples2,type)
      dat1 = samples_combine_by_group(samples1,type)
      dat2 = samples_combine_by_group(samples2,type)

      s_all = dat1.map{|k,v| k} | dat2.map{|k,v| k}
      n1 = s_all.map{|k| dat1[k].nil? ? 0 : dat1[k][0]} 
      n2 = s_all.map{|k| dat2[k].nil? ? 0 : dat2[k][0]} 

      con =  Rserve::Connection.new();
      con.assign("n1", n1);
      con.assign("n2", n2);
      r2 = con.eval(" r.lm <- lm(n1 ~ n2) 
                      summary(r.lm)$r.squared 
                   ").as_doubles()[0]
      con.close

      intersection  = dat1.map{|k,v| k} & dat2.map{|k,v| k}
      dat  = intersection.map{ |k| [k, dat1[k], dat2[k] ] }
      return {:dat=> dat, :r2=>r2 }
  end
  def get_clonotypes_convergent_overlay(samples1,samples2)
    #######  combine all data 
     aa    = {} 
     (samples1 + samples2).each do |sp|
      r     = sp.read_clone_data('all')
      nt    = r["nt"].as_strings()
      a     = r["aa"].as_strings()

      (0...nt.length).each do |i|
        if a[i].length > 1
          if aa[a[i]].nil? 
            aa[a[i]] = [nt[i]]
          else
            aa[a[i]] << nt[i]
          end
        end
      end
     end
     aa.each{|k,v| aa[k] = aa[k].uniq }

      dat1 = samples_combine_by_group(samples1,'aa')
      dat2 = samples_combine_by_group(samples2,'aa')
      intersection  = dat1.map{|k,v| k} & dat2.map{|k,v| k}

      dat  = intersection.map{ |k| [k, aa[k].length,aa[k],dat1[k], dat2[k] ] }
      return dat
  end


  def get_clonotypes_frequency_unoverlay(samples1,samples2,type)
      dat1 = samples_combine_by_group(samples1,type)
      dat2 = samples_combine_by_group(samples2,type)
      df1  = dat1.map{|k,v| k} - dat2.map{|k,v| k}
      df2  = dat2.map{|k,v| k} - dat1.map{|k,v| k}
      dat  = [df1.map{ |k| [k, dat1[k][0], dat1[k][1]] }.sort_by{|d| -d[1]}, 
              df2.map{ |k| [k, dat2[k][0], dat2[k][1]] }.sort_by{|d| -d[1]}]
      return dat
  end
 
  ########################################################################################
  #
  def compute_similarity(s1,s2,s_method)
   case  s_method 
   when 'mh'   ## Morisita-Horn similarity index 
     total1 = s1.inject(0){|sum,sk| sum + sk[1]} + 0.0 
     total2 = s2.inject(0){|sum,sk| sum + sk[1]} + 0.0 
     sum1 = s1.inject(0){|sum,d| sum + d[1]*s2[d[0]] } / (total1 * total2)
     sum2 = s1.inject(0){|sum,d| sum + d[1]*d[1] } / (total1 * total1) + s2.inject(0){|sum,d| sum + d[1]*d[1] } / (total2 * total2) 
    return sum1 * 2 / sum2 
      
   when 'ji'  # Jaccard index
     a1 = s1.map{|k,v| k}
     sum1 = s1.inject(0){|sum,d| sum + [d[1] , s2[d[0]]].min }
     sum2 = s1.inject(0){|sum,sk| sum + sk[1]} + s2.inject(0){|sum,sk| sum + sk[1]} + 0.0 
     return sum1 / (sum2 -sum1) 

   when 'si'  #Sørensen index 
     sum1 = s1.inject(0){|sum,d| sum + [d[1] , s2[d[0]]].min }
     sum2 = s1.inject(0){|sum,sk| sum + sk[1]} + s2.inject(0){|sum,sk| sum + sk[1]} + 0.0 
     return  2 * sum1 / sum2 
   when 'bc' ### Bhattacharyya (BC) coefficient
     total1 = s1.inject(0){|sum,sk| sum + sk[1]} + 0.0 
     total2 = s2.inject(0){|sum,sk| sum + sk[1]} + 0.0 
     sum   = s1.inject(0){|sum,d| sum + Math.sqrt(d[1]*s2[d[0]]) } / Math.sqrt(total1 * total2) 
     return sum
 
   when 'rd'  #Renyi’s divergence 
     a   = 2
     total1 = s1.inject(0){|sum,sk| sum + sk[1]} 
     total2 = s2.inject(0){|sum,sk| sum + sk[1]} 

     sim = s1.map{|k,v| k} & s2.map{|k,v| k} 
      aa = sim.inject(0){|sum,s|  }

   end


  end

  def seg_cunt(data,type)

   case  type 
   when "v" 
     idx = 0 
   when "j" 
     idx = 1 
   when "aa"  # cdr3  aa
     idx = 3 
   when "nt"  # cdr3  nt 
     idx = 2 
   end
  
    dat       = data.map{|d| [d[0].to_i, d[idx]]} 
    cunt = Hash.new(0)
    total = 0
    dat.each do |d|
       cunt[d[1]] += d[0]
       total += d[0]
    end

   return {:data=>cunt,:total=>total} 
  end


  def get_group_samples_id_by_factor(items_combine)  ### item is an array containing combine factors. if nil, use sample id 
    items       = items_combine
    items       = ["id"]  if items.nil?
    samples     = self.sub_experiments.select{|s| s.sample_id > 0}
    gplable     = samples.map{|s| [s.id, items.map{|item| s[item]}.join('_')] }
    ulabel      = gplable.map{|s| s[1]}.uniq
    groups      = ulabel.map{|s|  [s, gplable.select{|d| d[1] == s}.map{|d| d[0]}]  }
    return groups
  end

  def group_details(groups)
    factors = self.factor_name.split(",") 
    n       = factors.length
    dd = groups.each_with_index.map do |gp,i|
      gp[1].map do |id|
        sp = SubExperiment.find(id)
        [(i+1),sp.sample_name,sp.sample_name_org, (0...n).map{|k| sp["factor#{k+1}"]}].flatten 
      end
    end
    dd = dd.flatten(1)
    title = ["Group","Sample name","Original name"] + factors 
    {:head=>title,:data=>dd}
  end
  
  def format_array_title(n,title,maxrow)
    dn = n
    if maxrow > 0 && dn > maxrow
      dn = maxrow  
    end
    if title.nil?
      s1 = ""
    else
      if n == dn
        s1 = title + " (" + dn.to_s + " items)"  
      else
        s1 = title + " (" + dn.to_s  + "/" + n.to_s + ")"  
      end
    end
    s1
  end

  def top_proportion(groups,s_type)
    in_dir  = File.join(Rails.root,"public","sub_experiment") 
    fns_str = groups.map{|d| 
      dd = d[1].map{|id|  File.join(in_dir,id.to_s,"clone.csv")}
      dd.join(";")
    } 

    con =  Rserve::Connection.new();
    con.assign("fns_str", fns_str);
    con.assign("s_type", s_type);
    r = con.eval("get_top_proportion(fns_str,type=s_type) ").as_list()
    con.close

    mx = r["mx"].as_matrix()
    col = r["col"].as_strings()

    data_fig = (0...mx.row_size).map{|i| {:key => col[i] ,:values=> (0...mx.column_size).map{|j| [j+1, mx[i,j]]} }}
    data     = (0...mx.row_size).map{|i|  (0...mx.column_size).map{|j| [(j+1).to_s, col[i],  mx[i,j]]} }.flatten(1)
    {:data_fig=>data_fig, :data=>data,:head=>["Top","Group","Proportion"]}
  end


  def clone_space(groups,s_type)
    in_dir  = File.join(Rails.root,"public","sub_experiment") 
    fns_str = groups.map{|d| 
      dd = d[1].map{|id|  File.join(in_dir,id.to_s,"clone.csv")}
      dd.join(";")
    } 

    con =  Rserve::Connection.new();
    con.assign("fns_str", fns_str);
    con.assign("s_type", s_type);
    r = con.eval("get_clone_space(fns_str,type=s_type) ").as_list()
    con.close

    mx = r["mx"].as_matrix()
    col = r["col"].as_strings()

    data_fig = (0...mx.row_size).map{|i| {:key => col[i] ,:values=> (0...mx.column_size).map{|j| [j+1, mx[i,j]]} }}
    data     = (0...mx.row_size).map{|i|  (0...mx.column_size).map{|j| [(j+1).to_s, col[i],  mx[i,j]]} }.flatten(1)
    {:data_fig=>data_fig, :data=>data,:head=>["Group","Type","Proportion"]}
  end

  def clonotype_tracking(groups,s_type)
    in_dir  = File.join(Rails.root,"public","sub_experiment") 
    fns_str = groups.map{|d| 
      dd = d[1].map{|id|  File.join(in_dir,id.to_s,"clone.csv")}
      dd.join(";")
    } 

    con =  Rserve::Connection.new();
    con.assign("fns_str", fns_str);
    con.assign("s_type", s_type);
    r = con.eval("get_clonotype_tracking(fns_str,type=s_type) ").as_list()
    con.close

    share_k = r["share_k"].as_integers()
    share_n = r["share_n"].as_integers()

    mx  = r["mx"].as_matrix()
    col = r["col"].as_strings()
    data     = (0...mx.row_size).map{|i|  [(0...mx.column_size).map{|j| mx[i,j].to_i.to_s}, col[i]].flatten()}

    n = mx.row_size
    n = 50 if n > 50
    data_fig = {:d1 => {:data=>(0...n).map{|i| {:values => (2...mx.column_size).map{|j| {:x=> j-1 , :y=> mx[i,j]}  } , :key => col[i] }},
                        :xlabel=>  (1..mx.column_size).map{|i| i}},
                :d2 =>{:data=>[{:values=>(0...share_n.length).map{|i| {:x=> share_k[i],:y=>share_n[i]}} , :key=> "Shared clonotypes"  }],:xlabel => share_k }
                         
                }
   {:data_fig => data_fig, :data => data,:head => ["Shared","Count",(2...mx.column_size).map{|j| "Group" + (j-1).to_s  }].flatten()}
  end

  def overlap_analysis(s_type,s_method,groups)

    in_dir  = File.join(Rails.root,"public","sub_experiment") 
    fns_str = ""
    fns_str = groups.map{|d| 
      dd = d[1].map{|id|  File.join(in_dir,id.to_s,"clone.csv")}
      dd.join(";")
    } 
    con =  Rserve::Connection.new();
    con.assign("fns_str", fns_str);
    con.assign("s_type", s_type);
    con.assign("s_method", s_method);
    r = con.eval(" get_overlap_analysis(fns_str,type=s_type) ").as_matrix()
    con.close

    data = (0...r.row_size).map{|i| [r[i,0].to_i,r[i,1].to_i,r[i,2].to_i,r[i,3].to_i,r[i,4].to_i,r[i,5].to_i,r[i,6].to_i,r[i,7],r[i,8].to_i,r[i,9] ]}  
    mx   = (1..groups.length).map{|i| (1..groups.length).map{|j| 0 }} 

    case s_method 
    when 'ct' 
      idx = 6
    when 'ctm'
      idx = 7
    when 'cr'
      idx = 8
    when 'crm'
      idx = 9
    end

    data.each{|d|  
      mx[d[0]-1][d[3]-1] = d[idx] 
      mx[d[3]-1][d[0]-1] = d[idx] 
    }

    data_fig= {:row_labels => (0...groups.length).map{|i| (i+1).to_s}, 
               :col_labels => (0...groups.length).map{|i| (i+1).to_s}, 
               :mx         => mx }
    {:data=>data, :data_fig=>data_fig,:head=>["Group","clonotypes","reads","Group","clonotypes","reads",
                                              "Shared clonotypes","Shared clonotypes(normalize)","Shared reads","Shared reads(normalize)"]}
  end




  def get_similarity_within_group(s_type,s_method,data)

    in_dir = File.join(Rails.root,"public","sub_experiment") 
    sm = data.each_with_index.map do |d,i|
      fns = d[1].map{|id| File.join(in_dir,id.to_s,"clone.csv") } 
      con =  Rserve::Connection.new();
      con.assign("fns", fns);
      con.assign("s_type", s_type);
      con.assign("s_method", s_method);
      r = con.eval(" get_similarity_within_group(fns,type=s_type,method=s_method) ").as_doubles()
      con.close
      avg = r.inject(0){|sum,d| sum + d } / r.size 
      [i+1, avg, r]
    end

    {:head =>["Group","Similarity","Paires similarity"],:data=>sm }
  end

  def write_file_for_download(data)
    fn = File.join(self.file_path_root,data[:fn])
     CSV.open( fn, "wb") do |csv|
       csv << data[:head] 
       data[:data].each{|d| csv << d }
     end
  end

  def get_samples_similarity_matrix(s_type,s_method,groups)

    in_dir  = File.join(Rails.root,"public","sub_experiment") 
    fns_str = ""
    fns_str = groups.map{|d| 
      dd = d[1].map{|id|  File.join(in_dir,id.to_s,"clone.csv")}
      dd.join(";")
    } 

    con =  Rserve::Connection.new();
    con.assign("fns_str", fns_str);
    con.assign("s_type", s_type);
    con.assign("s_method", s_method);
    r = con.eval("get_group_similarity_matrix(fns_str,type=s_type,method=s_method) ").as_matrix()
    con.close

    data    = (0...r.row_size).map{|i| (i...r.column_size).map{|j| [i+1, j+1,r[i,j] ]}}.flatten(1)  
    data_fig= {:row_labels=>  (0...r.row_size).map{|i| (i+1).to_s}, 
               :col_labels=> (0...r.column_size).map{|i| (i+1).to_s}, 
               :mx => (0...r.row_size).map{|i| (0...r.column_size).map{|j| r[i,j] }}  }
    {:data=>data, :data_fig=>data_fig,:head=>["Group","Group","Similarity"]}
  end


  ### cluster
  def get_cluster_result(gps,par)
    data = get_samples_similarity_matrix(par[:s_type],par[:s_method], gps)

    mx   = Matrix.rows(data[:data_fig][:mx])
    labels = data[:data_fig][:row_labels] 

    # cluster using R
    con =  Rserve::Connection.new();
    con.assign("mx", mx);
    con.assign("labels", labels);
    con.assign("sim", par[:sim]);
    con.assign("cluster", par[:cluster]);

    r = con.eval("
                  rownames(mx) <- labels 
                  colnames(mx) <- labels 

                  sim_methods   <- c('euclidean','manhattan','pearson', 'spearman', 'kendall')
                  clust_methods <- c('ward', 'single', 'complete', 'average', 'mcquitty', 'median' ,'centroid')

                  #################    clustering ##########
                  # compute dist
                  if(sim %in% c(1,2)){
                    dmx <- dist(mx, method = sim_methods[sim])
                  }
                  if(sim %in% c(3,4,5)){
                    dmx <- as.dist((1-cor(mx,method=sim_methods[sim]))/2)
                  }
                  cl <- hclust(dmx,method=clust_methods[cluster])
                  mx = mx[cl$order,cl$order]

                  list(col_merge=cl$merge,col_height=cl$height,col_order=cl$order,col_labels=colnames(mx),
                       row_merge=cl$merge,row_height=cl$height,row_order=cl$order,row_labels=rownames(mx),mx=mx)
               ").as_list()
    con.close
    return { :col_merge => r["col_merge"].as_matrix(),:col_height => r["col_height"].as_doubles(), :col_order => r["col_order"].as_integers(),:col_labels => r["col_labels"].as_strings(),
             :row_merge => r["row_merge"].as_matrix(),:row_height => r["row_height"].as_doubles(), :row_order => r["row_order"].as_integers(),:row_labels => r["row_labels"].as_strings(), :mx => r["mx"].as_matrix() }
  end

  ###########################################

  def get_two_group_similarity(s1,s2,s_type,s_method)
    in_dir  = File.join(Rails.root,"public","sub_experiment") 
    fns1 = s1.map{|id| File.join(in_dir,id.to_s,"clone.csv")}
    fns2 = s2.map{|id| File.join(in_dir,id.to_s,"clone.csv")}
    con =  Rserve::Connection.new();
    con.assign("fns1", fns1);
    con.assign("fns2", fns2);
    con.assign("s_type", s_type);
    con.assign("s_method", s_method);
    r = con.eval(" get_two_group_similarity(fns1,fns2,type=s_type,method=s_method) ").as_doubles()
    con.close
    r[0]
 end


  def pairwise_analysis(par)
     s1 = par[:s1].split(";").map{|s| s.split(":").map{|t| t.split(",").map{|id| id } }}
     s2 = par[:s2].split(";").map{|s| s.split(":").map{|t| t.split(",").map{|id| id } }}
     paired = 0  
     paired = 1   if par[:paired] == "1"
 
    d1 = s1.map{|svs| get_two_group_similarity(svs[0],svs[1],par[:s_type],par[:s_method]) }
    d2 = s2.map{|svs| get_two_group_similarity(svs[0],svs[1],par[:s_type],par[:s_method]) }
    # T- test using R
    con =  Rserve::Connection.new();
    con.assign("x", d1);
    con.assign("y", d2);
    con.assign("paired",paired)
    con.assign("t_method",par[:t_method].to_i)
    
    r = con.eval(" 
                 if(paired == 1){ 
                    ispaired = TRUE
                   }else{
                    ispaired = FALSE 
                   }

                 if(t_method == 0){
                      d = t.test(x,y,paired=ispaired)
                    }else{
                      d = wilcox.test(x,y,paired=ispaired)
                    } 
                 d 
                ").as_list()
    con.close
    return {:p => r["p.value"].as_doubles()[0],:v => [d1,d2],:org=>{:s1=>s1,:s2=>s2}}
  end

  ####################diversity
  #
  def compute_diversity(s,par)
   s_method = par[:method]
   case  s_method 
   when 'shan'   ## shannon diversity index 
     total = s.inject(0){|sum,sk| sum + sk[1]} + 0.0 
     sum = 0
     s.each do |k,v| 
       p = v / total
       sum += p * Math.log(p)
     end
     return -sum 
       
   when 'smp' #Simpsons index 
     total = s.inject(0){|sum,sk| sum + sk[1]} + 0.0 
     sum = 0
     s.each do |k,v| 
       sum +=  v * v 
     end
     return sum / (total * total) 

    when 'ismp' #Inverse Simpsons index 
     total = s.inject(0){|sum,sk| sum + sk[1]} + 0.0 
     sum = 0
     s.each do |k,v| 
       sum +=  v * v 
     end
     return (total * total) / sum 
     
    when 'gsi' # Gini–Simpson index
     total = s.inject(0){|sum,sk| sum + sk[1]} + 0.0 
     sum = 0
     s.each do |k,v| 
       sum +=  v * v 
     end
     return 1 - sum / (total * total) 

    when 'bpi' # Berger–Parker index
     total = s.inject(0){|sum,sk| sum + sk[1]} + 0.0 
     return  s.map{|k,v| v}.max / total

    when 'renyi' #Rényi entropy
     q = par[:q] 
     total = s.inject(0){|sum,sk| sum + sk[1]} + 0.0 
     sum = 0
     s.each do |k,v| 
       p = v / total
       sum += p ** q
     end
     return  Math.log(sum)/(1-q)

   when 'un'
     return 1

   end


  end


  def get_samples_diversity(par,grps)
    in_dir  = File.join(Rails.root,"public","sub_experiment") 
    fns     = grps.map{|grp| grp[1].map{|id| File.join(in_dir,id.to_s,"clone.csv") }.join(";")}
    con =  Rserve::Connection.new();
    con.assign("fns", fns);
    con.assign("s_type", par[:s_type]);
    con.assign("s_method", par[:s_method]);
    con.assign("q_value", par[:q_value]);
    r = con.eval(" group_diversity(fns,type=s_type,method=s_method,q=q_value) ").as_doubles()
    con.close
    {:head=>["Group","Diversity"], :data => r.each_with_index.map{|v,i| [i+1,v]}}
 end


  def diversity_significant_test(par, id_facs)
    in_dir  = File.join(Rails.root,"public","sub_experiment") 
    fns     = id_facs.map{|id_fac|  File.join(in_dir,id_fac[0].to_s,"clone.csv") }
    facs    = id_facs.map{|id_fac|  id_fac[1] }
    flag = true
    msg  = ""
    begin
      con =  Rserve::Connection.new();
      con.assign("fns", fns);
      con.assign("s_type", par[:s_type]);
      con.assign("s_method", par[:s_method]);
      con.assign("facs", facs);
      r = con.eval(" diversity_test(fns,facs,type=s_type,method=s_method) ").as_list()
      con.close
      data = {:p=>r["p"].as_doubles()[0],:v=>r["dv"].as_doubles(),:facs=>r["facs"].as_strings()}
    rescue
      data = {:v=>r["dv"].as_doubles(),:facs=>r["facs"].as_strings()}
      flag = false
      msg = "Error"
    end
    return {:data => data, :flag=>flag,:msg=> msg}
  end

 
  def pairwise_diversity_analysis(par)
     in_dir  = File.join(Rails.root,"public","sub_experiment") 
     fns1 = par[:s1].split(";").map{|ss| ss.split(",").map{|id| File.join(in_dir,id.to_s,"clone.csv") }.join(";")} 
     fns2 = par[:s2].split(";").map{|ss| ss.split(",").map{|id| File.join(in_dir,id.to_s,"clone.csv") }.join(";")} 
     paired = false  
     paired = true   if par[:paired] == "1"

     con =  Rserve::Connection.new();
     con.assign("fns1", fns1);
     con.assign("fns2", fns2);
     con.assign("s_type", par[:s_type]);
     con.assign("s_method", par[:s_method]);
     con.assign("q_value", par[:q_value]);
     con.assign("t_method", par[:t_method]);
     con.assign("paired",paired)
    
     r = con.eval(" pairwise_diversity_analysis(fns1,fns2,type=s_type,method=s_method,q=q_value,t_method = t_method,paired = paired) ").as_list()
     con.close

    return {:p => r["p"].as_doubles()[0], :v => [r["dv1"].as_doubles(),r["dv2"].as_doubles()],:method=>r["method"].as_strings()[0]}
  end
end
