options (skip=1)
load data
infile vovcabulary_id_to_code.csv
into table vovcabulary_id_to_code
replace
fields terminated by ','
trailing nullcols
(
  vocabulary_id,
  vocabulary_code
  
)