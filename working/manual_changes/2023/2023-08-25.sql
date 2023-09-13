--Change of vocabulary license requirements and vocabulary_reference for CO-CONNECT family of the vocabularies
--AVOC-4015
UPDATE vocabulary 
SET vocabulary_name = replace(vocabulary_name, 'IQVIA ', '') ||' (University of Dundee)',
    vocabulary_reference = 'https://co-connect.ac.uk/'
WHERE vocabulary_id IN ('CO-CONNECT', 'CO-CONNECT TWINS', 'CO-CONNECT MIABIS');

UPDATE vocabulary_conversion
SET available = NULL,
    URL = NULL
WHERE vocabulary_id_v5 IN ('CO-CONNECT', 'CO-CONNECT TWINS', 'CO-CONNECT MIABIS');


--Adding two new vocabularies
--https://github.com/OHDSI/Vocabulary-v5.0/issues/843

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewVocabulary(
	pVocabulary_id			  => 'NHS Ethnic Category',
	pVocabulary_name		  => 'NHS Ethnic Category',
	pVocabulary_reference	=> 'https://www.datadictionary.nhs.uk/data_elements/ethnic_category.html#element_ethnic_category.description',
	pVocabulary_version		=> '2023',
	pOMOP_req				      => NULL,
	pClick_default			  => NULL, --NULL or 'Y'
	pAvailable				    => NULL, --NULL, 'Currently not available','License required' or 'EULA required'
	pURL					        => NULL,
	pClick_disabled			  => NULL --NULL or 'Y'
);

	PERFORM VOCABULARY_PACK.AddNewVocabulary(
	pVocabulary_id			  => 'NHS Place of Service',
	pVocabulary_name		  => 'NHS Admission Source and Discharge Destination',
	pVocabulary_reference	=> 'https://www.datadictionary.nhs.uk/about/about.html',
	pVocabulary_version		=> '2023',
	pOMOP_req				      => NULL,
	pClick_default			  => NULL, --NULL or 'Y'
	pAvailable				    => NULL, --NULL, 'Currently not available','License required' or 'EULA required'
	pURL					        => NULL,
	pClick_disabled			  => NULL --NULL or 'Y'
);
END $_$;