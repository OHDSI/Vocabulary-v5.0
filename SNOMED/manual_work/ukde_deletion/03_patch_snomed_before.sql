/*
 * Apply this script to a clean schema to get stage tables that could be applied
 * as a patch before running SNOMED's load_stage.sql.
 */

/*
    Contents:
    1. Deletion of *_manual entries for affected concepts
    2. Route manual mapping
 */
--0. Set up manual tables and clean stage tables
TRUNCATE concept_relationship_stage;
TRUNCATE concept_synonym_stage;
TRUNCATE concept_stage;
TRUNCATE concept_relationship_manual;
TRUNCATE concept_synonym_manual;
TRUNCATE concept_manual;

INSERT INTO concept_manual
SELECT *
FROM dev_snomed.concept_manual;
INSERT INTO concept_synonym_manual
SELECT *
FROM dev_snomed.concept_synonym_manual;
INSERT INTO concept_relationship_manual
SELECT *
FROM dev_snomed.concept_relationship_manual;
--1.
--1.1. Table of retired concepts
DROP TABLE IF EXISTS retired_concepts CASCADE;
CREATE TABLE retired_concepts AS
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
    c.concept_id
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
ALTER TABLE retired_concepts ADD PRIMARY KEY (concept_id);
ALTER TABLE retired_concepts ADD FOREIGN KEY (concept_id)
    REFERENCES concept (concept_id);
ANALYSE retired_concepts;
--1.2. Delete concept_manual entries
/*EMPTY*/
DELETE FROM concept_manual m
WHERE
    EXISTS(
        SELECT 1
        FROM concept c
        JOIN retired_concepts rc ON
            rc.concept_id = c.concept_id
        WHERE
                c.concept_code = m.concept_code
            AND c.vocabulary_id = m.vocabulary_id
    )
;
--1.3. Update concept_relationship_manual entries
UPDATE concept_relationship_manual m
SET
    concept_code_2 = '704098003'
WHERE
        concept_code_2 = '71831000001102'
    AND vocabulary_id_2 = 'SNOMED'
;
DELETE FROM concept_relationship_manual m
WHERE
    EXISTS(
        SELECT 1
        FROM concept c
        JOIN retired_concepts rc ON
            rc.concept_id = c.concept_id
        WHERE
            c.concept_code = m.concept_code_2
            AND c.vocabulary_id = m.vocabulary_id_2
    )
;
--1.4. Delete concept_relationship_manual entries that affect
-- concepts "stolen" by dm+d
DELETE FROM concept_relationship_manual m
WHERE
    EXISTS (
        SELECT 1
        FROM concept c
        LEFT JOIN concept c2 ON
            c2.concept_code = m.concept_code_2
            AND c2.vocabulary_id = m.vocabulary_id_2
        WHERE
                c.concept_code = m.concept_code_2
            AND c.vocabulary_id = 'dm+d'
            AND m.vocabulary_id_2 = 'SNOMED'
            AND c2.concept_id IS NULL
    )
;
--1.5. Update concept_synonym_manual entries
/*EMPTY*/
DELETE FROM concept_synonym_manual m
WHERE
    EXISTS (
        SELECT 1
        FROM concept c
        WHERE
            c.concept_code = m.synonym_concept_code
        AND c.vocabulary_id = m.synonym_vocabulary_id
        AND c.concept_id IN (
            SELECT concept_id
            FROM retired_concepts
        )
    )
;
