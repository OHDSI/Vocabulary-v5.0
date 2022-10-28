--Language concept update
--Add new domain
DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewDomain(
		pDomain_id		=>'Language',
		pDomain_name	=>'Language'
	);
END $_$;

--add new vocabulary
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewVocabulary(
	pVocabulary_id			=> 'Language',
	pVocabulary_name		=> 'Language (OMOP)',
	pVocabulary_reference	=> 'OMOP generated',
	pVocabulary_version		=> NULL,
	pOMOP_req				=> NULL,
	pClick_default			=> NULL, --NULL or 'Y'
	pAvailable				=> NULL, --NULL, 'Currently not available','License required' or 'EULA required'
	pURL					=> NULL,
	pClick_disabled			=> NULL --NULL or 'Y'
);
END $_$;

--add new concept
DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewConcept(
		pConcept_name		=>'Genetic nomenclature',
		pDomain_id			=>'Language',
		pVocabulary_id		=>'Language',
		pConcept_class_id	=>'Qualifier Value',
		pStandard_concept	=>'S',
		pConcept_code		=>'Genetic_nomenclature'
	);
END $_$;


