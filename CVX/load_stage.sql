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
DECLARE
   cCVXFDate   DATE;
BEGIN
   SELECT MAX (last_updated_date) INTO cCVXFDate FROM CVX;

   DEVV5.VOCABULARY_PACK.SetLatestUpdate (pVocabularyName        => 'CVX',
                                          pVocabularyDate        => cCVXFDate,
                                          pVocabularyVersion     => 'CVX code set ' || cCVXFDate,
                                          pVocabularyDevSchema   => 'DEV_CVX');
END;
COMMIT;

--2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;

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
   SELECT SUBSTR (full_vaccine_name, 1, 255) AS concept_name,
          'CVX' AS vocabulary_id,
          'Drug' AS domain_id,
          'Drg Class' AS concept_class_id,
          'C' AS standard_concept,
          cvx_code AS concept_code,
          (SELECT MIN(concept_date) FROM CVX_DATES d WHERE D.CVX_CODE=C.CVX_CODE) AS valid_start_date, --get concept date from true source
          TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
          NULL AS invalid_reason
     FROM CVX c;
COMMIT;			

--4. load into concept_synonym_stage
INSERT INTO concept_synonym_stage (synonym_concept_id,
                                   synonym_concept_code,
                                   synonym_name,
                                   synonym_vocabulary_id,
                                   language_concept_id)
   SELECT DISTINCT NULL AS synonym_concept_id,
                   cvx_code AS synonym_concept_code,
                   DESCRIPTION AS synonym_name,
                   'CVX' AS synonym_vocabulary_id,
                   4180186 AS language_concept_id                   -- English
     FROM (SELECT full_vaccine_name, short_description, cvx_code FROM CVX)
          UNPIVOT
             (DESCRIPTION  --take both full_vaccine_name and short_description
             FOR DESCRIPTIONS
             IN (full_vaccine_name, short_description));			  
COMMIT;

---------------
--???

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script		