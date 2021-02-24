
DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Relative to (SNOMED)',
	pRelationship_id			=>'Relative to',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pRelationship_name_rev	=>'Relative to of (SNOMED)',
	pReverse_relationship_id		=>'Relative to of',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Count of active ingredients (SNOMED)',
	pRelationship_id			=>'Has count of act ing',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pRelationship_name_rev	=>'Is count of active ingredients in (SNOMED)',
	pReverse_relationship_id		=>'Count of act ing in',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Has product characteristic (SNOMED)',
	pRelationship_id			=>'Has prod character',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pRelationship_name_rev	=>	'Product characteristic of (SNOMED)',
	pReverse_relationship_id		=>'Prod character of',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Has surface characteristic (SNOMED)',
	pRelationship_id			=>'Has surface char',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pRelationship_name_rev	=>	'Surface characteristic of (SNOMED)',
	pReverse_relationship_id		=>	'Surf character of',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Has device intended site (SNOMED)',
	pRelationship_id			=>'Has dev intend site',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pRelationship_name_rev	=>	'Device intended site of (SNOMED)',
	pReverse_relationship_id		=>	'Dev intended site of',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Has compositional material (SNOMED)',
	pRelationship_id			=>'Has comp material',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pRelationship_name_rev	=>	'Compositional material of (SNOMED)',
	pReverse_relationship_id		=>	'Comp material of',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Has filling (SNOMED)',
	pRelationship_id			=>'Has filling',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pRelationship_name_rev	=>	'Filling material of (SNOMED)',
	pReverse_relationship_id		=>	'Filling of',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;