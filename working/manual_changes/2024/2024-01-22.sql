-- Script for retirement of existing SNOMED CT United Kingdom Drug Extension content
-- Background: See the [forum post](https://forums.ohdsi.org/t/announcing-the-retirement-of-snomed-ct-uk-drug-extension/20487).

-- Pre-requisites:
--- Note: this deletion supposes use of modified GenericUpdate version that supports pMode specification

--1. Delete concepts that are supposed to be retired, their synonyms and relationships from base_concept_manual, base_concept_synonym_manual and base_concept_relationship_manual respectively (run only in devv5)
--1.0. Persisting storage for patch the date: will be used to control date of the patch
DROP TABLE IF EXISTS patch_date;
CREATE TABLE patch_date (
    patch_date DATE
);

--1.1. Manual override of a single concept
INSERT INTO patch_date (patch_date) VALUES (to_date('01-11-2023', 'DD-MM-YYYY'));
UPDATE devv5.base_concept_relationship_manual m
SET
    concept_code_2 = '704098003'
WHERE
    concept_code_2 = '71831000001102'
    AND vocabulary_id_2 = 'SNOMED'
;
--1.2. Create table retired_concepts
DROP TABLE IF EXISTS retired_concepts CASCADE;
CREATE TABLE retired_concepts AS

WITH last_non_uk_active AS (
    SELECT c.id,
           first_value(c.active) OVER (PARTITION BY c.id ORDER BY effectivetime DESC) AS active
    FROM sources_archive.sct2_concept_full_merged c
    WHERE moduleid NOT IN (
                           999000011000001104, --UK Drug extension
                           999000021000001108)  --UK Drug extension reference set module
),

    killed_by_intl AS (
    SELECT id
    FROM last_non_uk_active
    WHERE active = 0
),

    current_module AS (
	SELECT c.id,
    first_value(moduleid) OVER (PARTITION BY c.id ORDER BY effectivetime DESC) AS moduleid
    FROM sources_archive.sct2_concept_full_merged c
    )

SELECT DISTINCT c.concept_id,
				c.concept_code,
				c.vocabulary_id
FROM concept c
JOIN current_module cm ON c.concept_code = cm.id :: text
            AND cm.moduleid IN (
                                999000011000001104, --UK Drug extension
                                999000021000001108) --UK Drug extension reference set module
            AND c.vocabulary_id = 'SNOMED'
    --Not killed by international release
	--Concepts here are expected to be "recovered" by their original
	--module and deprecated normally.
LEFT JOIN killed_by_intl k ON k.id :: text = c.concept_code
WHERE k.id IS NULL
;

--1.3. Delete concept_manual entries
DELETE FROM devv5.base_concept_manual m
WHERE EXISTS(
			SELECT 1
			FROM retired_concepts c
			WHERE c.concept_code = m.concept_code
				AND c.vocabulary_id = m.vocabulary_id
);

--1.4. Delete concept_synonym_manual entries
DELETE FROM devv5.base_concept_synonym_manual m
WHERE EXISTS (
			SELECT 1
			FROM retired_concepts c
			WHERE c.concept_code = m.synonym_concept_code
				AND c.vocabulary_id = m.synonym_vocabulary_id
)
;

-- 1.5. Delete concept_relationship_manual
DELETE FROM devv5.base_concept_relationship_manual m
WHERE EXISTS (
			SELECT 1
			FROM retired_concepts c
			WHERE c.concept_code = m.concept_code_1
				AND c.vocabulary_id = m.vocabulary_id_1
)
OR EXISTS (
			SELECT 1
			FROM retired_concepts c
			WHERE (c.concept_code, c.vocabulary_id) IN (m.concept_code_2, m.vocabulary_id_2)
);

--1.6. Drop temporary tables
DROP TABLE IF EXISTS retired_concepts CASCADE;
DROP TABLE IF EXISTS patch_date;

-- 2. Run FastRecreateSchema in the working schema

-- 3. Patch release for dm+d
-- 3.0. Preparation
-- 3.0.1. Empty stage tables
TRUNCATE concept_relationship_stage;
TRUNCATE concept_synonym_stage;
TRUNCATE concept_stage;

--3.0.2. Persisting storage for patch the date: will be used to control date of the patch
DROP TABLE IF EXISTS patch_date;
CREATE TABLE patch_date (
    patch_date DATE
);
INSERT INTO patch_date (patch_date) VALUES (to_date('28-01-2022', 'DD-MM-YYYY'));

--3.0.3. Source dm+d tables
--vmps: Virtual Medicinal Product
DROP TABLE IF EXISTS vmps;
CREATE TABLE vmps AS
SELECT devv5.py_unescape(unnest(xpath('/VMP/NM/text()', i.xmlfield))::VARCHAR) nm,
       to_date(unnest(xpath('/VMP/VPIDDT/text()', i.xmlfield))::VARCHAR,'YYYY-MM-DD') VPIDDT,
       unnest(xpath('/VMP/INVALID/text()', i.xmlfield))::VARCHAR INVALID,
       unnest(xpath('/VMP/VPID/text()', i.xmlfield))::VARCHAR VPID,
       unnest(xpath('/VMP/VPIDPREV/text()', i.xmlfield))::VARCHAR VPIDPREV,
       unnest(xpath('/VMP/VTMID/text()', i.xmlfield))::VARCHAR VTMID,
       devv5.py_unescape(unnest(xpath('/VMP/NMPREV/text()', i.xmlfield))::VARCHAR) NMPREV,
       to_date(unnest(xpath('/VMP/NMDT/text()', i.xmlfield))::VARCHAR,'YYYY-MM-DD') NMDT,
       devv5.py_unescape(unnest(xpath('/VMP/ABBREVNM/text()', i.xmlfield))::VARCHAR) ABBREVNM,
       unnest(xpath('/VMP/COMBPRODCD/text()', i.xmlfield))::VARCHAR COMBPRODCD,
       unnest(xpath('/VMP/NON_AVAILDT/text()', i.xmlfield))::VARCHAR NON_AVAILDT,
       unnest(xpath('/VMP/DF_INDCD/text()', i.xmlfield))::VARCHAR DF_INDCD,
       unnest(xpath('/VMP/UDFS/text()', i.xmlfield))::VARCHAR::numeric UDFS,
       unnest(xpath('/VMP/UDFS_UOMCD/text()', i.xmlfield))::VARCHAR UDFS_UOMCD,
       unnest(xpath('/VMP/UNIT_DOSE_UOMCD/text()', i.xmlfield))::VARCHAR UNIT_DOSE_UOMCD,
       unnest(xpath('/VMP/PRES_STATCD/text()', i.xmlfield))::VARCHAR PRES_STATCD
FROM (
         SELECT unnest(xpath('/VIRTUAL_MED_PRODUCTS/VMPS/VMP', i.xmlfield)) xmlfield
         FROM sources.f_vmp2 i
     ) AS i;

UPDATE vmps SET invalid = '0' WHERE invalid IS NULL;

--keep the newest replacement only (*prev)
UPDATE vmps v
SET
    nmprev = NULL,
    vpidprev = NULL
WHERE
    v.vpidprev IS NOT NULL AND
    exists
        (
            SELECT
            FROM vmps u
            WHERE
                    u.vpidprev = v.vpidprev AND
                    v.nmdt < u.nmdt
        )
;

-- 3.1. Create views of rows to be affected
-- 3.1.1. Create view of manual mappings missing from dm+d
DROP TABLE IF EXISTS dmd_missing_mappings_vacc;
CREATE TABLE dmd_missing_mappings_vacc AS
SELECT
    cm1.concept_code_1,
    cm1.concept_code_2,
    cm1.relationship_id,
    cm1.vocabulary_id_2,
    cm1.invalid_reason
FROM dev_snomed.concept_relationship_manual cm1
JOIN concept cd ON
    cd.vocabulary_id = 'dm+d' AND
    cd.concept_code = cm1.concept_code_1
LEFT JOIN concept_relationship_manual cm2 ON
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
    p.patch_date,
    to_date('31-12-2099', 'DD-MM-YYYY')
FROM dmd_missing_mappings_vacc dv
JOIN patch_date p ON TRUE
;
DROP TABLE dmd_missing_mappings_vacc;

-- 3.1.2. Create table of concept codes (Devices) that currently map to SNOMED
DROP TABLE IF EXISTS dmd_mapped_to_snomed;
CREATE TABLE dmd_mapped_to_snomed AS
SELECT
    c.concept_id,
    c2.concept_id AS snomed_concept_id,
    c2.domain_id AS snomed_domain_id,
    c.invalid_reason AS invalid_reason,
    c3.concept_id AS replacement_concept_id,
    c3.vocabulary_id AS replacement_vocabulary_id
FROM concept c
JOIN concept_relationship r ON
        c.concept_id = r.concept_id_1
    AND r.relationship_id = 'Maps to'
    AND c.vocabulary_id = 'dm+d'
    AND r.invalid_reason IS NULL
JOIN concept c2 ON
        c2.concept_id = r.concept_id_2
    AND c2.vocabulary_id = 'SNOMED'
-- For deprecated concepts, check if replacement exists
LEFT JOIN concept_relationship r2 ON
        c.concept_id = r2.concept_id_1
    AND c.invalid_reason IS NOT NULL
    AND r2.relationship_id = 'Concept replaced by'
-- Also check for replacement in source dm+d VMPs table, if
-- one not provided explicitly
LEFT JOIN vmps v ON
        r2.concept_id_2 is NULL
    AND v.vpidprev = c.concept_code

LEFT JOIN concept c3 ON
        c3.concept_id = r2.concept_id_2 OR
        (c3.concept_code = v.vpid AND c3.vocabulary_id = 'dm+d')
;
-- 3.2. Fill the stage tables
-- 3.2.1. Prepare stage tables
TRUNCATE concept_stage;
TRUNCATE concept_relationship_stage;
TRUNCATE concept_synonym_stage;

-- 3.2.2. Populate the concept_stage with affected concepts only
INSERT INTO concept_stage (
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
    CASE
        WHEN d.invalid_reason IS NULL THEN to_date('31-12-2099', 'DD-MM-YYYY')
        ELSE p.patch_date - INTERVAL '1 day'
    END AS valid_end_date,
    d.invalid_reason
FROM dmd_mapped_to_snomed d
JOIN concept c USING (concept_id)
JOIN patch_date p ON TRUE
;
-- 3.2.3. Populate the concept_relationship_stage with new correct mappings only
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
    p.patch_date AS valid_start_date,
    to_date('31-12-2099', 'DD-MM-YYYY') AS valid_end_date
FROM concept_stage cs
JOIN patch_date p ON TRUE
JOIN dmd_mapped_to_snomed dmts ON
    cs.concept_id = dmts.concept_id
-- Join to replacement concept does it map anywhere?
LEFT JOIN concept r ON
    r.concept_id = dmts.replacement_concept_id
LEFT JOIN concept_relationship r2 ON
        r.concept_id = r2.concept_id_1
    AND r2.relationship_id = 'Maps to'
    AND r2.invalid_reason IS NULL
LEFT JOIN concept t ON
    t.concept_id = r2.concept_id_2
WHERE (
    cs.standard_concept = 'S' OR
    t.concept_id IS NOT NULL
)
;
-- 3.2.4. Explicitly deprecate old existing mappings
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
    r.valid_start_date,
    GREATEST(p.patch_date, r.valid_start_date) AS valid_end_date,
    'D' AS invalid_reason
FROM dmd_mapped_to_snomed dm
JOIN patch_date p ON TRUE
JOIN concept c USING (concept_id)
JOIN concept_relationship r ON
        r.concept_id_1 = dm.concept_id
    AND r.relationship_id = 'Maps to'
    AND r.invalid_reason IS NULL
JOIN concept t ON
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

-- 3.2.5. Fill latest_update field for dm+d
SELECT
    VOCABULARY_PACK.SetLatestUpdate(
            pVocabularyName			=> 'dm+d',
            pVocabularyDate			=> '2023-05-22',
            pVocabularyVersion		=> 'DMD 2023-05-22',
            pVocabularyDevSchema	=> 'dev_snomed'
    )
FROM patch_date p
;

-- 4. Run `GenericUpdate('DELTA')`

-- 5. Patch release for Gemscript
-- 5.0. Clean stage tables to delete changes from the previous step
TRUNCATE concept_relationship_stage;
TRUNCATE concept_synonym_stage;
TRUNCATE concept_stage;
TRUNCATE concept_relationship_manual;

INSERT INTO concept_relationship_manual
SELECT concept_code_1,
		concept_code_2,
		vocabulary_id_1,
		vocabulary_id_2,
		relationship_id,
		valid_start_date,
		valid_end_date,
		invalid_reason
FROM devv5.base_concept_relationship_manual
WHERE concept_id_1 <> 0
	AND concept_id_2 <> 0;

-- 5.1. Create table of concepts currently mapped to SNOMED, but that could be mapped to dm+d
DROP TABLE IF EXISTS gemscript_mapped_to_snomed;
CREATE TABLE gemscript_mapped_to_snomed AS
SELECT
    c.concept_id AS gemscript_concept_id,
    c.concept_code AS gemscript_concept_code,
    t.concept_id AS snomed_concept_id,
    d.concept_id AS dmd_concept_id,
    t.concept_code AS shared_concept_code
FROM devv5.concept c
JOIN devv5.concept_relationship r ON
        c.concept_id = r.concept_id_1
    AND r.relationship_id = 'Maps to'
    AND r.invalid_reason IS NULL
    AND c.vocabulary_id = 'Gemscript'
JOIN devv5.concept t ON
        r.concept_id_2 = t.concept_id
    AND t.vocabulary_id = 'SNOMED'
JOIN devv5.concept d ON
        d.concept_code = t.concept_code
    AND d.vocabulary_id = 'dm+d'
;

-- 5.2. Populate new mappings
INSERT INTO concept_relationship_stage
    (concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2,
    relationship_id, valid_start_date, valid_end_date)
SELECT
    gemscript_concept_code,
    shared_concept_code,
    'Gemscript',
    'dm+d',
    'Maps to',
    p.patch_date,
    to_date('2099-12-31', 'YYYY-MM-DD')
FROM gemscript_mapped_to_snomed
JOIN patch_date p ON TRUE
;

--5.3. Deprecate existing mappings
INSERT INTO concept_relationship_stage
    (concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2,
    relationship_id, valid_start_date, valid_end_date, invalid_reason)
SELECT
    g.gemscript_concept_code,
    c.concept_code,
    'Gemscript',
    c.vocabulary_id,
    'Maps to',
    c.valid_start_date,
    p.patch_date - INTERVAL '1 day',
    'D'
FROM gemscript_mapped_to_snomed g
JOIN patch_date p ON TRUE
JOIN devv5.concept_relationship r ON
        r.concept_id_1 = g.gemscript_concept_id
    AND r.relationship_id = 'Maps to'
    AND r.invalid_reason IS NULL
JOIN devv5.concept c ON
    r.concept_id_2 = c.concept_id
;
DROP TABLE IF EXISTS gemscript_mapped_to_snomed;

-- 5.4. Fill latest_update field for Gemscript
SELECT
	VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'Gemscript',
	pVocabularyDate			=> p.patch_date,
	pVocabularyVersion		=> 'Gemscript 2021-02-01',
	pVocabularyDevSchema	=> 'dev_snomed'
)
FROM patch_date p
;

-- 6. Run `GenericUpdate('DELTA').

-- 7. Run `SNOMED/load_stage.sql`

-- 8. Add replacement relationships for SNOMED UKDE retired concepts and whites them out in concept_stage
-- 8.1. Create table of retired concepts
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
CREATE INDEX idx_retired_concepts_cv ON retired_concepts (concept_code, vocabulary_id);
;
ANALYSE patch_date;
ANALYSE retired_concepts;
;

-- 8.2. Add replacement relationships for retired concepts
--- We assume that dm+d is in fixed state by now, including taking
--- ownership of the UK Drug Extension module concepts where relevant.
-- 8.2.0. Upload all relationships for the retired concepts that exist in base tables only:
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
SELECT DISTINCT c.concept_code,
	cc.concept_code,
	c.vocabulary_id,
	cc.vocabulary_id,
	cr.relationship_id,
	cr.valid_start_date,
	cr.valid_end_date,
	cr.invalid_reason
FROM concept_relationship cr
JOIN retired_concepts c on c.concept_id = cr.concept_id_1
JOIN concept cc on cc.concept_id = cr.concept_id_2
WHERE cr.invalid_reason IS NULL
AND NOT EXISTS(
	SELECT 1 -- if the link from cr already exists in crs
		FROM concept_relationship_stage crs
		WHERE crs.concept_code_1 = c.concept_code
			AND crs.concept_code_2 = cc.concept_code
			AND crs.relationship_id = cr.relationship_id
			AND crs.vocabulary_id_1 = c.vocabulary_id
			AND crs.vocabulary_id_2 = cc.vocabulary_id
);

-- 8.2.1. Deprecate existing relationships except for external "Maps to" -- update
UPDATE concept_relationship_stage crs
SET
    invalid_reason = 'D',
    valid_end_date = GREATEST(
        p.patch_date - INTERVAL '1 day',
        crs.valid_start_date) -- If somehow added this release

FROM patch_date p
WHERE
        crs.invalid_reason IS NULL
    AND EXISTS ( -- Target and/or source is UKDE retired concept
        SELECT 1
        FROM retired_concepts c
        WHERE
                (c.concept_code, c.vocabulary_id) = (crs.concept_code_1, crs.vocabulary_id_1)
            OR  (c.concept_code, c.vocabulary_id) = (crs.concept_code_2, crs.vocabulary_id_2)
    )
    AND NOT -- Not an external Maps to/CRB
    (
            crs.relationship_id in ('Maps to', 'Concept replaced by')
        AND (crs.concept_code_1, crs.vocabulary_id_1) IN (
            SELECT concept_code, vocabulary_id
            FROM retired_concepts
        )
        AND NOT (crs.concept_code_2, crs.vocabulary_id_2) IN (
            SELECT concept_code, vocabulary_id
            FROM retired_concepts
        )
    )
;

-- 8.2.3. Add 'Concept replaced by' relationships where possible
INSERT INTO concept_relationship_stage (
    concept_code_1,
    concept_code_2,
    vocabulary_id_1,
    vocabulary_id_2,
    relationship_id,
    valid_start_date,
    valid_end_date
)
SELECT
    rc.concept_code,
    coalesce(
        dmd2.concept_code,
        dmd.concept_code
    ),
    rc.vocabulary_id,
    coalesce(
        dmd2.vocabulary_id,
        dmd.vocabulary_id
    ),
    'Concept replaced by',
    p.patch_date,
    TO_DATE('20991231', 'yyyymmdd')
FROM retired_concepts rc
JOIN patch_date p ON TRUE
JOIN concept dmd ON
        dmd.concept_code = rc.concept_code
    AND dmd.vocabulary_id = 'dm+d'
	AND (dmd.invalid_reason = 'U' OR dmd.invalid_reason IS NULL)
LEFT JOIN concept_relationship rep ON
        dmd.invalid_reason IS NOT NULL
    AND dmd.concept_id = rep.concept_id_1
    AND rep.relationship_id = 'Concept replaced by'
    AND rep.invalid_reason IS NULL
LEFT JOIN concept dmd2 ON
        dmd2.concept_id = rep.concept_id_2
    AND dmd2.vocabulary_id = 'dm+d'
	AND (dmd2.invalid_reason = 'U' OR dmd2.invalid_reason IS NULL)
WHERE
    -- Replacement not already given in concept_relationship_stage
    NOT EXISTS(
        SELECT 1
        FROM concept_relationship_stage x
        WHERE
                    x.invalid_reason IS NULL
            AND (
                    rc.concept_code,
                    coalesce(
                        dmd2.concept_code,
                        dmd.concept_code
                    ),
                    rc.vocabulary_id,
                    coalesce(
                        dmd2.vocabulary_id,
                        dmd.vocabulary_id
                    ),
                    'Concept replaced by'
                ) = (
                    x.concept_code_1,
                    x.concept_code_2,
                    x.vocabulary_id_1,
                    x.vocabulary_id_2,
                    x.relationship_id
                )
);

-- 8.2.4. Deprecate all 'Maps to' links from the retired concepts, that obtained replacement link above:
UPDATE concept_relationship_stage i
SET
    invalid_reason = 'D',
    valid_end_date = GREATEST(p.patch_date, valid_start_date)
FROM retired_concepts r
JOIN patch_date p on TRUE
WHERE
        r.concept_code = i.concept_code_1
    AND r.vocabulary_id = i.vocabulary_id_1
    AND i.relationship_id = 'Maps to'
    AND i.invalid_reason IS NULL
    AND EXISTS(
        SELECT 1
        FROM concept_relationship_stage rp
        WHERE
                r.concept_code = rp.concept_code_1
            AND r.vocabulary_id = rp.vocabulary_id_1
            AND rp.relationship_id = 'Concept replaced by'
            AND rp.invalid_reason IS NULL)
;

-- 8.2.6. Process replacement relationships and build mappings following them

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

-- Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

-- Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;

--9. Run `GenericUpdate()`

--10. White out the concepts
UPDATE concept c
SET concept_code = CASE c.domain_id
    WHEN 'Route' THEN c.concept_code
    ELSE gen_random_uuid() :: text
    END,
    concept_name = CASE c.domain_id WHEN 'Route' THEN c.concept_name -- || ' (retired module, do not use)'
        			ELSE 'Retired SNOMED UK Drug extension concept, do not use, use ' ||
             				'concept indicated by the CONCEPT_RELATIONSHIP table, if any'
    END,
    valid_end_date = LEAST(
        c.valid_end_date,
        p.patch_date - INTERVAL '1 day'),
    standard_concept = NULL,
    invalid_reason = COALESCE(c.invalid_reason, 'D')
FROM retired_concepts rc
JOIN patch_date p ON TRUE
WHERE
    c.concept_id = rc.concept_id
;
--10.1. Delete synonyms
DELETE FROM concept_synonym
WHERE concept_id IN (
    SELECT concept_id
    FROM retired_concepts
);

DROP TABLE IF EXISTS retired_concepts CASCADE;
DROP TABLE IF EXISTS patch_date CASCADE;
DROP TABLE IF EXISTS vmps;

--11. Run normal QA routines and `specific_qa/test_ukde_deletion_result.sql`

