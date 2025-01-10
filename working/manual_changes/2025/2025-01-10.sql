-- 1. Create new relationship linking Dose Form and Route of Administration (Community Contribution):

DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewRelationship(
    pRelationship_name       =>'Dose form to route of administration (OMOP)',
    pRelationship_id         =>'Dose form to route',
    pIs_hierarchical         =>0,
    pDefines_ancestry        =>0,
    pReverse_relationship_id =>'Route to dose form',
    pRelationship_name_rev   =>'Route of administration to dose form (OMOP)',
    pIs_hierarchical_rev     =>0,
    pDefines_ancestry_rev    =>0
);
END $_$;

-- 2. Make SNOMED Veterinary relationships 'Sub-specimen of' and 'Has sub-specimen' non-hierarchical:
--- They lead to the hierarchy loops creation in concept_ancestor

UPDATE relationship
SET is_hierarchical = 0
WHERE relationship_id IN ('Sub-specimen of', 'Has sub-specimen')
;

UPDATE relationship
SET defines_ancestry = 0
WHERE relationship_id IN ('Sub-specimen of', 'Has sub-specimen');