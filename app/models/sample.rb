class Sample < ActiveRecord::Base
  attr_accessible :sid, :description, :title,:user_id,:project_id
  belongs_to  :user
  belongs_to  :project
  after_destroy :del_relate_files

  def del_relate_files
    dir_path = "public/samples/" + self.id.to_s
    if Dir.exist?(dir_path)
      FileUtils.remove_dir  dir_path 
    end
  end

  def read_fastqc_result(i)
    # i is qc item no.
    file     =  "public/samples/" + self.id.to_s + "/sample_fastqc/fastqc_data.txt"
    data     = File.read(file) 
    data     = data.split(">>")
    d        = data[i*2-1].split("\n#")
    titleall = d[0].split("\t")
    title    = titleall[0]
    status   = titleall[1]
    data_table = d[-1]

    return {"title"=> title, "status"=> status,  "data_table" => data_table }
  end



end

