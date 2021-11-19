/**************************************************************************
* Copyright 2016 Observational Health Data Sciences AND Informatics (OHDSI)
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may NOT use this file except IN compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to IN writing, software
* distributed under the License is distributed ON an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*
* Authors: Polina Talapova
* Date: Nov 2021
**************************************************************************/
-- please, note, that concept_manual table should not be rewritten, it can be only enriched by new codes (that is why a backup is required)
-- add already existing codes using devv5 into the concept_manual table
INSERT INTO concept_manual
SELECT concept_name,
       domain_id,
       vocabulary_id,
       concept_class_id,
       standard_concept,
       concept_code,
       valid_start_date,
       valid_end_date,
       invalid_reason
FROM devv5.concept
WHERE vocabulary_id = 'LPD_Belgium'; 

-- resurrect wrongly killed if any
UPDATE concept_manual
   SET invalid_reason = NULL,
       valid_end_date = TO_DATE('20991231','yyyymmdd')
WHERE concept_code IN (SELECT prod_prd_id FROM belg_source_full)
AND   invalid_reason IS NOT NULL; -- 12869

-- add new codes
INSERT INTO concept_manual
SELECT DISTINCT prd_name AS concept_name,
       'Drug' AS domain_id, -- by default, will be changed in the load stage
       'LPD_Belgium' AS vocabulary_id,
       'Drug Product' AS concept_class_id, -- by default, will be changed in the load stage
       NULL AS standard_concept,
       prod_prd_id AS concept_code,
       TO_DATE('20190501','yyyymmdd') AS valid_start_date,
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
       NULL AS invalid_reason
FROM belg_source_full
WHERE prod_prd_id NOT IN (SELECT concept_code FROM concept_manual); -- 3197
