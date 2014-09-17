options (skip=1)
load data
infile relationship_id_to_code.csv
into table relationship_id_to_code
replace
fields terminated by ','
trailing nullcols
(
  relationship_id,
  relationship_code
  
)