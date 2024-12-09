-- Add new UCUM unit RU/ml:
DO $_$
BEGIN
PERFORM vocabulary_pack.AddNewConcept(
pConcept_name =>'relative units per milliliter',
pDomain_id =>'Unit',
pVocabulary_id =>'UCUM',
pConcept_class_id =>'Unit',
pStandard_concept =>'S',
pConcept_code =>'{RU}/mL'
);
END $_$;