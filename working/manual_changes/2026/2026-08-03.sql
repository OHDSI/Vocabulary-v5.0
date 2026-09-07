-- Add new UCUM unit daPa (Decapascal):
DO $_$
BEGIN
PERFORM vocabulary_pack.AddNewConcept(
pConcept_name =>'decapascal',
pDomain_id =>'Unit',
pVocabulary_id =>'UCUM',
pConcept_class_id =>'Unit',
pStandard_concept =>'S',
pConcept_code =>'daPa'
);
END $_$;

-- Add new UCUM unit mS (Millisiemens):
DO $_$
BEGIN
PERFORM vocabulary_pack.AddNewConcept(
pConcept_name =>'millisiemens',
pDomain_id =>'Unit',
pVocabulary_id =>'UCUM',
pConcept_class_id =>'Unit',
pStandard_concept =>'S',
pConcept_code =>'mS'
);
END $_$;
