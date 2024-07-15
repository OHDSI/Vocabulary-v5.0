-- Exclude 'CPT4-SNOMED cat' and the respective reverse relationship from concept_ancestor:

UPDATE relationship
SET is_hierarchical = 0
WHERE relationship_id = 'CPT4 - SNOMED cat';

UPDATE relationship
SET is_hierarchical = 0
WHERE relationship_id = 'SNOMED cat - CPT4';

UPDATE relationship
SET defines_ancestry = 0
WHERE relationship_id = 'SNOMED cat - CPT4';