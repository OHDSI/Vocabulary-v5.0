--new relationships for HemOnc
DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Has biosimilar',
	pRelationship_id			=>'Has biosimilar',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pReverse_relationship_id	=>'Biosimilar of',
	pRelationship_name_rev		=>'Biosimilar of',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;