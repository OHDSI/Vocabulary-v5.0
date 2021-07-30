--Adding required concept_class for MIN (RxNorm) [AVOF-3122]
DO
$_$
BEGIN
  PERFORM vocabulary_pack.AddNewConceptClass(
    pConcept_class_id       =>'Multiple Ingredients',
    pConcept_class_name     =>'Multiple Ingredients'
);
END $_$;