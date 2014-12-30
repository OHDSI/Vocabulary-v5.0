/*
1. Use UMLS as source (from SNOMED)

-- Update latest_update field to new date 
update vocabulary set latest_update=to_date('YYYYMMDD','yyyymmdd') where vocabulary_id='CPT4'; commit;
*/

--2 Load concepts into concept_stage from MRONSO
-- Main CPT codes. Str picked in certain order to get best concept_name
INSERT INTO concept_stage (concept_id,
                           concept_name,
                           domain_id,
                           vocabulary_id,
                           concept_class_id,
                           standard_concept,
                           concept_code,
                           valid_start_date,
                           valid_end_date,
                           invalid_reason)
   SELECT DISTINCT
          NULL AS concept_id,
          FIRST_VALUE (
             SUBSTR (str, 1, 255))
          OVER (
             PARTITION BY scui
             ORDER BY
                DECODE (tty,
                        'PT', 1,                             -- preferred term
                        'ETCLIN', 2,      -- Entry term, clinician description
                        'ETCF', 3, -- Entry term, consumer friendly description
                        'SY', 4,                                    -- Synonym
                        10))
             AS concept_name,
          NULL AS domain_id,                                -- adding manually
          'CPT4' AS vocabulary_id,
          'CPT4' AS concept_class_id,
          'S' AS standard_concept,
          scui AS concept_code,
          (SELECT latest_update
             FROM vocabulary
            WHERE vocabulary_id = 'CPT4')
             AS valid_start_date,
          TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
          NULL AS invalid_reason
     FROM mrconso
    WHERE     sab IN ('CPT', 'HCPT')
          AND suppress NOT IN ('E', 'O', 'Y')
          AND tty NOT IN ('HT', 'MP');

-- CPT Modifiers
INSERT INTO concept_stage (concept_id,
                           concept_name,
                           domain_id,
                           vocabulary_id,
                           concept_class_id,
                           standard_concept,
                           concept_code,
                           valid_start_date,
                           valid_end_date,
                           invalid_reason)
   SELECT DISTINCT
          NULL AS concept_id,
          FIRST_VALUE (SUBSTR (str, 1, 255))
             OVER (PARTITION BY scui ORDER BY DECODE (sab, 'CPT', 1, 10))
             AS concept_name,
          NULL AS domain_id,
          'CPT4' AS vocabulary_id,
          'CPT4 Modifier' AS concept_class_id,
          'S' AS standard_concept,
          scui AS concept_code,
          (SELECT latest_update
             FROM vocabulary
            WHERE vocabulary_id = 'CPT4')
             AS valid_start_date,
          TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
          NULL AS invalid_reason
     FROM mrconso
    WHERE     sab IN ('CPT', 'HCPT')
          AND suppress NOT IN ('E', 'O', 'Y')
          AND tty = 'MP';

-- Hierarchical CPT terms
INSERT INTO concept_stage (concept_id,
                           concept_name,
                           domain_id,
                           vocabulary_id,
                           concept_class_id,
                           standard_concept,
                           concept_code,
                           valid_start_date,
                           valid_end_date,
                           invalid_reason)
   SELECT DISTINCT NULL AS concept_id,
                   SUBSTR (str, 1, 255) AS concept_name,
                   NULL AS domain_id,
                   'CPT4' AS vocabulary_id,
                   'CPT4 Hierarchy' AS concept_class_id,
                   'C' AS standard_concept, -- not to appear in clinical tables, only for hierarchical search
                   scui AS concept_code,
                   (SELECT latest_update
                      FROM vocabulary
                     WHERE vocabulary_id = 'CPT4')
                      AS valid_start_date,
                   TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
                   NULL AS invalid_reason
     FROM mrconso
    WHERE     sab IN ('CPT', 'HCPT')
          AND suppress NOT IN ('E', 'O', 'Y')
          AND tty = 'HT';
COMMIT;

--3 Update domain_id in concept_stage from concept
UPDATE concept_stage cs
   SET (cs.domain_id) =
          (SELECT domain_id
             FROM concept c
            WHERE     c.concept_code = cs.concept_code
                  AND C.VOCABULARY_ID = CS.VOCABULARY_ID)
 WHERE cs.vocabulary_id = 'CPT4';
 COMMIT;
 
 --4 Pick up all different str values that are not obsolete or suppressed
 INSERT INTO concept_synonym_stage (synonym_concept_id,
                                   synonym_concept_code,
                                   synonym_name,
                                   language_concept_id)
   SELECT DISTINCT NULL AS synonym_concept_id,
                   scui AS synonym_concept_code,
                   SUBSTR (str, 1, 1000) AS synonym_name,
                   4093769 AS language_concept_id
     FROM mrconso
    WHERE sab IN ('CPT', 'HCPT') AND suppress NOT IN ('E', 'O', 'Y');
COMMIT;	

--5  Load concept_relationship_stage from the existing one. The reason is that there is no good source for these relationships, and we have to build the ones for new codes from UMLS and manually
INSERT INTO concept_relationship_stage (concept_id_1,
                                        concept_id_2,
                                        concept_code_1,
                                        concept_code_2,
                                        relationship_id,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT NULL AS concept_id_1,
          NULL AS concept_id_2,
          c.concept_code AS concept_code_1,
          c1.concept_code AS concept_code_2,
          r.relationship_id AS relationship_id,
          c.vocabulary_id AS vocabulary_id_1,
          c1.vocabulary_id AS vocabulary_id_2,
          r.valid_start_date,
          r.valid_end_date,
          r.invalid_reason
     FROM concept_relationship r, concept c, concept c1
    WHERE     c.concept_id = r.concept_id_1
          AND c.vocabulary_id = 'CPT4'
          AND C1.CONCEPT_ID = r.concept_id_2; 
COMMIT;

--6 Create hierarchical relationships between HT and normal CPT codes
/*not done yet*/		  

--7 Extract all CPT4 codes inside the concept_name of other cpt codes. Currently, there are only 5 of them, with up to 4 codes in each
INSERT INTO concept_relationship_stage (concept_id_1,
                                        concept_id_2,
                                        concept_code_1,
                                        concept_code_2,
                                        relationship_id,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT NULL AS concept_id_1,
          NULL AS concept_id_2,
          e.concept_code_1,
          e.concept_code_2,
          'Subsumes' AS relationship_id,
          'CPT4' AS vocabulary_id_1,
          'CPT4' AS vocabulary_id_2,
          TO_DATE ('19700101', 'yyyymmdd') AS valid_start_date,
          TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
          NULL AS invalid_reason
     FROM (SELECT TRANSLATE (REGEXP_SUBSTR (concept_name,
                                            '\(\d\d\d\d[A-Z]\)',
                                            1,
                                            1),
                             '1()',
                             '1')
                     AS concept_code_1,
                  concept_code AS concept_code_2
             FROM concept_stage
            WHERE     vocabulary_id = 'CPT4'
                  AND REGEXP_INSTR (concept_name,
                                    '\(\d\d\d\d[A-Z]\)',
                                    1,
                                    1,
                                    0,
                                    'i') > 0
           UNION
           SELECT TRANSLATE (REGEXP_SUBSTR (concept_name,
                                            '\(\d\d\d\d[A-Z]\)',
                                            1,
                                            2),
                             '1()',
                             '1')
                     AS concept_code_1,
                  concept_code AS concept_code_2
             FROM concept_stage
            WHERE     vocabulary_id = 'CPT4'
                  AND REGEXP_INSTR (concept_name,
                                    '\(\d\d\d\d[A-Z]\)',
                                    1,
                                    1,
                                    0,
                                    'i') > 0
           UNION
           SELECT TRANSLATE (REGEXP_SUBSTR (concept_name,
                                            '\(\d\d\d\d[A-Z]\)',
                                            1,
                                            3),
                             '1()',
                             '1')
                     AS concept_code_1,
                  concept_code AS concept_code_2
             FROM concept_stage
            WHERE     vocabulary_id = 'CPT4'
                  AND REGEXP_INSTR (concept_name,
                                    '\(\d\d\d\d[A-Z]\)',
                                    1,
                                    1,
                                    0,
                                    'i') > 0
           UNION
           SELECT TRANSLATE (REGEXP_SUBSTR (concept_name,
                                            '\(\d\d\d\d[A-Z]\)',
                                            1,
                                            4),
                             '1()',
                             '1')
                     AS concept_code_1,
                  concept_code AS concept_code_2
             FROM concept_stage
            WHERE     vocabulary_id = 'CPT4'
                  AND REGEXP_INSTR (concept_name,
                                    '\(\d\d\d\d[A-Z]\)',
                                    1,
                                    1,
                                    0,
                                    'i') > 0
           UNION
           SELECT TRANSLATE (REGEXP_SUBSTR (concept_name,
                                            '\(\d\d\d\d[A-Z]\)',
                                            1,
                                            5),
                             '1()',
                             '1')
                     AS concept_code_1,
                  concept_code AS concept_code_2
             FROM concept_stage
            WHERE     vocabulary_id = 'CPT4'
                  AND REGEXP_INSTR (concept_name,
                                    '\(\d\d\d\d[A-Z]\)',
                                    1,
                                    1,
                                    0,
                                    'i') > 0) e
    WHERE e.concept_code_2 IS NOT NULL AND e.concept_code_1 IS NOT NULL;
COMMIT;	


--8 create new codes and mappings according to UMLS	   
--9------ run Vocabulary-v5.0\generic_update.sql ---------------			