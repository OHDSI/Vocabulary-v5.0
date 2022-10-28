--Add ne domain Language
DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewDomain(
		pDomain_id		=>'Language',
		pDomain_name	=>'Language'
	);
END $_$;

--add new vocabulary Language
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewVocabulary(
	pVocabulary_id			=> 'Language',
	pVocabulary_name		=> 'Language (OMOP)',
	pVocabulary_reference	=> 'OMOP generated',
	pVocabulary_version		=> NULL,
	pOMOP_req				=> NULL,
	pClick_default			=> NULL, --NULL or 'Y'
	pAvailable				=> NULL, --NULL, 'Currently not available','License required' or 'EULA required'
	pURL					=> NULL,
	pClick_disabled			=> NULL --NULL or 'Y'
);
END $_$;


