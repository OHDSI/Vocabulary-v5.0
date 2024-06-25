--Add new vocabulary
DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewVocabulary(
	pVocabulary_id          => 'CDISC',
    pVocabulary_name        => 'Clinical Data Interchange Standards Consortium',
    pVocabulary_reference   => 'https://evs.nci.nih.gov/evs-download/metathesaurus-downloads',
    pVocabulary_version     => '2023_12D',
    pOMOP_req				=> 'Y', --NULL or 'Y'
	pClick_default			=> NULL, --NULL or 'Y'
	pAvailable				=> NULL, --NULL, 'Currently not available','License required' or 'EULA required'
	pURL					=> NULL,
	pClick_disabled			=> NULL, --NULL or 'Y'
	pSEQ_VIP_gen			=> FALSE --TRUE if VIP
);
END $_$;
