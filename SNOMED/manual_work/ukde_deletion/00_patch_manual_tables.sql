--0. Persisting storage for patch the date: will be used to control date of the patch
DROP TABLE IF EXISTS patch_date;
CREATE TABLE patch_date (
    patch_date DATE
);

--1. Manual override of a single concept
INSERT INTO patch_date (patch_date) VALUES (to_date('01-11-2023', 'DD-MM-YYYY'));
UPDATE devv5.base_concept_relationship_manual m
SET
    concept_code_2 = '704098003'
WHERE
    concept_code_2 = '71831000001102'
    AND vocabulary_id_2 = 'SNOMED'
;
DROP TABLE IF EXISTS retired_concepts CASCADE;
CREATE TABLE retired_concepts AS
WITH last_non_uk_active AS (
    SELECT
        c.id,
                first_value(c.active) OVER
            (PARTITION BY c.id ORDER BY effectivetime DESC) AS active
    FROM sources_archive.sct2_concept_full_merged c
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
        FROM sources_archive.sct2_concept_full_merged c
    )
SELECT DISTINCT
    c.concept_id,
    c.concept_code,
    c.vocabulary_id
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
;
--1.2. Delete concept_manual entries
DELETE FROM devv5.base_concept_manual m
WHERE
    EXISTS(
        SELECT 1
        FROM retired_concepts c
        WHERE
                c.concept_code = m.concept_code
            AND c.vocabulary_id = m.vocabulary_id
    )
;
DELETE FROM devv5.base_concept_synonym_manual m
WHERE
    EXISTS (
        SELECT 1
        FROM retired_concepts c
        WHERE
                c.concept_code = m.synonym_concept_code
            AND c.vocabulary_id = m.synonym_vocabulary_id
    )
;
DELETE FROM devv5.base_concept_relationship_manual m
WHERE
    EXISTS (
        SELECT 1
        FROM retired_concepts c
        WHERE
                c.concept_code = m.concept_code_1
            AND c.vocabulary_id = m.vocabulary_id_1
    )
    OR EXISTS (
        SELECT 1
        FROM retired_concepts c
        WHERE
            (c.concept_code, c.vocabulary_id) IN
                (m.concept_code_2, m.vocabulary_id_2)
    )
;
--2. Drop temporary tables
DROP TABLE IF EXISTS retired_concepts CASCADE;
DROP TABLE IF EXISTS patch_date;