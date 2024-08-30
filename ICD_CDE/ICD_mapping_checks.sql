CREATE TABLE icd_mappings_backup as SELECT * FROM icd_mappings;

--Create table with ICD10, ICD10CM, ICD9CM
TRUNCATE TABLE icd_mappings;
DROP TABLE icd_mappings;
CREATE TABLE icd_mappings (
    source_code varchar,
    source_code_description varchar,
    source_vocabulary_id varchar,
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
       'ICD10' as source_vocabulary_id,
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
FROM dev_icd10cn.concept_relationship_stage crs
LEFT JOIN concept c ON crs.concept_code_2 = c.concept_code
                           AND crs.vocabulary_id_2 = c.vocabulary_id
--AND c.standard_concept = 'S'
--AND c.invalid_reason is null
LEFT JOIN concept c2 ON crs.concept_code_1 = c2.concept_code
AND crs.vocabulary_id_1 = c2.vocabulary_id
WHERE crs.relationship_id in ('Maps to', 'Maps to value')
AND crs.invalid_reason is null)

UNION ALL

--ICD10CM mappings
SELECT DISTINCT
       crs.concept_code_1 as source_code,
       c2.concept_name as source_code_description,
       'ICD10CM' as source_vocabulary_id,
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
                           AND crs.vocabulary_id_2 = c.vocabulary_id
--AND c.standard_concept = 'S'
--AND c.invalid_reason is null
LEFT JOIN concept c2 ON crs.concept_code_1 = c2.concept_code
AND crs.vocabulary_id_1 = 'ICD10CM'
WHERE crs.relationship_id in ('Maps to', 'Maps to value')
AND crs.invalid_reason is null

UNION ALL

--ICD9CM mappings
SELECT DISTINCT
       crs.concept_code_1 as source_code,
       c2.concept_name as source_code_description,
       'ICD9CM' as source_vocabulary_id,
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
                           AND crs.vocabulary_id_2 = c.vocabulary_id
--AND c.standard_concept = 'S'
--AND c.invalid_reason is null
LEFT JOIN concept c2 ON crs.concept_code_1 = c2.concept_code
AND crs.vocabulary_id_1 = 'ICD9CM'
WHERE crs.relationship_id in ('Maps to', 'Maps to value')
    AND crs.invalid_reason is null);

DROP TABLE to_check;
TRUNCATE TABLE to_check;
CREATE TABLE to_check
(source_code varchar,
    source_code_description varchar,
    source_vocabulary_id varchar,
    relationship_id varchar,
    target_concept_id varchar,
    target_concept_code varchar,
    target_concept_name varchar,
    target_concept_class_id varchar,
    target_standard_concept varchar,
    target_invalid_reason varchar,
    target_domain_id varchar,
    target_vocabulary_id varchar,
    target_valid_start_date date,
    target_valid_end_date date);

INSERT INTO to_check
--'Maps to' mapping to abnormal domains/classes
(SELECT DISTINCT
       source_code,
       source_code_description,
       source_vocabulary_id,
       relationship_id,
       target_concept_id,
       target_concept_code,
       target_concept_name,
       target_concept_class_id,
       target_standard_concept,
       target_invalid_reason,
       target_vocabulary_id,
       target_valid_start_date,
       target_valid_end_date
FROM icd_mappings t
LEFT JOIN concept c
    ON t.target_concept_id = c.concept_id
AND t.target_vocabulary_id = c.vocabulary_id
WHERE (t.source_code, t.source_vocabulary_id) in (
    SELECT a.source_code, a.source_vocabulary_id
    FROM icd_mappings a
    WHERE (EXISTS(   SELECT 1
                    FROM icd_mappings b
                    LEFT JOIN concept c ON b.target_concept_id = c.concept_id
                    AND b.target_vocabulary_id = c.vocabulary_id
                    WHERE a.source_code = b.source_code
                        AND a.source_vocabulary_id = b.source_vocabulary_id
                        AND c.domain_id not in ('Observation', 'Procedure', 'Condition', 'Drug', 'Measurement', 'Device', 'Route', 'Visit') --add Device if needed
                        AND b.relationship_id !~* 'value|qualifier|unit|modifier'
                        AND b.target_concept_id NOT IN (0) --to exclude good concepts
                )
    OR
          EXISTS(   SELECT 1
                    FROM icd_mappings bb
                    LEFT JOIN concept cc ON bb.target_concept_id = cc.concept_id
                    AND bb.target_vocabulary_id = cc.vocabulary_id
                    WHERE a.source_code = bb.source_code
                        AND a.source_vocabulary_id = bb.source_vocabulary_id
                        AND cc.concept_class_id IN ('Organism', 'Attribute', 'Answer', 'Qualifier Value')
                        AND bb.relationship_id !~* 'value|qualifier|unit|modifier'
                        AND bb.target_concept_id NOT IN (0) --to exclude good concepts
                ))
    ));

--check value ambiguous mapping (2 Observation/Measurement for value)
SELECT DISTINCT
                 source_code,
       source_code_description,
       source_vocabulary_id,
       relationship_id,
       target_concept_id,
       target_concept_code,
       target_concept_name,
       target_concept_class_id,
       target_standard_concept,
       target_invalid_reason,
       target_vocabulary_id,
       target_valid_start_date,
       target_valid_end_date
FROM icd_mappings t
LEFT JOIN concept c
    ON t.target_concept_id = c.concept_id
WHERE (t.source_code, t.source_vocabulary_id) in (
    SELECT a.source_code, a.source_vocabulary_id
    FROM icd_mappings a
    WHERE EXISTS(   SELECT 1
                    FROM icd_mappings b
                    LEFT JOIN concept c
                        ON c.concept_id = b.target_concept_id
                    WHERE a.source_code = b.source_code
                      AND a.source_vocabulary_id = b.source_vocabulary_id
                      AND c.domain_id in ('Observation', 'Measurement')
                      AND (b.relationship_id = 'Maps to')
                    GROUP BY b.source_code
                    HAVING count (*) > 1
              )

    AND EXISTS(     SELECT 1
                    FROM icd_mappings c
                    WHERE a.source_code = c.source_code
                      AND a.source_vocabulary_id = c.source_vocabulary_id
                      AND (c.relationship_id = 'Maps to value')
            ))
ORDER BY source_vocabulary_id,
         source_code,
         source_code_description,
         relationship_id,
         target_concept_id
;

--check value ambiguous mapping (2 values for 1 Observation/Measurement)
SELECT DISTINCT
                 source_code,
       source_code_description,
       source_vocabulary_id,
       relationship_id,
       target_concept_id,
       target_concept_code,
       target_concept_name,
       target_concept_class_id,
       target_standard_concept,
       target_invalid_reason,
       target_vocabulary_id,
       target_valid_start_date,
       target_valid_end_date
FROM icd_mappings t
LEFT JOIN concept c
    ON t.target_concept_id = c.concept_id
WHERE (t.source_code, t.source_vocabulary_id) in (
    SELECT a.source_code, a.source_vocabulary_id
    FROM icd_mappings a
    WHERE EXISTS(   SELECT 1
                    FROM icd_mappings b
                    LEFT JOIN concept c
                        ON c.concept_id = b.target_concept_id
                    WHERE a.source_code = b.source_code
                      AND a.source_vocabulary_id = b.source_vocabulary_id
                      AND c.domain_id in ('Observation', 'Measurement')
                      AND (b.relationship_id = 'Maps to')

              )

    AND EXISTS(     SELECT 1
                    FROM icd_mappings c
                    WHERE a.source_code = c.source_code
                      AND a.source_vocabulary_id = c.source_vocabulary_id
                      AND (c.relationship_id = 'Maps to value')
                    GROUP BY c.source_code
                    HAVING count (*) > 1
            ))
ORDER BY source_vocabulary_id,
         source_code,
         source_code_description,
         relationship_id,
         target_concept_id;

INSERT INTO to_check (
--check value without corresponded Observation/Measurement
SELECT DISTINCT
                 source_code,
       source_code_description,
       source_vocabulary_id,
       relationship_id,
       target_concept_id,
       target_concept_code,
       target_concept_name,
       target_concept_class_id,
       target_standard_concept,
       target_invalid_reason,
       target_vocabulary_id,
       target_valid_start_date,
       target_valid_end_date
FROM icd_mappings t
WHERE (source_code, source_vocabulary_id) in (
    SELECT a.source_code, a.source_vocabulary_id
    FROM icd_mappings a
    WHERE NOT EXISTS(   SELECT 1
                        FROM icd_mappings b
                        LEFT JOIN concept c
                            ON c.concept_id = b.target_concept_id
                        WHERE a.source_code = b.source_code
                          AND c.domain_id in ('Observation', 'Measurement')
                          AND (b.relationship_id = 'Maps to')
              )

    AND EXISTS(   SELECT 1
                    FROM icd_mappings c
                    WHERE a.source_code = c.source_code
                      AND (c.relationship_id = 'Maps to value')
            )
              )
ORDER BY source_vocabulary_id,
         source_code,
         source_code_description,
         relationship_id,
         target_concept_id)
;

--maps to value without maps to mapping (by source_code)
SELECT DISTINCT
                 source_code,
       source_code_description,
       source_vocabulary_id,
       relationship_id,
       target_concept_id,
       target_concept_code,
       target_concept_name,
       target_concept_class_id,
       target_standard_concept,
       target_invalid_reason,
       target_vocabulary_id,
       target_valid_start_date,
       target_valid_end_date
FROM icd_mappings m1
WHERE EXISTS(   SELECT 1
                FROM icd_mappings m2
                WHERE m1.source_code = m2.source_code
                    AND m1.source_vocabulary_id = m2.source_vocabulary_id
                    AND m2.relationship_id = 'Maps to value')

AND NOT EXISTS( SELECT 1
                FROM icd_mappings m2
                WHERE m1.source_code = m2.source_code
                    AND m1.source_vocabulary_id = m2.source_vocabulary_id
                    AND m2.relationship_id = 'Maps to')

ORDER BY source_vocabulary_id,
         source_code,
         source_code_description,
         relationship_id,
         target_concept_id
;

INSERT INTO to_check (
SELECT source_code,
       source_code_description,
       source_vocabulary_id,
       relationship_id,
       target_concept_id,
       target_concept_code,
       target_concept_name,
       target_concept_class_id,
       target_standard_concept,
       target_invalid_reason,
       target_vocabulary_id,
       target_valid_start_date,
       target_valid_end_date
FROM icd_mappings
WHERE (source_vocabulary_id, source_code) IN
-- 1-to-many mapping to the descendant and its ancestor
(SELECT DISTINCT a.source_vocabulary_id,
       a.source_code
    FROM icd_mappings a
    JOIN icd_mappings b ON a.source_code = b.source_code
        AND a.source_vocabulary_id = b.source_vocabulary_id
    LEFT JOIN devv5.concept_ancestor ca
        ON a.target_concept_id = ca.descendant_concept_id
        AND b.target_concept_id = ca.ancestor_concept_id
WHERE a.target_concept_id != b.target_concept_id
    AND a.relationship_id = 'Maps to'
    AND b.relationship_id = 'Maps to'
    AND ca.descendant_concept_id IS NOT NULL));

SELECT * FROM to_check where source_code not in (SELECT DISTINCT source_code FROM icd_cde_source);
SELECT * FROM icd_cde_source where source_code = '010.03';


--Basic QA
--All concepts from the group have the same mapping:
--! NB devv5, dev_icd10.icd_cde_source are used in the current implementation, correct schemas accordingly
with groups AS 
    (
        SELECT DISTINCT s.source_code, s.source_vocabulary_id, c.concept_id, s.group_id
        FROM dev_icd10.icd_cde_source s 
        JOIN devv5.concept c 
        ON (c.concept_code, c.vocabulary_id) = (s.source_code, s.source_vocabulary_id)
    ),
    
    mapping_groups AS 
    (
        SELECT cr.concept_id_1, g.group_id, 
               array_agg(cr.relationship_id ORDER BY cr.concept_id_2) AS map_rel,
               array_agg(cr.concept_id_2 ORDER BY cr.concept_id_2) AS map_id
        FROM devv5.concept_relationship cr
        JOIN groups g
            ON g.concept_id = cr.concept_id_1 
            AND cr.invalid_reason IS NULL AND cr.relationship_id IN ('Maps to', 'Maps to value')
        GROUP BY cr.concept_id_1, group_id
    )

SELECT concept_id_1, group_id, map_rel, map_id
FROM mapping_groups mg
WHERE EXISTS(
    SELECT 1 FROM mapping_groups mg1 
    WHERE mg.group_id = mg1.group_id
    AND (mg1.map_rel, mg1.map_id) != (mg.map_rel, mg.map_id)
          )

ORDER BY group_id;