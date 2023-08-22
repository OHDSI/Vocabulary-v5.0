--Adding two new vocabularies
--https://github.com/OHDSI/Vocabulary-v5.0/issues/843

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewVocabulary(
	pVocabulary_id			=> 'NHS Ethnic Category',
	pVocabulary_name		=> 'NHS Ethnic Category',
	pVocabulary_reference	=> 'https://www.datadictionary.nhs.uk/data_elements/ethnic_category.html#element_ethnic_category.description',
	pVocabulary_version		=> '2023',
	pOMOP_req				=> NULL,
	pClick_default			=> NULL, --NULL or 'Y'
	pAvailable				=> NULL, --NULL, 'Currently not available','License required' or 'EULA required'
	pURL					=> NULL,
	pClick_disabled			=> NULL --NULL or 'Y'
);

	PERFORM VOCABULARY_PACK.AddNewVocabulary(
	pVocabulary_id			=> 'NHS Place of Service',
	pVocabulary_name		=> 'NHS Admission Source and Discharge Destination',
	pVocabulary_reference	=> 'https://www.datadictionary.nhs.uk/about/about.html',
	pVocabulary_version		=> '2023',
	pOMOP_req				=> NULL,
	pClick_default			=> NULL, --NULL or 'Y'
	pAvailable				=> NULL, --NULL, 'Currently not available','License required' or 'EULA required'
	pURL					=> NULL,
	pClick_disabled			=> NULL --NULL or 'Y'
);
END $_$;