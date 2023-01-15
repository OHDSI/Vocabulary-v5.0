--Add new relationships for HemOnc refresh
DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Has steroid therapy (HemOnc)',
	pRelationship_id			=>'Has steroid tx',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pRelationship_name_rev	=>'Steroid therapy of (HemOnc)',
	pReverse_relationship_id		=>'Steroid tx of',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Has steroid therapy - RxNorm (HemOnc)',
	pRelationship_id			=>'Has steroid tx Rx',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pRelationship_name_rev	=>'RxNorm steroid therapy of (HemOnc)',
	pReverse_relationship_id		=>'Rx steroid tx of',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;


DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Is current in adult (HemOnc)',
	pRelationship_id			=>'Is curr in adult',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pRelationship_name_rev	=>'Current adult indication for (HemOnc)',
	pReverse_relationship_id		=>'Curr adult indic for',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Is current in pediatric (HemOnc)',
	pRelationship_id			=>'Is curr in ped',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pRelationship_name_rev	=>'Current pediatric indication for (HemOnc)',
	pReverse_relationship_id		=>'Curr ped indic for',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Is historical in adult (HemOnc)',
	pRelationship_id			=>'Is hist in adult',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pRelationship_name_rev	=>'Historical adult indication for (HemOnc)',
	pReverse_relationship_id		=>'Hist adult indic for',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Had accepted use (HemOnc)',
	pRelationship_id			=>'Had accepted use',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pRelationship_name_rev	=>'Had accepted for (HemOnc)',
	pReverse_relationship_id		=>'Had accepted for',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Has investigational use (HemOnc)',
	pRelationship_id			=>'Has investig use',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pRelationship_name_rev	=>'Investigational use for (HemOnc)',
	pReverse_relationship_id		=>'Investig use for',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Has PDC - RxNorm (HemOnc)',
	pRelationship_id			=>'Has PDC Rx',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pRelationship_name_rev	=>'RxNorm PDC of (HemOnc)',
	pReverse_relationship_id		=>'Rx PDC of',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Is historical in pediatric (HemOnc)',
	pRelationship_id			=>'Is hist in ped',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pRelationship_name_rev	=>'Historical pediatric indication for (HemOnc)',
	pReverse_relationship_id		=>'Hist ped indic for',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;