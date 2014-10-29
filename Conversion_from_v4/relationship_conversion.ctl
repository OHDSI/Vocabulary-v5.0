options (skip=1)
load data
infile relationship_conversion.csv
into table relationship_conversion
replace
fields terminated by ','
trailing nullcols
(
  relationship_id,
  relationship_id_new  
)