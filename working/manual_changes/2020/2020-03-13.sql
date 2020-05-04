--new vocabulary='Nebraska Lexicon'
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewVocabulary(
	pVocabulary_id			=> 'Nebraska Lexicon',
	pVocabulary_name		=> 'Nebraska Lexicon',
	pVocabulary_reference	=> 'https://www.unmc.edu/pathology-research/bioinformatics/campbell/tdc.html',
	pVocabulary_version		=> 'Nebraska Lexicon 20200131',
	pOMOP_req				=> NULL,
	pClick_default			=> NULL, --NULL or 'Y'
	pAvailable				=> NULL, --NULL, 'Currently not available','License required' or 'EULA required'
	pURL					=> NULL,
	pClick_disabled			=> NULL --NULL or 'Y'
);
END $_$;
