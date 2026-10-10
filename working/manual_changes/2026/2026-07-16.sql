-- ORPHAcode added
DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewVocabulary(
	pVocabulary_id       => 'ORPHAcode',
    pVocabulary_name        => 'ORPHAcode',
    pVocabulary_reference   => 'https://www.orphacode.org/pack-nomenclature/',
    pVocabulary_version     => '2026',
    pOMOP_req		    => NULL, --NULL or 'Y'
	pClick_default	    => NULL, --NULL or 'Y'
	pAvailable	    => NULL, --NULL, 'Currently not available', 'License required' or 'EULA required'
	pURL		    => NULL,
	pClick_disabled	    => NULL, --NULL or 'Y'
	pSEQ_VIP_gen	    => FALSE --TRUE if VIP
);
END $_$;