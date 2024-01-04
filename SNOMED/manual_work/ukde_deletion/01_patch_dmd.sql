/*
 * Apply this script to a clean schema to get stage tables that could be
 applied as a patch before running SNOMED's load_stage.sql.
 */
--0.1. Empty stage tables and get dm+d *_manual data
TRUNCATE concept_relationship_stage;
TRUNCATE concept_synonym_stage;
TRUNCATE concept_stage;
TRUNCATE concept_relationship_manual;
TRUNCATE concept_synonym_manual;
TRUNCATE concept_manual;

INSERT INTO concept_manual
SELECT *
FROM dev_dmd.concept_manual;
INSERT INTO concept_synonym_manual
SELECT *
FROM dev_dmd.concept_synonym_manual;
INSERT INTO concept_relationship_manual
SELECT *
FROM dev_dmd.concept_relationship_manual;

--0.3. Persisting storage for patch the date: will be used to control date of the patch
DROP TABLE IF EXISTS patch_date;
CREATE TABLE patch_date (
    patch_date DATE
);
INSERT INTO patch_date (patch_date) VALUES (to_date('27-01-2022', 'DD-MM-YYYY'));

--0.2. Source dm+d tables
DROP TABLE IF EXISTS vmps;

--vmps: Virtual Medicinal Product
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

--1. Create views of rows to be affected
--1.1. Create view of manual mappings missing from dm+d
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
--2. Fill the stage tables
--2.1. Prepare stage tables
TRUNCATE concept_stage;
TRUNCATE concept_relationship_stage;
TRUNCATE concept_synonym_stage;

--2.2. Populate the concept_stage with affected concepts only
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

SELECT
    VOCABULARY_PACK.SetLatestUpdate(
            pVocabularyName			=> 'dm+d',
            pVocabularyDate			=> '2023-05-22',
            pVocabularyVersion		=> 'DMD 2023-05-22',
            pVocabularyDevSchema	=> 'dev_test3'
    )
FROM patch_date p
;
