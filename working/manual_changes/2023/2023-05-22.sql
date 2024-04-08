--Add new proprietary vocabularies
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewVocabulary(
	pVocabulary_id			=> 'CO-CONNECT',
	pVocabulary_name		=> 'IQVIA CO-CONNECT',
	pVocabulary_reference	=> 'IQVIA proprietary',
	pVocabulary_version		=> NULL,
	pOMOP_req				=> NULL,
	pClick_default			=> NULL, --NULL or 'Y'
	pAvailable				=> 'License required', --NULL, 'Currently not available','License required' or 'EULA required'
	pURL					=> NULL,
	pClick_disabled			=> NULL --NULL or 'Y'
);
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewVocabulary(
	pVocabulary_id			=> 'CO-CONNECT MIABIS',
	pVocabulary_name		=> 'IQVIA CO-CONNECT MIABIS',
	pVocabulary_reference	=> 'IQVIA proprietary',
	pVocabulary_version		=> NULL,
	pOMOP_req				=> NULL,
	pClick_default			=> NULL, --NULL or 'Y'
	pAvailable				=> 'License required', --NULL, 'Currently not available','License required' or 'EULA required'
	pURL					=> NULL,
	pClick_disabled			=> NULL --NULL or 'Y'
);
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewVocabulary(
	pVocabulary_id			=> 'CO-CONNECT TWINS',
	pVocabulary_name		=> 'IQVIA CO-CONNECT TWINS',
	pVocabulary_reference	=> 'IQVIA proprietary',
	pVocabulary_version		=> NULL,
	pOMOP_req				=> NULL,
	pClick_default			=> NULL, --NULL or 'Y'
	pAvailable				=> 'License required', --NULL, 'Currently not available','License required' or 'EULA required'
	pURL					=> NULL,
	pClick_disabled			=> NULL --NULL or 'Y'
);
END $_$;