-- 1. Update latest_update field to new date
ALTER TABLE vocabulary ADD latest_update DATE;
UPDATE vocabulary SET latest_update=(select i.latest_update from vocabulary i WHERE i.vocabulary_id='RxNorm') 
    WHERE vocabulary_id in ('NDFRT','VA Product', 'VA Class', 'ATC'); 
COMMIT;

-- 2. Truncate all working tables and remove indices
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
ALTER SESSION SET SKIP_UNUSABLE_INDEXES = TRUE; --disables error reporting of indexes and index partitions marked UNUSABLE
ALTER INDEX idx_cs_concept_code UNUSABLE;
ALTER INDEX idx_cs_concept_id UNUSABLE;
ALTER INDEX idx_concept_code_1 UNUSABLE;
ALTER INDEX idx_concept_code_2 UNUSABLE;

--3 Create interim table with rxcui in order to get relationships
CREATE TABLE drug_vocs
NOLOGGING

AS
   SELECT rxcui,
          code,
          concept_name,
          CASE
             WHEN concept_class_id LIKE 'VA%' THEN concept_class_id
             ELSE 'NDFRT'
          END
             AS vocabulary_id,
          CASE concept_class_id
             WHEN 'VA Product' THEN NULL
             WHEN 'Dose Form' THEN NULL
             WHEN 'Pharma Preparation' THEN NULL
             ELSE 'C'
          END
             AS standard_concept,
          concept_code,
          concept_class_id
     FROM (SELECT rxcui,
                  code,
                  CASE
                     WHEN INSTR (str, '[') > 1
                     THEN
                        SUBSTR (str, 1, INSTR (str, '[') - 1)
                     WHEN INSTR (str, '[') = 1
                     THEN
                        SUBSTR (str, INSTR (str, ']') + 2, 256)
                     ELSE
                        SUBSTR (str, 1, 255)
                  END
                     AS concept_name,
                  CASE
                     WHEN INSTR (str, '[') = 1
                     THEN
                        SUBSTR (str, 2, INSTR (str, ']') - 2)
                     ELSE
                        code
                  END
                     AS concept_code,
                  CASE
                     WHEN INSTR (str, '[') > 1
                     THEN
                        CASE REGEXP_REPLACE (str,
                                             '([^\[]+)\[([^]]+)\]',
                                             '\2')
                           WHEN 'PK'
                           THEN
                              'Pharmacokinetics'
                           WHEN 'Dose Form'
                           THEN
                              'Dose Form'
                           WHEN 'TC'
                           THEN
                              'Therapeutic Class'
                           WHEN 'MoA'
                           THEN
                              'Mechanism of Action'
                           WHEN 'PE'
                           THEN
                              'Physiolog Effect'
                           WHEN 'VA Product'
                           THEN
                              'VA Product'
                           WHEN 'EPC'
                           THEN
                              'Pharmacologic Class'
                           WHEN 'Chemical/Ingredient'
                           THEN
                              'Chemical Structure'
                           WHEN 'Disease/Finding'
                           THEN
                              'Indication'
                        END
                     WHEN INSTR (str, '[') = 1
                     THEN
                        'VA Class'
                     ELSE
                        'Pharma Preparation'
                  END
                     AS concept_class_id
             FROM rxnconso
            WHERE     sab = 'NDFRT'
                  AND tty IN ('FN', 'HT', 'MTH_RXN_RHT')
                  AND suppress != 'Y'
                  AND code != 'NOCODE')
    WHERE concept_class_id IS NOT NULL;   -- kick out "preparations", which really are the useless 1st initial of pharma preparations

-- Add ATC
INSERT /*+ APPEND */
      INTO  drug_vocs
   SELECT rxcui,
          code,
          concept_name,
          'ATC' AS vocabulary_id,
          CASE concept_class_id WHEN 'ATC 5th' THEN NULL -- need later to promote those to 'S' that are missing from RxNorm
                                                        ELSE 'C' END
             AS standard_concept,
          concept_code,
          concept_class_id
     FROM (SELECT DISTINCT
                  rxcui,
                  code,
                  SUBSTR (str, 1, 255) AS concept_name,
                  code AS concept_code,
                  CASE
                     WHEN LENGTH (code) = 1 THEN 'ATC 1st'
                     WHEN LENGTH (code) = 3 THEN 'ATC 2nd'
                     WHEN LENGTH (code) = 4 THEN 'ATC 3rd'
                     WHEN LENGTH (code) = 5 THEN 'ATC 4th'
                     WHEN LENGTH (code) = 7 THEN 'ATC 5th'
                  END
                     AS concept_class_id
             FROM rxnconso
            WHERE sab = 'ATC' AND suppress != 'Y' AND tty IN ('PT', 'IN'));
COMMIT;			

--4 Add synonyms to concept_synonym stage for each of the rxcui/code combinations in drug_vocs
INSERT INTO concept_synonym_stage (synonym_concept_id,
                                   synonym_concept_code,
                                   synonym_name,
                                   synonym_vocabulary_id,
                                   language_concept_id)
   SELECT DISTINCT NULL AS synonym_concept_id,
                   code AS synonym_concept_code,
                   SUBSTR (dv.concept_name, 1, 1000) AS synonym_name,
                   dv.vocabulary_id AS synonym_vocabulary_id,
                   4093769 AS language_concept_id
     FROM drug_vocs dv;
COMMIT;

--5 Update concept_id in concept_stage from concept for existing concepts
UPDATE concept_stage cs
    SET cs.concept_id=(SELECT c.concept_id FROM concept c WHERE c.concept_code=cs.concept_code AND c.vocabulary_id=cs.vocabulary_id)
    WHERE cs.concept_id IS NULL
;
COMMIT;

--6. Clean up
DROP TABLE drug_vocs PURGE;

--7 Reinstate constraints and indices
ALTER INDEX idx_cs_concept_code REBUILD NOLOGGING;
ALTER INDEX idx_cs_concept_id REBUILD NOLOGGING;
ALTER INDEX idx_concept_code_1 REBUILD NOLOGGING;
ALTER INDEX idx_concept_code_2 REBUILD NOLOGGING;	

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script		