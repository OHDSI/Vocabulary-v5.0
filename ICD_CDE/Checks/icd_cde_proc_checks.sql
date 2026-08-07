--1. Check the mapping accuracy in the icd_cde_proc table
--Create table with mappings to check
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
       target_domain_id,
       target_vocabulary_id,
       null as target_valid_start_date,
       null as target_valid_end_date
FROM dev_icd10.icd_cde_proc
);

--'Maps to' mapping to abnormal domains/classes
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
    );

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
WHERE (t.source_code, t.source_vocabulary_id) IN (
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
WHERE (t.source_code, t.source_vocabulary_id) IN (
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
         target_concept_id;

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
         target_concept_id;

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
    AND ca.descendant_concept_id IS NOT NULL);

--2.Check all the community contributions were included
WITH cc as
(SELECT
cc.source_code,
cc.source_code_description,
cc.source_vocabulary_id,
string_agg(cc.relationship_id::VARCHAR, '-' ORDER BY cc.relationship_id, cc.source_code, cc.source_vocabulary_id) as cc_relationship_id,
string_agg (cc.target_concept_code, '-' ORDER BY cc.relationship_id, cc.source_code, cc.source_vocabulary_id) as cc_target_concept_code,
string_agg(cc.target_concept_name, '-' ORDER BY cc.relationship_id, cc.source_code, cc.source_vocabulary_id) as cc_target_concept_name
FROM dev_icd10.icd_community_contribution cc
GROUP BY cc.source_code, cc.source_code_description, cc.source_vocabulary_id),

new_map as (
SELECT
p.source_code,
p.source_code_description,
p.source_vocabulary_id,
string_agg (p.relationship_id::VA, '-' ORDER BY p.relationship_id, p.source_code, p.source_vocabulary_id) as p_relationship_id,
string_agg (p.target_concept_code, '-' ORDER BY p.relationship_id, p.source_code, p.source_vocabulary_id) as p_target_concept_code,
string_agg (p.target_concept_name, '-' ORDER BY p.relationship_id, p.source_code, p.source_vocabulary_id) as p_target_concept_name
FROM dev_icd10.icd_cde_proc p
WHERE (p.source_code, p.source_vocabulary_id) IN (SELECT source_code, source_vocabulary_id FROM dev_icd10.icd_community_contribution)
group by p.source_code, p.source_code_description, p.source_vocabulary_id)

SELECT DISTINCT
a.source_code,
a.source_code_description,
a.source_vocabulary_id,
a.cc_relationship_id,
a.cc_target_concept_code,
a.cc_target_concept_name,
b.p_relationship_id,
b.p_target_concept_code,
b.p_target_concept_name
FROM cc a LEFT JOIN new_map b
    ON a.source_code = b.source_code
    AND a.source_vocabulary_id = b.source_vocabulary_id
WHERE b.p_target_concept_code is null OR b.p_target_concept_code != a.cc_target_concept_code;