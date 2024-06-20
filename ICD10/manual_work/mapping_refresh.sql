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
* Authors: Irina Zherko, Dmitry Dymshyts, Polina Talapova, Daryna Ivakhnenko
* Date: 2024
**************************************************************************/
-- Create table icd10_refresh
DROP TABLE icd10_refresh;
TRUNCATE TABLE icd10_refresh;
CREATE TABLE icd10_refresh
(
    source_code             TEXT NOT NULL,
    source_code_description varchar(255),
    source_vocabulary_id    varchar(20),
    relationship_id         varchar(20),
    target_concept_id       int,
    target_concept_code     varchar(50),
    target_concept_name     varchar(255),
    target_concept_class_id varchar(20),
    target_standard_concept varchar(1),
    target_invalid_reason   varchar(1),
    target_domain_id        varchar(20),
    target_vocabulary_id    varchar(20),
    rel_invalid_reason      varchar(1),
    valid_start_date        date,
    valid_end_date          date,
    mappings_origin         varchar
);

--Insert other potential replacement mappings
INSERT INTO icd10_refresh
    (source_code,
     source_code_description,
     source_vocabulary_id,
     relationship_id,
     target_concept_id,
     target_concept_code,
     target_concept_name,
     target_concept_class_id,
     target_standard_concept,
     target_invalid_reason,
     target_domain_id,
     target_vocabulary_id,
     rel_invalid_reason,
     valid_start_date,
     valid_end_date,
     mappings_origin)
(with mis_map as
(SELECT
cs.concept_code as source_code,
cs.concept_name as source_code_description,
cs.vocabulary_id as source_vocabulary_id,
crs.relationship_id as relationship_id,
crs.invalid_reason as rel_invalid_reason,
crs.valid_start_date as valid_start_date,
crs.valid_end_date as valid_end_date,
c.concept_id as target_concept_id
FROM concept_relationship_stage crs
LEFT JOIN concept c
ON crs.concept_code_2 = c.concept_code
and c.vocabulary_id = 'SNOMED'
JOIN concept_stage cs ON crs.concept_code_1 = cs.concept_code
WHERE relationship_id = 'Maps to'
     AND crs.invalid_reason in ('D', 'U')
AND concept_code_1 NOT IN
(SELECT concept_code_1 FROM concept_relationship_stage
    WHERE relationship_id = 'Maps to'
     AND invalid_reason is null)
    )
       SELECT DISTINCT m.source_code,
              m.source_code_description,
              m.source_vocabulary_id,
              m.relationship_id,
              c.concept_id as target_concept_id,
              c.concept_code as target_concept_code,
              c.concept_name as target_concept_name,
              c.concept_class_id as target_concept_class_id,
              c.standard_concept as target_standard_concept,
              c.invalid_reason as target_invalid_reason,
              c.domain_id as target_domain_id,
              c.vocabulary_id as target_vocabulary_id,
              m.rel_invalid_reason as rel_invalid_reason,
              m.valid_start_date as valid_start_date,
              m.valid_end_date as valid_end_date,
              'Concept poss_eq to' as mapping_origin
       FROM mis_map m JOIN concept_relationship cr
       ON m.target_concept_id = cr.concept_id_1
       JOIN concept c
       ON cr.concept_id_2 = c.concept_id
       AND cr.relationship_id in ('Concept poss_eq to')
       AND c.standard_concept = 'S'
       AND c.invalid_reason is null);

--Insert concepts without mapping
INSERT INTO icd10_refresh
    (source_code,
     source_code_description,
     source_vocabulary_id,
     target_concept_id,
     mappings_origin)
SELECT cs.concept_code as source_code,
       cs.concept_name as source_code_description,
       cs.vocabulary_id as source_vocabulary_id,
       NULL as target_concept_id,
       'without mapping' as mapping_origin
FROM concept_stage cs LEFT JOIN concept_relationship_stage crs on cs.concept_code = crs.concept_code_1
and crs.relationship_id in ('Maps to', 'Maps to value')
WHERE crs.concept_code_2 is null
and cs.invalid_reason is null
and cs.concept_class_id NOT IN ('ICD10 Chapter','ICD10 SubChapter', 'ICD10 Hierarchy');

