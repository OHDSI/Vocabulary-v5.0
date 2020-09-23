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
	pConcept_class_name	=>'Cancer topography and anatomical site'
);
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewConceptClass(
	pConcept_class_id	=>'Margin',
	pConcept_class_name	=>'Tumor resection margins and involvement by cancer cells'
);
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewConceptClass(
	pConcept_class_id	=>'Nodes',
	pConcept_class_name	=>'Lymph node metastases'
);
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewConceptClass(
	pConcept_class_id	=>'Staging/Grading',
	pConcept_class_name	=>'Official Grade or Stage System'
);
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewConceptClass(
	pConcept_class_id	=>'Extension/Invasion',
	pConcept_class_name	=>'Local cancer growth and invasion into adjacent tissue and organs'
);
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewConceptClass(
	pConcept_class_id	=>'Dimension',
	pConcept_class_name	=>'Tumor size and dimension'
);
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewConceptClass(
	pConcept_class_id	=>'Histopattern',
	pConcept_class_name	=>'Histological patterns of cancer tissue'
);
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewConceptClass(
	pConcept_class_id	=>'Metastasis',
	pConcept_class_name	=>'Distant metastases'
);
END $_$;