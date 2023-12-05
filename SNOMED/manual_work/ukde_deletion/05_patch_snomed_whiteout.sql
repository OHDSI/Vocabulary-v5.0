/*
 * Apply this script to a schema after running SNOMED's release. Needs
 * retired_concepts table from the previous step.
 */

--3.1. White out the concepts
UPDATE concept c
SET
    -- standard_concept = NULL,
    -- invalid_reason = 'D', -- Already done by the release
    concept_code = CASE c.domain_id
        WHEN 'Route' THEN c.concept_code
        ELSE gen_random_uuid() :: text
    END,
    concept_name = CASE c.domain_id
        WHEN 'Route' THEN c.concept_name || ' (retired module, do not use)'
        ELSE 'Concept belongs to a retired module, do not use'
    END,
    valid_end_date = LEAST(
        c.valid_end_date,
        to_date('31-10-2023', 'DD-MM-YYYY')
    ),
    standard_concept = NULL,
    invalid_reason = COALESCE(c.invalid_reason, 'D')
FROM retired_concepts rc
WHERE
    c.concept_id = rc.concept_id
;
DROP TABLE retired_concepts CASCADE;