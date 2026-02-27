-- 1. Refresh the CIEL manual mappings outside this script and load them as concept_relationship_manual_updated.
-- 2. Remove all CIEL mappings which have been processed automatically in maps_for_load_stage from the old concept_relationship_manual
DELETE
FROM concept_relationship_manual a
WHERE EXISTS (SELECT 1
              FROM maps_for_load_stage x
              WHERE rank_num in (1,2) AND x.source_code = a.concept_code_1
              AND a.vocabulary_id_1 = 'CIEL'
              AND   x.target_concept_code = a.concept_code_2
              AND   x.target_vocabulary_id = a.vocabulary_id_2
              AND   x.relationship_id = a.relationship_id); -- 62

-- 3. Deprecate legacy manual mappings in concept_relationship_manual that are no longer present in concept_relationship_manual_updated.
-- Derive the latest valid CIEL snapshot date (vYYYY-MM-DD / YYYY-MM-DD)
WITH snapshot_date AS (
    SELECT MAX(
             to_date(
               regexp_replace(btrim(version), '^[vV]', ''),  -- strip leading v/V if present
               'YYYY-MM-DD'
             )
           ) AS valid_end_date
    FROM sources.ciel_source_versions
    WHERE NULLIF(btrim(version), '') ~* '^v?\d{4}-\d{2}-\d{2}$'  -- keep only version-like strings
)
-- Retire CIEL manual relationships, only if we have a non-NULL snapshot date
UPDATE concept_relationship_manual AS crm
SET invalid_reason = 'D',
    valid_end_date  = b.valid_end_date
FROM snapshot_date AS b
WHERE crm.vocabulary_id_1 = 'CIEL'
  AND b.valid_end_date IS NOT NULL
      AND NOT EXISTS (SELECT 1 --do not deprecate mapping if the same exists in the current manual file
                    FROM concept_relationship_manual_updated rl
                    WHERE rl.concept_code_1 = crm.concept_code_1 -- the same source_code is mapped
                        AND rl.concept_code_2 = crm.concept_code_2 -- to the same concept_code
                        AND rl.vocabulary_id_2 = crm.vocabulary_id_2 -- of the same vocabulary
                        AND rl.relationship_id = crm.relationship_id -- with the same relationship
                        AND rl.vocabulary_id_1 = 'CIEL')
; -- 80

--4. Insert new manual mappings (present in concept_relationship_manual_updated but not yet stored in concept_relationship_manual)
WITH snapshot_date AS (
    -- Determine the effective start date for this refresh
    SELECT MAX(
             to_date(
               regexp_replace(btrim(version), '^[vV]', ''),  -- strip leading v/V if present
               'YYYY-MM-DD'
             )
           ) AS start_date
    FROM sources.ciel_source_versions
    WHERE NULLIF(btrim(version), '') ~* '^v?\d{4}-\d{2}-\d{2}$'  -- only version-like strings
),

mapping AS (
    -- New mappings from the refreshed manual file, restricted to Standard targets
    SELECT DISTINCT
        a.concept_code_1        AS concept_code_1,
        a.concept_code_2        AS concept_code_2,
        a.vocabulary_id_1       AS vocabulary_id_1,
        a.vocabulary_id_2       AS vocabulary_id_2,
        a.relationship_id       AS relationship_id,
        sd.start_date           AS valid_start_date, -- refresh date as start
        DATE '2099-12-31'       AS valid_end_date, -- open-ended validity
        NULL::varchar           AS invalid_reason -- all new mappings are valid
    FROM concept_relationship_manual_updated a
    JOIN concept c
      ON c.concept_code   = a.concept_code_2
     AND c.vocabulary_id  = a.vocabulary_id_2
     AND c.standard_concept = 'S'
    CROSS JOIN snapshot_date sd
)

INSERT INTO concept_relationship_manual (
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
    m.concept_code_1,
    m.concept_code_2,
    m.vocabulary_id_1,
    m.vocabulary_id_2,
    m.relationship_id,
    m.valid_start_date,
    m.valid_end_date,
    m.invalid_reason
FROM mapping m
WHERE NOT EXISTS (
    -- Do not insert if the exact same manual mapping already exists
    SELECT 1
    FROM concept_relationship_manual x
    WHERE x.concept_code_1  = m.concept_code_1
      AND x.concept_code_2  = m.concept_code_2
      AND x.vocabulary_id_1 = m.vocabulary_id_1
      AND x.vocabulary_id_2 = m.vocabulary_id_2
      AND x.relationship_id = m.relationship_id
); -- 509
