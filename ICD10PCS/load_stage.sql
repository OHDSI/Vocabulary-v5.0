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

--1 Update latest_update field to new date
BEGIN
   DEVV5.VOCABULARY_PACK.SetLatestUpdate (pVocabularyName        => 'ICD10PCS',
                                          pVocabularyDate        => TO_DATE ('20160518', 'yyyymmdd'),
                                          pVocabularyVersion     => 'ICD10PCS 20160518',
                                          pVocabularyDevSchema   => 'DEV_ICD10PCS');
END;
COMMIT;

--2 Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3 Insert into concept_stage
INSERT INTO concept_stage (concept_name,
                           vocabulary_id,
                           domain_id,
                           concept_class_id,
                           standard_concept,
                           concept_code,
                           valid_start_date,
                           valid_end_date,
                           invalid_reason)
   SELECT concept_name,
          'ICD10PCS' AS vocabulary_id,
          'Procedure' AS domain_id,
          'ICD10PCS' AS concept_class_id,
          'S' AS standard_concept,
          concept_code,
          (SELECT latest_update
             FROM vocabulary
            WHERE vocabulary_id = 'ICD10PCS')
             AS valid_start_date,
          TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
          NULL AS invalid_reason
     FROM ICD10PCS;
COMMIT;

--4 Add 'ICD10PCS Hierarchy' from umls.mrconso
INSERT INTO concept_stage (concept_name,
                           vocabulary_id,
                           domain_id,
                           concept_class_id,
                           standard_concept,
                           concept_code,
                           valid_start_date,
                           valid_end_date,
                           invalid_reason)
   SELECT DISTINCT
          -- take the best str
          FIRST_VALUE (
             SUBSTR (str, 1, 255))
          OVER (
             PARTITION BY code
             ORDER BY
                CASE tty WHEN 'HT' THEN 1 WHEN 'MTH_HX' THEN 2 WHEN 'HX' THEN 3 WHEN 'HS' THEN 4 WHEN 'PT' THEN 5 WHEN 'PX' THEN 6 WHEN 'AB' THEN 7 WHEN 'XM' THEN 8 END,
                CASE WHEN LENGTH (str) <= 255 THEN LENGTH (str) ELSE 0 END DESC,
                str
             ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
             AS concept_name,
          'ICD10PCS' AS vocabulary_id,
          'Procedure' AS domain_id,
          'ICD10PCS Hierarchy' AS concept_class_id,
          'S' AS standard_concept,
          code AS concept_code,
          TO_DATE ('19700101', 'yyyymmdd') AS valid_start_date,
          TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
          NULL AS invalid_reason
     FROM umls.mrconso
    WHERE     sab = 'ICD10PCS'
          AND NOT EXISTS
                 (SELECT 1
                    FROM concept_stage cs
                   WHERE cs.concept_code = code);
COMMIT;

--5 Add all synonyms to concept_synonym stage from umls.mrconso
INSERT /*+ APPEND */ INTO  concept_synonym_stage (synonym_concept_code,
                                   synonym_name,
                                   synonym_vocabulary_id,
                                   language_concept_id)
     SELECT code AS concept_code,
            str AS synonym_name,
            'ICD10PCS' AS vocabulary_id,
            4180186 AS language_concept_id
       FROM umls.mrconso
      WHERE sab = 'ICD10PCS'
   GROUP BY code, str;
COMMIT;

--6 Add ICD10CM to RxNorm manual mappings
BEGIN
   DEVV5.VOCABULARY_PACK.ProcessManualRelationships;
END;
COMMIT;

--7 Working with replacement mappings
BEGIN
   DEVV5.VOCABULARY_PACK.CheckReplacementMappings;
END;
COMMIT;

--8 Deprecate 'Maps to' mappings to deprecated and upgraded concepts
BEGIN
   DEVV5.VOCABULARY_PACK.DeprecateWrongMAPSTO;
END;
COMMIT;		

--9 Add mapping from deprecated to fresh concepts
BEGIN
   DEVV5.VOCABULARY_PACK.AddFreshMAPSTO;
END;
COMMIT;

--10 Delete ambiguous 'Maps to' mappings
BEGIN
   DEVV5.VOCABULARY_PACK.DeleteAmbiguousMAPSTO;
END;
COMMIT;

--11 Add "subsumes" relationship between concepts where the concept_code is like of another
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