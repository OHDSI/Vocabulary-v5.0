-- Add new concept class 'Disorder':
DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewConceptClass(
    pConcept_class_id       =>'Disorder',
    pConcept_class_name     =>'Disorder'
);
END $_$;