options (skip=1)
load data
infile class.csv
into table class
replace
fields terminated by '\t'
optionally enclosed by '"'
trailing nullcols
(
  class_code,
  class_name,
  class_concept_id

)