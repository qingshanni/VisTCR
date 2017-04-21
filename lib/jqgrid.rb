module Jqgrid

   def filter_by_conditions(columns)
     conditions = ""
     columns.each do |column|
       conditions << "#{column} LIKE '%#{params[column]}%' AND " unless params[column].nil?
     end
     conditions.chomp("AND ")
   end




end
