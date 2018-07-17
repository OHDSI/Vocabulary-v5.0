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
* Date: 2017
**************************************************************************/
SELECT error_type,
	COUNT(*)
FROM (
	SELECT drug_concept_id,
		'Empty strength' AS error_type
	FROM drug_strength
	WHERE coalesce(amount_value, numerator_value) IS NULL
	
	UNION ALL
	
	SELECT drug_concept_id,
		'missing unit'
	FROM drug_strength
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
	
	SELECT drug_concept_id,
		'Impossible dosages'
	FROM drug_strength
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
	
	SELECT drug_concept_id,
		'Percents in wrong place or have denominator'
	FROM drug_strength
	WHERE (
			numerator_unit_concept_id = 8554
			AND denominator_unit_concept_id IS NOT NULL
			)
		OR amount_unit_concept_id = 8554
	
	UNION ALL
	
	SELECT concept_id,
		'solid forms have denominator'
	FROM concept
	JOIN drug_strength ON drug_concept_id = concept_id
		AND (
			concept_name LIKE '%Tablet%'
			OR concept_name LIKE '%Capsule%'
			OR concept_name LIKE '%Lozenge%'
			OR concept_name LIKE '%Pellet%'
			) -- solid forms defined by their forms 
		AND numerator_value IS NOT NULL
	
	UNION ALL
	
	SELECT concept_id,
		'ML in amount/numerator'
	FROM concept
	JOIN drug_strength ON drug_concept_id = concept_id
	WHERE numerator_unit_concept_id = 8587
		OR amount_unit_concept_id = 8587
	
	UNION ALL
	
	SELECT an_id,
		'wrong ancestor RxE to descedant RxNorm'
	FROM (
		SELECT a.min_levels_of_separation AS a_min,
			an.concept_id AS an_id,
			an.concept_name AS an_name,
			an.vocabulary_id AS an_vocab,
			an.domain_id AS an_domain,
			an.concept_class_id AS an_class,
			de.concept_id AS de_id,
			de.concept_name AS de_name,
			de.vocabulary_id AS de_vocab,
			de.domain_id AS de_domain,
			de.concept_class_id AS de_class
		FROM concept an
		JOIN concept_ancestor a ON a.ancestor_concept_id = an.concept_id
			AND an.vocabulary_id = 'RxNorm Extension'
		JOIN concept de ON de.concept_id = a.descendant_concept_id
			AND de.vocabulary_id = 'RxNorm'
		) AS s0
	
	UNION ALL
	
	SELECT concept_id,
		'Packs missing in pack content'
	FROM concept
	WHERE (
			concept_class_id LIKE '%Pack%'
			OR (
				concept_class_id = 'Marketed Product'
				AND concept_name LIKE '%}% Pack %'
				)
			)
		AND vocabulary_id = 'RxNorm Extension'
		AND invalid_reason IS NULL
		AND concept_id NOT IN (
			SELECT pack_concept_id
			FROM pack_content
			)
	
	UNION ALL
	
	SELECT drug_concept_id,
		artefact
	FROM (
		SELECT DISTINCT drug_concept_id,
			ingredient_concept_id,
			CASE 
				WHEN a.valid_start_date IS NULL
					THEN 'three-legged'
				WHEN ds.valid_start_date IS NULL
					THEN 'cuckoo'
				END AS artefact
		FROM (
			SELECT de.concept_id AS drug_concept_id,
				an.concept_id AS ingredient_concept_id,
				an.valid_start_date
			FROM concept_ancestor a
			JOIN concept an ON a.ancestor_concept_id = an.concept_id
				AND an.vocabulary_id IN (
					'RxNorm',
					'RxNorm Extension'
					)
				AND an.concept_class_id = 'Ingredient'
			JOIN concept de ON de.concept_id = a.descendant_concept_id
				AND de.vocabulary_id IN (
					'RxNorm',
					'RxNorm Extension'
					)
				AND de.concept_class_id NOT IN (
					'Ingredient',
					'Clinical Dose Group',
					'Branded Dose Group'
					)
				AND de.concept_class_id NOT LIKE '%Pack%'
				AND de.concept_name NOT LIKE '% } Pack%'
			WHERE an.concept_id != de.concept_id
			) a
		FULL JOIN (
			SELECT ingredient_concept_id,
				drug_concept_id,
				valid_start_date
			FROM drug_strength
			WHERE ingredient_concept_id != drug_concept_id
			) ds USING (
				drug_concept_id,
				ingredient_concept_id
				)
		JOIN concept d ON concept_id = drug_concept_id
		WHERE ds.valid_start_date IS NULL
		) AS s1
	
	UNION ALL
	
	SELECT concept_id,
		'orphans'
	FROM concept
	WHERE concept_id IN (
			SELECT descendant_concept_id
			FROM concept_ancestor
			GROUP BY descendant_concept_id
			HAVING COUNT(*) = 1
			)
		AND concept_class_id != 'Ingredient'
		AND vocabulary_id = 'RxNorm Extension'
	) AS s2
GROUP BY error_type;