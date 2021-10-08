DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewConcept(
    pConcept_name     =>'nanokatal per liter',
    pDomain_id        =>'Unit',
    pVocabulary_id    =>'UCUM',
    pConcept_class_id =>'Unit',
    pStandard_concept =>'S',
    pConcept_code     =>'nkat/L',
    pValid_start_date => CURRENT_DATE
);
END $_$;