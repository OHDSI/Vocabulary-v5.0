-- Add a new attribute relationship of SNOMED:
DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewRelationship(
    pRelationship_name       =>'Regional part of (SNOMED)',
    pRelationship_id         =>'Regional part of',
    pIs_hierarchical         =>0,
    pDefines_ancestry        =>0,
    pReverse_relationship_id =>'Whole of',
    pRelationship_name_rev   =>'Whole of (SNOMED)',
    pIs_hierarchical_rev     =>0,
    pDefines_ancestry_rev    =>0
);
END $_$;