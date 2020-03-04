--new vocabulary='ICD9ProcCN'
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewVocabulary(
	pVocabulary_id			=> 'ICD9ProcCN',
	pVocabulary_name		=> 'International Classification of Diseases, Ninth Revision, Chinese Edition, Procedures',
	pVocabulary_reference	=> 'http://chiss.org.cn/hism/wcmpub/hism1029/notice/201712/P020171225613285104950.pdf',
	pVocabulary_version		=> NULL,
	pOMOP_req				=> NULL,
	pClick_default			=> NULL, --NULL or 'Y'
	pAvailable				=> NULL, --NULL, 'Currently not available','License required' or 'EULA required'
	pURL					=> NULL,
	pClick_disabled			=> NULL --NULL or 'Y'
);
END $_$;

--new class '6-dig billing code'
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewConceptClass(
	pConcept_class_id	=>'6-dig billing code',
	pConcept_class_name	=>'6-dig billing code'
);
END $_$;

--new class 'ICD9Proc Chapter'
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewConceptClass(
	pConcept_class_id	=>'ICD9Proc Chapter',
	pConcept_class_name	=>'ICD9Proc Chapter'
);
END $_$;
