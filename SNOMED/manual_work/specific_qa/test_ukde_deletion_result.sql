--1. Get counts of SNOMED concepts affected
SELECT
    count(1) as cnt,
    concept_name LIKE '% (retired%' AS name_preserved,
    concept_name LIKE 'Concept belonged to %' AS name_replaced,
    length(concept_code)=36 AS code_is_uuid,
    concept_class_id,
    domain_id,
    invalid_reason,
    standard_concept
FROM retired_concepts r
NATURAL JOIN concept c
GROUP BY (
    concept_name LIKE '% (retired%',
    concept_name LIKE 'Concept belonged to %',
    length(concept_code)=36,
    concept_class_id,
    domain_id,
    invalid_reason,
    standard_concept
)
ORDER BY 3,1 DESC
;
-- 2. Get counts of SNOMED concepts transferred
SELECT
    count(1) as cnt,
    c.concept_class_id,
    c.domain_id,
    c.invalid_reason
FROM concept c
JOIN devv5.concept c2 ON
        c.concept_id = c2.concept_id
    AND c.vocabulary_id = 'dm+d'
    AND c2.vocabulary_id = 'SNOMED'
GROUP BY
    c.concept_class_id,
    c.domain_id,
    c.invalid_reason