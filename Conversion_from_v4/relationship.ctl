options (skip=1)
load data
infile relationship.txt
into table relationship
replace
fields terminated by ','
trailing nullcols
(
  relationship_code,
  relationship_name,
  is_hierarchical nullif is_hierarchical='',
  defines_ancestry nullif defines_ancestry='',
  relationship_concept_id integer not null

)