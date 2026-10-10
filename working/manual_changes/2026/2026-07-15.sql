-- Add new vocabulary MONDO:
DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewVocabulary(
	pVocabulary_id       => 'Mondo',
    pVocabulary_name        => 'Mondo Ontology',
    pVocabulary_reference   => 'https://mondo.monarchinitiative.org/pages/download/',
    pVocabulary_version     => 'Mondo v2026-06-02',
    pOMOP_req		    => NULL, --NULL or 'Y'
	pClick_default	    => NULL, --NULL or 'Y'
	pAvailable	    => NULL, --NULL, 'Currently not available','License required' or 'EULA required'
	pURL		    => 'http://purl.obolibrary.org/obo/mondo.json',
	pClick_disabled	    => NULL, --NULL or 'Y'
	pSEQ_VIP_gen	    => FALSE --TRUE if VIP
);
END $_$;