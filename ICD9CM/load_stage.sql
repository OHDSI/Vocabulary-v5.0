-- 1. Update latest_update field to new date 
ALTER TABLE vocabulary ADD latest_update DATE;
UPDATE vocabulary SET latest_update=to_date('20141001','yyyymmdd') WHERE vocabulary_id='ICD9CM'; 
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

--3. Load into concept_stage from CMS_DESC_LONG_DX
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
   SELECT NULL AS concept_id,
          NAME AS concept_name,
          NULL AS domain_id,
          'ICD9CM' AS vocabulary_id,
          CASE
             WHEN SUBSTR (code, 1, 1) = 'V' THEN 'ICD9CM V code'
             WHEN SUBSTR (code, 1, 1) = 'E' THEN 'ICD9CM E code'
             ELSE 'ICD9CM code'
          END
             AS concept_class_id,
          NULL AS standard_concept,
          CASE                                        -- add dots to the codes
             WHEN SUBSTR (code, 1, 1) = 'V'
             THEN
                REGEXP_REPLACE (code, 'V([0-9]{2})([0-9]+)', 'V\1.\2') -- Dot after 2 digits for V codes
             WHEN SUBSTR (code, 1, 1) = 'E'
             THEN
                REGEXP_REPLACE (code, 'E([0-9]{3})([0-9]+)', 'E\1.\2') -- Dot after 3 digits for E codes
             ELSE
                REGEXP_REPLACE (code, '^([0-9]{3})([0-9]+)', '\1.\2') -- Dot after 3 digits for normal codes
          END
             AS concept_code,
          (select latest_update from vocabulary where vocabulary_id='ICD9CM') AS valid_start_date,
          TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
          NULL AS invalid_reason
     FROM CMS_DESC_LONG_DX;
COMMIT;					  

--4 load into concept_synonym_stage name from both CMS_DESC_LONG_DX.txt and CMS_DESC_SHORT_DX
INSERT INTO concept_synonym_stage (synonym_concept_id,
                                   synonym_concept_code,
                                   synonym_name,
                                   synonym_vocabulary_id,
                                   language_concept_id)
   (SELECT NULL AS synonym_concept_id,
           CASE                                       -- add dots to the codes
              WHEN SUBSTR (code, 1, 1) = 'V'
              THEN
                 REGEXP_REPLACE (code, 'V([0-9]{2})([0-9]+)', 'V\1.\2') -- Dot after 2 digits for V codes
              WHEN SUBSTR (code, 1, 1) = 'E'
              THEN
                 REGEXP_REPLACE (code, 'E([0-9]{3})([0-9]+)', 'E\1.\2') -- Dot after 3 digits for E codes
              ELSE
                 REGEXP_REPLACE (code, '^([0-9]{3})([0-9]+)', '\1.\2') -- Dot after 3 digits for normal codes
           END
              AS synonym_concept_code,
           NAME AS synonym_name,
		   'ICD9CM' as synonym_vocabulary_id,
           4093769 AS language_concept_id                           -- English
      FROM (SELECT * FROM CMS_DESC_LONG_DX
            UNION
            SELECT * FROM CMS_DESC_SHORT_DX));
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
          AND c.vocabulary_id = 'ICD9CM'
          AND C1.CONCEPT_ID = r.concept_id_2;  
COMMIT;		  

--6 create new codes and mappings according to UMLS	   
--7 Reinstate constraints and indices
ALTER INDEX idx_cs_concept_code REBUILD NOLOGGING;
ALTER INDEX idx_cs_concept_id REBUILD NOLOGGING;
ALTER INDEX idx_concept_code_1 REBUILD NOLOGGING;
ALTER INDEX idx_concept_code_2 REBUILD NOLOGGING;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script		