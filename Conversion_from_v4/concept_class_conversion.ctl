options (skip=1)
load data
infile concept_class_conversion.csv 
into table concept_class_conversion
replace
fields terminated by ','
optionally enclosed by '"'
trailing nullcols
(
  concept_class,
  concept_class_id_new
)