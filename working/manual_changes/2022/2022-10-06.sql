--add new vocabulary, 'COSMIC'
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewVocabulary(
	pVocabulary_id			=> 'COSMIC',
	pVocabulary_name		=> 'Catalogue Of Somatic Mutations In Cancer',
	pVocabulary_reference	=> 'https://cancer.sanger.ac.uk/cosmic',
	pVocabulary_version		=> 'v.96 20220531',
	pOMOP_req				=> NULL,
	pClick_default			=> NULL, --NULL or 'Y'
	pAvailable				=> 'License required', --NULL, 'Currently not available','License required' or 'EULA required'
	pURL					=> NULL,
	pClick_disabled			=> NULL --NULL or 'Y'
);
END $_$;