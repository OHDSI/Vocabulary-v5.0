DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewConcept(
    pConcept_name     =>'Viral-particle',
    pDomain_id        =>'Unit',
    pVocabulary_id    =>'UCUM',
    pConcept_class_id =>'Unit',
    pStandard_concept =>'S',
    pConcept_code     =>'{viral-particle}'
);
END $_$;


DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewConcept(
    pConcept_name     =>'Equivalent islet number',
    pDomain_id        =>'Unit',
    pVocabulary_id    =>'UCUM',
    pConcept_class_id =>'Unit',
    pStandard_concept =>'S',
    pConcept_code     =>'{ein}'
);
END $_$;