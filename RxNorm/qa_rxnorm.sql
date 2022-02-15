/*Optional QA-script for RxNorm, must be executed after the load_stage but before the generic_update
Output:
info_level: (W)arning, (I)nformation, (E)rror
description: description
err_cnt: rows count
*/

CREATE TYPE dev_rxnorm.type_get_qa_rxnorm AS (
	info_level VARCHAR(1000),
	description VARCHAR(1000),
	err_cnt BIGINT
	);

CREATE OR REPLACE FUNCTION dev_rxnorm.get_qa_rxnorm ()
RETURNS SETOF dev_rxnorm.type_get_qa_rxnorm
AS $BODY$
SELECT *
FROM (
	--1. Concepts that have active distinctive relations to attributes that are no longer active;
	---Brand Names
	SELECT 'W' AS info_level,
		'Branded concepts that have active relations to deprecated Brand Names' AS description,
		COUNT(cs.concept_code) AS err_cnt
	FROM concept_stage cs
	JOIN concept_relationship_stage crs ON crs.concept_code_1 = cs.concept_code
		AND crs.vocabulary_id_1 = cs.vocabulary_id
		AND crs.relationship_id = 'Has brand name'
		AND crs.invalid_reason IS NULL
	JOIN concept_stage c2 ON c2.concept_code = crs.concept_code_2
		AND c2.vocabulary_id = crs.vocabulary_id_2
		AND c2.invalid_reason IS NOT NULL
	WHERE cs.vocabulary_id = 'RxNorm'
		AND cs.domain_id = 'Drug'
		AND cs.standard_concept = 'S'
		--Check if concept has anoter active attribute of same type in stage
		--May be caused by our mishandling of RxNorm: we need to Investigate why active relations to inactive attributes exist in the first place!
		AND NOT EXISTS (
			SELECT 1
			FROM concept_relationship_stage crs_int
			JOIN concept_stage cs_int ON cs_int.concept_code = crs_int.concept_code_2
				AND cs_int.vocabulary_id = crs_int.vocabulary_id_2
				AND cs_int.invalid_reason IS NULL
			WHERE crs_int.concept_code_1 = cs.concept_code
				AND crs_int.vocabulary_id_1 = cs.vocabulary_id
				AND crs_int.relationship_id = 'Has brand name'
				AND crs_int.invalid_reason IS NULL
			)
		--Check if concept has anoter active attribute of same type in basic
		AND NOT EXISTS (
			SELECT 1
			FROM concept_relationship cr_int
			JOIN concept c_int1 ON c_int1.concept_code = cs.concept_code
				AND c_int1.vocabulary_id = 'RxNorm'
				AND c_int1.concept_id = cr_int.concept_id_1
			JOIN concept c_int2 ON c_int2.concept_id = cr_int.concept_id_2
				AND c_int2.concept_code <> c2.concept_code /*is not the same concept: not deprecating this release*/
				AND c_int2.vocabulary_id = 'RxNorm'
				AND c_int2.invalid_reason IS NULL
			WHERE cr_int.relationship_id = 'Has brand name'
				AND cr_int.invalid_reason IS NULL
			)
	
	UNION ALL
	
	---Dose Form
	SELECT 'W',
		'Formulated concepts that have active relations to deprecated Dose Forms' AS description,
		COUNT(c.concept_code) AS err_cnt
	FROM concept c
	JOIN concept_relationship_stage crs ON crs.concept_code_1 = c.concept_code
		AND crs.vocabulary_id_1 = c.vocabulary_id
		AND crs.relationship_id = 'RxNorm has dose form'
		AND crs.invalid_reason IS NULL
	JOIN concept_stage c2 ON c2.concept_code = crs.concept_code_2
		AND c2.vocabulary_id = crs.vocabulary_id_2
		AND c2.invalid_reason IS NOT NULL
	WHERE c.vocabulary_id = 'RxNorm'
		AND c.domain_id = 'Drug'
		AND c.standard_concept = 'S'
		--Check if concept has anoter active attribute of same type in stage
		--May be caused by our mishandling of RxNorm: we need to Investigate why active relations to inactive attributes exist in the first place!
		AND NOT EXISTS (
			SELECT 1
			FROM concept_relationship_stage crs_int
			JOIN concept_stage cs_int ON cs_int.concept_code = crs_int.concept_code_2
				AND cs_int.vocabulary_id = crs_int.vocabulary_id_2
				AND cs_int.invalid_reason IS NULL
			WHERE crs_int.concept_code_1 = c.concept_code
				AND crs_int.vocabulary_id_1 = c.vocabulary_id
				AND crs_int.relationship_id = 'RxNorm has dose form'
				AND crs_int.invalid_reason IS NULL
			)
		--Check if concept has anoter active attribute of same type in basic
		AND NOT EXISTS (
			SELECT 1
			FROM concept_relationship cr_int
			JOIN concept c_int ON c_int.concept_id = cr_int.concept_id_2
				AND c_int.concept_code <> c2.concept_code /*is not the same concept: not deprecating this release*/
				AND c_int.vocabulary_id = 'RxNorm'
				AND c_int.invalid_reason IS NULL
			WHERE cr_int.relationship_id = 'RxNorm has dose form'
				AND cr_int.invalid_reason IS NULL
				AND cr_int.concept_id_1 = c.concept_id
			)
	
	UNION ALL
	
	--2. Broken drug_strength entries; concepts that omit specifying important units in denominator/numerator pairings etc.
	SELECT 'E',
		'Drug concepts with misformulated strength',
		COUNT(drug_concept_code)
	FROM drug_strength_stage dcs
	JOIN concept_stage cs ON cs.concept_code = dcs.drug_concept_code
		AND cs.vocabulary_id = 'RxNorm'
	WHERE dcs.vocabulary_id_1 = 'RxNorm'
		AND (
			COALESCE(amount_unit_concept_id, numerator_unit_concept_id) IS NOT NULL
			AND COALESCE(amount_value, numerator_value) IS NULL
			)
		OR (
			numerator_value IS NOT NULL
			AND denominator_unit_concept_id IS NULL
			AND numerator_unit_concept_id <> 8554 --%
			)
	
	UNION ALL
	
	--3. Components that duplicate existing RxNorm components; RxNorm components may specify differing precise ingredients but be completely identical otherwise. Known to have broken RxE in the past.
	SELECT 'W',
		'Identical strength entries for clinical components',
		COUNT(cs1.concept_code)
	FROM concept_stage cs1
	JOIN drug_strength_stage dcs1 ON dcs1.drug_concept_code = cs1.concept_code
	JOIN drug_strength_stage dcs2 ON dcs2.ingredient_concept_code = dcs1.ingredient_concept_code
		AND COALESCE(dcs2.amount_value, dcs2.numerator_value) = COALESCE(dcs1.amount_value, dcs1.numerator_value)
		AND COALESCE(dcs2.amount_unit_concept_id, dcs2.numerator_unit_concept_id) = COALESCE(dcs1.amount_unit_concept_id, dcs1.numerator_unit_concept_id)
		AND (
			COALESCE(dcs1.denominator_unit_concept_id, dcs2.denominator_unit_concept_id) IS NULL
			OR dcs1.denominator_unit_concept_id = dcs2.denominator_unit_concept_id
			)
		AND dcs2.drug_concept_code <> dcs1.drug_concept_code
	JOIN concept_stage cs2 ON cs2.concept_code = dcs2.drug_concept_code
		AND cs2.concept_class_id = 'Clinical Drug Comp'
		AND cs2.standard_concept = 'S'
		AND cs2.vocabulary_id = 'RxNorm'
		AND cs2.concept_code > cs1.concept_code --reduce duplicates (code1+code2 and code2+code1)
	WHERE cs1.concept_class_id = 'Clinical Drug Comp'
		AND cs1.standard_concept = 'S'
		AND cs1.vocabulary_id = 'RxNorm'
	
	UNION ALL
	
	--4. Drug concepts have entries in drug_strength with precise ingredients as content targets. Usually arise when concepts change class from Ingredient to Precise Ingredient.
	SELECT 'E',
		'Drug concepts have entries in drug_strength with precise ingredients as content targets',
		COUNT(cs.concept_code)
	FROM drug_strength_stage dcs
	JOIN concept_stage cs ON cs.concept_code = dcs.ingredient_concept_code
		AND cs.vocabulary_id = dcs.vocabulary_id_2
		AND cs.concept_class_id = 'Precise Ingredient'
	WHERE dcs.vocabulary_id_1 = 'RxNorm'
	
	UNION ALL
	
	--5. New concepts by class
	SELECT 'I',
		'New concepts by class: ' || cs.concept_class_id,
		COUNT(cs.concept_code)
	FROM concept_stage cs
	WHERE NOT EXISTS (
			SELECT 1
			FROM concept c_int
			WHERE c_int.concept_code = cs.concept_code
				AND c_int.vocabulary_id = 'RxNorm'
			)
		AND cs.invalid_reason IS NULL
		AND cs.vocabulary_id = 'RxNorm'
	GROUP BY cs.concept_class_id
	
	UNION ALL
	
	--6. Deprecated concepts by class
	SELECT 'I',
		'Deprecated concepts by class: ' || c.concept_class_id,
		COUNT(c.concept_code)
	FROM concept c
	WHERE NOT EXISTS (
			SELECT 1
			FROM concept_stage cs
			WHERE cs.concept_code = c.concept_code
				AND cs.vocabulary_id = c.vocabulary_id
			)
		AND c.invalid_reason IS NULL
		AND c.vocabulary_id = 'RxNorm'
	GROUP BY c.concept_class_id
	
	UNION ALL
	
	--7. Updated concepts by class
	SELECT 'I',
		'Updated concepts by class: ' || cs.concept_class_id,
		COUNT(cs.concept_code)
	FROM concept_stage cs
	JOIN concept c ON c.vocabulary_id = cs.vocabulary_id
		AND c.concept_code = cs.concept_code
		AND c.invalid_reason IS NULL
	WHERE cs.invalid_reason = 'U'
		AND cs.vocabulary_id = 'RxNorm'
	GROUP BY cs.concept_class_id
	
	UNION ALL
	
	--8. Present persistent relation between Ingredient and a Brand Name concept that are not enCOUNTered as a combination; may be erroneous or be caused by persistent valid relation to a deprecated concept.
	SELECT 'W',
		'Relation between Ingredient and a Brand Name is not supported by a standard branded component',
		COUNT(cs1.concept_code)
	FROM concept_stage cs1
	JOIN concept_relationship_stage crs ON crs.concept_code_1 = cs1.concept_code
		AND crs.vocabulary_id_1 = cs1.vocabulary_id
		AND crs.invalid_reason IS NULL
	JOIN concept_stage cs2 ON cs2.concept_code = crs.concept_code_2
		AND cs2.vocabulary_id = crs.vocabulary_id_2
		AND cs2.concept_class_id = 'Brand Name'
		AND cs2.vocabulary_id = 'RxNorm'
	WHERE cs1.standard_concept = 'S'
		AND cs1.concept_class_id = 'Ingredient'
		AND cs1.vocabulary_id = 'RxNorm'
		AND NOT EXISTS (
			SELECT
			FROM concept_stage cs_int
			JOIN concept_relationship_stage crs_int1 ON crs_int1.concept_code_1 = cs_int.concept_code
				AND crs_int1.vocabulary_id_1 = cs_int.vocabulary_id
				AND crs_int1.concept_code_2 = cs1.concept_code
				AND crs_int1.vocabulary_id_2 = cs1.vocabulary_id
				AND crs_int1.invalid_reason IS NULL
			JOIN concept_relationship_stage crs_int2 ON crs_int2.concept_code_1 = cs_int.concept_code
				AND crs_int2.vocabulary_id_1 = cs_int.vocabulary_id
				AND crs_int2.concept_code_2 = cs2.concept_code
				AND crs_int2.vocabulary_id_2 = cs2.vocabulary_id
				AND crs_int2.invalid_reason IS NULL
			WHERE cs_int.concept_class_id = 'Branded Drug Comp'
				AND cs_int.standard_concept = 'S'
			)
		AND NOT EXISTS (
			SELECT
			FROM concept c_int1
			JOIN concept_relationship cr1 ON cr1.concept_id_1 = c_int1.concept_id
				AND cr1.invalid_reason IS NULL
			--join on concept to get concept_id for existing Brand Name concept_id
			JOIN concept c_int2 ON c_int2.concept_id = cr1.concept_id_2
				AND c_int2.invalid_reason IS NULL
				AND c_int2.concept_code = cs2.concept_code
				AND c_int2.vocabulary_id = cs2.vocabulary_id
			JOIN concept_relationship cr2 ON cr2.concept_id_1 = cr1.concept_id_1
				AND cr2.invalid_reason IS NULL
			--join on concept to get concept_id for existing Ingredient concept_id
			JOIN concept c_int3 ON c_int3.concept_id = cr2.concept_id_2
				AND c_int3.standard_concept = 'S'
				AND c_int3.concept_class_id = 'Ingredient'
				AND c_int3.concept_code = cs1.concept_code
				AND c_int3.vocabulary_id = cs1.vocabulary_id
			WHERE c_int1.concept_class_id = 'Branded Drug Comp'
				AND c_int1.standard_concept = 'S'
			)
	
	UNION ALL
	
	--9. Usually shows Ingredients becoming precise Ingredients, possible vice versa. Known to have broken RxE in the past.
	SELECT 'I',
		'Concepts changed class: ' || c.concept_class_id || ' to ' || cs.concept_class_id,
		COUNT(c.concept_code)
	FROM concept_stage cs
	JOIN concept c ON c.concept_code = cs.concept_code
		AND cs.concept_class_id <> c.concept_class_id
		AND c.vocabulary_id = 'RxNorm'
	WHERE cs.vocabulary_id = 'RxNorm'
	GROUP BY cs.concept_class_id,
		c.concept_class_id
	
	UNION ALL
	
	SELECT 'E',
		'Multiple instances of the same ingredient per drug',
		COUNT(drug_concept_code)
	FROM drug_strength_stage
	WHERE vocabulary_id_1 = 'RxNorm'
	GROUP BY drug_concept_code,
		ingredient_concept_code
	HAVING COUNT(ingredient_concept_code) > 1
	
	UNION ALL
	
	--10. Known problems in basic tables that don't have corresponding entries in stage tables.
	SELECT 'W',
		'Errors in basic tables not adressed in current release: valid relations to invalid concepts',
		COUNT(c1.concept_id)
	FROM concept c1
	JOIN concept_relationship r ON r.concept_id_1 = c1.concept_id
		AND r.invalid_reason IS NULL
	JOIN concept c2 ON c2.concept_id = r.concept_id_2
		AND c2.invalid_reason IS NOT NULL
		AND c2.vocabulary_id = 'RxNorm'
	WHERE NOT EXISTS (
			SELECT 1
			FROM concept_relationship_stage crs
			WHERE crs.concept_code_1 = c1.concept_code
				AND crs.vocabulary_id_1 = c1.vocabulary_id
				AND crs.concept_code_2 = c2.concept_code
				AND crs.vocabulary_id_2 = c2.vocabulary_id
				AND crs.relationship_id = r.relationship_id
			)
		AND r.relationship_id NOT IN (
			'Concept replaces',
			'Mapped from'
			)
		--limit to relations between drugs and ingredients
		AND (
			c1.concept_class_id LIKE '%Drug%'
			OR c1.concept_class_id LIKE '%Pack%'
			)
		AND c1.standard_concept = 'S'
		AND c1.vocabulary_id = 'RxNorm'
		AND c2.concept_class_id IN (
			'Brand Name',
			'Dose Form',
			'Ingredient'
			)
	
	UNION ALL
	
	SELECT 'W',
		'Errors in basic tables not adressed in current release: valid relations to invalid concepts (excluding having correct relationships of the same type)',
		COUNT(c1.concept_id)
	FROM concept c1
	JOIN concept_relationship r ON r.concept_id_1 = c1.concept_id
		AND r.invalid_reason IS NULL
	JOIN concept c2 ON c2.concept_id = r.concept_id_2
		AND c2.invalid_reason IS NOT NULL
		AND c2.vocabulary_id = 'RxNorm'
		AND c2.concept_class_id IN (
			'Ingredient',
			'Brand Name',
			'Dose Form'
			) -- attribute concept
	WHERE r.relationship_id NOT IN (
			'Concept replaces',
			'Mapped from'
			)
		--check for duplication
		AND NOT EXISTS (
			SELECT 1
			FROM concept_relationship_stage crs
			WHERE crs.concept_code_1 = c1.concept_code
				AND crs.vocabulary_id_1 = c1.vocabulary_id
				AND crs.concept_code_2 = c2.concept_code
				AND crs.vocabulary_id_2 = c2.vocabulary_id
				AND crs.relationship_id = r.relationship_id
			)
		AND NOT EXISTS (
			SELECT 1
			FROM concept_relationship cr_int
			JOIN concept c_int ON c_int.concept_id = cr_int.concept_id_2
				AND c_int.invalid_reason IS NULL
			WHERE cr_int.concept_id_1 = r.concept_id_1
				AND cr_int.concept_id_2 <> r.concept_id_2
				AND cr_int.invalid_reason IS NULL
				AND cr_int.relationship_id = r.relationship_id
			)
		AND c1.standard_concept = 'S'
		AND c1.vocabulary_id = 'RxNorm'
		AND (
			c1.concept_class_id LIKE '%Drug%'
			OR c1.concept_class_id LIKE '%Pack%'
			) -- drug concept
	
	UNION ALL
	
	SELECT 'W',
		'Errors in basic tables not adressed in current release: Concept that served as a mapping target deprecates without replacement',
		COUNT(cs.concept_id)
	FROM concept_stage cs
	WHERE cs.standard_concept IS NULL
		AND EXISTS (
			SELECT 1
			FROM concept_relationship cr_int
			JOIN concept c_int ON c_int.concept_id = cr_int.concept_id_2
				AND c_int.standard_concept = 'S'
			WHERE cr_int.concept_id_1 <> cr_int.concept_id_2
				AND cr_int.relationship_id = 'Maps to'
				AND cr_int.invalid_reason IS NULL
				AND c_int.concept_code = cs.concept_code
				AND c_int.vocabulary_id = cs.vocabulary_id
			)
		AND NOT EXISTS (
			SELECT 1
			FROM concept_relationship_stage crs_int
			WHERE crs_int.relationship_id IN (
					'Concept replaced by',
					'Maps to'
					)
				AND crs_int.concept_code_1 = cs.concept_code
				AND crs_int.vocabulary_id_1 = cs.vocabulary_id
				AND crs_int.invalid_reason IS NULL
			)
	
	UNION ALL
	
	--11. Standard Drug concept without drug_strength_stage or pack_content_stage entries. Checks if concept is created without ingredient.
	SELECT 'E',
		'Standard Drug concept without drug_strength_stage or pack_content_stage entries',
		COUNT(cs.concept_code)
	FROM concept_stage cs
	WHERE cs.standard_concept = 'S'
		AND NOT EXISTS (
			SELECT 1
			FROM drug_strength_stage dss
			WHERE dss.drug_concept_code = cs.concept_code
			)
		AND NOT EXISTS (
			SELECT 1
			FROM pack_content_stage pcs
			WHERE pcs.pack_concept_code = cs.concept_code
			)
		--New concepts with those classes only get ds entries after concept_ancestor generation
		AND cs.concept_class_id NOT IN (
			'Ingredient',
			'Branded Drug Form',
			'Clinical Drug Form'
			)
	
	UNION ALL
	
	--12. Valid relation to non-standard ingredient with no alternatives -- hard Error
	SELECT 'E' AS info_level,
		'Concepts that have active relations to deprecated Ingredients with no alternative' AS description,
		COUNT(cs.concept_code) AS err_cnt
	FROM concept_stage cs
	JOIN concept_relationship_stage crs ON crs.concept_code_1 = cs.concept_code
		AND crs.vocabulary_id_1 = cs.vocabulary_id
		AND crs.relationship_id = 'Has ingredient'
		AND crs.invalid_reason IS NULL
	JOIN concept_stage c2 ON c2.concept_code = crs.concept_code_2
		AND c2.vocabulary_id = crs.vocabulary_id_2
		AND c2.standard_concept IS NULL
	WHERE cs.vocabulary_id = 'RxNorm'
		AND cs.domain_id = 'Drug'
		AND cs.standard_concept = 'S'
		--Check if concept has anoter active attribute of same type in stage
		--May be caused by our mishandling of RxNorm: we need to Investigate why active relations to inactive attributes exist in the first place!
		AND NOT EXISTS (
			SELECT 1
			FROM concept_relationship_stage crs_int
			JOIN concept_stage cs_int ON cs_int.concept_code = crs_int.concept_code_2
				AND cs_int.vocabulary_id = crs_int.vocabulary_id_2
				AND cs_int.standard_concept IS NOT NULL
			WHERE crs_int.concept_code_1 = cs.concept_code
				AND crs_int.vocabulary_id_1 = cs.vocabulary_id
				AND crs_int.relationship_id = 'Has ingredient'
				AND crs_int.invalid_reason IS NULL
			)
		--Check if concept has anoter active attribute of same type in basic
		AND NOT EXISTS (
			SELECT 1
			FROM concept_relationship cr_int
			JOIN concept c_int1 ON c_int1.concept_code = cs.concept_code
				AND c_int1.vocabulary_id = 'RxNorm'
				AND c_int1.concept_id = cr_int.concept_id_1
			JOIN concept c_int2 ON c_int2.concept_id = cr_int.concept_id_2
				AND c_int2.concept_code <> c2.concept_code
				AND c_int2.vocabulary_id = 'RxNorm'
				AND c_int2.standard_concept IS NOT NULL
			WHERE cr_int.relationship_id = 'Has ingredient'
				AND cr_int.invalid_reason IS NULL
			)
	
	UNION ALL
	
	--13. PI-promotion related reports
	SELECT 'I' AS info_level,
		'Artificially promoted Ingredients from Precise Ingredients' AS description,
		COUNT(DISTINCT pi_rxcui) AS err_cnt
	FROM pi_promotion
	
	UNION ALL
	
	SELECT 'I' AS info_level,
		'New RxNorm Extension concepts inisde hierarchy by class: ' || cs.concept_class_id AS description,
		COUNT(cs.concept_code) AS err_cnt
	FROM concept_stage cs
	WHERE cs.vocabulary_id = 'RxNorm Extension'
	GROUP BY cs.concept_class_id
	
	UNION ALL
	
	SELECT 'I' AS info_level,
		'Replaced relations due to creation of synthetic RxNorm Extension concepts' AS description,
		COUNT(crs.relationship_id)
	FROM concept_relationship_stage crs
	JOIN relationship r ON r.relationship_id = crs.relationship_id
		AND r.defines_ancestry = 1
	WHERE crs.vocabulary_id_1 = 'RxNorm'
		AND crs.vocabulary_id_2 = 'RxNorm Extension'
	) AS s0
WHERE err_cnt <> 0;
$BODY$
LANGUAGE 'sql'
STABLE PARALLEL SAFE SECURITY INVOKER
SET check_function_bodies = false; --pi_promotion is not our "base" table, so it might not be present at function compilation time