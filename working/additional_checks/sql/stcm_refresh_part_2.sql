--get the rows where target concepts can't be updated or mapped automatically for manual mapping and review
--note, if a source concept has several mappings, and you want to update one of them, please put all mappings (even those you don't touch) in this manual table
SELECT s.*, c.concept_id, c.concept_code, c.concept_name, c.vocabulary_id, c.domain_id, arc.descendant_record_count
FROM @scratchSchema.source_to_concept_map s
JOIN concept c ON c.concept_id = s.target_concept_id AND COALESCE(c.standard_concept, 'C') = 'C' -- when it's null or C it is a mistake
LEFT JOIN @resultSchema.achilles_result_concept_count arc ON target_concept_id = arc.concept_id --left join is used since routes and units aren't captured by the achilles results concept count
WHERE s.target_concept_id != 0
  AND s.invalid_reason IS NULL
ORDER BY arc.descendant_record_count DESC
