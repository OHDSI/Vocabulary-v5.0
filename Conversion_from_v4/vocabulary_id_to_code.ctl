options (skip=1)
load data
infile vocabulary_id_to_code.csv
into table vocabulary_id_to_code
replace
fields terminated by ','
trailing nullcols
(
  vocabulary_id,
  vocabulary_code
  
)