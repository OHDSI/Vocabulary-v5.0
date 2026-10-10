WITH new_map AS (
  SELECT DISTINCT
      a.concept_id,
      a.vocabulary_id,
      a.concept_class_id,
      a.standard_concept,
      a.concept_code,
      a.concept_name,

      /* relationship_agg: ORDER BY r.relationship_id, b.concept_code, b.vocabulary_id */
      concat_ws(
        '-',
        transform(
          sort_array(
            collect_list(
              struct(
                r.relationship_id           AS rel,
                b.concept_code              AS tgt_code,
                b.vocabulary_id             AS tgt_voc,
                r.relationship_id           AS val_to_emit
              )
            )
          ),
          x -> x.val_to_emit
        )
      ) AS relationship_agg,

      /* code_agg: same ORDER BY, but emit code/self-label */
      concat_ws(
        '-/-',
        transform(
          sort_array(
            collect_list(
              struct(
                r.relationship_id                                          AS rel,
                b.concept_code                                             AS tgt_code,
                b.vocabulary_id                                            AS tgt_voc,
                CASE WHEN a.concept_id = b.concept_id
                     THEN '<Mapped to itself>'
                     ELSE b.concept_code
                END                                                        AS val_to_emit
              )
            )
          ),
          x -> x.val_to_emit
        )
      ) AS code_agg,

      /* name_agg: same ORDER BY, but emit name/self-label */
      concat_ws(
        '-/-',
        transform(
          sort_array(
            collect_list(
              struct(
                r.relationship_id                                          AS rel,
                b.concept_code                                             AS tgt_code,
                b.vocabulary_id                                            AS tgt_voc,
                CASE WHEN a.concept_id = b.concept_id
                     THEN '<Mapped to itself>'
                     ELSE b.concept_name
                END                                                        AS val_to_emit
              )
            )
          ),
          x -> x.val_to_emit
        )
      ) AS name_agg,

      cc.record_count
  FROM concept a
  JOIN @resultSchema.achilles_result_concept_count cc
    ON cc.concept_id = a.concept_id
  LEFT JOIN concept_relationship r
    ON a.concept_id = r.concept_id_1
   AND r.relationship_id IN ('Maps to', 'Maps to value')
   AND r.invalid_reason IS NULL
  LEFT JOIN concept b
    ON b.concept_id = r.concept_id_2
  WHERE cc.record_count > 100
    AND EXISTS (
      SELECT 1
      FROM @scratchSchema.bnui
      WHERE upper(a.concept_name) LIKE concat('%', bnui.cleaned_name, '%')
         OR lower(a.concept_name) LIKE concat('%', bnui.ingr_name,  '%')
    )
  GROUP BY
      a.concept_id, a.vocabulary_id, a.concept_class_id, a.standard_concept,
      a.concept_code, a.concept_name, cc.record_count
),

old_map AS (
  SELECT
      a.concept_id,
      a.vocabulary_id,
      a.concept_class_id,
      a.standard_concept,
      a.concept_code,
      a.concept_name,

      concat_ws(
        '-',
        transform(
          sort_array(
            collect_list(
              struct(
                r.relationship_id           AS rel,
                b.concept_code              AS tgt_code,
                b.vocabulary_id             AS tgt_voc,
                r.relationship_id           AS val_to_emit
              )
            )
          ),
          x -> x.val_to_emit
        )
      ) AS relationship_agg,

      concat_ws(
        '-/-',
        transform(
          sort_array(
            collect_list(
              struct(
                r.relationship_id                                          AS rel,
                b.concept_code                                             AS tgt_code,
                b.vocabulary_id                                            AS tgt_voc,
                CASE WHEN a.concept_id = b.concept_id
                     THEN '<Mapped to itself>'
                     ELSE b.concept_code
                END                                                        AS val_to_emit
              )
            )
          ),
          x -> x.val_to_emit
        )
      ) AS code_agg,

      concat_ws(
        '-/-',
        transform(
          sort_array(
            collect_list(
              struct(
                r.relationship_id                                          AS rel,
                b.concept_code                                             AS tgt_code,
                b.vocabulary_id                                            AS tgt_voc,
                CASE WHEN a.concept_id = b.concept_id
                     THEN '<Mapped to itself>'
                     ELSE b.concept_name
                END                                                        AS val_to_emit
              )
            )
          ),
          x -> x.val_to_emit
        )
      ) AS name_agg

  FROM @oldVocSchema.concept a
  LEFT JOIN @oldVocSchema.concept_relationship r
    ON a.concept_id = r.concept_id_1
   AND r.relationship_id IN ('Maps to', 'Maps to value')
   AND r.invalid_reason IS NULL
  LEFT JOIN @oldVocSchema.concept b
    ON b.concept_id = r.concept_id_2
  GROUP BY
      a.concept_id, a.vocabulary_id, a.concept_class_id, a.standard_concept,
      a.concept_code, a.concept_name
)

SELECT
  b.vocabulary_id                                AS vocabulary_id,
  b.concept_class_id,
  b.standard_concept,
  b.concept_code                                 AS source_code,
  b.concept_name                                 AS source_name,
  a.relationship_agg                             AS old_relat_agg,
  a.code_agg                                     AS old_code_agg,
  a.name_agg                                     AS old_name_agg,
  b.relationship_agg                             AS new_relat_agg,
  b.code_agg                                     AS new_code_agg,
  b.name_agg                                     AS new_name_agg,
  b.record_count
FROM old_map a
JOIN new_map b
  ON a.concept_id = b.concept_id
 AND (
      coalesce(a.code_agg, '')        != coalesce(b.code_agg, '')
   OR coalesce(a.relationship_agg, '') != coalesce(b.relationship_agg, '')
 )
ORDER BY b.record_count DESC
