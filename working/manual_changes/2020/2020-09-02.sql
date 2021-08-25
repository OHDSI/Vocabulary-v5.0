--add new vocabulary='ICD10GM' [AVOF-2783]
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewVocabulary(
	pVocabulary_id			=> 'ICD10GM',
	pVocabulary_name		=> 'International Classification of Diseases, Tenth Revision, German Edition',
	pVocabulary_reference	=> 'https://www.dimdi.de/dynamic/.downloads/klassifikationen/icd-10-gm',
	pVocabulary_version		=> 'ICD10GM 2021',
	pOMOP_req				=> NULL, --NULL or 'Y'
	pClick_default			=> NULL, --NULL or 'Y'
	pAvailable				=> NULL, --NULL, 'Currently not available','License required' or 'EULA required'
	pURL					=> NULL,
	pClick_disabled			=> NULL --NULL or 'Y'
);
END $_$;