# Load the rails application
require File.expand_path('../application', __FILE__)

#require 'rserve'
#require 'rconnect'
#require 'matrix'
# Initialize the rails application
Qpcr::Application.initialize!

# Rconnet = Rserve::Connection.new();
 TASK_REPLACE = {"replace_by"=> {"target"=>"target",
                                 "endogenous control"=>"endogenous control", 
                                 "unknown"=>"target",
                                 "ntc"=>"endogenous control",
                                 "standard"=>"endogenous control"},
                "replace_code"=>{"target"=>1,
                                 "endogenous control"=>2, 
                                 "unknown"=>3,
                                 "ntc"=>4,
                                 "standard"=>5} 
               }

