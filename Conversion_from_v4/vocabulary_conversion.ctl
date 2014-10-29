options (skip=1)
load data
infile vocabulary_conversion.csv
into table vocabulary_conversion
replace
fields terminated by ','
trailing nullcols
(
  vocabulary_id_v4,
  vocabulary_id_v5,
  omop_req,
  click_default,
  available
)