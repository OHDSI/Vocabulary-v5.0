-- Source concepts that are new in the refreshed STCM (did not exist in the old STCM)
SELECT a.*
FROM @scratchSchema.source_to_concept_map a
LEFT JOIN @oldVocSchema.source_to_concept_map b
  USING (source_code, source_vocabulary_id)
WHERE a.invalid_reason IS NULL
  AND b.invalid_reason IS NULL
  AND b.source_code IS NULL
