	--new vocabulary='ICD10CN'
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewVocabulary(
	pVocabulary_id			=> 'ICD10CN',
	pVocabulary_name		=> 'International Classification of Diseases, Tenth Revision, Chinese Edition',
	pVocabulary_reference	=> 'http://medportal.bmicc.cn/ontologies/ICD10CN',
	pVocabulary_version		=> NULL,
	pOMOP_req				=> NULL,
	pClick_default			=> NULL, --NULL or 'Y'
	pAvailable				=> NULL, --NULL, 'Currently not available','License required' or 'EULA required'
	pURL					=> NULL,
	pClick_disabled			=> NULL --NULL or 'Y'
);
END $_$;