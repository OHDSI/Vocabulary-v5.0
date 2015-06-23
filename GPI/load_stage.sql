-- 1. Update latest_update field to new date 
BEGIN
   EXECUTE IMMEDIATE 'ALTER TABLE vocabulary DROP COLUMN latest_update';
EXCEPTION WHEN OTHERS THEN NULL;
END;
ALTER TABLE vocabulary ADD latest_update DATE;
UPDATE vocabulary SET latest_update=to_date('20150506','yyyymmdd'), vocabulary_version='RXNORM CROSS REFERENCE 15.2.1.002' WHERE vocabulary_id='GPI'; 
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

--3. Load into concept_stage from rxxxref
INSERT /*+ APPEND */
      INTO  concept_stage (concept_name,
                           domain_id,
                           vocabulary_id,
                           concept_class_id,
                           standard_concept,
                           concept_code,
                           valid_start_date,
                           valid_end_date,
                           invalid_reason)
   SELECT DISTINCT COALESCE (concept_name, --take name from concept table OR RxNorm
                             drug_string,
                             rx_name,
                             ' ')
                      AS concept_name,
                   domain_id,
                   vocabulary_id,
                   concept_class_id,
                   standard_concept,
                   concept_code,
                   valid_start_date,
                   valid_end_date,
                   invalid_reason
     FROM (SELECT DISTINCT
                  LAST_VALUE (
                     c.concept_name)
                  OVER (
                     PARTITION BY r.concept_value
                     ORDER BY LENGTH (c.concept_name), c.concept_name
                     ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
                     AS concept_name,
                  'Drug' AS domain_id,
                  'GPI' AS vocabulary_id,
                  'GPI' AS concept_class_id,
                  NULL AS standard_concept,
                  r.concept_value AS concept_code,
                  v.latest_update AS valid_start_date,
                  TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
                  NULL AS invalid_reason,
                  LAST_VALUE (
                     gn.drug_string)
                  OVER (
                     PARTITION BY r.concept_value
                     ORDER BY LENGTH (gn.drug_string), gn.drug_string
                     ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
                     AS drug_string,
                  LAST_VALUE (
                     rx.concept_name)
                  OVER (
                     PARTITION BY r.concept_value
                     ORDER BY LENGTH (rx.concept_name), rx.concept_name
                     ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
                     AS rx_name
             FROM rxxxref r
                  JOIN vocabulary v ON v.vocabulary_id = 'GPI'
                  LEFT JOIN concept c
                     ON     r.concept_value = c.concept_code
                        AND c.vocabulary_id = 'GPI'
                        AND c.invalid_reason IS NULL
                  LEFT JOIN gpi_name gn ON gn.gpi_code = r.concept_value
                  LEFT JOIN concept rx
                     ON     r.rxnorm_code = rx.concept_code
                        AND rx.vocabulary_id = 'RxNorm'
						AND rx.invalid_reason IS NULL
            WHERE r.concept_type_id = 5                            -- GPI only
);
COMMIT;					  

--4 Load into concept_relationship_stage name from rxxxref
INSERT INTO concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        relationship_id,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT DISTINCT r.concept_value AS concept_code_1,
                   r.rxnorm_code AS concept_code_2,
                   'Maps to' AS relationship_id,
                   'GPI' AS vocabulary_id_1,
                   'RxNorm' AS vocabulary_id_2,
                   v.latest_update AS valid_start_date,
                   TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
                   NULL AS invalid_reason
     FROM rxxxref r, vocabulary v
    WHERE     r.concept_type_id = 5                                -- GPI only
          AND r.match_type IN ('01', '02')
          AND r.rxnorm_code IS NOT NULL
          AND v.vocabulary_id = 'GPI';
COMMIT;

--5. Add synonyms
INSERT INTO concept_synonym_stage (synonym_concept_id,
                                   synonym_concept_code,
                                   synonym_name,
                                   synonym_vocabulary_id,
                                   language_concept_id)
   SELECT DISTINCT NULL,
                   concept_code,
                   concept_name,
                   'GPI',
                   4093769                                          -- English
     FROM (SELECT cs.concept_code, cs.concept_name
             FROM concept_stage cs
           UNION ALL
           SELECT cs.concept_code, gn.drug_string
             FROM gpi_name gn, concept_stage cs
            WHERE gn.gpi_code = cs.concept_code)
    WHERE TRIM (concept_name) IS NOT NULL;
COMMIT;

--6. Update concept_id in concept_stage from concept for existing concepts
UPDATE concept_stage cs
    SET cs.concept_id=(SELECT c.concept_id FROM concept c WHERE c.concept_code=cs.concept_code AND c.vocabulary_id=cs.vocabulary_id)
    WHERE cs.concept_id IS NULL;


--7. Reinstate constraints and indices
ALTER INDEX idx_cs_concept_code REBUILD NOLOGGING;
ALTER INDEX idx_cs_concept_id REBUILD NOLOGGING;
ALTER INDEX idx_concept_code_1 REBUILD NOLOGGING;
ALTER INDEX idx_concept_code_2 REBUILD NOLOGGING;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script		