--add new vocabulary, 'OMOP Invest Drug'
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewVocabulary(
	pVocabulary_id			=> 'OMOP Invest Drug',
	pVocabulary_name		=> 'OMOP Investigational Drugs',
	pVocabulary_reference	=> 'https://gsrs.ncats.nih.gov/, https://evs.nci.nih.gov/ftp1/NCI_Thesaurus/Drug_or_Substance/Antineoplastic_Agent.txt',
	pVocabulary_version		=> NULL,
	pOMOP_req				=> NULL,
	pClick_default			=> NULL, --NULL or 'Y'
	pAvailable				=> NULL, --NULL, 'Currently not available','License required' or 'EULA required'
	pURL					=> NULL,
	pClick_disabled			=> NULL --NULL or 'Y'
);
END $_$;
