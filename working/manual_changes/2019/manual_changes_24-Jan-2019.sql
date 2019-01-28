--additional fix fro ICD10CM (AVOF-1433)
UPDATE concept_relationship r
SET invalid_reason = NULL,
	valid_end_date = to_date('20991231', 'yyyymmdd')
FROM (
	SELECT r.*
	FROM concept_relationship r
	JOIN concept c1 ON c1.concept_id = r.concept_id_1
		AND c1.vocabulary_id = 'ICD10CM'
	JOIN concept c2 ON c2.concept_id = r.concept_id_2
		AND c2.vocabulary_id = 'ICD10CM'
		AND r.relationship_id IN (
			'Concept replaced by',
			'Concept replaces'
			)
		AND r.invalid_reason = 'D'
		AND (
			(
				r.relationship_id = 'Concept replaced by'
				AND c2.invalid_reason IS NULL
				)
			OR (
				r.relationship_id = 'Concept replaces'
				AND c1.invalid_reason IS NULL
				)
			)
	) s0
WHERE s0.concept_id_1 = r.concept_id_1
	AND s0.concept_id_2 = r.concept_id_2
	AND s0.relationship_id = r.relationship_id;

UPDATE concept c
SET concept_code = upper(concept_code)
WHERE c.vocabulary_id = 'ICD10CM'
	AND c.concept_code ~ '[a-x]';