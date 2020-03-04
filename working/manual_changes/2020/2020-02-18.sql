--add new UCUM concepts
DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewConcept(
    pConcept_name     =>'centimeter per second',
    pDomain_id        =>'Unit',
    pVocabulary_id    =>'UCUM',
    pConcept_class_id =>'Unit',
    pStandard_concept =>'S',
    pConcept_code     =>'cm/s'
);
END $_$;

DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewConcept(
    pConcept_name     =>'milliliter per square meter',
    pDomain_id        =>'Unit',
    pVocabulary_id    =>'UCUM',
    pConcept_class_id =>'Unit',
    pStandard_concept =>'S',
    pConcept_code     =>'ml/m2'
);
END $_$;