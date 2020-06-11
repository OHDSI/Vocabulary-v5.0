--manual GPI names update [AVOF-2206]
UPDATE concept c
	SET concept_name = i.concept_name
	FROM (
		SELECT c1.concept_id,
			vocabulary_pack.CutConceptName(CONCAT (
					'No name provided',
					' - mapped to ' || STRING_AGG(c2.concept_name, ' | ' ORDER BY c2.concept_name)
					)) AS concept_name
		FROM concept c1
		LEFT JOIN concept_relationship cr ON cr.concept_id_1 = c1.concept_id
			AND cr.relationship_id = 'Maps to'
			AND cr.invalid_reason IS NULL
		LEFT JOIN concept c2 ON c2.concept_id = cr.concept_id_2
		WHERE c1.vocabulary_id='GPI'
			AND c1.concept_name = ' '
		GROUP BY c1.concept_id
		) i
	WHERE i.concept_id = c.concept_id;