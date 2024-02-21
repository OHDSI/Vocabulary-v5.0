--add new concept_class
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewConceptClass(
	pConcept_class_id	=>'Vaccine Group',
	pConcept_class_name	=>'Vaccine Group'
);
END $_$;