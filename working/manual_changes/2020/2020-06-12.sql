--create new Relationship_id for PPI
DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Has question source (PPI)',
	pRelationship_id			=>'Has question source',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pReverse_relationship_id	=>'Question source of',
	pRelationship_name_rev		=>'Question source of (PPI)',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;

--create new classes for PPI
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewConceptClass(
	pConcept_class_id	=>'Question source',
	pConcept_class_name	=>'Question source'
);
END $_$;
