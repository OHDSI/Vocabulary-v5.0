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
	pVocabulary_version		=>  'Language 20221028',
	pOMOP_req				=> 'Y',
	pClick_default			=> 'Y', --NULL or 'Y'
	pAvailable				=> NULL, --NULL, 'Currently not available','License required' or 'EULA required'
	pURL					=> NULL,
	pClick_disabled			=> 'Y' --NULL or 'Y'
);
END $_$;

--add new concept_classes
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewConceptClass(
	pConcept_class_id	=>'Language',
	pConcept_class_name	=>'Language'
);
END $_$;

--add new concept
DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewConcept(
		pConcept_name		=>'Genetic nomenclature',
		pDomain_id			=>'Language',
		pVocabulary_id		=>'Language',
		pConcept_class_id	=>'Language',
		pStandard_concept	=>'S',
		pConcept_code		=> 'OMOP5181831'
	);
END $_$;
