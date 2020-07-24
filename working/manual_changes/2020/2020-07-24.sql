DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewVocabulary(
	pVocabulary_id			=> 'CIM10Fr',
	pVocabulary_name		=> 'International Classification of Diseases, Tenth Revision, French Edition',
	pVocabulary_reference	=> 'https://www.atih.sante.fr/nomenclatures-de-recueil-de-linformation/cim',
	pVocabulary_version		=> 'CIM10Fr 2020-04-14',
	pOMOP_req				=> NULL, --NULL or 'Y'
	pClick_default			=> NULL, --NULL or 'Y'
	pAvailable				=> NULL, --NULL, 'Currently not available','License required' or 'EULA required'
	pURL					=> NULL,
	pClick_disabled			=> NULL --NULL or 'Y'
);
END $_$;