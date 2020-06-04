--new ATC links, new postprocessing logic [AVOF-2464, AVOF-2548]

UPDATE relationship
SET defines_ancestry = 0
WHERE relationship_id IN (
		'ATC - RxNorm name',
		'ATC - RxNorm',
		'Drug class of drug'
		);

DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewRelationship(
    pRelationship_name       =>'ATC to RxNorm/Extension primary lateral (OMOP)',
    pRelationship_id         =>'ATC - RxNorm pr lat',
    pIs_hierarchical         =>0,
    pDefines_ancestry        =>0,
    pReverse_relationship_id =>'RxNorm - ATC pr lat',
    pRelationship_name_rev   =>'RxNorm/Extension to ATC pr lateral (OMOP)',
    pIs_hierarchical_rev     =>0,
    pDefines_ancestry_rev    =>0
);
END $_$;

DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewRelationship(
    pRelationship_name       =>'ATC to RxNorm/Extension secondary lateral (OMOP)',
    pRelationship_id         =>'ATC - RxNorm sec lat',
    pIs_hierarchical         =>0,
    pDefines_ancestry        =>0,
    pReverse_relationship_id =>'RxNorm - ATC sec lat',
    pRelationship_name_rev   =>'RxNorm/Extension to ATC secondary lateral (OMOP)',
    pIs_hierarchical_rev     =>0,
    pDefines_ancestry_rev    =>0
);
END $_$;

DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewRelationship(
    pRelationship_name       =>'ATC to RxNorm/Extension primary upwards (OMOP)',
    pRelationship_id         =>'ATC - RxNorm pr up',
    pIs_hierarchical         =>0,
    pDefines_ancestry        =>0,
    pReverse_relationship_id =>'RxNorm - ATC pr up',
    pRelationship_name_rev   =>'RxNorm/Extension to ATC primary upwards (OMOP)',
    pIs_hierarchical_rev     =>0,
    pDefines_ancestry_rev    =>0
);
END $_$;

DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewRelationship(
    pRelationship_name       =>'ATC to RxNorm/Extension secondary upwards (OMOP)',
    pRelationship_id         =>'ATC - RxNorm sec up',
    pIs_hierarchical         =>0,
    pDefines_ancestry        =>0,
    pReverse_relationship_id =>'RxNorm - ATC sec up',
    pRelationship_name_rev   =>'RxNorm/Extension to ATC secondary upwards (OMOP)',
    pIs_hierarchical_rev     =>0,
    pDefines_ancestry_rev    =>0
);
END $_$;