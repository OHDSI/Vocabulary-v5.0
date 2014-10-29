options (skip=1)
load data
infile relationship.csv
into table relationship
replace
fields terminated by ','
optionally enclosed by '"'
trailing nullcols
(
  relationship_id,
  relationship_name,
  is_hierarchical nullif is_hierarchical='',
  defines_ancestry nullif defines_ancestry='',
  reverse_relationship_id,
  relationship_concept_id
)