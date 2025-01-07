-- Make relationships 'Sub-specimen of' and 'Has sub-specimen' non-hierarchical.
--- They come from SNOMED Vet and lead to the hierarchy loops creation.
UPDATE relationship
SET is_hierarchical = 0
WHERE relationship_id IN ('Sub-specimen of', 'Has sub-specimen')
;

UPDATE relationship
SET defines_ancestry = 0
WHERE relationship_id IN ('Sub-specimen of', 'Has sub-specimen');

select * from relationship where relationship_id like '%specimen%'

