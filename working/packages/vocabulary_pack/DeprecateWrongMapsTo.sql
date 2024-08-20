CREATE OR REPLACE FUNCTION vocabulary_pack.DeprecateWrongMapsTo ()
RETURNS VOID AS
$BODY$
	/*
	1. Deprecates 'Maps to' and 'Maps to value' mappings to deprecated ('D'), upgraded ('U') or non-standard concepts
	2. Deprecates 'Maps to' and 'Maps to value' mappings if the source concept has standard_concept = 'S', unless it is to self
	*/
BEGIN
	UPDATE concept_relationship_stage crs
	SET valid_end_date = GREATEST(crs.valid_start_date, (
				SELECT MAX(v.latest_update) - 1
				FROM vocabulary v
				WHERE v.vocabulary_id IN (
						crs.vocabulary_id_1,
						crs.vocabulary_id_2
						)
				)),
		invalid_reason = 'D'
	WHERE crs.relationship_id IN (
			'Maps to',
			'Maps to value'
			)
		AND crs.invalid_reason IS NULL
		AND EXISTS (
			SELECT 1
			FROM vocabulary_pack.GetActualConceptInfo(crs.concept_code_2, crs.vocabulary_id_2) a
			WHERE a.invalid_reason IN (
					'U',
					'D'
					)
				OR a.standard_concept IS DISTINCT FROM 'S'
			);

	UPDATE concept_relationship_stage crs
	SET valid_end_date = GREATEST(crs.valid_start_date, (
				SELECT MAX(v.latest_update) - 1
				FROM vocabulary v
				WHERE v.vocabulary_id IN (
						crs.vocabulary_id_1,
						crs.vocabulary_id_2
						)
				)),
		invalid_reason = 'D'
	WHERE crs.relationship_id IN (
			'Maps to',
			'Maps to value'
			)
		AND crs.invalid_reason IS NULL
		AND EXISTS (
			SELECT 1
			FROM vocabulary_pack.GetActualConceptInfo(crs.concept_code_1, crs.vocabulary_id_1) a
			WHERE a.standard_concept = 'S'
			)
		AND crs.concept_code_1 <> crs.concept_code_2
		AND crs.vocabulary_id_1 <> crs.vocabulary_id_2;
END;
$BODY$
LANGUAGE 'plpgsql';