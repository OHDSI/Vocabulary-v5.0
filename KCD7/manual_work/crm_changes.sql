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
* Authors: Irina Zherko, Darina Ivakhnenko, Dmitry Dymshyts
* Date: 2024
**************************************************************************/
 --1. Update the concept_relationship_manual table
-- CREATE TABLE concept_relationship_manual_bu as (SELECT * FROM concept_relationship_manual);
-- INSERT INTO concept_relationship_manual (SELECT * FROM concept_relationship_manual_bu);
TRUNCATE TABLE dev_KCD7.concept_relationship_manual;
INSERT INTO concept_relationship_manual (concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
SELECT DISTINCT
concept_code_1,
concept_code_2,
vocabulary_id_1,
vocabulary_id_2,
relationship_id,
valid_start_date,
valid_end_date,
invalid_reason
FROM devv5.base_concept_relationship_manual
where vocabulary_id_1 = 'KCD7';

-- deprecate previous inaccurate mapping
UPDATE concept_relationship_manual crm
SET invalid_reason = 'D',
    valid_end_date = current_date

--SELECT * FROM concept_relationship_manual crm --use this SELECT for QA
WHERE invalid_reason IS NULL --deprecate only what's not yet deprecated in order to preserve the original deprecation date

    AND concept_code_1 IN (SELECT source_code FROM dev_icd10.icd_cde_proc WHERE source_vocabulary_id = 'KCD7') --work only with the codes presented in the manual file of the current vocabulary refresh
    AND vocabulary_id_1 = 'KCD7'
    AND NOT EXISTS (SELECT 1 --don't deprecate mapping if the same exists in the current manual file
                    FROM dev_icd10.icd_cde_proc rl
                    WHERE rl.source_code = crm.concept_code_1 --the same source_code is mapped
                        AND rl.target_concept_code = crm.concept_code_2 --to the same concept_code
                        AND rl.target_vocabulary_id = crm.vocabulary_id_2 --of the same vocabulary
                        AND rl.relationship_id = crm.relationship_id --with the same relationship
                        AND rl.source_vocabulary_id = 'KCD7'     )
;

-- activate mapping, that became valid again
UPDATE concept_relationship_manual crm
SET invalid_reason = null,
    valid_end_date = to_date('20991231','yyyymmdd'),
    valid_start_date = current_date

--SELECT * FROM concept_relationship_manual crm --use this SELECT for QA
WHERE invalid_reason = 'D' -- activate only deprecated mappings

    AND EXISTS (SELECT 1 -- activate mapping if the same exists in the current manual file
                    FROM dev_icd10.icd_cde_proc rl
                    WHERE rl.source_code = crm.concept_code_1 --the same source_code is mapped
                        AND rl.target_concept_code = crm.concept_code_2 --to the same concept_code
                        AND rl.target_vocabulary_id = crm.vocabulary_id_2 --of the same vocabulary
                        AND rl.relationship_id = crm.relationship_id --with the same relationship
                        AND rl.source_vocabulary_id = 'KCD7'
        )
;

-- insert new mapping
with mapping AS -- select all new codes with their mappings from manual file
    (
        SELECT DISTINCT source_code AS concept_code_1,
               target_concept_code AS concept_code_2,
               'KCD7' AS vocabulary_id_1, -- set current vocabulary name as vocabulary_id_1
               target_vocabulary_id AS vocabulary_id_2,
               relationship_id AS relationship_id,
               current_date AS valid_start_date, -- set the date of the refresh as valid_start_date
               to_date('20991231','yyyymmdd') AS valid_end_date,
               NULL AS invalid_reason -- make all new mappings valid
        FROM dev_icd10.icd_cde_proc
        WHERE target_concept_id is not null -- select only codes with mapping to standard concepts
              and target_concept_id != 0
          AND source_vocabulary_id = 'KCD7'
    )
-- insert new mappings into concept_relationship_manual table
INSERT INTO concept_relationship_manual(concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
(
        SELECT concept_code_1,
            concept_code_2,
            vocabulary_id_1,
            vocabulary_id_2,
            relationship_id,
            valid_start_date,
            valid_end_date,
            invalid_reason
     FROM mapping m
        -- don't insert codes with mapping if the same exists in the current manual file
        WHERE (concept_code_1, --the same source_code is mapped
               concept_code_2, --to the same concept_code
               vocabulary_id_1,
               vocabulary_id_2, --of the same vocabulary
               relationship_id) --with the same relationship
        NOT IN (SELECT concept_code_1,
                       concept_code_2,
                       vocabulary_id_1,
                       vocabulary_id_2,
                       relationship_id FROM concept_relationship_manual)
    )
;