-- Source concepts present in the old STCM that are missing entirely from the refreshed STCM
SELECT a.*
FROM @oldVocSchema.source_to_concept_map a
LEFT JOIN @scratchSchema.source_to_concept_map b
  ON  a.source_code         = b.source_code
  AND a.source_vocabulary_id = b.source_vocabulary_id
  AND b.invalid_reason IS NULL
WHERE a.invalid_reason IS NULL
  AND b.source_code IS NULL
