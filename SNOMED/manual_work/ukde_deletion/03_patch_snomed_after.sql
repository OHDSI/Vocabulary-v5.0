/*
 * Apply this script to a schema after running SNOMED's load_stage.sql.
 */
-- This script adds replacement relationships for SNOMED UKDE retired concepts
-- and whites them out in concept_stage.

--1.1. Table of retired concepts
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
--2. Add replacement relationships for retired concepts
-- We assume that dm+d is in fixed state by now, including taking
-- ownership of the UK Drug Extension module concepts where relevant.
--2.1. Deprecate existing relationships except for external "Maps to" -- update
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
--2.2. Deprecate existing relationships except for external "Maps to" -- expl
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
    rc.concept_code,
    r2.concept_code,
    rc.vocabulary_id,
    r2.vocabulary_id,
    r.relationship_id,
    r.valid_start_date,
    GREATEST(p.patch_date - INTERVAL '1 day', r.valid_start_date),
    'D'
FROM concept_relationship r
JOIN patch_date p ON TRUE
JOIN retired_concepts rc ON
        r.concept_id_1 = rc.concept_id
    AND r.invalid_reason IS NULL
LEFT JOIN retired_concepts r2 ON
    r2.concept_id = r.concept_id_2
WHERE
    NOT (
            r.relationship_id in ('Maps to', 'Concept replaced by'
				   )
        AND r2.concept_id IS NULL
    )
    -- Not already given in concept_relationship_stage
    AND NOT EXISTS(
        SELECT 1
        FROM concept_relationship_stage x
        WHERE
            (
                rc.concept_code,
                r2.concept_code,
                rc.vocabulary_id,
                r2.vocabulary_id,
                r.relationship_id
            ) = (
                x.concept_code_1,
                x.concept_code_2,
                x.vocabulary_id_1,
                x.vocabulary_id_2,
                x.relationship_id
            )
    )
;
--2.3. Add concept replaced by relationships where possible
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
    )
;

--2.5. Deprecate all 'Maps to' links from the retired concepts, that obtained replacement link above:
UPDATE concept_relationship_stage i
SET invalid_reason = 'D',
    valid_end_date = GREATEST(p.patch_date, crs.valid_start_date)
FROM concept_relationship_stage crs
join concept c on c.concept_code = crs.concept_code_1
         and c.vocabulary_id = crs.vocabulary_id_1
join patch_date p on TRUE
WHERE i.concept_code_1 = crs.concept_code_1
  and i.vocabulary_id_1 = crs.vocabulary_id_1
  and i.relationship_id = crs.relationship_id
  and i.concept_code_2 = crs.concept_code_2
  and i.vocabulary_id_2 = crs.vocabulary_id_2
  and c.concept_id in (SELECT concept_id
                     from retired_concepts)
  and crs.relationship_id = 'Maps to'
  AND crs.invalid_reason IS NULL
  AND exists(SELECT 1
             FROM concept_relationship_stage r
             WHERE crs.concept_code_1 = r.concept_code_1
             AND c.vocabulary_id = r.vocabulary_id_1
             AND r.relationship_id = 'Concept replaced by'
             AND r.invalid_reason IS NULL);

--2.5. Bizzare edge case: Nebraska Lexicon concept mapped to a concept which
-- is not yet standard in dm+d.
;
--2.6. Add Maps to from replaced by
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
