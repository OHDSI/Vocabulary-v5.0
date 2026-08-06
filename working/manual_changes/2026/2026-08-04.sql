-- Add Pregnancy to the Episode vocabulary:
DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewConcept(
    pConcept_name     =>'Pregnancy',
    pDomain_id        =>'Episode',
    pVocabulary_id    =>'Episode',
    pConcept_class_id =>'Episode of Care',
    pStandard_concept =>'S'
);
END $_$;

-- Erase duplicative ICDO3 concept with non-trimmed concept_code:
UPDATE concept
SET concept_code = gen_random_uuid(),
    concept_name = 'Invalid ICDO3 concept, do not use'
WHERE concept_id = 36402927;

-- Fix UCUM unit spelling:


