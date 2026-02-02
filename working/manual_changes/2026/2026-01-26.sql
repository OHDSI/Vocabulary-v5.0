--Add new vocabulary HPO
DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewVocabulary(
	pVocabulary_id       => 'HPO',
    pVocabulary_name        => 'Human Phenotype Ontology',
    pVocabulary_reference   => 'https://hpo.jax.org',
    pVocabulary_version     => 'HPO v2025-11-24',
    pOMOP_req		    => NULL, --NULL or 'Y'
	pClick_default	    => NULL, --NULL or 'Y'
	pAvailable	    => NULL, --NULL, 'Currently not available','License required' or 'EULA required'
	pURL		    => 'http://purl.obolibrary.org/obo/hp.json',
	pClick_disabled	    => NULL, --NULL or 'Y'
	pSEQ_VIP_gen	    => FALSE --TRUE if VIP
);
END $_$;