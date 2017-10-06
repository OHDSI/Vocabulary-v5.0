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
   cCVXFDate1   DATE;
BEGIN
   SELECT max(to_date (LAST_UPDATED_DATE, 'mm/dd/yyyy')) INTO cCVXFDate1 FROM CVX;

   DEVV5.VOCABULARY_PACK.SetLatestUpdate (pVocabularyName        => 'CVX',
                                          pVocabularyDate        => cCVXFDate1,
                                          pVocabularyVersion     => 'CVX code set ' || cCVXFDate1,
                                          pVocabularyDevSchema   => 'DEV_CVX');
END;
/
COMMIT;

--2. Truncate all working tables
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
   SELECT SUBSTR (full_vaccine_name, 1, 255) AS concept_name,
          'CVX' AS vocabulary_id,
          'Drug' AS domain_id,
          'CVX' AS concept_class_id,
          'S' AS standard_concept,
          cvx_code AS concept_code,
          nvl((SELECT MIN(concept_date) FROM CVX_DATES d WHERE d.cvx_code=c.cvx_code),to_date (LAST_UPDATED_DATE, 'mm/dd/yyyy'))  AS valid_start_date, --get concept date from true source
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

--5. Add CVX to RxNorm/RxNorm Extension manual mappings
BEGIN
   DEVV5.VOCABULARY_PACK.ProcessManualRelationships;
END;
COMMIT;

--6. Add additional mappings from rxnconso
INSERT INTO concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
    SELECT DISTINCT rxn.code AS concept_code_1,
                    rxn.rxcui AS concept_code_2,
                    'CVX' AS vocabulary_id_1,
                    'RxNorm' AS vocabulary_id_2,
                    'CVX - RxNorm' AS relationship_id,
                    (SELECT latest_update - 1
                       FROM vocabulary
                      WHERE vocabulary_id = 'CVX')
                        AS valid_start_date,
                    TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
                    NULL AS invalid_reason
      FROM rxnconso rxn
           JOIN concept c ON c.concept_code = rxn.rxcui AND c.vocabulary_id = 'RxNorm' AND c.standard_concept = 'S'
           JOIN concept_stage cs ON cs.concept_code = rxn.code
     WHERE     rxn.sab = 'CVX'
           AND NOT EXISTS
                   (SELECT 1
                      FROM concept_relationship_stage crs
                     WHERE crs.concept_code_1 = rxn.code AND crs.concept_code_2 = rxn.rxcui AND crs.relationship_id = 'CVX - RxNorm');
COMMIT;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script