-- check_stale_attribute_relationships.sql
--
-- Tracks valid relationships in the basic tables from standard RxNorm / RxNorm Extension
-- drug concepts to deprecated attribute concepts (Brand Names, Dose Forms, Ingredients)
-- that are carried forward without remediation across releases.
--
-- Extends qa_rxnorm.sql checks #10a-#10b by:
--   - covering RxNorm Extension as an additional source vocabulary
--   - breaking down counts by attribute class and relationship_id
--   - distinguishing relationships being retired or replaced this release from
--     those left fully unaddressed
--
-- When to run: after load_stage.sql, before GenericUpdate().
--
-- How to interpret:
--   stale_in_devv5        : backlog entering this release; should trend downward over time.
--   retired_this_release  : CRS explicitly deprecates the stale relationship.
--   replaced_this_release : CRS adds a new valid relationship of the same type for the
--                           same source concept (stale rel will be superseded post-update).
--   unaddressed_remaining : will persist after GenericUpdate; the primary remediation target.
--   pct_addressed         : share of the backlog handled this release.
--
-- A non-zero and growing unaddressed_remaining for 'Ingredient' / 'Has ingredient' rows
-- is a blocker risk for the RxNorm Extension build (see qa_rxnorm.sql check #12).

WITH
-- -------------------------------------------------------------------------
-- Step 1: Identify all stale relationships in devv5 (the baseline backlog).
-- A relationship is stale when:
--   (a) it is valid in the basic concept_relationship table, AND
--   (b) the target attribute concept is deprecated, AND
--   (c) the relationship type is a meaningful attribute link
--       (not a replacement or mapping administrative relationship).
-- Source vocabulary is extended to RxNorm Extension vs. qa_rxnorm.sql check #10.
-- -------------------------------------------------------------------------
stale_devv5 AS (
    SELECT
        c1.concept_code     AS drug_concept_code,
        c1.vocabulary_id    AS drug_vocabulary_id,
        c2.concept_code     AS attr_concept_code,
        c2.vocabulary_id    AS attr_vocabulary_id,
        c2.concept_class_id AS attribute_class,
        r.relationship_id
    FROM devv5.concept_relationship r
    JOIN devv5.concept c1
        ON  c1.concept_id       = r.concept_id_1
        AND c1.vocabulary_id    IN ('RxNorm', 'RxNorm Extension')
        AND c1.standard_concept = 'S'
        AND c1.invalid_reason   IS NULL
        AND (c1.concept_class_id LIKE '%Drug%' OR c1.concept_class_id LIKE '%Pack%')
    JOIN devv5.concept c2
        ON  c2.concept_id       = r.concept_id_2
        AND c2.vocabulary_id    = 'RxNorm'
        AND c2.concept_class_id IN ('Brand Name', 'Dose Form', 'Ingredient')
        AND c2.invalid_reason   IS NOT NULL
    WHERE r.invalid_reason IS NULL
      AND r.relationship_id NOT IN (
            'Concept replaces',
            'Concept replaced by',
            'Mapped from',
            'Maps to'
      )
),

-- -------------------------------------------------------------------------
-- Step 2: For each stale relationship, determine whether the current release
-- is addressing it via concept_relationship_stage (CRS).
--
-- 'retired'    : CRS carries an entry for this exact (code1, rel, code2) with
--                invalid_reason IS NOT NULL -- the stale rel will be deprecated.
-- 'replaced'   : CRS adds a new valid entry with the same (code1, rel) pointing
--                to a DIFFERENT target that is not being deprecated this release;
--                the stale rel becomes superseded once GenericUpdate rewrites it.
-- 'unaddressed': neither condition is met; the relationship will survive unchanged.
-- -------------------------------------------------------------------------
stale_classified AS (
    SELECT
        sd.attribute_class,
        sd.relationship_id,
        CASE
            -- Explicit retirement: CRS deprecates this exact relationship
            WHEN EXISTS (
                SELECT 1
                FROM concept_relationship_stage crs
                WHERE crs.concept_code_1  = sd.drug_concept_code
                  AND crs.vocabulary_id_1 = sd.drug_vocabulary_id
                  AND crs.concept_code_2  = sd.attr_concept_code
                  AND crs.vocabulary_id_2 = sd.attr_vocabulary_id
                  AND crs.relationship_id = sd.relationship_id
                  AND crs.invalid_reason IS NOT NULL
            ) THEN 'retired'

            -- Replacement: CRS adds a valid relationship of the same type for
            -- this source concept to a different target that is not being
            -- deprecated in concept_stage during this release
            WHEN EXISTS (
                SELECT 1
                FROM concept_relationship_stage crs2
                WHERE crs2.concept_code_1  = sd.drug_concept_code
                  AND crs2.vocabulary_id_1 = sd.drug_vocabulary_id
                  AND crs2.relationship_id = sd.relationship_id
                  AND crs2.invalid_reason  IS NULL
                  AND crs2.concept_code_2 <> sd.attr_concept_code
                  -- Confirm replacement target is not itself being deprecated this release
                  AND NOT EXISTS (
                      SELECT 1
                      FROM concept_stage cs_chk
                      WHERE cs_chk.concept_code  = crs2.concept_code_2
                        AND cs_chk.vocabulary_id = crs2.vocabulary_id_2
                        AND cs_chk.invalid_reason IS NOT NULL
                  )
            ) THEN 'replaced'

            ELSE 'unaddressed'
        END AS crs_status
    FROM stale_devv5 sd
),

-- -------------------------------------------------------------------------
-- Step 3: Aggregate by attribute class and relationship_id.
-- -------------------------------------------------------------------------
summary AS (
    SELECT
        attribute_class,
        relationship_id,
        COUNT(*)                                             AS stale_in_devv5,
        COUNT(*) FILTER (WHERE crs_status = 'retired')      AS retired_this_release,
        COUNT(*) FILTER (WHERE crs_status = 'replaced')     AS replaced_this_release,
        COUNT(*) FILTER (WHERE crs_status = 'unaddressed')  AS unaddressed_remaining
    FROM stale_classified
    GROUP BY attribute_class, relationship_id
)

-- -------------------------------------------------------------------------
-- Final output: per-group rows followed by a TOTAL row, consistent with
-- the layout used in check_abnormal_triplets.sql.
-- -------------------------------------------------------------------------
SELECT
    attribute_class,
    relationship_id,
    stale_in_devv5,
    retired_this_release,
    replaced_this_release,
    retired_this_release + replaced_this_release  AS addressed_this_release,
    unaddressed_remaining,
    CASE
        WHEN stale_in_devv5 = 0 THEN NULL
        ELSE ROUND(
                 (retired_this_release + replaced_this_release)
                 * 100.0 / stale_in_devv5,
                 1
             ) || '%'
    END AS pct_addressed
FROM summary

UNION ALL

SELECT
    'TOTAL'  AS attribute_class,
    ''       AS relationship_id,
    SUM(stale_in_devv5),
    SUM(retired_this_release),
    SUM(replaced_this_release),
    SUM(retired_this_release + replaced_this_release),
    SUM(unaddressed_remaining),
    CASE
        WHEN SUM(stale_in_devv5) = 0 THEN NULL
        ELSE ROUND(
                 SUM(retired_this_release + replaced_this_release)
                 * 100.0 / SUM(stale_in_devv5),
                 1
             ) || '%'
    END AS pct_addressed
FROM summary

ORDER BY attribute_class, relationship_id;