options (skip=1)
load data
infile domain.csv
into table domain
replace
fields terminated by ','
trailing nullcols
(
  domain_code,
  domain_name,
  domain_concept_id

)