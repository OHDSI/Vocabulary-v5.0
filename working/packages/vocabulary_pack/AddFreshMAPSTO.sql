CREATE OR REPLACE FUNCTION vocabulary_pack.addfreshmapsto (
)
RETURNS void AS
$body$
/*
 Adds mapping from deprecated to fresh concepts
*/
BEGIN
	WITH to_be_upserted
	AS (
		WITH RECURSIVE rec AS (
				SELECT u.concept_code_1,
					u.vocabulary_id_1,
					u.concept_code_2,
					u.vocabulary_id_2,
					u.concept_code_1 AS root_concept_code_1,
					u.vocabulary_id_1 AS root_vocabulary_id_1,
					ARRAY [ ROW (u.concept_code_2, u.vocabulary_id_2) ] AS full_path
				FROM upgraded_concepts u
				
				UNION ALL
				
				SELECT uc.concept_code_1,
					uc.vocabulary_id_1,
					uc.concept_code_2,
					uc.vocabulary_id_2,
					r.root_concept_code_1,
					r.root_vocabulary_id_1,
					r.full_path || ROW(uc.concept_code_2, uc.vocabulary_id_2)
				FROM upgraded_concepts uc
				JOIN rec r ON r.concept_code_2 = uc.concept_code_1
					AND r.vocabulary_id_2 = uc.vocabulary_id_1
				WHERE ROW(uc.concept_code_2, uc.vocabulary_id_2) <> ALL (full_path) --excluding loops
				),
			upgraded_concepts AS (
				SELECT *
				FROM (
					SELECT DISTINCT concept_code_1,
						CASE 
							WHEN rel_id <> 6
								THEN FIRST_VALUE(concept_code_2) OVER (
										PARTITION BY concept_code_1 ORDER BY rel_id ROWS BETWEEN UNBOUNDED PRECEDING
												AND UNBOUNDED FOLLOWING
										)
							ELSE
								--we need only fresh 'Maps to' which contains in stage-tables (per each concept_code_1), but if we doesn't have them - take from base tables
								--fixed bug AVOF-307/AVOF-308
								CASE 
									WHEN in_base_tables = MIN(in_base_tables) OVER (PARTITION BY concept_code_1)
										THEN concept_code_2
									ELSE NULL
									END
							END AS concept_code_2,
						vocabulary_id_1,
						vocabulary_id_2
					FROM (
						SELECT crs.concept_code_1,
							crs.concept_code_2,
							crs.vocabulary_id_1,
							crs.vocabulary_id_2,
							--if concepts have more than one relationship_id, then we take only the one with following precedence
							CASE 
								WHEN crs.relationship_id = 'Concept replaced by'
									THEN 1
								WHEN crs.relationship_id = 'Concept same_as to'
									THEN 2
								WHEN crs.relationship_id = 'Concept alt_to to'
									THEN 3
								WHEN crs.relationship_id = 'Concept poss_eq to'
									THEN 4
								WHEN crs.relationship_id = 'Concept was_a to'
									THEN 5
								WHEN crs.relationship_id = 'Maps to'
									THEN 6
								END AS rel_id,
							0 AS in_base_tables
						FROM concept_relationship_stage crs
						WHERE crs.relationship_id IN (
								'Concept replaced by',
								'Concept same_as to',
								'Concept alt_to to',
								'Concept poss_eq to',
								'Concept was_a to',
								'Maps to'
								)
							AND crs.invalid_reason IS NULL
							AND (
								(
									(
										(
											crs.vocabulary_id_1 = crs.vocabulary_id_2
											AND crs.vocabulary_id_1 NOT IN (
												'RxNorm',
												'RxNorm Extension'
												)
											AND crs.vocabulary_id_2 NOT IN (
												'RxNorm',
												'RxNorm Extension'
												)
											)
										OR (
											crs.vocabulary_id_1 IN (
												'RxNorm',
												'RxNorm Extension'
												)
											AND crs.vocabulary_id_2 IN (
												'RxNorm',
												'RxNorm Extension'
												)
											)
										)
									AND crs.relationship_id <> 'Maps to'
									)
								OR crs.relationship_id = 'Maps to'
								)
							AND crs.concept_code_1 <> crs.concept_code_2
						
						UNION ALL
						
						--some concepts might be in 'base' tables
						SELECT c1.concept_code,
							c2.concept_code,
							c1.vocabulary_id,
							c2.vocabulary_id,
							6 AS rel_id,
							1 AS in_base_tables
						FROM concept c1,
							concept c2,
							concept_relationship r
						WHERE c1.concept_id = r.concept_id_1
							AND c2.concept_id = r.concept_id_2
							AND r.concept_id_1 <> r.concept_id_2
							AND r.invalid_reason IS NULL
							AND r.relationship_id = 'Maps to'
							--don't use already deprecated relationships
							AND NOT EXISTS (
								SELECT 1
								FROM concept_relationship_stage crs_int
								WHERE crs_int.concept_code_1 = c1.concept_code
									AND crs_int.vocabulary_id_1 = c1.vocabulary_id
									AND crs_int.concept_code_2 = c2.concept_code
									AND crs_int.vocabulary_id_2 = c2.vocabulary_id
									AND crs_int.relationship_id = r.relationship_id
									AND crs_int.invalid_reason IS NOT NULL
								)
						) AS s1
					) AS s2
				WHERE concept_code_2 IS NOT NULL
				)
		SELECT root_concept_code_1,
			concept_code_2,
			root_vocabulary_id_1,
			vocabulary_id_2,
			'Maps to'::VARCHAR AS relationship_id,
			(
				SELECT MAX(latest_update)
				FROM vocabulary
				WHERE latest_update IS NOT NULL
				) AS valid_start_date,
			TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
			NULL::VARCHAR AS invalid_reason
		FROM (
			SELECT DISTINCT root_concept_code_1,
				root_vocabulary_id_1,
				concept_code_2,
				vocabulary_id_2
			FROM rec r
			WHERE NOT EXISTS (
					/*same as oracle's CONNECT_BY_ISLEAF*/
					SELECT 1
					FROM rec r_int
					WHERE r_int.concept_code_1 = r.concept_code_2
						AND r_int.vocabulary_id_1 = r.vocabulary_id_2
					)
				AND EXISTS (
					SELECT 1
					FROM concept_relationship_stage crs
					WHERE crs.concept_code_1 = r.root_concept_code_1
						AND crs.vocabulary_id_1 = r.root_vocabulary_id_1
					)
			) AS s3
		),
	updated
	AS (
		UPDATE concept_relationship_stage crs
		SET invalid_reason = NULL,
			valid_end_date = tbu.valid_end_date
		FROM to_be_upserted tbu
		WHERE crs.concept_code_1 = tbu.root_concept_code_1
			AND crs.concept_code_2 = tbu.concept_code_2
			AND crs.vocabulary_id_1 = tbu.root_vocabulary_id_1
			AND crs.vocabulary_id_2 = tbu.vocabulary_id_2
			AND crs.relationship_id = tbu.relationship_id RETURNING crs.*
		)
	INSERT INTO concept_relationship_stage (
		concept_code_1,
		concept_code_2,
		vocabulary_id_1,
		vocabulary_id_2,
		relationship_id,
		valid_start_date,
		valid_end_date,
		invalid_reason
		)
	SELECT *
	FROM to_be_upserted tbu
	WHERE (
			tbu.root_concept_code_1,
			tbu.concept_code_2,
			tbu.root_vocabulary_id_1,
			tbu.vocabulary_id_2,
			tbu.relationship_id
			) NOT IN (
			SELECT up.concept_code_1,
				up.concept_code_2,
				up.vocabulary_id_1,
				up.vocabulary_id_2,
				up.relationship_id
			FROM updated up
			);
END;
$body$
LANGUAGE 'plpgsql'
VOLATILE
CALLED ON NULL INPUT
SECURITY INVOKER
COST 100;