CREATE OR REPLACE FUNCTION vocabulary_pack.DeleteAmbiguousMAPSTO ()
RETURNS VOID AS
$BODY$
	/*
	 Deprecate ambiguous 'Maps to' mappings following by rules:
	 1. if we have 'true' mappings to Ingredient or Clinical Drug Comp, then deprecate all others mappings
	 2. if we don't have 'true' mappings, then leave only one fresh mapping
	 3. if we have 'true' mappings to Ingredients AND Clinical Drug Comps, then deprecate mappings to Ingredients, which have mappings to Clinical Drug Comp
	*/
BEGIN
	ANALYZE concept_relationship_stage, concept_stage;
	
	CREATE TEMP TABLE has_rel_with_comp ON COMMIT DROP AS
		SELECT crs_int2.concept_code_1,
			crs_int2.vocabulary_id_1,
			crs_int1.concept_code_1 AS concept_code_2,
			crs_int1.vocabulary_id_1 AS vocabulary_id_2
		FROM concept_relationship_stage crs_int1
		JOIN concept_relationship_stage crs_int2 ON crs_int2.concept_code_2 = crs_int1.concept_code_2
			AND crs_int2.vocabulary_id_2 = crs_int1.vocabulary_id_2
			AND crs_int2.relationship_id = 'Maps to'
			AND crs_int2.invalid_reason IS NULL
		JOIN concept_stage cs_int ON cs_int.concept_code = crs_int1.concept_code_2
			AND cs_int.vocabulary_id = crs_int1.vocabulary_id_2
			AND cs_int.domain_id = 'Drug'
			AND cs_int.concept_class_id = 'Clinical Drug Comp'
			AND cs_int.vocabulary_id LIKE 'Rx%'
		WHERE crs_int1.relationship_id = 'RxNorm ing of'
			AND crs_int1.invalid_reason IS NULL;

	CREATE TEMP TABLE ambiguous_mappings ON COMMIT DROP AS
		WITH mappings AS (
			SELECT s1.concept_code_1,
				s1.concept_code_2,
				s1.vocabulary_id_1,
				s1.vocabulary_id_2,
				s1.pseudo_class_id,
				s1.rn,
				MIN(s1.pseudo_class_id) OVER (
					PARTITION BY s1.concept_code_1,
					s1.vocabulary_id_1
					) have_true_mapping,
				s1.concept_class_id
			FROM (
				SELECT crs.concept_code_1,
					crs.concept_code_2,
					crs.vocabulary_id_1,
					crs.vocabulary_id_2,
					CASE 
						WHEN a.concept_class_id IN (
								'Ingredient',
								'Clinical Drug Comp'
								)
							THEN 1
						ELSE 2
						END pseudo_class_id,
					ROW_NUMBER() OVER (
						PARTITION BY crs.concept_code_1,
						crs.vocabulary_id_1 ORDER BY crs.valid_start_date DESC, --fresh mappings first
							CASE crs.vocabulary_id_2
								WHEN 'RxNorm'
									THEN 1
								ELSE 2
								END, --mappings to RxNorm first
							a.concept_id DESC,
							crs.concept_code_2 --if no concept_id found
						) rn,
					a.concept_class_id
				FROM concept_relationship_stage crs
				CROSS JOIN vocabulary_pack.GetActualConceptInfo(crs.concept_code_2, crs.vocabulary_id_2) a
				WHERE crs.relationship_id = 'Maps to'
					AND crs.invalid_reason IS NULL
					AND crs.vocabulary_id_2 LIKE 'Rx%'
					AND a.domain_id = 'Drug'
				) AS s1
			)
		SELECT m.concept_code_1,
			m.concept_code_2,
			m.vocabulary_id_1,
			m.vocabulary_id_2
		FROM mappings m
		WHERE m.have_true_mapping = 1
			AND m.pseudo_class_id = 2 --if we have 'true' mappings to Ingredients or Clinical Drug Comps (pseudo_class_id=1), then deprecate all others mappings (pseudo_class_id=2)

		UNION ALL

		SELECT m.concept_code_1,
			m.concept_code_2,
			m.vocabulary_id_1,
			m.vocabulary_id_2
		FROM mappings m
		WHERE m.have_true_mapping <> 1
			AND m.rn > 1 --if we don't have 'true' mappings, then leave only one fresh mapping

		UNION ALL

		SELECT m.concept_code_1,
			m.concept_code_2,
			m.vocabulary_id_1,
			m.vocabulary_id_2
		FROM mappings m
		WHERE m.concept_class_id = 'Ingredient'
		--if we have 'true' mappings to Ingredients AND Clinical Drug Comps, then deprecate mappings to Ingredients, which have mappings to Clinical Drug Comp
		AND EXISTS (
			SELECT 1
			FROM has_rel_with_comp h
			WHERE h.concept_code_1 = m.concept_code_1
				AND h.vocabulary_id_1 = m.vocabulary_id_1
				AND h.concept_code_2 = m.concept_code_2
				AND h.vocabulary_id_2 = m.vocabulary_id_2
		);

	UPDATE concept_relationship_stage crs
	SET invalid_reason = 'D',
		valid_end_date = GREATEST(crs.valid_start_date, (
				SELECT MAX(v.latest_update) - 1
				FROM vocabulary v
				WHERE v.vocabulary_id IN (
						crs.vocabulary_id_1,
						crs.vocabulary_id_2
						)
				))
	FROM ambiguous_mappings am
	WHERE crs.concept_code_1 = am.concept_code_1
		AND crs.concept_code_2 = am.concept_code_2
		AND crs.vocabulary_id_1 = am.vocabulary_id_1
		AND crs.vocabulary_id_2 = am.vocabulary_id_2
		AND crs.relationship_id = 'Maps to'
		AND crs.invalid_reason IS NULL;

	--if the function is executed in a transaction, then by the time of the next call the temp table will exist
	DROP TABLE has_rel_with_comp, ambiguous_mappings;
END;
$BODY$
LANGUAGE 'plpgsql';