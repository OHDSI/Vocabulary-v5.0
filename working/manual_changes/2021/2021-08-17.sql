--new vocabulary
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewVocabulary(
	pVocabulary_id			=> 'OncoTree',
	pVocabulary_name		=> 'OncoTree (MSK)',
	pVocabulary_reference	=> 'http://oncotree.mskcc.org/',
	pVocabulary_version		=> NULL,
	pOMOP_req				=> NULL,
	pClick_default			=> NULL, --NULL or 'Y'
	pAvailable				=> NULL, --NULL, 'Currently not available','License required' or 'EULA required'
	pURL					=> NULL,
	pClick_disabled			=> NULL --NULL or 'Y'
);
END $_$;

--new relationships for OncoTree to ICDO
DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'OncoTree to ICDO equivalent',
	pRelationship_id			=>'OncoTree to ICDO eq',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pReverse_relationship_id	=>'ICDO to OncoTree eq',
	pRelationship_name_rev		=>'ICDO to OncoTree equivalent',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;

--new relationships for Oncotre
DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'OncoTree to ICDO broader',
	pRelationship_id			=>'OncoTree to ICDO br',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pReverse_relationship_id	=>'ICDO br to OncoTree',
	pRelationship_name_rev		=>'ICDO broader to OncoTree',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;
