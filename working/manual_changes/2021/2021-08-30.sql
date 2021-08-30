-- Adding new relationships for the SNOMED-2021 releases
DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Has absorbability',
	pRelationship_id			=>'Has absorbability',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pReverse_relationship_id	=>'Absorbability of',
	pRelationship_name_rev		=>'Absorbability of',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;

DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Has coating material',
	pRelationship_id			=>'Has coating material',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pReverse_relationship_id	=>'Coating material of',
	pRelationship_name_rev		=>'Coating material of',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;

DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Is sterile',
	pRelationship_id			=>'Is sterile',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pReverse_relationship_id	=>'Is sterile reverse',
	pRelationship_name_rev		=>'Is sterile reverse',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;

DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Has ingredient qualitative strength',
	pRelationship_id			=>'Has ing qual strengt',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pReverse_relationship_id	=>'Ing qual strengt of',
	pRelationship_name_rev		=>'Ingredient qualitative strength of',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;

DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Process extends to',
	pRelationship_id			=>'Process extends to',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pReverse_relationship_id	=>'Extended by process',
	pRelationship_name_rev		=>'Extended by process',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;


DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Has surface texture',
	pRelationship_id			=>'Has surface texture',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pReverse_relationship_id	=>'Surface texture of',
	pRelationship_name_rev		=>'Surface texture of',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;

DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Has target population',
	pRelationship_id			=>'Has target populatio',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pReverse_relationship_id	=>'Target population of',
	pRelationship_name_rev		=>'Target population of',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;
