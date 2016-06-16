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

--1. Update latest_update field to new date
BEGIN
   DEVV5.VOCABULARY_PACK.SetLatestUpdate (pVocabularyName        => 'ICD9Proc',
                                          pVocabularyDate        => TO_DATE ('20141001', 'yyyymmdd'),
                                          pVocabularyVersion     => 'ICD9CM v32 master descriptions',
                                          pVocabularyDevSchema   => 'DEV_ICD9PROC');
END;
COMMIT;

--2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;

--3. Load into concept_stage from CMS_DESC_LONG_SG
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
          'Procedure' AS domain_id,
          'ICD9Proc' AS vocabulary_id,
          length(code)||'-dig billing code' AS concept_class_id,
          'S' AS standard_concept,
          REGEXP_REPLACE (code, '^([0-9]{2})([0-9]+)', '\1.\2')
             AS concept_code,
          (SELECT latest_update
             FROM vocabulary
            WHERE vocabulary_id = 'ICD9Proc')
             AS valid_start_date,
          TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
          NULL AS invalid_reason
     FROM CMS_DESC_LONG_SG;
COMMIT;					  

--4 Add the non-billable or HT codes for ICD9Proc
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
          SUBSTR (str, 1, 256) AS concept_name,
          'Procedure' AS domain_id,
          'ICD9Proc' AS vocabulary_id,
          length(replace(code,'.'))||'-dig nonbill code' AS concept_class_id,
          'S' AS standard_concept,
          code AS concept_code,
          (SELECT latest_update
             FROM vocabulary
            WHERE vocabulary_id = 'ICD9Proc')
             AS valid_start_date,
          TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
          NULL AS invalid_reason
     FROM UMLS.mrconso
    WHERE     sab = 'ICD9CM'
          AND tty = 'HT'
          AND (INSTR (code, '.') = 3 OR -- Dot in 3rd position in Procedure codes, in UMLS also called ICD9CM
                                       LENGTH (code) = 2     -- Procedure code
                                                        )
          AND code NOT IN (SELECT concept_code
                             FROM concept_stage
                            WHERE vocabulary_id LIKE 'ICD9%')
          AND suppress = 'N';

COMMIT;

--5 load into concept_synonym_stage name from both CMS_DESC_LONG_DX.txt and CMS_DESC_SHORT_DX
INSERT INTO concept_synonym_stage (synonym_concept_id,
                                   synonym_concept_code,
                                   synonym_name,
                                   synonym_vocabulary_id,
                                   language_concept_id)
   (SELECT NULL AS synonym_concept_id,
           REGEXP_REPLACE (code, '^([0-9]{2})([0-9]+)', '\1.\2')
              AS synonym_concept_code,
           NAME AS synonym_name,
		   'ICD9Proc' as synonym_vocabulary_id,
           4180186 AS language_concept_id                           -- English
      FROM (SELECT * FROM CMS_DESC_LONG_SG
            UNION
            SELECT * FROM CMS_DESC_SHORT_SG));
COMMIT;

--6 Add the non-billable or HT codes for ICD9Proc as a synonym
INSERT INTO concept_synonym_stage (synonym_concept_id,
                                   synonym_concept_code,
                                   synonym_name,
                                   synonym_vocabulary_id,
                                   language_concept_id)
   SELECT NULL AS synonym_concept_id,
          code AS synonym_concept_code,
          SUBSTR (str, 1, 256) AS synonym_name,
          'ICD9Proc' AS vocabulary_id,
          4180186 AS language_concept_id                            -- English
     FROM UMLS.mrconso
    WHERE     sab = 'ICD9CM'
          AND tty = 'HT'
          AND (INSTR (code, '.') = 3 OR -- Dot in 3rd position in Procedure codes, in UMLS also called ICD9CM
                                       LENGTH (code) = 2     -- Procedure code
                                                        )
          AND code NOT IN (SELECT concept_code
                             FROM concept_stage
                            WHERE vocabulary_id LIKE 'ICD9%')
          AND suppress = 'N';

COMMIT;

--7 Load concept_relationship_stage from the existing one. The reason is that there is no good source for these relationships, and we have to build the ones for new codes from UMLS and manually
INSERT INTO concept_relationship_stage (concept_id_1,
                                        concept_id_2,
                                        concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT NULL AS concept_id_1,
          NULL AS concept_id_2,
          c1.concept_code AS concept_code_1,
          c2.concept_code AS concept_code_2,
          c1.vocabulary_id AS vocabulary_id_1,
          c2.vocabulary_id AS vocabulary_id_2,
          r.relationship_id AS relationship_id,
          r.valid_start_date,
          r.valid_end_date,
          r.invalid_reason
     FROM concept_relationship r, concept c1, concept c2
    WHERE     c1.concept_id = r.concept_id_1
          AND (
              c1.vocabulary_id = 'ICD9Proc' OR c2.vocabulary_id = 'ICD9Proc'
          )
          AND C2.CONCEPT_ID = r.concept_id_2  
          AND r.invalid_reason IS NULL -- only fresh ones
          AND r.relationship_id NOT IN ('Domain subsumes', 'Is domain') 
;
COMMIT;		  

--8 Create text for Medical Coder with new codes and mappings
SELECT NULL AS concept_id_1,
       NULL AS concept_id_2,
       c.concept_code AS concept_code_1,
       NULL AS concept_code_2
  FROM concept_stage c
 WHERE NOT EXISTS
          (SELECT 1
             FROM concept co
            WHERE     co.concept_code = c.concept_code
                  AND co.vocabulary_id = 'ICD9Proc') -- only new codes we don't already have
AND c.vocabulary_id = 'ICD9Proc';

--9 Append resulting file from Medical Coder (in concept_relationship_stage format) to concept_relationship_stage
BEGIN
   DEVV5.VOCABULARY_PACK.ProcessManualRelationships;
END;
COMMIT;

--10 Working with replacement mappings
BEGIN
   DEVV5.VOCABULARY_PACK.CheckReplacementMappings;
END;
COMMIT;

--11 Deprecate 'Maps to' mappings to deprecated and upgraded concepts
BEGIN
   DEVV5.VOCABULARY_PACK.DeprecateWrongMAPSTO;
END;
COMMIT;	

--12 Add mapping from deprecated to fresh concepts
BEGIN
   DEVV5.VOCABULARY_PACK.AddFreshMAPSTO;
END;
COMMIT;		 

--13 Delete ambiguous 'Maps to' mappings
BEGIN
   DEVV5.VOCABULARY_PACK.DeleteAmbiguousMAPSTO;
END;
COMMIT;

--14 Add "subsumes" relationship between concepts where the concept_code is like of another
INSERT INTO concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT c1.concept_code AS concept_code_1,
          c2.concept_code AS concept_code_2,
          c1.vocabulary_id AS vocabulary_id_1,
          c1.vocabulary_id AS vocabulary_id_2,
          'Subsumes' AS relationship_id,
          (SELECT latest_update
             FROM vocabulary
            WHERE vocabulary_id = c1.vocabulary_id)
             AS valid_start_date,
          TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
          NULL AS invalid_reason
     FROM concept_stage c1, concept_stage c2
    WHERE     c2.concept_code LIKE c1.concept_code || '%'
          AND c1.concept_code <> c2.concept_code
          AND NOT EXISTS
                 (SELECT 1
                    FROM concept_relationship_stage r_int
                   WHERE     r_int.concept_code_1 = c1.concept_code
                         AND r_int.concept_code_2 = c2.concept_code
                         AND r_int.relationship_id = 'Subsumes');
COMMIT;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script		