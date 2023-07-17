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

DROP TABLE dev_icd10.icd_cde;
TRUNCATE TABLE dev_icd10.icd_cde;
CREATE TABLE dev_icd10.icd_cde
(
    concept_name_id      serial primary key,
    concept_name         varchar,
    group_id             int,
    concept_code_icd10   varchar,
    concept_code_icd10cm varchar,
    concept_code_icd10gm varchar,
    concept_code_cim10   varchar,
    concept_code_kcd7    varchar,
    concept_code_icd10cn varchar
--target_concept_id int,
--target_concept_name varchar,
--target_concept_class varchar,
--target_standard_concept varchar,
--target_invalid_reason varchar,
--target_domain_id varchar,
--target_vocabulary_id varchar
);

--icd10 insertion
INSERT INTO dev_icd10.icd_cde
(concept_name,
 concept_code_icd10
 --,
 --target_concept_id,
 --target_concept_name,
 --target_concept_class,
 --target_standard_concept,
 --target_invalid_reason,
 --target_domain_id,
 --target_vocabulary_id
)
SELECT DISTINCT
concept_name,
concept_code
--,
--target_concept_id,
--target_concept_name,
--target_concept_class,
--target_standard_concept,
--target_invalid_reason,
--target_domain_id,
--target_vocabulary_id
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
          FROM dev_icd10.icd_cde
      )
AND concept_name !~* 'Invalid'
order by concept_code, concept_name
;

--insert concept_codes for the concepts already presented in CDE
UPDATE dev_icd10.icd_cde a
SET concept_code_icd10
        = b.concept_code
FROM icd10 b
WHERE COALESCE(a.concept_name, 'x!x') = COALESCE(b.concept_name, 'x!x')
     AND COALESCE(a.concept_code_icd10, 'x!x') = COALESCE(b.concept_code, 'x!x')
  --AND COALESCE(a.source_code_description_synonym, 'x!x') = COALESCE(b.source_code_description_synonym, 'x!x')
--AND COALESCE (source_concept_id, -9876543210) = COALESCE (b.source_concept_id, -9876543210)
;

--icd10cm insertion
INSERT INTO dev_icd10.icd_cde
(concept_name,
 concept_code_icd10cm
 --,
 --target_concept_id,
 --target_concept_name,
 --target_concept_class,
 --target_standard_concept,
 --target_invalid_reason,
 --target_domain_id,
 --target_vocabulary_id
)
SELECT DISTINCT
concept_name,
concept_code
--,
--target_concept_id,
--target_concept_name,
--target_concept_class,
--target_standard_concept,
--target_invalid_reason,
--target_domain_id,
--target_vocabulary_id
FROM icd10cm
WHERE (
       --COALESCE(concept_code, 'x!x'),
       COALESCE(concept_name, 'x!x')
       --COALESCE(source_code_description_synonym, 'x!x')
          --,COALESCE (source_concept_id, -9876543210)
          )
          NOT IN (
          SELECT
                 --COALESCE(concept_code, 'x!x'),
                 COALESCE(concept_name, 'x!x')
                 --COALESCE(source_code_description_synonym, 'x!x')
                 --,COALESCE (source_concept_id, -9876543210)
          FROM dev_icd10.icd_cde
      )
AND concept_name !~* 'Invalid'
order by concept_code, concept_name;

--insert concept_codes for the concepts already presented in CDE
UPDATE dev_icd10.icd_cde a
SET concept_code_icd10cm
        = b.concept_code
FROM icd10cm b
WHERE COALESCE(a.concept_name, 'x!x') = COALESCE(b.concept_name, 'x!x')
  --AND COALESCE(a.concept_code_icd10cm, 'x!x') = COALESCE(b.concept_code, 'x!x')
  --AND COALESCE(a.source_code_description_synonym, 'x!x') = COALESCE(b.source_code_description_synonym, 'x!x')
--AND COALESCE (source_concept_id, -9876543210) = COALESCE (b.source_concept_id, -9876543210)
;

--icd10gm insertion
INSERT INTO dev_icd10.icd_cde
(concept_name,
 concept_code_icd10gm
 --target_concept_id,
 --target_concept_name,
 --target_concept_class,
 --target_standard_concept,
 --target_invalid_reason,
 --target_domain_id,
 --target_vocabulary_id
)
SELECT DISTINCT
concept_name,
concept_code
--,
--target_concept_id,
--target_concept_name,
--target_concept_class,
--target_standard_concept,
--target_invalid_reason,
--target_domain_id,
--target_vocabulary_id
FROM dev_icd10gm.concept_stage
WHERE (
       --COALESCE(concept_code, 'x!x'),
       COALESCE(concept_name, 'x!x')
       --COALESCE(source_code_description_synonym, 'x!x')
          --,COALESCE (source_concept_id, -9876543210)
          )
          NOT IN (
          SELECT
                 --COALESCE(concept_code, 'x!x'),
                 COALESCE(concept_name, 'x!x')
                 --COALESCE(source_code_description_synonym, 'x!x')
                 --,COALESCE (source_concept_id, -9876543210)
          FROM dev_icd10.icd_cde
      )
AND concept_name !~* 'Invalid'
order by concept_code, concept_name;

--insert concept_codes for the concepts already presented in CDE
UPDATE dev_icd10.icd_cde a
SET concept_code_icd10gm
        = b.concept_code
FROM dev_icd10gm.concept_stage b
WHERE COALESCE(a.concept_name, 'x!x') = COALESCE(b.concept_name, 'x!x')
  --AND COALESCE(a.concept_code_icd10cm, 'x!x') = COALESCE(b.concept_code, 'x!x')
  --AND COALESCE(a.source_code_description_synonym, 'x!x') = COALESCE(b.source_code_description_synonym, 'x!x')
--AND COALESCE (source_concept_id, -9876543210) = COALESCE (b.source_concept_id, -9876543210)
;

--kcd7
INSERT INTO dev_icd10.icd_cde
(concept_name,
 concept_code_kcd7
 --target_concept_id,
 --target_concept_name,
 --target_concept_class,
 --target_standard_concept,
 --target_invalid_reason,
 --target_domain_id,
 --target_vocabulary_id
)
SELECT DISTINCT
concept_name,
concept_code
--,
--target_concept_id,
--target_concept_name,
--target_concept_class,
--target_standard_concept,
--target_invalid_reason,
--target_domain_id,
--target_vocabulary_id
FROM dev_kcd7.concept_stage
WHERE (
       --COALESCE(concept_code, 'x!x'),
       COALESCE(concept_name, 'x!x')
       --COALESCE(source_code_description_synonym, 'x!x')
          --,COALESCE (source_concept_id, -9876543210)
          )
          NOT IN (
          SELECT
                 --COALESCE(concept_code, 'x!x'),
                 COALESCE(concept_name, 'x!x')
                 --COALESCE(source_code_description_synonym, 'x!x')
                 --,COALESCE (source_concept_id, -9876543210)
          FROM dev_icd10.icd_cde
      )
AND concept_name !~* 'Invalid'
order by concept_code, concept_name;

--insert concept_codes for the concepts already presented in CDE
UPDATE dev_icd10.icd_cde a
SET concept_code_kcd7
        = b.concept_code
FROM dev_kcd7.concept_stage b
WHERE COALESCE(a.concept_name, 'x!x') = COALESCE(b.concept_name, 'x!x')
  --AND COALESCE(a.concept_code_icd10cm, 'x!x') = COALESCE(b.concept_code, 'x!x')
  --AND COALESCE(a.source_code_description_synonym, 'x!x') = COALESCE(b.source_code_description_synonym, 'x!x')
--AND COALESCE (source_concept_id, -9876543210) = COALESCE (b.source_concept_id, -9876543210)
;

--icd10cn
INSERT INTO dev_icd10.icd_cde
(concept_name,
 concept_code_icd10cn
 --target_concept_id,
 --target_concept_name,
 --target_concept_class,
 --target_standard_concept,
 --target_invalid_reason,
 --target_domain_id,
 --target_vocabulary_id
)
SELECT DISTINCT
concept_name,
concept_code
--,
--target_concept_id,
--target_concept_name,
--target_concept_class,
--target_standard_concept,
--target_invalid_reason,
--target_domain_id,
--target_vocabulary_id
FROM dev_icd10cn.concept_stage
WHERE (
       --COALESCE(concept_code, 'x!x'),
       COALESCE(concept_name, 'x!x')
       --COALESCE(source_code_description_synonym, 'x!x')
          --,COALESCE (source_concept_id, -9876543210)
          )
          NOT IN (
          SELECT
                 --COALESCE(concept_code, 'x!x'),
                 COALESCE(concept_name, 'x!x')
                 --COALESCE(source_code_description_synonym, 'x!x')
                 --,COALESCE (source_concept_id, -9876543210)
          FROM dev_icd10.icd_cde
      )
AND concept_name !~* 'Invalid'
order by concept_code, concept_name;

--insert concept_codes for the concepts already presented in CDE
UPDATE dev_icd10.icd_cde a
SET concept_code_icd10cn
        = b.concept_code
FROM dev_icd10cn.concept_stage b
WHERE COALESCE(a.concept_name, 'x!x') = COALESCE(b.concept_name, 'x!x')
  --AND COALESCE(a.concept_code_icd10cm, 'x!x') = COALESCE(b.concept_code, 'x!x')
  --AND COALESCE(a.source_code_description_synonym, 'x!x') = COALESCE(b.source_code_description_synonym, 'x!x')
--AND COALESCE (source_concept_id, -9876543210) = COALESCE (b.source_concept_id, -9876543210)
;

--cim10 insertion -- not inserted. needs source review
INSERT INTO dev_icd10.icd_cde
(concept_name,
 concept_code_cim10
 --target_concept_id,
 --target_concept_name,
 --target_concept_class,
 --target_standard_concept,
 --target_invalid_reason,
 --target_domain_id,
 --target_vocabulary_id
)
SELECT DISTINCT
concept_name,
concept_code
--,
--target_concept_id,
--target_concept_name,
--target_concept_class,
--target_standard_concept,
--target_invalid_reason,
--target_domain_id,
--target_vocabulary_id
FROM dev_cim10.concept_stage
WHERE (
       --COALESCE(concept_code, 'x!x'),
       COALESCE(concept_name, 'x!x')
       --COALESCE(source_code_description_synonym, 'x!x')
          --,COALESCE (source_concept_id, -9876543210)
          )
          NOT IN (
          SELECT
                 --COALESCE(concept_code, 'x!x'),
                 COALESCE(concept_name, 'x!x')
                 --COALESCE(source_code_description_synonym, 'x!x')
                 --,COALESCE (source_concept_id, -9876543210)
          FROM dev_icd10.icd_cde
      )
AND concept_name !~* 'Invalid'
order by concept_code, concept_name;

--insert concept_codes for the concepts already presented in CDE
UPDATE dev_icd10.icd_cde a
SET concept_code_cim10 --specify the exact customer
        = b.concept_code
FROM dev_cim10.concept_stage b
WHERE COALESCE(a.concept_name, 'x!x') = COALESCE(b.concept_name, 'x!x')
  --AND COALESCE(a.concept_code_icd10cm, 'x!x') = COALESCE(b.concept_code, 'x!x')
  --AND COALESCE(a.source_code_description_synonym, 'x!x') = COALESCE(b.source_code_description_synonym, 'x!x')
--AND COALESCE (source_concept_id, -9876543210) = COALESCE (b.source_concept_id, -9876543210)
;

SELECT * FROM dev_icd10.icd_cde
order by  concept_name, concept_code_icd10
;

SELECT * FROM dev_cim10.concept_stage;
