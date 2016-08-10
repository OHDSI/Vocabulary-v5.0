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
   DEVV5.VOCABULARY_PACK.SetLatestUpdate (pVocabularyName        => 'EphMRA ATC',
                                          pVocabularyDate        => TO_DATE ('20160704', 'yyyymmdd'),
                                          pVocabularyVersion     => 'EphMRA ATC 2016',
                                          pVocabularyDevSchema   => 'DEV_EPHMRA_ATC');
END;
COMMIT;


-- 2. Truncate all working tables and remove indices
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3. Insert into concept_stage
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
          'EphMRA ATC' AS vocabulary_id,
          'Drug' AS domain_id,
          CASE
             WHEN LENGTH (concept_code) = 1 THEN 'ATC 1st'
             WHEN LENGTH (concept_code) = 2 THEN 'ATC 2nd'
             WHEN LENGTH (concept_code) = 3 THEN 'ATC 3rd'
             WHEN LENGTH (concept_code) = 4 THEN 'ATC 4th'
             WHEN LENGTH (concept_code) = 5 THEN 'ATC 5th'
          END
             AS concept_class_id,
          'C' AS standard_concept,
          concept_code,
          TO_DATE ('19700101', 'yyyymmdd') AS valid_start_date,
          TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
          NULL AS invalid_reason
     FROM (SELECT UPPER (TRIM (concept_code)) AS concept_code,
                  REPLACE (COALESCE (concept_name,
                                     n1,
                                     n2,
                                     n3,
                                     n4,
                                     n5),
                           '?',
                           '-')
                     AS concept_name
             FROM ATC_Glossary
            WHERE concept_code NOT LIKE '\_%' ESCAPE '\' AND TRIM (concept_code) IS NOT NULL);
COMMIT;				  

--4. Add hierarchy inside EphMRA ATC
INSERT INTO concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        relationship_id,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT uppr.concept_code AS concept_code_1,
          lowr.concept_code AS concept_code_2,
          'Is a' AS relationship_id,
          'EphMRA ATC' AS vocabulary_id_1,
          'EphMRA ATC' AS vocabulary_id_2,
          v.latest_update AS valid_start_date,
          TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
          NULL AS invalid_reason
     FROM concept_stage uppr, concept_stage lowr, vocabulary v
    WHERE     lowr.concept_code = SUBSTR (uppr.concept_code, 1, LENGTH (uppr.concept_code) - 1)
          AND uppr.vocabulary_id = 'EphMRA ATC'
          AND lowr.vocabulary_id = 'EphMRA ATC'
          AND v.vocabulary_id = 'EphMRA ATC';
COMMIT;		  

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script		