/*
Adds new concept

Usage:
DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewConcept(
    pConcept_name     =>'test concept name',
    pDomain_id        =>'Drug',
    pVocabulary_id    =>'SNOMED',
    pConcept_class_id =>'Ingredient',
    pStandard_concept =>'S',
    pConcept_code     =>'123_test2'
);
END $_$;

OR (if you want to get the concept_id):

SELECT vocabulary_pack.AddNewConcept(
    pConcept_name     =>'test concept name',
    pDomain_id        =>'Drug',
    pVocabulary_id    =>'SNOMED',
    pConcept_class_id =>'Ingredient',
    pStandard_concept =>'S',
    pConcept_code     =>'123_test3'
);

You can omit pConcept_code, then it will be generated automatically (OMOPXXXX)
*/

CREATE OR REPLACE FUNCTION vocabulary_pack.AddNewConcept (
  pConcept_name concept.concept_name%TYPE,
  pDomain_id concept.domain_id%TYPE,
  pVocabulary_id concept.vocabulary_id%TYPE,
  pConcept_class_id concept.concept_class_id%TYPE,
  pStandard_concept concept.standard_concept%TYPE,
  pConcept_code concept.concept_code%TYPE = NULL,
  pValid_start_date concept.valid_start_date%TYPE = TO_DATE ('19700101', 'YYYYMMDD'),
  pValid_end_date concept.valid_end_date%TYPE = TO_DATE ('20991231', 'YYYYMMDD'),
  pInvalid_reason concept.invalid_reason%TYPE = NULL
)
RETURNS int4 AS
$BODY$
DECLARE
  z  INT;
  ex INT;
BEGIN
  IF COALESCE(pStandard_concept,'S') NOT IN ('S','C') THEN RAISE EXCEPTION 'Incorrect value for pStandard_concept: %', pStandard_concept; END IF;
  IF pStandard_concept='S' AND pInvalid_reason IS NOT NULL THEN RAISE EXCEPTION 'pStandard_concept cannot be S (pInvalid_reason is not null)'; END IF;
  
  pConcept_name:=REGEXP_REPLACE(pConcept_name, '[[:cntrl:]]+', ' ', 'g');
  pConcept_name:=REGEXP_REPLACE(pConcept_name, ' {2,}', ' ', 'g');
  pConcept_name:=TRIM(pConcept_name);
  pConcept_name:=REPLACE(pConcept_name, '–', '-');
  
  pConcept_code:=REGEXP_REPLACE(pConcept_code, '[[:cntrl:]]+', ' ', 'g');
  pConcept_code:=REGEXP_REPLACE(pConcept_code, ' {2,}', ' ', 'g');
  pConcept_code:=TRIM(pConcept_code);
  pConcept_code:=REPLACE(pConcept_code, '–', '-');
  pConcept_code:=COALESCE(pConcept_code,(SELECT 'OMOP'||MAX(REPLACE(concept_code, 'OMOP','')::INT4)+1 FROM concept WHERE concept_code LIKE 'OMOP%' AND concept_code NOT LIKE '% %'));

  DROP SEQUENCE IF EXISTS v5_concept;

  SELECT MAX (concept_id) + 1 INTO ex FROM concept
  WHERE concept_id >= 31967 AND concept_id < 72245;

  EXECUTE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' CACHE 20';

  --insert the concept
  SELECT nextval('v5_concept') INTO z;
  INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
    VALUES (z, pConcept_name, pDomain_id, pVocabulary_id, pConcept_class_id, pStandard_concept, pConcept_code, pValid_start_date, pValid_end_date, pInvalid_reason);

  --insert the mapping
  IF pStandard_concept='S' THEN
    INSERT INTO concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
      VALUES (z, z, 'Maps to', pValid_start_date, TO_DATE('20991231', 'YYYYMMDD'), NULL),
             (z, z, 'Mapped from', pValid_start_date, TO_DATE('20991231', 'YYYYMMDD'), NULL);
  END IF;

  /*--insert the synonym (=pConcept_name)
  INSERT INTO concept_synonym (concept_id, concept_synonym_name, language_concept_id)
    VALUES (z, pConcept_name, 4180186 /*English*/);*/ --deprecated [AVOF-2971]

  DROP SEQUENCE v5_concept;
  
  RETURN z;
END;
$BODY$
LANGUAGE 'plpgsql'
VOLATILE
CALLED ON NULL INPUT
SECURITY INVOKER
COST 100
SET client_min_messages = error;