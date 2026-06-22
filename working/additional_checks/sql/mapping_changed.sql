WITH source_vocabularies AS (
  SELECT explode(array(
    'ICD10', 'ICD10CM', 'CPT4', 'HCPCS', 'ICD9CM', 'ICD9Proc', 'ICD10PCS', 'ICDO3'
  )) AS vocabulary_id
),

new_map AS (
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
        sort_array(collect_list(named_struct(
          'rel', r.relationship_id,
          'code', b.concept_code,
          'vocab', b.vocabulary_id
        ))),
        x -> x.rel
      )
    ) AS relationship_agg,

    concat_ws(
      '-/-',
      transform(
        sort_array(collect_list(named_struct(
          'rel', r.relationship_id,
          'code', b.concept_code,
          'vocab', b.vocabulary_id,
          'val', b.concept_code
        ))),
        x -> x.val
      )
    ) AS code_agg,

    concat_ws(
      '-/-',
      transform(
        sort_array(collect_list(named_struct(
          'rel', r.relationship_id,
          'code', b.concept_code,
          'vocab', b.vocabulary_id,
          'val', b.concept_name
        ))),
        x -> x.val
      )
    ) AS name_agg,

    cc.record_count
  FROM @newVocSchema.concept a
  JOIN @resultSchema.achilles_result_concept_count cc
    ON cc.concept_id = a.concept_id
  JOIN source_vocabularies sv
    ON sv.vocabulary_id = a.vocabulary_id
  LEFT JOIN @newVocSchema.concept_relationship r
    ON a.concept_id = r.concept_id_1
   AND r.relationship_id IN ('Maps to', 'Maps to value')
   AND r.invalid_reason IS NULL
  LEFT JOIN @newVocSchema.concept b
    ON b.concept_id = r.concept_id_2
  WHERE cc.record_count > 100
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
        sort_array(collect_list(named_struct(
          'rel', r.relationship_id,
          'code', b.concept_code,
          'vocab', b.vocabulary_id
        ))),
        x -> x.rel
      )
    ) AS relationship_agg,

    concat_ws(
      '-/-',
      transform(
        sort_array(collect_list(named_struct(
          'rel', r.relationship_id,
          'code', b.concept_code,
          'vocab', b.vocabulary_id,
          'val', b.concept_code
        ))),
        x -> x.val
      )
    ) AS code_agg,

    concat_ws(
      '-/-',
      transform(
        sort_array(collect_list(named_struct(
          'rel', r.relationship_id,
          'code', b.concept_code,
          'vocab', b.vocabulary_id,
          'val', b.concept_name
        ))),
        x -> x.val
      )
    ) AS name_agg
  FROM @oldVocSchema.concept a
  JOIN source_vocabularies sv
    ON sv.vocabulary_id = a.vocabulary_id
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
  b.vocabulary_id AS vocabulary_id,
  b.concept_class_id,
  b.standard_concept,
  b.concept_code AS source_code,
  b.concept_name AS source_concept_name,
  a.relationship_agg AS old_relat_agg,
  a.code_agg AS old_code_agg,
  a.name_agg AS old_mapped_concept_name,
  b.relationship_agg AS new_relat_agg,
  b.code_agg AS new_code_agg,
  b.name_agg AS new_mapped_concept_name,
  b.record_count
FROM old_map a
JOIN new_map b
  ON a.concept_id = b.concept_id
AND (
  coalesce(a.code_agg, '') <> coalesce(b.code_agg, '')
  OR coalesce(a.relationship_agg, '') <> coalesce(b.relationship_agg, '')
)
ORDER BY a.vocabulary_id, a.concept_code, b.record_count DESC;

