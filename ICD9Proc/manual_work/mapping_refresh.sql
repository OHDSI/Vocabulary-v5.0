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
* Authors: Irina Zherko
* Date: 2022
**************************************************************************/
DROP TABLE IF EXISTS refresh_lookup;
CREATE TABLE refresh_lookup AS WITH miss_map
AS
(
SELECT *
from concept_relationship_stage
WHERE vocabulary_id_1 = 'ICD9Proc'
AND vocabulary_id_2 = 'SNOMED' -- set target vocabulary
AND relationship_id in ('Maps to', 'Maps to value')
AND invalid_reason is not null
ORDER BY concept_code_1)
SELECT cr.concept_code_1 as icd_code,
       c.concept_name as icd_name,
       cr.relationship_id as current_relationship,
       cc.concept_id as current_id,
       cr.concept_code_2 as current_code,
       cc.concept_name as current_name,
       cc.domain_id as current_domain,
       cc.vocabulary_id as current_vocabulary,
       cor.concept_id as repl_by_id,
       rr.concept_code_2 as repl_by_code,
       cor.concept_name as repl_by_name,
       cor.domain_id as repl_by_domain,
       cor.vocabulary_id as repl_by_vocabulary
FROM miss_map cr JOIN concept c ON cr.concept_code_1=c.concept_code
AND c.vocabulary_id =  'ICD9Proc'
JOIN concept cc ON cr.concept_code_2 = cc.concept_code
AND cc.vocabulary_id = 'SNOMED' -- set target vocabulary
LEFT JOIN concept_relationship_stage rr ON cr.concept_code_2 = rr.concept_code_1
AND rr.vocabulary_id_2 = 'SNOMED'
AND rr.invalid_reason is null
LEFT JOIN concept cor ON rr.concept_code_2 = cor.concept_code
AND cor.vocabulary_id = 'SNOMED'
AND cor.standard_concept = 'S';