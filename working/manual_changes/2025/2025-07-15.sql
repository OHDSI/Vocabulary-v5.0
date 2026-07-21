-- Add new vocabulary SG COHORTS:
DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewVocabulary(
	pVocabulary_id       => 'SG COHORTS',
    pVocabulary_name        => 'SINGAPORE COHORTS',
    pVocabulary_reference   => 'https://www.ntu.edu.sg/helios',
    pVocabulary_version     => '2025',
    pOMOP_req		    => NULL, --NULL or 'Y'
	pClick_default	    => NULL, --NULL or 'Y'
	pAvailable	    => NULL, --NULL, 'Currently not available','License required' or 'EULA required'
	pURL		    => NULL,
	pClick_disabled	    => NULL, --NULL or 'Y'
	pSEQ_VIP_gen	    => FALSE --TRUE if VIP
);
END $_$;