-- Duplicate rows in the refreshed STCM (same source_code + vocabulary + target)
SELECT *
FROM @scratchSchema.source_to_concept_map
WHERE (source_code, source_vocabulary_id, target_concept_id) IN (
  SELECT source_code, source_vocabulary_id, target_concept_id
  FROM @scratchSchema.source_to_concept_map
  WHERE invalid_reason IS NULL
    AND source_vocabulary_id != 'JNJ_PMR_OBS_CODE' -- exclusion: same names mean different things in Premier - low priority
  GROUP BY source_code, source_vocabulary_id, target_concept_id
  HAVING COUNT(1) > 1
)
