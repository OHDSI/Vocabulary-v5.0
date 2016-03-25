/**************************************************************************
* Copyright 2016 Observational Health Data Sciences and Informatics (OHDSI)
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
* 
* Authors: Timur Vakhitov, Christian Reich
* Date: 2016
**************************************************************************/

-- 1. Update latest_update field to new date 
BEGIN
   EXECUTE IMMEDIATE 'ALTER TABLE vocabulary DROP COLUMN latest_update';
EXCEPTION WHEN OTHERS THEN NULL;
END;
ALTER TABLE vocabulary ADD latest_update DATE;
UPDATE vocabulary SET latest_update=to_date('20160325','yyyymmdd'), vocabulary_version='ICD10CM FY2016 code descriptions' WHERE vocabulary_id='ICD10CM'; 
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

--3. Load into concept_stage from ICD10CM_TABLE
INSERT /*+ APPEND */ INTO concept_stage (concept_id,
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
          SUBSTR (
             CASE
                WHEN LENGTH (LONG_NAME) > 255 AND SHORT_NAME IS NOT NULL
                THEN
                   SHORT_NAME
                ELSE
                   LONG_NAME
             END,
             1,
             255)
             AS concept_name,
          NULL AS domain_id,
          'ICD10CM' AS vocabulary_id,
          CASE
             WHEN CODE_TYPE = 1 THEN LENGTH (code) || '-char billing code'
             ELSE LENGTH (code) || '-char nonbill code'
          END
             AS concept_class_id,
          NULL AS standard_concept,
          REGEXP_REPLACE (code, '([[:print:]]{3})([[:print:]]+)', '\1.\2') -- Dot after 3 characters
             AS concept_code,
          (SELECT latest_update
             FROM vocabulary
            WHERE vocabulary_id = 'ICD10CM')
             AS valid_start_date,
          TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
          NULL AS invalid_reason
     FROM ICD10CM_TABLE;
COMMIT;					  

--4 Add ICD10CM to SNOMED mappings
INSERT INTO concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        relationship_id,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT SOURCE_CODE AS concept_code_1,
          TARGET_CODE AS concept_code_2,
          MAPPING_TYPE AS relationship_id,
          'ICD10CM' AS vocabulary_id_1,
          'SNOMED' AS vocabulary_id_2,
          TO_DATE ('19700101', 'yyyymmdd') AS valid_start_date,
          TO_DATE ('31.12.2099', 'dd.mm.yyyy') AS valid_end_date,
          NULL AS invalid_reason
     FROM icd10cm2snomed;
COMMIT;

--5 Load into concept_synonym_stage name from ICD10CM_TABLE
INSERT /*+ APPEND */ INTO concept_synonym_stage (synonym_concept_id,
                                   synonym_concept_code,
                                   synonym_name,
                                   synonym_vocabulary_id,
                                   language_concept_id)
   SELECT DISTINCT NULL AS synonym_concept_id,
                   code AS synonym_concept_code,
                   DESCRIPTION AS synonym_name,
                   'ICD10CM' AS synonym_vocabulary_id,
                   4093769 AS language_concept_id                   -- English
     FROM (SELECT LONG_NAME,
                  SHORT_NAME,
                  REGEXP_REPLACE (code,
                                  '([[:print:]]{3})([[:print:]]+)',
                                  '\1.\2')
                     AS code
             FROM ICD10CM_TABLE) UNPIVOT (DESCRIPTION --take both LONG_NAME and SHORT_NAME
                                 FOR DESCRIPTIONS
                                 IN (LONG_NAME, SHORT_NAME));
COMMIT;


------------------------------------------

--?? Update concept_id in concept_stage from concept for existing concepts
UPDATE concept_stage cs
    SET cs.concept_id=(SELECT c.concept_id FROM concept c WHERE c.concept_code=cs.concept_code AND c.vocabulary_id=cs.vocabulary_id)
    WHERE cs.concept_id IS NULL;


--?? Reinstate constraints and indices
ALTER INDEX idx_cs_concept_code REBUILD NOLOGGING;
ALTER INDEX idx_cs_concept_id REBUILD NOLOGGING;
ALTER INDEX idx_concept_code_1 REBUILD NOLOGGING;
ALTER INDEX idx_concept_code_2 REBUILD NOLOGGING;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script		