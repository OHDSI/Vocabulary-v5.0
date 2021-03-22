--Add milligravity unit
DO $_$
BEGIN
PERFORM vocabulary_pack.AddNewConcept(
pConcept_name =>'milligravity unit',
pDomain_id =>'Unit',
pVocabulary_id =>'UCUM',
pConcept_class_id =>'Unit',
pStandard_concept =>'S',
pConcept_code =>'mgu'
);
END $_$;
