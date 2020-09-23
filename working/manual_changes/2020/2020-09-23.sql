--new classes for NCIt
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewConceptClass(
	pConcept_class_id	=>'AJCC Chapter',
	pConcept_class_name	=>'AJCC Chapter'
);
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewConceptClass(
	pConcept_class_id	=>'AJCC Category',
	pConcept_class_name	=>'AJCC Category'
);
END $_$;

--new relationships for NCIt
DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Category in Chapter',
	pRelationship_id			=>'Category in Chapter',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pReverse_relationship_id	=>'Chapter has Category',
	pRelationship_name_rev		=>'Chapter has Category',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;
--new relationships for NCIt
DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Chapter to ICDO',
	pRelationship_id			=>'Chapter to ICDO',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pReverse_relationship_id	=>'ICDO to Chapter',
	pRelationship_name_rev		=>'ICDO to Chapter',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;
-
