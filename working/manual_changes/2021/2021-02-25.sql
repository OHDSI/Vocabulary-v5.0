// Two monoclonal antibodies are currently missing from RxNorm but are required to map ICD10PCS concepts
DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewConcept(
    pConcept_name     =>'etesevimab',
    pDomain_id        =>'Drug',
    pVocabulary_id    =>'RxNorm Extension',
    pConcept_class_id =>'Ingredient',
    pStandard_concept =>'S'
);
END $_$;

DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewConcept(
    pConcept_name     =>'leronlimab',
    pDomain_id        =>'Drug',
    pVocabulary_id    =>'RxNorm Extension',
    pConcept_class_id =>'Ingredient',
    pStandard_concept =>'S'
);
END $_$;
