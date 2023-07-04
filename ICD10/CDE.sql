--ICD10 with mapping
CREATE TABLE icd10 as (
SELECT cs.concept_code,
       cs.concept_name,
       c.concept_id as target_concept_id,
       crs.concept_code_2 as target_concept_code,
       c.concept_name as target_concept_name,
       c.concept_class_id as target_concept_class,
       c.standard_concept as target_standard_concept,
       c.invalid_reason as target_invalid_reason,
       c.domain_id as target_domain_id,
       crs.vocabulary_id_2 as target_vocabulary_id
FROM dev_icd10.concept_stage cs
LEFT JOIN dev_icd10.concept_relationship_stage crs
on cs.concept_code = crs.concept_code_1
    and relationship_id = 'Maps to'
LEFT JOIN concept c on crs.concept_code_2 = c.concept_code
and c.standard_concept = 'S'
and c.invalid_reason is null);

-- ICD10CM with mapping
CREATE TABLE icd10cm as (
SELECT cs.concept_code,
       cs.concept_name,
       c.concept_id as target_concept_id,
       crs.concept_code_2 as target_concept_code,
       c.concept_name as target_concept_name,
       c.concept_class_id as target_concept_class,
       c.standard_concept as target_standard_concept,
       c.invalid_reason as target_invalid_reason,
       c.domain_id as target_domain_id,
       crs.vocabulary_id_2 as target_vocabulary_id
FROM dev_icd10cm.concept_stage cs
LEFT JOIN dev_icd10cm.concept_relationship_stage crs
on cs.concept_code = crs.concept_code_1
    and relationship_id = 'Maps to'
LEFT JOIN concept c on crs.concept_code_2 = c.concept_code
and c.standard_concept = 'S'
and c.invalid_reason is null);

TRUNCATE TABLE dev_icd10_icd10cm_cde;
CREATE TABLE dev_icd10_icd10cm_cde
(concept_name varchar,
concept_code_icd10 varchar,
concept_code_icd10cm varchar,
target_concept_id int,
target_concept_name varchar,
target_concept_class varchar,
target_standard_concept varchar,
target_invalid_reason varchar,
target_domain_id varchar,
target_vocabulary_id varchar);


INSERT INTO dev_icd10_icd10cm_cde
(concept_name,
 concept_code_icd10,
 target_concept_id,
 target_concept_name,
 target_concept_class,
 target_standard_concept,
 target_invalid_reason,
 target_domain_id,
 target_vocabulary_id
)
SELECT DISTINCT concept_name,
concept_code,
target_concept_id,
target_concept_name,
target_concept_class,
target_standard_concept,
target_invalid_reason,
target_domain_id,
target_vocabulary_id
FROM icd10
WHERE (
       COALESCE(concept_code, 'x!x'),
       COALESCE(concept_name, 'x!x')
       --COALESCE(source_code_description_synonym, 'x!x')
          --,COALESCE (source_concept_id, -9876543210)
          )
          NOT IN (
          SELECT COALESCE(concept_code, 'x!x'),
                 COALESCE(concept_name, 'x!x')
                 --COALESCE(source_code_description_synonym, 'x!x')
                 --,COALESCE (source_concept_id, -9876543210)
          FROM dev_icd10_icd10cm_cde
      );

--insert counts for the concepts already presented in dataset-specific source table (use for dataset-specific tables (in contrast to customer-specific))
UPDATE dev_icd10_icd10cm_cde a
SET concept_code_icd10 --specify the exact customer
        = b.concept_code
FROM icd10 b
WHERE COALESCE(a.concept_name, 'x!x') = COALESCE(b.concept_name, 'x!x')
  --AND COALESCE(a.source_code, 'x!x') = COALESCE(b.source_code, 'x!x')
  --AND COALESCE(a.source_code_description_synonym, 'x!x') = COALESCE(b.source_code_description_synonym, 'x!x')
--AND COALESCE (source_concept_id, -9876543210) = COALESCE (b.source_concept_id, -9876543210)
;

INSERT INTO dev_icd10_icd10cm_cde
(concept_name,
 concept_code_icd10,
 target_concept_id,
 target_concept_name,
 target_concept_class,
 target_standard_concept,
 target_invalid_reason,
 target_domain_id,
 target_vocabulary_id
)
SELECT DISTINCT concept_name,
concept_code,
target_concept_id,
target_concept_name,
target_concept_class,
target_standard_concept,
target_invalid_reason,
target_domain_id,
target_vocabulary_id
FROM icd10cm
WHERE (
       --COALESCE(concept_code, 'x!x'),
       COALESCE(concept_name, 'x!x')
       --COALESCE(source_code_description_synonym, 'x!x')
          --,COALESCE (source_concept_id, -9876543210)
          )
          NOT IN (
          SELECT --COALESCE(concept_code, 'x!x'),
                 COALESCE(concept_name, 'x!x')
                 --COALESCE(source_code_description_synonym, 'x!x')
                 --,COALESCE (source_concept_id, -9876543210)
          FROM dev_icd10_icd10cm_cde
      );

--insert counts for the concepts already presented in dataset-specific source table (use for dataset-specific tables (in contrast to customer-specific))
UPDATE dev_icd10_icd10cm_cde a
SET concept_code_icd10cm --specify the exact customer
        = b.concept_code
FROM icd10cm b
WHERE COALESCE(a.concept_name, 'x!x') = COALESCE(b.concept_name, 'x!x')
  --AND COALESCE(a.source_code, 'x!x') = COALESCE(b.source_code, 'x!x')
  --AND COALESCE(a.source_code_description_synonym, 'x!x') = COALESCE(b.source_code_description_synonym, 'x!x')
--AND COALESCE (source_concept_id, -9876543210) = COALESCE (b.source_concept_id, -9876543210)
;

SELECT * FROM dev_icd10_icd10cm_cde
where concept_name !~* 'Invalid'
order by concept_code_icd10, concept_name
;