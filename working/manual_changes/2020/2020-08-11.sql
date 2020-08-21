--revert back wrongly deprecated KDC concepts [AVOF-2747]
UPDATE concept_relationship r
SET invalid_reason = NULL,
	valid_end_date = TO_DATE('20991231', 'yyyymmdd')
FROM concept c
WHERE c.concept_id = r.concept_id_1
	AND r.concept_id_1 = r.concept_id_2
	AND r.relationship_id IN (
		'Maps to',
		'Mapped from'
		)
	AND r.invalid_reason = 'D'
	AND c.invalid_reason = 'D'
	AND c.domain_id = 'Device'
	AND c.vocabulary_id = 'KDC';

UPDATE concept
SET invalid_reason = NULL,
	valid_end_date = TO_DATE('20991231', 'yyyymmdd')
WHERE vocabulary_id = 'KDC'
	AND domain_id = 'Drug'
	AND invalid_reason = 'D';

UPDATE concept
SET invalid_reason = NULL,
	standard_concept = 'S',
	valid_end_date = TO_DATE('20991231', 'yyyymmdd')
WHERE vocabulary_id = 'KDC'
	AND domain_id = 'Device'
	AND invalid_reason = 'D';