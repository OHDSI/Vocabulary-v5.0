CREATE OR REPLACE FUNCTION vocabulary_pack.deleteambiguousmapsto (
)
RETURNS void AS
$body$
/*
 Deprecate ambiguous 'Maps to' mappings following by rules:
 1. if we have 'true' mappings to Ingredient or Clinical Drug Comp, then deprecate all others mappings
 2. if we don't have 'true' mappings, then leave only one fresh mapping
 3. if we have 'true' mappings to Ingredients AND Clinical Drug Comps, then deprecate mappings to Ingredients, which have mappings to Clinical Drug Comp
*/
BEGIN
	ANALYZE concept_relationship_stage;

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
			concept_code_1,
			concept_code_2,
			vocabulary_id_1,
			vocabulary_id_2
			) IN (
			WITH t AS (
					SELECT rid,
						concept_code_1,
						concept_code_2,
						vocabulary_id_1,
						vocabulary_id_2,
						pseudo_class_id,
						rn,
						MIN(pseudo_class_id) OVER (
							PARTITION BY concept_code_1,
							vocabulary_id_1
							) have_true_mapping,
						has_rel_with_comp
					FROM (
						SELECT cs.ctid rid,
							concept_code_1,
							concept_code_2,
							vocabulary_id_1,
							vocabulary_id_2,
							CASE 
								WHEN c.concept_class_id IN (
										'Ingredient',
										'Clinical Drug Comp'
										)
									THEN 1
								ELSE 2
								END pseudo_class_id,
							ROW_NUMBER() OVER (
								PARTITION BY concept_code_1,
								vocabulary_id_1 ORDER BY cs.valid_start_date DESC, --fresh mappings first
									CASE vocabulary_id_2
										WHEN 'RxNorm'
											THEN 1
										ELSE 2
										END, --mappings to RxNorm first
									c.concept_id DESC
								) rn,
							(
								SELECT 1
								FROM (
									SELECT concept_code_1,
										concept_code_2,
										vocabulary_id_1,
										vocabulary_id_2
									FROM concept_relationship_stage
									WHERE invalid_reason IS NULL
										AND relationship_id = 'RxNorm ing of'
									) cr_int,
									(
										SELECT concept_code_1,
											concept_code_2,
											vocabulary_id_1,
											vocabulary_id_2
										FROM concept_relationship_stage
										WHERE invalid_reason IS NULL
											AND relationship_id = 'Maps to'
										) crs_int,
									(
										(
											SELECT DISTINCT concept_code,
												vocabulary_id,
												first_value(concept_class_id) OVER (
													PARTITION BY concept_code ORDER BY table_type
													) AS concept_class_id
											FROM (
												SELECT cs.concept_id,
													cs.domain_id,
													cs.vocabulary_id,
													cs.concept_class_id,
													cs.concept_code,
													cs.valid_start_date,
													1 AS table_type
												FROM concept_stage cs
												WHERE cs.domain_id = 'Drug'
													AND cs.concept_class_id = 'Clinical Drug Comp'
													AND cs.vocabulary_id LIKE 'Rx%'
												) AS s0
											)
										) c_int
								WHERE cr_int.concept_code_1 = c.concept_code
									AND cr_int.vocabulary_id_1 = c.vocabulary_id
									AND c.concept_class_id = 'Ingredient'
									AND crs_int.concept_code_1 = cs.concept_code_1
									AND crs_int.vocabulary_id_1 = cs.vocabulary_id_1
									AND crs_int.concept_code_2 = c_int.concept_code
									AND crs_int.vocabulary_id_2 = c_int.vocabulary_id
									AND cr_int.concept_code_2 = c_int.concept_code
									AND cr_int.vocabulary_id_2 = c_int.vocabulary_id
								) has_rel_with_comp
						FROM concept_relationship_stage cs,
							(
								SELECT DISTINCT concept_code,
									vocabulary_id,
									first_value(concept_id) OVER (
										PARTITION BY concept_code,
										vocabulary_id ORDER BY table_type
										) AS concept_id,
									first_value(domain_id) OVER (
										PARTITION BY concept_code,
										vocabulary_id ORDER BY table_type
										) AS domain_id,
									first_value(concept_class_id) OVER (
										PARTITION BY concept_code ORDER BY table_type
										) AS concept_class_id,
									first_value(valid_start_date) OVER (
										PARTITION BY concept_code,
										vocabulary_id ORDER BY table_type
										) AS valid_start_date
								FROM (
									SELECT cs.concept_id,
										cs.domain_id,
										cs.vocabulary_id,
										cs.concept_class_id,
										cs.concept_code,
										cs.valid_start_date,
										1 AS table_type
									FROM concept_stage cs
									WHERE cs.domain_id = 'Drug'
										AND cs.vocabulary_id LIKE 'Rx%'
									
									UNION ALL
									
									SELECT c_i.concept_id,
										c_i.domain_id,
										c_i.vocabulary_id,
										c_i.concept_class_id,
										c_i.concept_code,
										c_i.valid_start_date,
										2 AS table_type
									FROM concept c_i
									WHERE c_i.domain_id = 'Drug'
										AND c_i.vocabulary_id LIKE 'Rx%'
									) AS s0
								) c
						WHERE relationship_id = 'Maps to'
							AND cs.invalid_reason IS NULL
							AND cs.concept_code_2 = c.concept_code
							AND cs.vocabulary_id_2 = c.vocabulary_id
							AND cs.vocabulary_id_2 LIKE 'Rx%'
						) AS s1
					)
			SELECT concept_code_1,
				concept_code_2,
				vocabulary_id_1,
				vocabulary_id_2
			FROM t
			WHERE have_true_mapping = 1
				AND pseudo_class_id = 2 --if we have 'true' mappings to Ingredients or Clinical Drug Comps (pseudo_class_id=1), then delete all others mappings (pseudo_class_id=2)
			
			UNION ALL
			
			SELECT concept_code_1,
				concept_code_2,
				vocabulary_id_1,
				vocabulary_id_2
			FROM t
			WHERE have_true_mapping <> 1
				AND rn > 1 --if we don't have 'true' mappings, then leave only one fresh mapping
			
			UNION ALL
			
			SELECT concept_code_1,
				concept_code_2,
				vocabulary_id_1,
				vocabulary_id_2
			FROM t
			WHERE has_rel_with_comp = 1 --if we have 'true' mappings to Ingredients AND Clinical Drug Comps, then delete mappings to Ingredients, which have mappings to Clinical Drug Comp
			)
		AND relationship_id = 'Maps to'
		AND invalid_reason IS NULL;

END;
$body$
LANGUAGE 'plpgsql'
VOLATILE
CALLED ON NULL INPUT
SECURITY INVOKER
COST 100;