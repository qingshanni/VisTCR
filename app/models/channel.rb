class Channel < ActiveRecord::Base
  attr_accessible :user_id, :experiment_id, :sub_experiment_id, :position, :sample, :detector, :ct_value, :task, :confidence    
  belongs_to :experiment
  belongs_to :sub_experiment
  belongs_to :primer
  belongs_to :user

end
