-- Source concepts whose target concept(s) changed between the old and refreshed STCM
WITH old AS (
  SELECT
    source_code,
    source_code_description,
    source_vocabulary_id,
    concat_ws(
      '-',
      array_sort(collect_set(CAST(target_concept_id AS STRING)))
    ) AS target_concept_id_agg
  FROM @oldVocSchema.source_to_concept_map
  WHERE invalid_reason IS NULL
  GROUP BY source_code, source_code_description, source_vocabulary_id
),
new AS (
  SELECT
    source_code,
    source_code_description,
    source_vocabulary_id,
    concat_ws(
      '-',
      array_sort(collect_set(CAST(target_concept_id AS STRING)))
    ) AS target_concept_id_agg
  FROM @scratchSchema.source_to_concept_map
  WHERE invalid_reason IS NULL
  GROUP BY source_code, source_code_description, source_vocabulary_id
)
SELECT
  o.*,
  n.target_concept_id_agg AS new_target_concept_id_agg
FROM old o
JOIN new n
  ON  o.source_code         = n.source_code
  AND o.source_vocabulary_id = n.source_vocabulary_id
  AND o.target_concept_id_agg <> n.target_concept_id_agg
