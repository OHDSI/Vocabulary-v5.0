--add new vocabulary
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewVocabulary(
	pVocabulary_id			=> 'Cancer Modifier',
	pVocabulary_name		=> 'Diagnostic Modifiers of Cancer (OMOP)',
	pVocabulary_reference	=> 'OMOP generated',
	pVocabulary_version		=> NULL,
	pOMOP_req				=> NULL,
	pClick_default			=> NULL, --NULL or 'Y'
	pAvailable				=> NULL, --NULL, 'Currently not available','License required' or 'EULA required'
	pURL					=> NULL,
	pClick_disabled			=> NULL --NULL or 'Y'
);
END $_$;

--add new concept_classes
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewConceptClass(
	pConcept_class_id	=>'Topography',
	pConcept_class_name	=>'Topography'
);
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewConceptClass(
	pConcept_class_id	=>'Margin',
	pConcept_class_name	=>'Margin'
);
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewConceptClass(
	pConcept_class_id	=>'Nodes',
	pConcept_class_name	=>'Nodes'
);
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewConceptClass(
	pConcept_class_id	=>'Staging/Grading',
	pConcept_class_name	=>'Staging/Grading'
);
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewConceptClass(
	pConcept_class_id	=>'Extension/Invasion',
	pConcept_class_name	=>'Extension/Invasion'
);
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewConceptClass(
	pConcept_class_id	=>'Dimension',
	pConcept_class_name	=>'Dimension'
);
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewConceptClass(
	pConcept_class_id	=>'Histopattern',
	pConcept_class_name	=>'Histopattern'
);
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewConceptClass(
	pConcept_class_id	=>'Metastasis',
	pConcept_class_name	=>'Metastasis'
);
END $_$;