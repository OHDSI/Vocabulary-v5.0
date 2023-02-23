--Add new relationships for CVX refresh
DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Has vaccine group (CVX)',
	pRelationship_id			=>'Has vaccine group',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pRelationship_name_rev	=>'Vaccine group of (CVX)',
	pReverse_relationship_id		=>'Vaccine group of',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;