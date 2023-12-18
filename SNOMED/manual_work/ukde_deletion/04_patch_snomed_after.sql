/*
 * Apply this script to a schema after running SNOMED's load_stage.sql.
 */
-- This script adds replacement relationships for SNOMED UKDE retired concepts
-- and whites them out in concept_stage.

--2. Add replacement relationships for retired concepts
-- We assume that dm+d is in fixed state by now, including taking
-- ownership of the UK Drug Extension module concepts where relevant.
--2.1. Deprecate existing relationships except for external "Maps to" -- update
UPDATE concept_relationship_stage crs
SET
    invalid_reason = 'D',
    valid_end_date = GREATEST(
        to_date('31-10-2023', 'DD-MM-YYYY'),
        valid_start_date + INTERVAL '1 day' -- If somehow added this release
    )
WHERE
        crs.invalid_reason IS NULL
    AND EXISTS (
        SELECT 1
        FROM concept c
        JOIN retired_concepts rc ON
            rc.concept_id = c.concept_id
                    AND c.concept_code = crs.concept_code_1
                    AND c.vocabulary_id = crs.vocabulary_id_1)
    AND NOT -- Not an external Maps to/CRB
    (
            crs.relationship_id IN (
                'Maps to',
                'Concept replaced by')
        AND NOT EXISTS (
            SELECT 1
            FROM retired_concepts rc
            JOIN concept c ON
                    c.concept_id = rc.concept_id
                AND c.concept_code = crs.concept_code_2
                AND c.vocabulary_id = crs.vocabulary_id_2
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
    c1.concept_code,
    c2.concept_code,
    c1.vocabulary_id,
    c2.vocabulary_id,
    r.relationship_id,
    r.valid_start_date,
    to_date('31-10-2023', 'DD-MM-YYYY'),
    'D'
FROM concept_relationship r
JOIN concept c1 ON
    c1.concept_id = r.concept_id_1
JOIN concept c2 ON
    c2.concept_id = r.concept_id_2
JOIN retired_concepts rc ON
        r.concept_id_1 = rc.concept_id
    AND r.invalid_reason IS NULL
LEFT JOIN retired_concepts r2 ON
    r2.concept_id = r.concept_id_2
WHERE
    NOT (
            r.relationship_id in ('Maps to', 'Concept replaced by')
        AND r2.concept_id IS NULL
    )
    -- Not already given in concept_relationship_stage
    AND NOT EXISTS(
        SELECT 1
        FROM concept_relationship_stage x
        WHERE
            (
                c1.concept_code,
                c2.concept_code,
                c1.vocabulary_id,
                c2.vocabulary_id,
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

--2.3. Deprecate all staged relationships except for external "Maps to" and
-- possible external replacements
UPDATE concept_relationship_stage crs
SET
    invalid_reason = 'D',
    valid_end_date = GREATEST(
        to_date('31-10-2023', 'DD-MM-YYYY'),
        valid_start_date + INTERVAL '1 day' -- If somehow added this release
    )
WHERE
        crs.invalid_reason IS NULL
    AND EXISTS (
        SELECT 1
        FROM retired_concepts rc
        JOIN concept c ON
                c.concept_id = rc.concept_id
            AND c.concept_code = crs.concept_code_1
            AND c.vocabulary_id = crs.vocabulary_id_1
        WHERE
            rc.concept_id = c.concept_id
        )
    AND NOT ( -- External Maps to and replacement
            crs.relationship_id IN (
                'Maps to',
                'Concept replaced by'
            )
        AND NOT EXISTS (
            SELECT 1
            FROM retired_concepts rc
            JOIN concept c ON
                    c.concept_id = rc.concept_id
                AND c.concept_code = crs.concept_code_2
                AND c.vocabulary_id = crs.vocabulary_id_2
        )
    )
;
--2.4. Add concept replaced by relationships where possible
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
    c.concept_code,
    coalesce(
        dmd2.concept_code,
        dmd.concept_code
    ),
    c.vocabulary_id,
    coalesce(
        dmd2.vocabulary_id,
        dmd.vocabulary_id
    ),
    'Concept replaced by',
    to_date('01-11-2023', 'DD-MM-YYYY'),
    to_date('31-12-2099', 'DD-MM-YYYY')
FROM concept c
JOIN retired_concepts rc ON
    rc.concept_id = c.concept_id
JOIN concept dmd ON
        dmd.concept_code = c.concept_code
    AND dmd.vocabulary_id = 'dm+d'
    AND c.vocabulary_id = 'SNOMED'
LEFT JOIN concept_relationship rep ON
        dmd.invalid_reason IS NOT NULL
    AND dmd.concept_id = rep.concept_id_1
    AND rep.relationship_id = 'Concept replaced by'
    AND rep.invalid_reason IS NULL
LEFT JOIN concept dmd2 ON
        dmd2.concept_id = rep.concept_id_2
    AND dmd2.vocabulary_id = 'dm+d'
WHERE
    -- Replacement not already given in concept_relationship_stage
    NOT EXISTS(
        SELECT 1
        FROM concept_relationship_stage x
        WHERE
            (
                c.concept_code,
                coalesce(
                    dmd2.concept_code,
                    dmd.concept_code
                ),
                c.vocabulary_id,
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
--2.5. Add Maps to from replaced by
SELECT vocabulary_pack.addFreshMapsTo();
