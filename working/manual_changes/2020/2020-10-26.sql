--add new vocabulary_id='CCAM' and new concept_class [AVOF-2780]
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewVocabulary(
	pVocabulary_id			=> 'CCAM',
	pVocabulary_name		=> 'Common Classification of Medical Acts',
	pVocabulary_reference	=> 'https://www.ameli.fr/accueil-de-la-ccam/telechargement/index.php',
	pVocabulary_version		=> NULL,
	pOMOP_req				=> NULL,
	pClick_default			=> NULL, --NULL or 'Y'
	pAvailable				=> NULL, --NULL, 'Currently not available','License required' or 'EULA required'
	pURL					=> NULL,
	pClick_disabled			=> NULL --NULL or 'Y'
);
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewConceptClass(
	pConcept_class_id	=>'Proc Group',
	pConcept_class_name	=>'Procedure Group'
);
END $_$;