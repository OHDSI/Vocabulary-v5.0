-- 1. Make SNOMED Veterinary relationships 'Sub-specimen of' and 'Has sub-specimen' non-hierarchical:
--- They lead to the hierarchy loops creation in concept_ancestor

UPDATE relationship
SET is_hierarchical = 0
WHERE relationship_id IN ('Sub-specimen of', 'Has sub-specimen')
;

UPDATE relationship
SET defines_ancestry = 0
WHERE relationship_id IN ('Sub-specimen of', 'Has sub-specimen');