CREATE OR REPLACE FUNCTION vocabulary_pack.addfreshmapstovalue (
)
RETURNS void AS
$body$
/*
 Adds mapping from deprecated to fresh concepts for the 'Maps to value' relationship_id
*/
BEGIN
	WITH to_be_upserted
	AS (
		WITH recursive hierarchy_concepts(ancestor_concept_id, descendant_concept_id, root_ancestor_concept_id, full_path) AS (
				SELECT ancestor_concept_id,
					descendant_concept_id,
					ancestor_concept_id AS root_ancestor_concept_id,
					ARRAY [descendant_concept_id] AS full_path
				FROM concepts
				
				UNION ALL
				
				SELECT c.ancestor_concept_id,
					c.descendant_concept_id,
					root_ancestor_concept_id,
					hc.full_path || c.descendant_concept_id AS full_path
				FROM concepts c
				JOIN hierarchy_concepts hc ON hc.descendant_concept_id = c.ancestor_concept_id
				WHERE c.descendant_concept_id <> ALL (full_path)
				),
			concepts AS (
				SELECT DISTINCT r.concept_id_1 AS ancestor_concept_id,
					first_value(r.concept_id_2) OVER (
						PARTITION BY r.concept_id_1 ORDER BY
							--if concepts have more than one relationship_id, then we take only the one with following precedence
							CASE 
								WHEN r.relationship_id = 'Concept replaced by'
									THEN 1
								WHEN r.relationship_id = 'Concept same_as to'
									THEN 2
								WHEN r.relationship_id = 'Concept alt_to to'
									THEN 3
								WHEN r.relationship_id = 'Concept poss_eq to'
									THEN 4
								WHEN r.relationship_id = 'Concept was_a to'
									THEN 5
								END ROWS BETWEEN UNBOUNDED PRECEDING
								AND UNBOUNDED FOLLOWING
						) AS descendant_concept_id
				FROM concept_relationship r
				JOIN concept c1 ON c1.concept_id = r.concept_id_1
				JOIN concept c2 ON c2.concept_id = r.concept_id_2
				WHERE r.relationship_id IN (
						'Concept replaced by',
						'Concept same_as to',
						'Concept alt_to to',
						'Concept poss_eq to',
						'Concept was_a to'
						)
					AND r.invalid_reason IS NULL
				)
		SELECT crs.concept_code_1,
			c_des.concept_code AS concept_code_2,
			crs.vocabulary_id_1,
			c_des.vocabulary_id AS vocabulary_id_2,
			'Maps to value' AS relationship_id,
			(
				SELECT MAX(latest_update)
				FROM vocabulary
				WHERE latest_update IS NOT NULL
				) AS valid_start_date,
			TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
			NULL::VARCHAR AS invalid_reason
		FROM hierarchy_concepts hc
		JOIN concept_relationship_stage crs ON crs.relationship_id = 'Maps to value'
			AND crs.invalid_reason IS NULL
		JOIN concept c2 ON c2.concept_code = crs.concept_code_2
			AND c2.vocabulary_id = crs.vocabulary_id_2
			AND c2.invalid_reason = 'U'
			AND c2.concept_id = hc.root_ancestor_concept_id
		JOIN concept c_des ON c_des.concept_id = hc.descendant_concept_id
		WHERE NOT EXISTS (
				/*same as oracle's CONNECT_BY_ISLEAF*/
				SELECT 1
				FROM hierarchy_concepts hc_int
				WHERE hc_int.ancestor_concept_id = hc.descendant_concept_id
				)
		),
	updated
	AS (
		UPDATE concept_relationship_stage crs
		SET invalid_reason = NULL,
			valid_end_date = tbu.valid_end_date
		FROM to_be_upserted tbu
		WHERE crs.concept_code_1 = tbu.concept_code_1
			AND crs.concept_code_2 = tbu.concept_code_2
			AND crs.vocabulary_id_1 = tbu.vocabulary_id_1
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
			tbu.concept_code_1,
			tbu.concept_code_2,
			tbu.vocabulary_id_1,
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