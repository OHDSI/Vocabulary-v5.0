/*
 * Apply this script to a schema after running SNOMED's release. Needs
 * retired_concepts table from the previous step.
 */

--3.1. White out the concepts
UPDATE concept c
SET
    concept_code = CASE c.domain_id
        WHEN 'Route' THEN c.concept_code
        ELSE gen_random_uuid() :: text
    END,
    concept_name = CASE c.domain_id
        WHEN 'Route' THEN c.concept_name || ' (retired module, do not use)'
        ELSE 'Concept belonged to retired SNOMED CT module'
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
--3.2. Delete synonyms
DELETE FROM concept_synonym
WHERE concept_id IN (
    SELECT concept_id
    FROM retired_concepts
);
DROP TABLE retired_concepts CASCADE;
