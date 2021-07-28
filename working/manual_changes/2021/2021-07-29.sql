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
	pRelationship_name			=>'OncoTree to ICDO',
	pRelationship_id			=>'OncoTree to ICDO',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pReverse_relationship_id	=>'ICDO to OncoTree',
	pRelationship_name_rev		=>'ICDO to OncoTree',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;
