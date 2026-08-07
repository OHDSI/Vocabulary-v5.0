-- PostgreSQL version of lost_leg_of_mapping.sql.
-- Replaces Spark-native sort_array/collect_set with string_agg(DISTINCT ...).
-- Note: PostgreSQL's string_agg(DISTINCT ...) does not support ORDER BY;
--       the order of replacement_targets entries is therefore unspecified
--       (cosmetic difference only — values are identical).
-- Parameters: @oldVocSchema, @newVocSchema

WITH old_maps AS (
    SELECT DISTINCT
        cr.concept_id_1 AS source_concept_id,
        s.concept_code  AS source_code,
        s.concept_name  AS source_concept_name,
        s.vocabulary_id AS source_vocabulary_id,
        cr.concept_id_2 AS old_target_concept_id,
        t.concept_code  AS old_target_concept_code,
        t.concept_name  AS old_target_concept_name
    FROM @oldVocSchema.concept_relationship cr
    JOIN @oldVocSchema.concept s
      ON s.concept_id = cr.concept_id_1
    JOIN @oldVocSchema.concept t
      ON t.concept_id = cr.concept_id_2
    WHERE cr.relationship_id = 'Maps to'
      AND cr.invalid_reason IS NULL
      AND s.vocabulary_id IN ('ICD10', 'ICD10CM', 'CPT4', 'HCPCS', 'NDC', 'ICD9CM', 'ICD9Proc', 'ICD10PCS', 'ICDO3', 'JMDC')
),
new_maps AS (
    SELECT DISTINCT
        cr.concept_id_1 AS source_concept_id,
        s.concept_code  AS source_code,
        s.concept_name  AS source_concept_name,
        s.vocabulary_id AS source_vocabulary_id,
        cr.concept_id_2 AS new_target_concept_id,
        t.concept_code  AS new_target_concept_code,
        t.concept_name  AS new_target_concept_name
    FROM @newVocSchema.concept_relationship cr
    JOIN @newVocSchema.concept s
      ON s.concept_id = cr.concept_id_1
    JOIN @newVocSchema.concept t
      ON t.concept_id = cr.concept_id_2
    WHERE cr.relationship_id = 'Maps to'
      AND cr.invalid_reason IS NULL
      AND s.vocabulary_id IN ('ICD10', 'ICD10CM', 'CPT4', 'HCPCS', 'NDC', 'ICD9CM', 'ICD9Proc', 'ICD10PCS', 'ICDO3', 'JMDC')
),
diff_rows AS (
    SELECT
        coalesce(o.source_concept_id, n.source_concept_id)       AS source_concept_id,
        coalesce(o.source_code, n.source_code)                   AS source_code,
        coalesce(o.source_concept_name, n.source_concept_name)   AS source_concept_name,
        coalesce(o.source_vocabulary_id, n.source_vocabulary_id) AS source_vocabulary_id,

        o.old_target_concept_id,
        o.old_target_concept_code,
        o.old_target_concept_name,

        n.new_target_concept_id,
        n.new_target_concept_code,
        n.new_target_concept_name,

        CASE
            WHEN o.old_target_concept_id IS NOT NULL AND n.new_target_concept_id IS NOT NULL THEN 'KEPT'
            WHEN o.old_target_concept_id IS NOT NULL AND n.new_target_concept_id IS NULL THEN 'LOST'
            WHEN o.old_target_concept_id IS NULL AND n.new_target_concept_id IS NOT NULL THEN 'ADDED'
        END AS row_status
    FROM old_maps o
    FULL OUTER JOIN new_maps n
      ON o.source_concept_id = n.source_concept_id
     AND o.old_target_concept_id = n.new_target_concept_id
),
eligible_sources AS (
    SELECT source_concept_id
    FROM diff_rows
    GROUP BY source_concept_id
    HAVING MAX(CASE WHEN row_status = 'KEPT' THEN 1 ELSE 0 END) = 1
       AND (
            MAX(CASE WHEN row_status = 'LOST' THEN 1 ELSE 0 END) = 1
         OR MAX(CASE WHEN row_status = 'ADDED' THEN 1 ELSE 0 END) = 1
       )
),
replacement_candidates AS (
    SELECT
        cr.concept_id_1 AS lost_target_concept_id,
        string_agg(
            DISTINCT CONCAT(
                cr.relationship_id, ': ',
                CAST(cr.concept_id_2 AS VARCHAR),
                ' (', coalesce(c.concept_code, ''), ') ',
                coalesce(c.concept_name, '')
            ),
            ' | '
        ) AS replacement_targets
    FROM @newVocSchema.concept_relationship cr
    LEFT JOIN @newVocSchema.concept c
      ON c.concept_id = cr.concept_id_2
    WHERE cr.relationship_id IN ('Maps to', 'Concept replaced by')
      AND cr.invalid_reason IS NULL
    GROUP BY cr.concept_id_1
)
SELECT
    d.source_vocabulary_id,
    d.source_concept_id,
    d.source_code,
    d.source_concept_name,

    d.old_target_concept_id,
    d.old_target_concept_code,
    d.old_target_concept_name,

    d.new_target_concept_id,
    d.new_target_concept_code,
    d.new_target_concept_name,

    d.row_status,

    CASE WHEN d.row_status = 'LOST' THEN rc.replacement_targets END AS lost_target_replacements_in_new,
    CASE
        WHEN d.row_status = 'LOST'
         AND rc.replacement_targets IS NOT NULL
         AND rc.replacement_targets <> '' THEN 1
        ELSE 0
    END AS has_replacement_in_new
FROM diff_rows d
JOIN eligible_sources es
  ON es.source_concept_id = d.source_concept_id
LEFT JOIN replacement_candidates rc
  ON rc.lost_target_concept_id = d.old_target_concept_id
ORDER BY
    d.source_vocabulary_id,
    d.source_code,
    CASE d.row_status WHEN 'KEPT' THEN 1 WHEN 'LOST' THEN 2 WHEN 'ADDED' THEN 3 ELSE 4 END,
    coalesce(d.old_target_concept_id, d.new_target_concept_id)
