CREATE OR REPLACE FUNCTION vocabulary_pack.checkreplacementmappings (
)
RETURNS void AS
$body$
/*
 Working with 'Concept replaced by', 'Concept same_as to', etc mappings:
 1. Delete duplicate replacement mappings (one concept has multiply target concepts)
 2. Delete self-connected mappings ("A 'Concept replaced by' B" and "B 'Concept replaced by' A")
 3. Deprecate concepts if we have no active replacement record in the concept_relationship_stage
 4. Deprecate replacement records if target concept was depreceted
 5. Deprecate concepts if we have no active replacement record in the concept_relationship_stage (yes, again)
*/
BEGIN
	--Delete duplicate replacement mappings (one concept has multiply target concepts)
	DELETE
	FROM concept_relationship_stage
	WHERE (
			concept_code_1,
			relationship_id
			) IN (
			SELECT concept_code_1,
				relationship_id
			FROM concept_relationship_stage
			WHERE relationship_id IN (
					'Concept replaced by',
					'Concept same_as to',
					'Concept alt_to to',
					'Concept poss_eq to',
					'Concept was_a to'
					)
				AND invalid_reason IS NULL
				AND vocabulary_id_1 = vocabulary_id_2
			GROUP BY concept_code_1,
				relationship_id
			HAVING COUNT(DISTINCT concept_code_2) > 1
			);

	--Delete self-connected mappings ("A 'Concept replaced by' B" and "B 'Concept replaced by' A")
	DELETE
	FROM concept_relationship_stage crs
	WHERE EXISTS (
			SELECT 1
			FROM concept_relationship_stage cs1,
				concept_relationship_stage cs2
			WHERE cs1.invalid_reason IS NULL
				AND cs2.invalid_reason IS NULL
				AND cs1.concept_code_1 = cs2.concept_code_2
				AND cs1.concept_code_2 = cs2.concept_code_1
				AND cs1.vocabulary_id_1 = cs2.vocabulary_id_1
				AND cs2.vocabulary_id_2 = cs2.vocabulary_id_2
				AND cs1.vocabulary_id_1 = cs1.vocabulary_id_2
				AND cs1.relationship_id = cs2.relationship_id
				AND cs1.relationship_id IN (
					'Concept replaced by',
					'Concept same_as to',
					'Concept alt_to to',
					'Concept poss_eq to',
					'Concept was_a to'
					)
				AND crs.concept_code_1 = cs1.concept_code_1
				AND crs.concept_code_2 = cs1.concept_code_2
				AND crs.relationship_id = cs1.relationship_id
			);

	--Deprecate concepts if we have no active replacement record in the concept_relationship_stage
	UPDATE concept_stage cs
	SET valid_end_date = (
			SELECT v.latest_update - 1
			FROM VOCABULARY v
			WHERE v.vocabulary_id = cs.vocabulary_id
			),
		invalid_reason = 'D',
		standard_concept = NULL
	WHERE NOT EXISTS (
			SELECT 1
			FROM concept_relationship_stage crs
			WHERE crs.concept_code_1 = cs.concept_code
				AND crs.vocabulary_id_1 = cs.vocabulary_id
				AND crs.invalid_reason IS NULL
				AND crs.relationship_id IN (
					'Concept replaced by',
					'Concept same_as to',
					'Concept alt_to to',
					'Concept poss_eq to',
					'Concept was_a to'
					)
			)
		AND cs.invalid_reason = 'U';

	UPDATE concept_relationship_stage crs
	SET invalid_reason = 'D',
		valid_end_date = GREATEST(valid_start_date, (
				SELECT MAX(latest_update) - 1
				FROM vocabulary
				WHERE vocabulary_id IN (
						crs.vocabulary_id_1,
						crs.vocabulary_id_2
						)
				))
	WHERE (
			crs.concept_code_1,
			crs.vocabulary_id_1,
			crs.concept_code_2,
			crs.vocabulary_id_2,
			crs.relationship_id
			) IN (
			WITH RECURSIVE rec AS (
					SELECT u.concept_code_1,
						u.vocabulary_id_1,
						u.concept_code_2,
						u.vocabulary_id_2,
						u.relationship_id
					FROM upgraded_concepts u
					WHERE u.concept_code_2 IN (
							SELECT concept_code_2
							FROM upgraded_concepts
							WHERE invalid_reason = 'D'
							)
					
					UNION ALL
					
					SELECT uc.concept_code_1,
						uc.vocabulary_id_1,
						uc.concept_code_2,
						uc.vocabulary_id_2,
						uc.relationship_id
					FROM upgraded_concepts uc
					JOIN rec r ON r.concept_code_1 = uc.concept_code_2
					),
				upgraded_concepts AS (
					SELECT crs.concept_code_1,
						crs.vocabulary_id_1,
						crs.concept_code_2,
						crs.vocabulary_id_2,
						crs.relationship_id,
						CASE 
							WHEN COALESCE(cs.concept_code, c.concept_code) IS NULL
								THEN 'D'
							ELSE CASE 
									WHEN cs.concept_code IS NOT NULL
										THEN cs.invalid_reason
									ELSE c.invalid_reason
									END
							END AS invalid_reason
					FROM concept_relationship_stage crs
					LEFT JOIN concept_stage cs ON crs.concept_code_2 = cs.concept_code
						AND crs.vocabulary_id_2 = cs.vocabulary_id
					LEFT JOIN concept c ON crs.concept_code_2 = c.concept_code
						AND crs.vocabulary_id_2 = c.vocabulary_id
					WHERE crs.relationship_id IN (
							'Concept replaced by',
							'Concept same_as to',
							'Concept alt_to to',
							'Concept poss_eq to',
							'Concept was_a to'
							)
						AND crs.vocabulary_id_1 = crs.vocabulary_id_2
						AND crs.concept_code_1 <> crs.concept_code_2
						AND crs.invalid_reason IS NULL
					)
			SELECT DISTINCT *
			FROM rec
			);

	--Deprecate concepts if we have no active replacement record in the concept_relationship_stage (yes, again)
	UPDATE concept_stage cs
	SET valid_end_date = (
			SELECT v.latest_update - 1
			FROM VOCABULARY v
			WHERE v.vocabulary_id = cs.vocabulary_id
			),
		invalid_reason = 'D',
		standard_concept = NULL
	WHERE NOT EXISTS (
			SELECT 1
			FROM concept_relationship_stage crs
			WHERE crs.concept_code_1 = cs.concept_code
				AND crs.vocabulary_id_1 = cs.vocabulary_id
				AND crs.invalid_reason IS NULL
				AND crs.relationship_id IN (
					'Concept replaced by',
					'Concept same_as to',
					'Concept alt_to to',
					'Concept poss_eq to',
					'Concept was_a to'
					)
			)
		AND cs.invalid_reason = 'U';
END;
$body$
LANGUAGE 'plpgsql'
VOLATILE
CALLED ON NULL INPUT
SECURITY INVOKER
COST 100;