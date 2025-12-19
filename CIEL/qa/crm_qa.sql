-- QA for concept_relationship_manual_updated (can be used for concept_relationship_manual as well)
-- Aggregated by error_type; for details, replace outer SELECT with `SELECT * FROM issues`
WITH issues AS (
    /* 1. Non-standard target for Maps to / Maps to value */
    SELECT
        'non-standard target (Maps to / Maps to value must point to Standard concept)'::text AS error_type,
        m.concept_code_1      AS source_code,
        m.vocabulary_id_1     AS source_vocabulary_id,
        m.concept_code_2      AS target_code,
        m.vocabulary_id_2     AS target_vocabulary_id,
        m.relationship_id     AS relationship_id
    FROM concept_relationship_manual_updated m
    JOIN concept c2
      ON c2.concept_code  = m.concept_code_2
     AND c2.vocabulary_id = m.vocabulary_id_2
    WHERE m.relationship_id IN ('Maps to','Maps to value')
      AND (c2.standard_concept IS DISTINCT FROM 'S'
           OR c2.standard_concept IS NULL)
    UNION ALL
    /* 2. Maps to value without any Maps to for the same source (within manual table) */
    SELECT
        'Maps to value without Maps to (manual only)'::text AS error_type,
        m.concept_code_1      AS source_code,
        m.vocabulary_id_1     AS source_vocabulary_id,
        m.concept_code_2      AS target_code,
        m.vocabulary_id_2     AS target_vocabulary_id,
        m.relationship_id     AS relationship_id
    FROM concept_relationship_manual_updated m
    WHERE m.relationship_id = 'Maps to value'
      AND NOT EXISTS (
            SELECT 1
            FROM concept_relationship_manual_updated x
            WHERE x.concept_code_1  = m.concept_code_1
              AND x.vocabulary_id_1 = m.vocabulary_id_1
              AND x.relationship_id = 'Maps to'
          )
    UNION ALL
    /* 3. Duplicate mappings in manual (same pair + relationship) */
    SELECT
        'duplicate manual mapping (same source, target, vocabularies, relationship)'::text AS error_type,
        m.concept_code_1      AS source_code,
        m.vocabulary_id_1     AS source_vocabulary_id,
        m.concept_code_2      AS target_code,
        m.vocabulary_id_2     AS target_vocabulary_id,
        m.relationship_id     AS relationship_id
    FROM (
        SELECT
            m.*,
            COUNT(*) OVER (
                PARTITION BY
                    m.concept_code_1,
                    m.vocabulary_id_1,
                    m.concept_code_2,
                    m.vocabulary_id_2,
                    m.relationship_id
            ) AS dup_cnt
        FROM concept_relationship_manual_updated m
    ) m
    WHERE m.dup_cnt > 1
    UNION ALL
    /* 4. Suspicious source vocabulary (expected CIEL as source) */
    SELECT
        'unexpected source vocabulary_id_1 (expected CIEL)'::text AS error_type,
        m.concept_code_1      AS source_code,
        m.vocabulary_id_1     AS source_vocabulary_id,
        m.concept_code_2      AS target_code,
        m.vocabulary_id_2     AS target_vocabulary_id,
        m.relationship_id     AS relationship_id
    FROM concept_relationship_manual_updated m
    WHERE m.vocabulary_id_1 <> 'CIEL'
    UNION ALL
    /* 5. Invalid relationship_id in manual file */
    SELECT
        'unexpected relationship_id in manual'::text AS error_type,
        m.concept_code_1      AS source_code,
        m.vocabulary_id_1     AS source_vocabulary_id,
        m.concept_code_2      AS target_code,
        m.vocabulary_id_2     AS target_vocabulary_id,
        m.relationship_id     AS relationship_id
    FROM concept_relationship_manual_updated m
    WHERE m.relationship_id NOT IN (
              'Maps to',
              'Maps to value'
          )
    UNION ALL
    /* 6. Invalid date range (valid_start_date >= valid_end_date) */
    SELECT
        'invalid date interval (valid_start_date >= valid_end_date)'::text AS error_type,
        m.concept_code_1      AS source_code,
        m.vocabulary_id_1     AS source_vocabulary_id,
        m.concept_code_2      AS target_code,
        m.vocabulary_id_2     AS target_vocabulary_id,
        m.relationship_id     AS relationship_id
    FROM concept_relationship_manual_updated m
    WHERE m.valid_start_date IS NOT NULL
      AND m.valid_end_date   IS NOT NULL
      AND m.valid_start_date >= m.valid_end_date
)
SELECT
    error_type,
    COUNT(*) AS cnt
FROM issues
GROUP BY error_type
ORDER BY error_type;
