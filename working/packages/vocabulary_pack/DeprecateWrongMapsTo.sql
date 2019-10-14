CREATE OR REPLACE FUNCTION vocabulary_pack.deprecatewrongmapsto (
)
RETURNS void AS
$body$
/*
 Deprecates 'Maps to' mappings to deprecated ('D') and upgraded ('U') concepts
*/
BEGIN
	UPDATE concept_relationship_stage crs
	SET valid_end_date = GREATEST(valid_start_date, (
				SELECT MAX(latest_update) - 1
				FROM vocabulary
				WHERE vocabulary_id IN (
						crs.vocabulary_id_1,
						crs.vocabulary_id_2
						)
				)),
		invalid_reason = 'D'
	WHERE crs.relationship_id = 'Maps to'
		AND crs.invalid_reason IS NULL
		AND EXISTS (
			SELECT 1
			FROM (
				SELECT *
				FROM (
					--taking invalid_reason of concept_code_2, first from the concept_stage, next from the concept (if concept doesn't exists in the concept_stage)
					SELECT cs.concept_code,
						cs.vocabulary_id,
						cs.invalid_reason,
						1 AS source_id
					FROM concept_stage cs
					WHERE cs.concept_code = crs.concept_code_2
						AND cs.vocabulary_id = crs.vocabulary_id_2
					
					UNION ALL
					
					SELECT c.concept_code,
						c.vocabulary_id,
						c.invalid_reason,
						2 AS source_id
					FROM concept c
					WHERE c.concept_code = crs.concept_code_2
						AND c.vocabulary_id = crs.vocabulary_id_2
					) AS concepts
				ORDER BY source_id FETCH FIRST 1 ROW ONLY
				) AS concepts
			WHERE concepts.invalid_reason IN (
					'U',
					'D'
					)
			);
END;
$body$
LANGUAGE 'plpgsql'
VOLATILE
CALLED ON NULL INPUT
SECURITY INVOKER
COST 100;