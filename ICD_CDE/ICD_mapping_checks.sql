--Create table with ICD10, ICD10CM, ICD9CM
CREATE TABLE icd_mappings (
    source_code varchar,
    source_code_description varchar,
    relationship_id varchar,
    target_concept_id int,
    target_concept_code varchar,
    target_concept_name varchar,
    target_concept_class_id varchar,
    target_standard_concept varchar,
    target_invalid_reason varchar,
    target_domain_id varchar,
    target_vocabulary_id varchar,
    target_valid_start_date date,
    target_valid_end_date date
);

INSERT INTO icd_mappings(
--ICD10 mappings
SELECT DISTINCT
       crs.concept_code_1 as source_code,
       c2.concept_name as source_code_description,
       crs.relationship_id as relationship_id,
       c.concept_id as target_concept_id,
       c.concept_code as target_concept_code,
       c.concept_name as target_concept_name,
       c.concept_class_id as target_concept_class_id,
       c.standard_concept as target_standard_concept,
       c.invalid_reason as target_invalid_reason,
       c.domain_id as target_domain_id,
       c.vocabulary_id as target_vocabulary_id,
       c.valid_start_date as target_valid_end_date,
       c.valid_end_date as target_valid_end_date
FROM dev_icd10.concept_relationship_stage crs
LEFT JOIN concept c ON crs.concept_code_2 = c.concept_code
AND c.standard_concept = 'S'
AND c.invalid_reason is null
LEFT JOIN concept c2 ON crs.concept_code_1 = c2.concept_code
AND crs.vocabulary_id_1 = 'ICD10'
WHERE crs.relationship_id in ('Maps to', 'Maps to value')

UNION ALL

--ICD10CM mappings
SELECT DISTINCT
       crs.concept_code_1 as source_code,
       c2.concept_name as source_code_description,
       crs.relationship_id as relationship_id,
       c.concept_id as target_concept_id,
       c.concept_code as target_concept_code,
       c.concept_name as target_concept_name,
       c.concept_class_id as target_concept_class_id,
       c.standard_concept as target_standard_concept,
       c.invalid_reason as target_invalid_reason,
       c.domain_id as target_domain_id,
       c.vocabulary_id as target_vocabulary_id,
       c.valid_start_date as target_valid_end_date,
       c.valid_end_date as target_valid_end_date
FROM dev_icd10cm.concept_relationship_stage crs
LEFT JOIN concept c ON crs.concept_code_2 = c.concept_code
AND c.standard_concept = 'S'
AND c.invalid_reason is null
LEFT JOIN concept c2 ON crs.concept_code_1 = c2.concept_code
AND crs.vocabulary_id_1 = 'ICD10CM'
WHERE crs.relationship_id in ('Maps to', 'Maps to value')

UNION ALL

--ICD9CM mappings
SELECT DISTINCT
       crs.concept_code_1 as source_code,
       c2.concept_name as source_code_description,
       crs.relationship_id as relationship_id,
       c.concept_id as target_concept_id,
       c.concept_code as target_concept_code,
       c.concept_name as target_concept_name,
       c.concept_class_id as target_concept_class_id,
       c.standard_concept as target_standard_concept,
       c.invalid_reason as target_invalid_reason,
       c.domain_id as target_domain_id,
       c.vocabulary_id as target_vocabulary_id,
       c.valid_start_date as target_valid_end_date,
       c.valid_end_date as target_valid_end_date
FROM dev_icd9cm.concept_relationship_stage crs
LEFT JOIN concept c ON crs.concept_code_2 = c.concept_code
AND c.standard_concept = 'S'
AND c.invalid_reason is null
LEFT JOIN concept c2 ON crs.concept_code_1 = c2.concept_code
AND crs.vocabulary_id_1 = 'ICD9CM'
WHERE crs.relationship_id in ('Maps to', 'Maps to value'));


