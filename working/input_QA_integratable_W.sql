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
* Authors: Christian Reich, Dmitry Dymshyts, Anna Ostropolets
* Date: 2016
**************************************************************************/ 
--this algorithm shows you concept_code and an error type related to this code
--for ds_stage
with s0 as
(

	SELECT drug_concept_code,
		'dosage with ml: only allowed for gasseous substances' as error_type,
		'ds_stage' as affected_table
	FROM ds_stage
	join relationship_to_concept on
		concept_code_1 in (numerator_unit,amount_unit) and
		concept_id_2 = 8587

		UNION ALL
	
	select drug_concept_code,
		'Redundant box_size equal to 1 in ds_stage',
		'ds_stage'
	from ds_stage
	where box_size = 1
	
		
	union all

	SELECT drug_concept_code,
		'homeopathic units in amounts, need to check' as error_type,
		'ds_stage' as affected_table
	FROM ds_stage ds
	JOIN relationship_to_concept rtc ON (amount_unit = rtc.concept_code_1 or numerator_unit = rtc.concept_code_1)
		AND rtc.concept_id_2 IN (
			9324,
			9325
			)
	
	UNION ALL
	
	--wrong dosages > 1000
	SELECT drug_concept_code,
		'Suspicious dosages > 1000 mg/ml',
		'ds_stage'
	FROM ds_stage
	WHERE (
			LOWER(numerator_unit) IN ('mg')
			AND LOWER(denominator_unit) IN (
				'ml',
				'g'
				)
			OR LOWER(numerator_unit) IN ('g')
			AND LOWER(denominator_unit) IN ('l')
			)
		AND numerator_value / coalesce(denominator_value, 1) > 1000
	
	UNION ALL
	
	--% in ds_stage 
	SELECT drug_concept_code,
		'% in ds_stage',
		'ds_stage'
	FROM ds_stage
	join relationship_to_concept on
		concept_code_1 in (numerator_unit,amount_unit,denominator_unit) and
		concept_id_2 = 8554
	
	UNION ALL
		
	--map to unit that doesn't exist in RxNorm
	SELECT a.concept_code_1,
		'Unit that is not in use by RxNorm',
		'ds_stage'
	FROM relationship_to_concept a
	JOIN drug_concept_stage b ON concept_code_1 = concept_code
	JOIN concept c ON concept_id_2 = c.concept_id
	WHERE b.concept_class_id = 'Unit'
		AND concept_id_2 NOT IN (
			SELECT coalesce(AMOUNT_UNIT_CONCEPT_ID, NUMERATOR_UNIT_CONCEPT_ID)
			FROM drug_strength a
			JOIN concept b ON drug_concept_id = concept_id
				AND vocabulary_id = 'RxNorm'
			WHERE coalesce(AMOUNT_UNIT_CONCEPT_ID, NUMERATOR_UNIT_CONCEPT_ID) IS NOT NULL
			
			UNION ALL
			
			SELECT DENOMINATOR_UNIT_CONCEPT_ID
			FROM drug_strength a
			JOIN concept b ON drug_concept_id = concept_id
				AND vocabulary_id = 'RxNorm'
			WHERE DENOMINATOR_UNIT_CONCEPT_ID IS NOT NULL
			)
	
		UNION ALL
	
	--wrong dosages ,> 1000, with conversion
	SELECT drug_concept_code,
		'Suspicious dosages > 1000 mg/ml, with conversion',
		'ds_stage'
	FROM ds_stage ds
	JOIN relationship_to_concept n ON numerator_unit = n.concept_code_1
		AND n.concept_id_2 = 8576
	JOIN relationship_to_concept d ON denominator_unit = d.concept_code_1
		AND d.concept_id_2 = 8587
	WHERE numerator_value * coalesce (n.conversion_factor,1) / (denominator_value * coalesce (d.conversion_factor,1)) > 1000
	UNION ALL
	
--for internal_relationship_stage

	--drugs without ingredients won't be proceeded
	SELECT concept_code,
		'missing relationship to ingredient: drug won''t be processed',
		'internal_relationship_stage'
	FROM drug_concept_stage
	WHERE concept_code NOT IN (
			SELECT concept_code_1
			FROM internal_relationship_stage
			JOIN drug_concept_stage ON concept_code_2 = concept_code
				AND concept_class_id = 'Ingredient'
			)
		AND concept_code NOT IN (
			SELECT pack_concept_code
			FROM pc_stage
			)
		AND concept_class_id = 'Drug Product'
	
	UNION ALL
	
	--Attribute doesn't relate to any drug
	SELECT DISTINCT a.concept_code,
		'Attribute doesn''t relate to any drug',
		'internal_relationship_stage'
	FROM drug_concept_stage a
	LEFT JOIN internal_relationship_stage b ON a.concept_code = b.concept_code_2
	WHERE a.concept_class_id in ('Brand Name','Dose Form','Supplier')
		AND b.concept_code_1 IS NULL
	
	UNION ALL
	
	
-- for drug_concept_stage

--same names for different drug classes
	SELECT concept_code,
		'same names for basic drug classes',
		'drug_concept_stage'
	FROM drug_concept_stage
	WHERE TRIM(LOWER(concept_name)) IN (
			SELECT TRIM(LOWER(concept_name)) AS n
			FROM drug_concept_stage
			WHERE concept_class_id IN (
					'Brand Name',
					'Dose Form',
					'Unit',
					'Ingredient',
					'Supplier'
					)
				AND invalid_reason is null
			GROUP BY TRIM(LOWER(concept_name))
			HAVING COUNT(*) > 1
			)
	
	UNION ALL
	
	--short names but not a Unit
	SELECT concept_code,
		'short names but not a Unit',
		'drug_concept_stage'
	FROM drug_concept_stage
	WHERE LENGTH(concept_name) < 3
		AND concept_class_id NOT IN ('Unit')
	
		UNION ALL
	
	-- as we don't have the mapping all valid devices should be standard
	SELECT concept_code,
		'non-standard valid devices',
		'drug_concept_stage'
	FROM drug_concept_stage
	WHERE domain_id = 'Device'
		AND 
			(
				standard_concept IS NULL and
				invalid_reason is null
			)

	UNION ALL
	
	
--for relationship_to_concept
	SELECT concept_code_1,
		'Empty conversion factor for a unit',
		'relationship_to_concept'
	FROM relationship_to_concept a
	JOIN concept b ON concept_id_2 = concept_id
		AND concept_class_id = 'Unit'
	WHERE conversion_factor IS NULL
	
		UNION ALL
	
	--Wrong vocabulary mapping
	SELECT concept_code_1,
		'Wrong vocabulary mapping: content will be ignored by Build_RxE',
		'relationship_to_concept'
	FROM relationship_to_concept a
	JOIN concept b ON a.concept_id_2 = b.concept_id
	WHERE b.VOCABULARY_ID NOT IN 
		(
			'UCUM',
			'RxNorm',
			'RxNorm Extension'
		)

		UNION all

--for concept_synonym_stage

	SELECT synonym_concept_code,
		'concept_code & vocabulary_id combination is absent from drug_concept_stage',
		'concept_synonym_stage'
	from concept_synonym_stage s
	left join drug_concept_stage c on
		(c.concept_code, c.vocabulary_id) = (s.synonym_concept_code, s.synonym_vocabulary_id)
	where c.concept_code is null

)
SELECT error_type,affected_table,COUNT(*) AS cnt
FROM s0
GROUP BY error_type, affected_table