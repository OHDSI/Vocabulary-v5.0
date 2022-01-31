--add new Unit [AVOF-3333]
DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewConcept(
    pConcept_name     =>'milliliter per kilogram per 24 hours',
    pDomain_id        =>'Unit',
    pVocabulary_id    =>'UCUM',
    pConcept_class_id =>'Unit',
    pStandard_concept =>'S',
    pConcept_code     =>'mL/kg/(24.h)'
);
END $_$;