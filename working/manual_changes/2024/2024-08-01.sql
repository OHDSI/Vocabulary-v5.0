--Add new vocabulary
DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewVocabulary(
	pVocabulary_id       => 'CDISC',
    pVocabulary_name        => 'Clinical Data Interchange Standards Consortium',
    pVocabulary_reference   => 'https://ncim.nci.nih.gov/ncimbrowser/',
    pVocabulary_version     => '2023_12D',
    pOMOP_req		    => NULL, --NULL or 'Y'
	pClick_default	    => NULL, --NULL or 'Y'
	pAvailable	    => NULL, --NULL, 'Currently not available','License required' or 'EULA required'
	pURL		    => 'https://evs.nci.nih.gov/evs-download/metathesaurus-downloads',
	pClick_disabled	    => NULL, --NULL or 'Y'
	pSEQ_VIP_gen	    => FALSE --TRUE if VIP
);
END $_$;
