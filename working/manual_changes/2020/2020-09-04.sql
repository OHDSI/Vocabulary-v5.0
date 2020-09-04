--add new unit [https://forums.ohdsi.org/t/units-of-measure-to-add/11260/19]
DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewConcept(
    pConcept_name     =>'Generic unit for indivisible thing',
    pDomain_id        =>'Unit',
    pVocabulary_id    =>'UCUM',
    pConcept_class_id =>'Unit',
    pStandard_concept =>'S',
    pConcept_code     =>'1'
);
END $_$;