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
        TO_DATE('20231030', 'YYYYMMDD'),
        valid_start_date + INTERVAL '1 day'
    )
WHERE
        crs.invalid_reason IS NULL
    AND EXISTS (
        SELECT 1
        FROM concept c
        JOIN retired_concepts rc ON
                rc.concept_id = c.concept_id
            AND (
                    (c.concept_code, c.vocabulary_id) = (crs.concept_code_1, crs.vocabulary_id_1) OR
                    (c.concept_code, c.vocabulary_id) = (crs.concept_code_2, crs.vocabulary_id_2)
                )
    )
    AND NOT (
            crs.relationship_id IN ('Maps to'--, 'Concept replaced by'
                                   )
        AND EXISTS (
            SELECT 1
            FROM retired_concepts rc
            JOIN concept c ON
                    c.concept_id = rc.concept_id
                AND c.concept_code = crs.concept_code_1
                AND c.vocabulary_id = crs.vocabulary_id_1
        )
        AND NOT EXISTS ( -- Target is not
            SELECT 1
            FROM retired_concepts rc
            JOIN concept c ON
                    c.concept_id = rc.concept_id
                AND c.concept_code = crs.concept_code_2
                AND c.vocabulary_id = crs.vocabulary_id_2
        )
    );

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
    TO_DATE('31-10-2023', 'DD-MM-YYYY'),
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
            r.relationship_id in ('Maps to'--, 'Concept replaced by'
				   )
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
    TO_DATE('20231101', 'yyyymmdd'),
    TO_DATE('20991231', 'yyyymmdd')
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
                    x.invalid_reason IS NULL
            AND (
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
--2.5. Bizzare edge case: Nebraska Lexicon concept mapped to a concept which
-- is not yet standard in dm+d.
;
--2.6. Add Maps to from replaced by
SELECT vocabulary_pack.addFreshMapsTo();
