options (skip=1)
load data
infile concept_synonym.txt
into table concept_synonym
replace
fields terminated by '\t'
trailing nullcols
(
  concept_synonym_name char(1005),
  concept_id,
  language_concept_id constant 4093769
)