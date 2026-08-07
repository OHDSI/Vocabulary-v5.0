-- Concepts in the refreshed STCM that map to non-standard targets
SELECT s.*
FROM @scratchSchema.source_to_concept_map s
JOIN concept c
  ON c.concept_id = s.target_concept_id
 AND (c.standard_concept IS NULL OR c.standard_concept = 'C')
 AND s.target_concept_id != 0
 AND s.invalid_reason IS NULL
