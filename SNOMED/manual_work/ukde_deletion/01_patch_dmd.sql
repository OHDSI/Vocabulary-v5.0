/*
 * Apply this script to a clean* schema to get stage tables that could be
 applied as a patch before running SNOMED's load_stage.sql.

 * -- vmps, amps, ampps etc. must be created from fresh sources! Execute
 dmd/load_stage.sql up until line #510.
 */

--1. Create views of rows to be affected
--1.1. Create view of manual mappings missing from dm+d
DROP VIEW IF EXISTS dmd_missing_mappings_vacc;
CREATE OR REPLACE VIEW dmd_missing_mappings_vacc AS
SELECT
    cm1.concept_code_1,
    cm1.concept_code_2,
    cm1.relationship_id,
    cm1.vocabulary_id_2,
    cm1.invalid_reason
FROM dev_snomed.concept_relationship_manual cm1
JOIN devv5.concept cd ON
    cd.vocabulary_id = 'dm+d' AND
    cd.concept_code = cm1.concept_code_1
LEFT JOIN dev_dmd.concept_relationship_manual cm2 ON
-- We are only interested in mappings that are:
--  1. From the same concept code
--  2. Active
-- Actual mapping target is unimportant, SNOMED always
-- loses in this case.
        cm2.concept_code_1 = cm1.concept_code_1
    AND cm2.vocabulary_id_1 = 'dm+d'
    AND cm2.relationship_id = 'Maps to'
    AND cm2.invalid_reason IS NULL
WHERE
        cm1.vocabulary_id_1 = 'SNOMED'
    AND cm1.vocabulary_id_2 != 'SNOMED'
    AND cm1.relationship_id = 'Maps to'
    AND cm2.concept_code_1 IS NULL
    AND cm1.invalid_reason IS NULL
;
INSERT INTO concept_relationship_manual (
    concept_code_1,
    concept_code_2,
    vocabulary_id_1,
    vocabulary_id_2,
    relationship_id,
    valid_start_date,
    valid_end_date
)
SELECT
    dv.concept_code_1,
    dv.concept_code_2,
    'dm+d',
    dv.vocabulary_id_2,
    dv.relationship_id,
    to_date('01-11-2023', 'DD-MM-YYYY'),
    to_date('31-12-2099', 'DD-MM-YYYY')
FROM dmd_missing_mappings_vacc dv
;
DROP VIEW dmd_missing_mappings_vacc;

--1.2. Create table of concept codes (Devices) that currently map to SNOMED
DROP TABLE IF EXISTS dmd_mapped_to_snomed;
CREATE TABLE dmd_mapped_to_snomed AS
SELECT
    c.concept_id,
    c2.concept_id AS snomed_concept_id,
    c2.domain_id AS snomed_domain_id,
    c.invalid_reason AS invalid_reason,
    c3.concept_id AS replacement_concept_id,
    c3.vocabulary_id AS replacement_vocabulary_id
FROM devv5.concept c
JOIN devv5.concept_relationship r ON
        c.concept_id = r.concept_id_1
    AND r.relationship_id = 'Maps to'
    AND c.vocabulary_id = 'dm+d'
    AND r.invalid_reason IS NULL
JOIN devv5.concept c2 ON
        c2.concept_id = r.concept_id_2
    AND c2.vocabulary_id = 'SNOMED'
-- For deprecated concepts, check if replacement exists
LEFT JOIN devv5.concept_relationship r2 ON
        c.concept_id = r2.concept_id_1
    AND c.invalid_reason IS NOT NULL
    AND r2.relationship_id = 'Concept replaced by'
-- Also check for replacement in source dm+d VMPs table, if
-- one not provided explicitly
LEFT JOIN dev_dmd.vmps v ON
        r2.concept_id_2 is NULL
    AND v.vpidprev = c.concept_code

LEFT JOIN devv5.concept c3 ON
        c3.concept_id = r2.concept_id_2 OR
        (c3.concept_code = v.vpid AND c3.vocabulary_id = 'dm+d')
;
--2. Fill the stage tables
--2.1. Prepare stage tables
TRUNCATE concept_stage;
TRUNCATE concept_relationship_stage;
TRUNCATE concept_synonym_stage;

--2.2. Populate the concept_stage with affected concepts only
INSERT INTO dev_dmd.concept_stage (
    concept_id,
    concept_name,
    domain_id,
    vocabulary_id,
    concept_class_id,
    standard_concept,
    concept_code,
    valid_start_date,
    valid_end_date,
    invalid_reason
)
SELECT
    d.concept_id,
    c.concept_name,
    d.snomed_domain_id AS domain_id, -- Use mapping target domain
    'dm+d' AS vocabulary_id,
    c.concept_class_id,
    CASE WHEN d.invalid_reason IS NULL THEN 'S' END AS standard_concept,
    c.concept_code,
    c.valid_start_date,
    to_date('31-12-2099', 'DD-MM-YYYY') AS valid_end_date,
    d.invalid_reason
FROM dmd_mapped_to_snomed d
JOIN concept c USING (concept_id)
;
--2.3. Populate the concept_relationship_stage with new correct mappings only
INSERT INTO concept_relationship_stage (
    concept_code_1,
    concept_code_2,
    vocabulary_id_1,
    vocabulary_id_2,
    relationship_id,
    valid_start_date,
    valid_end_date
)
SELECT DISTINCT
    cs.concept_code AS concept_code_1,
    CASE
        WHEN cs.standard_concept = 'S' THEN cs.concept_code
        ELSE t.concept_code
    END AS concept_code_2,
    'dm+d' AS vocabulary_id_1,
    CASE
        WHEN cs.standard_concept = 'S' THEN 'dm+d'
        ELSE t.vocabulary_id
    END AS vocabulary_id_2,
    'Maps to' AS relationship_id,
    to_date('01-11-2023', 'DD-MM-YYYY') AS valid_start_date,
    to_date('31-12-2099', 'DD-MM-YYYY') AS valid_end_date
FROM concept_stage cs
JOIN dmd_mapped_to_snomed dmts ON
    cs.concept_id = dmts.concept_id
-- Join to replacement concept does it map anywhere?
LEFT JOIN devv5.concept r ON
    r.concept_id = dmts.replacement_concept_id
LEFT JOIN devv5.concept_relationship r2 ON
        r.concept_id = r2.concept_id_1
    AND r2.relationship_id = 'Maps to'
    AND r2.invalid_reason IS NULL
LEFT JOIN devv5.concept t ON
    t.concept_id = r2.concept_id_2
WHERE (
    cs.standard_concept = 'S' OR
    t.concept_id IS NOT NULL
)
;
--2.4. Explicitly deprecate old existing mappings
INSERT INTO concept_relationship_stage (
    concept_code_1,
    concept_code_2,
    vocabulary_id_1,
    vocabulary_id_2,
    relationship_id,
    valid_start_date,
    valid_end_date,
    invalid_reason
)
SELECT
    c.concept_code AS concept_code_1,
    t.concept_code AS concept_code_2,
    'dm+d' AS vocabulary_id_1,
    t.vocabulary_id AS vocabulary_id_2,
    'Maps to' AS relationship_id,
    to_date('01-11-2023', 'DD-MM-YYYY') AS valid_start_date,
    to_date('31-12-2099', 'DD-MM-YYYY') AS valid_end_date,
    'D' AS invalid_reason
FROM dmd_mapped_to_snomed dm
JOIN devv5.concept c USING (concept_id)
JOIN devv5.concept_relationship r ON
        r.concept_id_1 = dm.concept_id
    AND r.relationship_id = 'Maps to'
    AND r.invalid_reason IS NULL
JOIN devv5.concept t ON
    t.concept_id = r.concept_id_2
--Unless somehow reinforced by a new mapping
LEFT JOIN concept_relationship_stage crs ON
        crs.concept_code_1 = c.concept_code
    AND crs.concept_code_2 = t.concept_code
    AND crs.vocabulary_id_1 = 'dm+d'
    AND crs.vocabulary_id_2 = t.vocabulary_id
    AND crs.relationship_id = 'Maps to'
WHERE crs.concept_code_1 IS NULL
--This should make a 0 rows insert, unless concept_relationship_manual is
--affecting this
;

--3. "Steal" SNOMED concepts that will appear in the new release through
-- concept table surgery
--3.1. Create a table of SNOMED concepts that will be affected
DROP TABLE IF EXISTS snomed_concepts_to_steal;
CREATE TABLE snomed_concepts_to_steal AS
--Marginal case: what if the concept is stolen by UK?
--If this is the case, it should be excluded from transfer, as
--SNOMED run will restore it's original module
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
FROM devv5.concept c
JOIN current_module cm ON
        c.concept_code = cm.id :: text
    AND cm.moduleid IN (
        999000011000001104, --UK Drug extension
        999000021000001108  --UK Drug extension reference set module
    )
    AND c.vocabulary_id = 'SNOMED'
JOIN (
    SELECT vtmid as id from vtms
        UNION ALL
    SELECT isid FROM ingredient_substances
        UNION ALL
    SELECT vpid FROM vmps
        UNION ALL
    SELECT apid FROM amps
        UNION ALL
    SELECT vppid FROM vmpps
        UNION ALL
    SELECT appid FROM ampps
) dm_sources ON
        c.concept_code = dm_sources.id
    AND c.vocabulary_id = 'SNOMED'
--Not present in current release of dm+d
LEFT JOIN devv5.concept d ON
        d.concept_code = c.concept_code
    AND d.vocabulary_id = 'dm+d'
--Not killed by international release
LEFT JOIN killed_by_intl k ON
    k.id = c.concept_code
WHERE
        d.concept_id IS NULL
    AND c.invalid_reason IS NULL
;
--3.2. Deprecate all existing relationships -- unless it is an external Maps to
INSERT INTO concept_relationship_stage (
    concept_code_1,
    concept_code_2,
    vocabulary_id_1,
    vocabulary_id_2,
    relationship_id,
    valid_start_date,
    valid_end_date,
    invalid_reason
)
SELECT
    c.concept_code AS concept_code_1,
    c2.concept_code AS concept_code_2,
    --'SNOMED' AS vocabulary_id_1,
    'dm+d' AS vocabulary_id_1,
    c2.vocabulary_id AS vocabulary_id_2,
    r.relationship_id AS relationship_id,
    r.valid_start_date AS valid_start_date,
    to_date('31-10-2023', 'DD-MM-YYYY') AS valid_end_date,
    'D' AS invalid_reason
FROM devv5.concept_relationship r
JOIN devv5.concept c ON
    c.concept_id = r.concept_id_1
JOIN devv5.concept c2 ON
    c2.concept_id = r.concept_id_2
JOIN snomed_concepts_to_steal s ON
    s.concept_id = c.concept_id
LEFT JOIN snomed_concepts_to_steal s2 ON
    s2.concept_id = c2.concept_id
WHERE
        NOT (
                r.relationship_id = 'Maps to'
            AND s2.concept_id IS NOT NULL
        )
    AND r.invalid_reason IS NULL
;
--TODO: Find a place for this step with Timur V.
--3.3. Steal the concepts!
UPDATE concept c SET
    vocabulary_id = 'dm+d',
    invalid_reason = 'D',
    standard_concept = NULL,
    valid_end_date = to_date('31-10-2023', 'DD-MM-YYYY'),
    valid_start_date = CASE
        WHEN valid_start_date >= to_date('31-10-2023', 'DD-MM-YYYY')
            THEN to_date('01-01-1970', 'DD-MM-YYYY')
        ELSE valid_start_date
    END
FROM snomed_concepts_to_steal s
WHERE
        c.concept_id = s.concept_id
;
DROP TABLE snomed_concepts_to_steal;
