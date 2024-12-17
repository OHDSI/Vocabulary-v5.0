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
--Create table icd10cn_refresh
DROP TABLE icd10cn_refresh;
TRUNCATE TABLE icd10cn_refresh;
CREATE TABLE icd10cn_refresh
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

--Insert concepts, which are represented in the crm and where changed by functions
INSERT INTO icd10cn_refresh
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
with deprecated_mappings as
(SELECT concept_code_1, vocabulary_id_1, concept_code_2, vocabulary_id_2, relationship_id, valid_end_date
    FROM concept_relationship_stage crs
    WHERE (concept_code_1, vocabulary_id_1, concept_code_2, vocabulary_id_2, relationship_id) IN
    (SELECT concept_code_1, vocabulary_id_1, concept_code_2, vocabulary_id_2, relationship_id
    FROM devv5.base_concept_relationship_manual WHERE vocabulary_id_1 = 'ICD10CN')
    and invalid_reason = 'D'
    and valid_end_date in (SELECT DISTINCT GREATEST(crs.valid_start_date, (
				SELECT MAX(v.latest_update) - 1
				FROM vocabulary v
				WHERE v.vocabulary_id IN (
						crs.vocabulary_id_1,
						crs.vocabulary_id_2
					)
			)) FROM concept_relationship_stage crs)) --108
SELECT
    crs.concept_code_1 as source_code,
    cs.concept_name as source_code_description,
    crs.vocabulary_id_1 as source_vocabulary_id,
    crs.relationship_id as relationship_id,
    c.concept_id as target_concept_id,
    c.concept_code as target_concept_code,
    c.concept_name as target_concept_name,
    c.concept_class_id as target_concept_class_id,
    c.standard_concept as target_standard_concept,
    c.invalid_reason as target_invalid_reason,
    c.domain_id as target_domain_id,
    crs.vocabulary_id_2 as target_vocabulary_id,
    crs.invalid_reason as rel_invalid_reason,
    crs.valid_start_date,
    crs.valid_end_date,
    'functions_updated' as mappings_origin
FROM concept_relationship_stage crs
LEFT JOIN concept_stage cs ON crs.concept_code_1 = cs.concept_code
AND crs.vocabulary_id_1 = cs.vocabulary_id
LEFT JOIN concept c ON crs.concept_code_2 = c.concept_code AND crs.vocabulary_id_2 = c.vocabulary_id
    WHERE (concept_code_1, vocabulary_id_1, concept_code_2, vocabulary_id_2, relationship_id) IN
    (SELECT concept_code_1, vocabulary_id_1, concept_code_2, vocabulary_id_2, relationship_id
    FROM deprecated_mappings)

UNION ALL

SELECT
crs.concept_code_1 as source_code,
    cs.concept_name as source_code_description,
    crs.vocabulary_id_1 as source_vocabulary_id,
    crs.relationship_id as relationship_id,
    c.concept_id as target_concept_id,
    c.concept_code as target_concept_code,
    c.concept_name as target_concept_name,
    c.concept_class_id as target_concept_class_id,
    c.standard_concept as target_standard_concept,
    c.invalid_reason as target_invalid_reason,
    c.domain_id as target_domain_id,
    crs.vocabulary_id_2 as target_vocabulary_id,
    crs.invalid_reason as rel_invalid_reason,
    crs.valid_start_date,
    crs.valid_end_date,
    'functions_updated' as mappings_origin
FROM concept_relationship_stage crs
LEFT JOIN concept_stage cs ON crs.concept_code_1 = cs.concept_code
AND crs.vocabulary_id_1 = cs.vocabulary_id
LEFT JOIN concept c ON crs.concept_code_2 = c.concept_code AND crs.vocabulary_id_2 = c.vocabulary_id
WHERE (concept_code_1, vocabulary_id_1, relationship_id) IN
(SELECT concept_code_1, vocabulary_id_1, relationship_id FROM deprecated_mappings)
AND crs.valid_start_date = (SELECT DISTINCT GREATEST (d.lu_1, d.lu_2)
    FROM (SELECT v1.latest_update AS lu_1, v2.latest_update AS lu_2
			FROM concept_relationship_stage crs
			JOIN vocabulary v1 ON v1.vocabulary_id = crs.vocabulary_id_1
			JOIN vocabulary v2 ON v2.vocabulary_id = crs.vocabulary_id_2) d)
and crs.invalid_reason is null
;

--Insert other potential replacement mappings for concepts from crm
INSERT INTO icd10cn_refresh
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
c.concept_id as target_concept_id,
crs.invalid_reason as rel_invalid_reason,
crs.valid_start_date as valid_start_date,
crs.valid_end_date as valid_end_date
FROM concept_relationship_stage crs
LEFT JOIN concept c
ON crs.concept_code_2 = c.concept_code
and c.vocabulary_id = 'SNOMED'
JOIN concept_stage cs ON crs.concept_code_1 = cs.concept_code
WHERE (concept_code_1, vocabulary_id_1, concept_code_2, vocabulary_id_2, relationship_id) IN
    (SELECT concept_code_1, vocabulary_id_1, concept_code_2, vocabulary_id_2, relationship_id
    FROM devv5.base_concept_relationship_manual WHERE vocabulary_id_1 = 'ICD10CN')
    and crs.invalid_reason = 'D'
    and crs.valid_end_date in (SELECT DISTINCT GREATEST(crs.valid_start_date, (
				SELECT MAX(v.latest_update) - 1
				FROM vocabulary v
				WHERE v.vocabulary_id IN (
						crs.vocabulary_id_1,
						crs.vocabulary_id_2
					)
			)) FROM concept_relationship_stage crs))
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

--Insert the rest of crm relationships which are not represented in the icd_cde_source table
INSERT INTO icd10cn_refresh
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
SELECT
    crm.concept_code_1 as source_code,
    c.concept_name as source_code_description,
    crm.vocabulary_id_1 as source_vocabulary_id,
    crm.relationship_id as relationship_id,
    c2.concept_id as target_concept_id,
    crm.concept_code_2 as target_concept_code,
    c2.concept_name as target_concept_name,
    c2.concept_class_id as target_concept_class_id,
    c2.standard_concept as target_standard_concept,
    c2.invalid_reason as targer_invalid_reason,
    c2.domain_id as target_domain_id,
    c2.vocabulary_id as target_vocabulary_id,
    crm.invalid_reason as rel_invalid_reason,
    crm.valid_start_date as valid_start_date,
    crm.valid_end_date as valid_end_date,
    'crm' as mapping_origin
FROM devv5.base_concept_relationship_manual crm
LEFT JOIN concept c on crm.concept_code_1 = c.concept_code and crm.vocabulary_id_1 = c.vocabulary_id
LEFT JOIN concept c2 on crm.concept_code_2 = c2.concept_code and crm.vocabulary_id_2 = c2.vocabulary_id
WHERE (crm.concept_code_1, crm.vocabulary_id_1, crm.relationship_id) not in (SELECT source_code, source_vocabulary_id, relationship_id FROM icd10cn_refresh)
AND crm.vocabulary_id_1 = 'ICD10CN'
AND (crm.concept_code_1, crm.vocabulary_id_1, crm.concept_code_2. crm.vocabulary_id_2) NOT IN
    (SELECT source_code, source_vocabulary_id, target_concept_code, target_vocabulary_id FROM dev_icd10.icd_cde_source);

--Insert concepts without mapping --Not used at every refresh
INSERT INTO icd10cn_refresh
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
WHERE crs.concept_code_2 is null
and cs.invalid_reason is null
and cs.concept_class_id NOT IN ('ICD10 Chapter','ICD10 SubChapter', 'ICD10 Hierarchy');
