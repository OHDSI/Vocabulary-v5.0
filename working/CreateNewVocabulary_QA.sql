/**************************************************************************
* Copyright 2016 Observational Health Data Sciences and Informatics (OHDSI)
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
* 
* Authors: Christian Reich, Anna Ostropolets, Dmitry Dymshyts
* Date: 2016
**************************************************************************/
SELECT error_type,
	count(*)
FROM (
	--dublicates
	SELECT concept_Code,
		'Duplicate codes in concept_stage' AS error_type
	FROM concept_stage
	GROUP BY concept_Code
	HAVING count(*) > 1
	
	UNION ALL
	
	SELECT lower(concept_name),
		'Duplicate names in concept_stage (RxE)'
	FROM concept_stage
	WHERE vocabulary_id LIKE 'Rx%'
		AND invalid_reason IS NULL
		AND concept_name NOT LIKE '%...%'
	GROUP BY lower(concept_name)
	HAVING count(*) > 1
	
	UNION ALL
	
	--concept_relationship_stage
	SELECT concept_code_2,
		'Missing concept_code_1'
	FROM concept_relationship_stage
	WHERE concept_code_1 IS NULL
	
	UNION ALL
	
	SELECT concept_code_1,
		'Missing concept_code_2'
	FROM concept_relationship_stage
	WHERE concept_code_2 IS NULL
	
	UNION ALL
	
	SELECT DISTINCT relationship_id,
		'Wrong relationship_id in concept_relationship_stage'
	FROM concept_relationship_stage
	WHERE relationship_id NOT IN (
			SELECT relationship_id
			FROM relationship
			)
	
	UNION ALL
	
	SELECT concept_code,
		'Concepts from concept_relationship_stage missing in concept_stage'
	FROM concept_relationship_stage crs
	LEFT JOIN concept_stage cs ON cs.concept_code = crs.concept_code_1
	WHERE cs.concept_code IS NULL
		AND crs.vocabulary_id_1 = cs.vocabulary_id
	
	UNION ALL
	
	--relationship problems in concept_relationship_stage
	SELECT concept_code,
		'Deprecated concepts dont have necessary relationships'
	FROM concept_stage
	WHERE NOT EXISTS (
			SELECT 1
			FROM concept_stage c
			JOIN concept_relationship_stage cr ON cr.concept_code_1 = c.concept_code
			WHERE c.invalid_reason = 'D'
				AND relationship_id IN (
					'Maps to',
					'Concept replaced by'
					)
			)
		AND invalid_reason = 'D'
	
	UNION ALL
	
	--check if relationship 'Has standard brand' exsists only to brand names
	SELECT concept_code_1,
		'Has standard brand refers not to brand name'
	FROM concept_relationship_stage crs
	JOIN devv5.concept c ON concept_code_2 = concept_code
	WHERE relationship_id = 'Has standard brand'
		AND c.concept_class_id != 'Brand Name'
		AND c.vocabulary_id = 'RxNorm'
	
	UNION ALL
	
	--check if relationship 'Has standard form' exsists only to dose form;
	SELECT concept_code_1,
		'Has standard form refers not to dose form'
	FROM concept_relationship_stage crs
	JOIN devv5.concept c ON concept_code_2 = concept_code
	WHERE relationship_id = 'Has standard form'
		AND c.concept_class_id != 'Dose Form'
		AND c.vocabulary_id = 'RxNorm'
	
	UNION ALL
	
	--check if relationship 'Has standard ing' exsists only to ingredient
	SELECT concept_code_1,
		'Has standard ing refers not to ingredient'
	FROM concept_relationship_stage crs
	JOIN devv5.concept c ON concept_code_2 = concept_code
	WHERE relationship_id = 'Has standard ing'
		AND c.concept_class_id != 'Ingredient'
		AND c.vocabulary_id = 'RxNorm'
	
	UNION ALL
	
	SELECT DISTINCT concept_code_1,
		'Has tradename refers to wrong concept_class'
	FROM concept_relationship_stage crs
	LEFT JOIN concept_stage cs ON concept_code_2 = cs.concept_code
		AND crs.vocabulary_id_2 = cs.vocabulary_id
	LEFT JOIN concept_stage cs2 ON concept_code_1 = cs2.concept_code
		AND crs.vocabulary_id_1 = cs2.vocabulary_id
	WHERE relationship_id = 'Has tradename'
		AND (
			cs.concept_class_id NOT LIKE '%Branded%'
			OR cs2.concept_class_id NOT LIKE '%Clinical%'
			)
	
	UNION ALL
	
	--Should be only Component to Drug relationship
	SELECT DISTINCT concept_code_1,
		'Constitutes refers to wrong concept_class'
	FROM concept_relationship_stage crs
	LEFT JOIN concept_stage cs ON concept_code_2 = cs.concept_code
		AND crs.vocabulary_id_2 = cs.vocabulary_id
	LEFT JOIN concept_stage cs2 ON concept_code_1 = cs2.concept_code
		AND crs.vocabulary_id_1 = cs2.vocabulary_id
	WHERE relationship_id = 'Constitutes'
		AND (
			cs.concept_class_id NOT LIKE '%Drug%'
			OR cs2.concept_class_id NOT LIKE '%Comp%'
			)
	
	UNION ALL
	
	--concept_stage
	--important query - without it we'll ruin Generic_update
	SELECT DISTINCT concept_class_id,
		'Wrong concept_class_id in concept_stage'
	FROM concept_stage
	WHERE concept_class_id NOT IN (
			SELECT DISTINCT concept_class_id
			FROM devv5.concept_class
			)
	
	UNION ALL
	
	SELECT concept_code_1,
		'relationships RxNorm-RxNorm exist in concept_relationship_stage'
	FROM concept_relationship_stage
	WHERE vocabulary_id_1 = 'RxNorm'
		AND vocabulary_id_2 = 'RxNorm'
	
	UNION ALL
	
	--There should be no standard deprecated and updated concepts
	SELECT DISTINCT c.concept_code,
		'Wrong standard_concept'
	FROM concept_stage c
	JOIN concept_relationship_stage cr ON cr.concept_code_1 = c.concept_code
	WHERE c.standard_concept = 'S'
		AND (
			c.invalid_reason = 'U'
			OR c.invalid_reason = 'D'
			)
	
	UNION
	
	SELECT DISTINCT c.concept_code,
		'Wrong standard_concept'
	FROM concept_stage c
	JOIN concept_relationship_stage cr ON cr.concept_code_2 = c.concept_code
	WHERE c.standard_concept = 'S'
		AND (
			c.invalid_reason = 'U'
			OR c.invalid_reason = 'D'
			)
	
	UNION ALL
	
	--drug_strength
	SELECT DISTINCT drug_concept_code,
		'Impossible dosages'
	FROM drug_strength_stage
	WHERE (
			numerator_unit_concept_id = 8576
			AND denominator_unit_concept_id = 8587
			AND numerator_value / denominator_value > 1000
			)
		OR (
			numerator_unit_concept_id = 8576
			AND denominator_unit_concept_id = 8576
			AND numerator_value / denominator_value > 1
			)
	
	UNION ALL
	
	SELECT drug_concept_code,
		'missing unit'
	FROM drug_strength_stage
	WHERE (
			numerator_value IS NOT NULL
			AND numerator_unit_concept_id IS NULL
			)
		OR (
			denominator_value IS NOT NULL
			AND denominator_unit_concept_id IS NULL
			)
		OR (
			amount_value IS NOT NULL
			AND amount_unit_concept_id IS NULL
			)
	
	UNION ALL
	
	SELECT DISTINCT drug_concept_code,
		'Percents in wrong place'
	FROM drug_strength_stage
	WHERE (
			numerator_unit_concept_id = 8554
			AND denominator_unit_concept_id IS NOT NULL
			)
		OR AMOUNT_UNIT_CONCEPT_ID = 8554
	
	UNION ALL
	
	--same name in concept and concept_stage
	SELECT concept_name,
		'same name in concept and concept_stage'
	FROM concept_stage
	WHERE lower(concept_name) IN (
			SELECT concept_name
			FROM (
				SELECT lower(concept_name) AS concept_name
				FROM concept_stage
				WHERE vocabulary_id LIKE 'Rx%'
					AND invalid_reason IS NULL
					AND concept_name NOT LIKE '%...%'
				
				UNION ALL
				
				SELECT lower(concept_name)
				FROM concept
				WHERE vocabulary_id LIKE 'Rx%'
					AND invalid_reason IS NULL
					AND concept_name NOT LIKE '%...%'
				) AS s0
			GROUP BY concept_name
			HAVING count(*) > 1
			)
		AND vocabulary_id LIKE 'Rx%'
		AND invalid_reason IS NULL
		AND concept_name NOT LIKE '%...%'
	
	UNION ALL
	
	SELECT r.concept_code_1 AS concept_code,
		'Concept_replaced by many concepts' --count(*) 
	FROM concept_stage c1,
		concept_stage c2,
		concept_relationship_stage r
	WHERE c1.concept_code = r.concept_code_1
		AND c2.concept_code = r.concept_code_2
		AND c1.vocabulary_id = 'RxNorm Extension'
		AND c2.vocabulary_id = 'RxNorm Extension'
		AND relationship_id = 'Concept replaced by'
		AND r.invalid_reason IS NULL
	GROUP BY r.concept_code_1
	HAVING count(*) > 1
	ORDER BY 2 DESC
	) AS s1
GROUP BY error_type;