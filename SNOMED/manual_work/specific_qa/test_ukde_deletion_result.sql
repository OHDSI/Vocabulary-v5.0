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
-- 2. Get counts of old SNOMED concepts transferred to future release if dm+d
-- (in disregard of casuality principles, breaks thermodynamics and entropy)
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
;
-- 3. Get counts of external relationships
SELECT
    v.invalid_reason IS NULL AS was_valid,
    count(1) AS cnt,
    c.domain_id,
    m.concept_id_1 IS NOT NULL AS mapped,
    cm.vocabulary_id AS mapped_to_voc,
    m2.concept_id_1 IS NOT NULL AS replaced,
    cm2.vocabulary_id AS replaced_by_voc,
    m.concept_id_2 = m2.concept_id_2 AS same_target
FROM concept c
JOIN retired_concepts r USING (concept_id)
join devv5.concept v USING (concept_id)
LEFT JOIN concept_relationship m ON
        c.concept_id = m.concept_id_1
    AND m.relationship_id = 'Maps to'
    AND m.invalid_reason IS NULL
LEFT JOIN concept cm ON
        m.concept_id_2 = cm.concept_id
LEFT JOIN concept_relationship m2 ON
        c.concept_id = m2.concept_id_1
    AND m2.relationship_id = 'Concept replaced by'
    AND m2.invalid_reason IS NULL
LEFT JOIN concept cm2 ON
        m2.concept_id_2 = cm2.concept_id
GROUP BY (
    v.invalid_reason IS NULL,
    c.domain_id,
    m.concept_id_1 IS NOT NULL,
    m2.concept_id_1 IS NOT NULL,
    m.concept_id_2 = m2.concept_id_2,
    cm.vocabulary_id,
    cm2.vocabulary_id
)
ORDER BY 1 DESC, 3, 2 DESC
;
-- 4. Make sure manual mappings for retired concepts still exist (covers Route
-- reassignment)
SELECT
    c.domain_id,
    c.concept_class_id,
    t.concept_id_1 IS NOT NULL as mapped_ok
FROM retired_concepts r
JOIN devv5.concept c ON -- for concept_code
    r.concept_id = c.concept_id
JOIN concept_relationship_manual m ON
        m.concept_code_1 = c.concept_code
    AND m.relationship_id IN ('Maps to', 'Concept replaced by')
    AND m.vocabulary_id_1 = 'SNOMED'
JOIN concept s ON
        m.concept_code_2 = s.concept_code
    AND m.vocabulary_id_2 = s.vocabulary_id
LEFT JOIN concept_relationship t ON
        m.relationship_id = t.relationship_id
    AND c.concept_id = t.concept_id_1
    AND s.concept_id = t.concept_id_2
GROUP BY (
    c.domain_id,
    c.concept_class_id,
    t.concept_id_1 IS NOT NULL
)
;
-- 5. Make sure dm+d and Gemscript concepts that were mapped to retired SNOMED
-- concepts have updated mappings (presumably to dm+d)
SELECT
    count(1) AS cnt,
    c1.vocabulary_id AS source_vocab,
    'SNOMED' AS old_target_vocab, -- for presentation
    c2.vocabulary_id AS new_target_vocab,
    c1.invalid_reason AS old_invalid_reason,
    s.standard_concept AS new_standard_status,
    s.invalid_reason AS new_invalid_reason
FROM retired_concepts r
-- Was
JOIN devv5.concept_relationship c ON
        r.concept_id = c.concept_id_2
    AND c.relationship_id = 'Maps to'
    AND c.invalid_reason IS NULL
JOIN devv5.concept c1 ON
        c.concept_id_1 = c1.concept_id
    AND c1.vocabulary_id IN ('dm+d', 'Gemscript')
-- Now
LEFT JOIN concept_relationship t ON
        t.concept_id_1 = c1.concept_id
    AND t.relationship_id = 'Maps to'
    AND t.invalid_reason IS NULL
LEFT JOIN concept c2 ON
        t.concept_id_2 = c2.concept_id
-- Concept attributes
JOIN concept s ON
    c.concept_id_1 = s.concept_id
GROUP BY (
    c1.vocabulary_id,
    c2.vocabulary_id,
    s.standard_concept,
    s.invalid_reason,
    c1.invalid_reason
)
;
-- 6. Look at surviving concepts (expect only Routes):
WITH last_non_uk_active AS (
    SELECT
        c.id,
        first_value(c.active) OVER
            (PARTITION BY c.id ORDER BY effectivetime DESC) AS active
    FROM sources.sct2_concept_full_merged c
    WHERE moduleid NOT IN (
           999000011000001104, --UK Drug extension
           999000021000001108  --UK Drug extension reference set module
        )
),
killed_by_intl AS (
    SELECT id
    FROM last_non_uk_active
    WHERE active = 0
),
current_module AS (
    SELECT
        c.id,
        first_value(moduleid) OVER
            (PARTITION BY c.id ORDER BY effectivetime DESC) AS moduleid
    FROM sources.sct2_concept_full_merged c
)
SELECT DISTINCT
    c.domain_id,
    c.concept_name LIKE '% (retired module, do not use)' AS concept_name_mangled,
    count(1) AS surviving_count
FROM concept c
JOIN current_module cm ON
        c.concept_code = cm.id :: text
    AND cm.moduleid IN (
        999000011000001104, --UK Drug extension
        999000021000001108  --UK Drug extension reference set module
    )
    AND c.vocabulary_id = 'SNOMED'
--Not killed by international release
--Concepts here are expected to be "recovered" by their original
--module and deprecated normally.
LEFT JOIN killed_by_intl k ON
    k.id :: text = c.concept_code
WHERE
    k.id IS NULL
GROUP BY 1, 2
;
-- 7. Look at remaining active relationships for fully mangled concepts:
SELECT
    r.relationship_id,
    c2.vocabulary_id as target_vocab,
    c2.domain_id as target_domain,
    count(1) as cnt
FROM concept c
JOIN concept_relationship r ON
        c.concept_id = r.concept_id_1
    AND r.invalid_reason IS NULL
JOIN concept c2 ON
    r.concept_id_2 = c2.concept_id
WHERE
        c.vocabulary_id = 'SNOMED'
    AND length(c.concept_code) = 36 -- UUID
GROUP BY 1, 2, 3
;
-- 8. Evaluate number of UKDE concepts that end up without any active 'Maps to'
-- or CRB relationships
SELECT  --Expect around 4k counts -- metadata concepts
    count(1) AS cnt,
    c.domain_id,
    c.concept_class_id,
    c.invalid_reason,
    x.invalid_reason
FROM concept c
JOIN devv5.concept x ON
    x.concept_id = c.concept_id
LEFT JOIN concept_relationship r ON
        c.concept_id = r.concept_id_1
    AND r.invalid_reason IS NULL
    AND r.relationship_id IN ('Maps to', 'Concept replaced by')
WHERE
        length(c.concept_code) = 36 -- UUID
    AND c.vocabulary_id = 'SNOMED'
    AND r.concept_id_1 IS NULL
GROUP BY 2, 3, 4, 5
ORDER BY 5, 1 DESC
;
