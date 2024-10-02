-- Add new relationship of equivalence between HCPCS and the Visit domain:
DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewRelationship(
    pRelationship_name       =>'HCPCS - Visit equivalent (OMOP)',
    pRelationship_id         =>'HCPCS - Visit eq',
    pIs_hierarchical         =>0,
    pDefines_ancestry        =>0,
    pReverse_relationship_id =>'Visit - HCPCS eq',
    pRelationship_name_rev   =>'Visit - HCPCS equivalent (OMOP)',
    pIs_hierarchical_rev     =>0,
    pDefines_ancestry_rev    =>0
);
END $_$;

select * from relationship where relationship_id = 'CPT4 - SNOMED eq';