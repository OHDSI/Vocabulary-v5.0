--new vocabulary='CTD'
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewVocabulary(
	pVocabulary_id			=> 'CTD',
	pVocabulary_name		=> 'Comparative Toxicogenomic Database',
	pVocabulary_reference	=> 'http://ctdbase.org',
	pVocabulary_version		=> NULL,
	pOMOP_req				=> NULL,
	pClick_default			=> NULL, --NULL or 'Y'
	pAvailable				=> NULL, --NULL, 'Currently not available','License required' or 'EULA required'
	pURL					=> NULL,
	pClick_disabled			=> NULL --NULL or 'Y'
);
END $_$;

--new vocabulary='EDI'
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewVocabulary(
	pVocabulary_id			=> 'EDI',
	pVocabulary_name		=> 'Korean EDI',
	pVocabulary_reference	=> 'http://www.hira.or.kr/rd/insuadtcrtr/bbsView.do?pgmid=HIRAA030069000400&brdScnBltNo=4&brdBltNo=51354&pageIndex=1&isPopupYn=Y',
	pVocabulary_version		=> 'EDI 2019.10.01',
	pOMOP_req				=> NULL,
	pClick_default			=> NULL, --NULL or 'Y'
	pAvailable				=> NULL, --NULL, 'Currently not available','License required' or 'EULA required'
	pURL					=> NULL,
	pClick_disabled			=> NULL --NULL or 'Y'
);
END $_$;

--new class for EDI
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewConceptClass(
	pConcept_class_id	=>'Proc Hierarchy',
	pConcept_class_name	=>'Procedure Hierarchy'
);
END $_$;
