require 'fileutils'

class ApplicationController < ActionController::Base
  protect_from_forgery
  
  include Rconnect 

  rescue_from CanCan::AccessDenied do |exception|
    redirect_to root_path, :alert => exception.message
  end
  def sort_order(default)
    "#{(params[:c] || default.to_s).gsub(/[\s;'\"']/,'')} #{params[:d] == 'down' ? 'DESC' : 'ASC'}"
  end

  def read_help(code)
    fn    = File.join(Rails.root,"public","sup","help_txt") 
    data  = File.read(fn) 
    reg   = "/^#" + code + "\n@.*\n([\\w\\W]*?)^#/.match(data)"
    msg   = eval(reg)
    if ! msg.nil?
      msg = msg[1].strip.gsub("\n","<br>")
    end
    msg
  end
   
  ##### [['asd',10],['wesd',6],['dqqw',20]]
  def get_item_count(arr)
    u = Hash.new(0)
    arr.each do |d|
      u[d[0]] = u[d[0]] + d[1]
    end
    u.sort{|x,y| y[1] <=> x[1]}
  end
  
end
