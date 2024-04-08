SELECT DISTINCT c.concept_name as source_name,
        c.concept_code as source_code,
        c.concept_class_id,
        c.invalid_reason,
        c.domain_id,
        c.vocabulary_id,
		null as invalid_reason,
     	null as mapping_tool,
        null as mapping_source,
		'1' as confidence,
        'Maps to' as relationship_id,
       	null as relationship_preference,
       	'evaluation finding' as source,
       	null as comment,
		ii.concept_id,
		ii.concept_code,
    	ii.concept_name,
     	ii.concept_class_id AS target_concept_class_id,
      	ii.standard_concept AS target_standard_concept,
     	ii.invalid_reason AS target_invalid_reason,
     	ii.domain_id AS target_domain_id,
     	ii.vocabulary_id AS target_vocabulary_id,
     	'your_name' as mapper_id
FROM concept c
JOIN concept_relationship cr on cr.concept_id_1 = c.concept_id AND cr.relationship_id = 'Has interprets' AND cr.invalid_reason IS NULL
JOIN concept_relationship ccr on ccr.concept_id_1 = cr.concept_id_2 AND ccr.relationship_id = 'Maps to' AND cr.invalid_reason IS NULL
JOIN concept ii on ii.concept_id = ccr.concept_id_2
JOIN snomed_ancestor sa ON sa.descendant_concept_code::TEXT = c.concept_code
WHERE c.vocabulary_id = 'SNOMED'
	AND ii.standard_concept = 'S'
	AND sa.
;
SELECT * from devv5.concept_ancestor where descendant_concept_id = 4088515;
