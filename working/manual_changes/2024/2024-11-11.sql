-- Add new relationship of equivalence between CPT4 and the Visit domain:
DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewRelationship(
    pRelationship_name       =>'CPT4 - Visit equivalent (OMOP)',
    pRelationship_id         =>'CPT4 - Visit eq',
    pIs_hierarchical         =>0,
    pDefines_ancestry        =>0,
    pReverse_relationship_id =>'Visit - CPT4 eq',
    pRelationship_name_rev   =>'Visit - CPT4 equivalent (OMOP)',
    pIs_hierarchical_rev     =>0,
    pDefines_ancestry_rev    =>0
);
END $_$;
