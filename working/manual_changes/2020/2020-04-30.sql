--new relationships for CAP
DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'CAP to Nebraska Lexicon category',
	pRelationship_id			=>'CAP-Nebraska cat',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pReverse_relationship_id	=>'Nebraska-CAP cat',
	pRelationship_name_rev		=>'Nebraska Lexicon to CAP category',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'CAP to Nebraska Lexicon equivalent',
	pRelationship_id			=>'CAP-Nebraska eq',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pReverse_relationship_id	=>'Nebraska-CAP eq',
	pRelationship_name_rev		=>'Nebraska Lexicon to CAP equivalent',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;