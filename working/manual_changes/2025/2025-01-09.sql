-- Add a new relationship of between HCPCS/CPT4 concepts and the Visit domain:
DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewRelationship(
    pRelationship_name       =>'Has associated visit (OMOP)',
    pRelationship_id         =>'Has asso visit',
    pIs_hierarchical         =>0,
    pDefines_ancestry        =>0,
    pReverse_relationship_id =>'Asso visit of',
    pRelationship_name_rev   =>'Associated visit of (OMOP)',
    pIs_hierarchical_rev     =>0,
    pDefines_ancestry_rev    =>0
);
END $_$;
