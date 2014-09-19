options (skip=1)
load data
infile class_old_to_new.csv 
into table class_old_to_new
replace
fields terminated by ','
trailing nullcols
(
  original,
  class_code
  
)