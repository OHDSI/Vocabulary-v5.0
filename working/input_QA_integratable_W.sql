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
* Date: 2020
**************************************************************************/

--ds_stage: 7
--internal_relationship_stage: 2
--drug_concept_stage: 3
--relationship_to_concept: 2
--concept_synonym_stage 1
--drug_concept_stage: 2
--relationship_to_concept:1

--this algorithm shows you concept_code and an error type related to this code
--for ds_stage
SELECT error_type, affected_table, COUNT(*) AS cnt
FROM (
	SELECT drug_concept_code, 'dosage with ml: only allowed for gasseous substances' AS error_type, 'ds_stage' AS affected_table
	FROM ds_stage ds
	JOIN relationship_to_concept rtc ON rtc.concept_code_1 IN (
			ds.numerator_unit,
			ds.amount_unit
			)
		AND rtc.concept_id_2 = 8587
	
	UNION ALL
	
	SELECT drug_concept_code, 'Redundant box_size equal to 1 in ds_stage', 'ds_stage'
	FROM ds_stage
	WHERE box_size = 1
	
	UNION ALL
	
	SELECT drug_concept_code, 'homeopathic units in amounts, need to check', 'ds_stage'
	FROM ds_stage ds
	JOIN relationship_to_concept rtc ON (
			rtc.concept_code_1 = ds.amount_unit
			OR rtc.concept_code_1 = ds.numerator_unit
			)
		AND rtc.concept_id_2 IN (
			9324,
			9325
			)
	
	UNION ALL
	
	--wrong dosages > 1000
	SELECT drug_concept_code, 'Suspicious dosages > 1000 mg/ml', 'ds_stage'
	FROM ds_stage
	WHERE (
			LOWER(numerator_unit) = 'mg'
			AND LOWER(denominator_unit) IN (
				'ml',
				'g'
				)
			OR LOWER(numerator_unit) = ('g')
			AND LOWER(denominator_unit) = ('l')
			)
		AND numerator_value / COALESCE(denominator_value, 1) > 1000
	
	UNION ALL
	
	--% in ds_stage 
	SELECT drug_concept_code, '% in ds_stage', 'ds_stage'
	FROM ds_stage ds
	JOIN relationship_to_concept rtc ON rtc.concept_code_1 IN (
			ds.numerator_unit,
			ds.amount_unit,
			ds.denominator_unit
			)
		AND rtc.concept_id_2 = 8554
	
	UNION ALL
	
	--map to unit that doesn't exist in RxNorm
	SELECT a.concept_code_1, 'Unit that is not in use by RxNorm', 'ds_stage'
	FROM relationship_to_concept a
	JOIN drug_concept_stage b ON b.concept_code = a.concept_code_1
	JOIN concept c ON c.concept_id = a.concept_id_2
	WHERE b.concept_class_id = 'Unit'
		AND concept_id_2 NOT IN (
			SELECT COALESCE(amount_unit_concept_id, numerator_unit_concept_id)
			FROM drug_strength a
			JOIN concept b ON drug_concept_id = concept_id
				AND vocabulary_id = 'RxNorm'
			WHERE COALESCE(amount_unit_concept_id, numerator_unit_concept_id) IS NOT NULL
			
			UNION ALL
			
			SELECT denominator_unit_concept_id
			FROM drug_strength a
			JOIN concept b ON drug_concept_id = concept_id
				AND vocabulary_id = 'RxNorm'
			WHERE denominator_unit_concept_id IS NOT NULL
			)
	
	UNION ALL
	
	--wrong dosages ,> 1000, with conversion
	SELECT drug_concept_code, 'Suspicious dosages > 1000 mg/ml, with conversion', 'ds_stage'
	FROM ds_stage ds
	JOIN relationship_to_concept n ON n.concept_code_1 = ds.numerator_unit
		AND n.concept_id_2 = 8576
	JOIN relationship_to_concept d ON d.concept_code_1 = ds.denominator_unit
		AND d.concept_id_2 = 8587
	WHERE ds.numerator_value * COALESCE(n.conversion_factor, 1) / (ds.denominator_value * COALESCE(d.conversion_factor, 1)) > 1000
	
	UNION ALL
	
	--for internal_relationship_stage
	--drugs without ingredients won't be proceeded
	SELECT concept_code, 'missing relationship to ingredient: drug won''t be processed', 'internal_relationship_stage'
	FROM drug_concept_stage
	WHERE concept_code NOT IN (
			SELECT concept_code_1
			FROM internal_relationship_stage irs_int
			JOIN drug_concept_stage dcs_int ON dcs_int.concept_code = irs_int.concept_code_2
				AND dcs_int.concept_class_id = 'Ingredient'
			)
		AND concept_code NOT IN (
			SELECT pack_concept_code
			FROM pc_stage
			)
		AND concept_class_id = 'Drug Product'
	
	UNION ALL
	
	--Attribute doesn't relate to any drug
	SELECT DISTINCT a.concept_code, 'Attribute doesn''t relate to any drug', 'internal_relationship_stage'
	FROM drug_concept_stage a
	LEFT JOIN internal_relationship_stage b ON b.concept_code_2 = a.concept_code
	WHERE a.concept_class_id IN (
			'Brand Name',
			'Dose Form',
			'Supplier'
			)
		AND b.concept_code_2 IS NULL
	
	UNION ALL
	
	-- for drug_concept_stage
	--same names for different drug classes
	SELECT concept_code, 'same names for basic drug classes', 'drug_concept_stage'
	FROM (
		SELECT concept_code, COUNT(*) OVER (PARTITION BY TRIM(LOWER(concept_name))) AS c
		FROM drug_concept_stage
		WHERE concept_class_id IN (
				'Brand Name',
				'Dose Form',
				'Unit',
				'Ingredient',
				'Supplier'
				)
			AND invalid_reason IS NULL
		) AS s0
	WHERE c > 1
	
	UNION ALL
	
	--short names but not a Unit
	SELECT concept_code, 'short names but not a Unit', 'drug_concept_stage'
	FROM drug_concept_stage
	WHERE LENGTH(concept_name) < 3
		AND concept_class_id NOT IN ('Unit')
	
	UNION ALL
	
	--as we don't have the mapping all valid devices should be standard
	SELECT concept_code, 'non-standard valid devices', 'drug_concept_stage'
	FROM drug_concept_stage
	WHERE domain_id = 'Device'
		AND standard_concept IS NULL
		AND invalid_reason IS NULL
	
	UNION ALL
	
	--for relationship_to_concept
	SELECT concept_code_1, 'Empty conversion factor for a unit', 'relationship_to_concept'
	FROM relationship_to_concept a
	JOIN concept b ON b.concept_id = a.concept_id_2
		AND b.concept_class_id = 'Unit'
	WHERE a.conversion_factor IS NULL
	
	UNION ALL
	
	--wrong vocabulary mapping
	SELECT concept_code_1, 'Wrong vocabulary mapping: content will be ignored by Build_RxE', 'relationship_to_concept'
	FROM relationship_to_concept a
	JOIN concept b ON b.concept_id = a.concept_id_2
	WHERE b.vocabulary_id NOT IN (
			'UCUM',
			'RxNorm',
			'RxNorm Extension'
			)
	
	UNION ALL
	
	--for concept_synonym_stage
	SELECT synonym_concept_code, 'concept_code & vocabulary_id combination is absent from drug_concept_stage', 'concept_synonym_stage'
	FROM concept_synonym_stage s
	LEFT JOIN drug_concept_stage c ON (c.concept_code, c.vocabulary_id) = (s.synonym_concept_code, s.synonym_vocabulary_id)
	WHERE c.concept_code IS NULL
	
	UNION ALL
	
	--Brand Names containing Ingedient (e.g., Aspirin Bayer)
	SELECT a.concept_code, 'Brand Names containing Ingedient (Aspirin Bayer)', 'drug_concept_stage'
	FROM drug_concept_stage a
	JOIN drug_concept_stage b ON (
			a.concept_name ilike '% ' || b.concept_name -- Bayer Aspirin
			OR a.concept_name ilike b.concept_name || ' %' -- Aspirin Bayer
			OR a.concept_name = b.concept_name --Aspirin
			)
	WHERE a.concept_class_id = 'Brand Name'
		AND b.concept_class_id = 'Ingredient'
	
	UNION ALL
	
	--Drugs need to be Devices
	SELECT DISTINCT a.concept_code AS device_code, 'Drugs need to be Devices', 'drug_concept_stage'
	FROM drug_concept_stage a
	JOIN internal_relationship_stage i ON i.concept_code_1 = a.concept_code
	JOIN relationship_to_concept r ON r.concept_code_1 = i.concept_code_2
	WHERE EXISTS (
			SELECT 1
			FROM concept_ancestor ca
			JOIN concept_relationship r ON r.concept_id_2 = ca.descendant_concept_id
				AND r.relationship_id = 'RxNorm - SNOMED eq'
				AND r.invalid_reason IS NULL
			JOIN concept d ON d.concept_id = ca.ancestor_concept_id
				AND d.vocabulary_id = 'SNOMED'
			WHERE d.concept_code IN (
					-- list of device peaks in SNOMED
					'407935004',
					'385420005', --Contrast Media
					'767234009', --Gadolinium (salt) -- also contrast
					'255922001', --Dental material
					'764087006', --Product containing genetically modified T-cell
					'89457008', --Radioactive isotope
					'37521911000001102', --Radium-223
					'420884001', --Human mesenchymal stem cell
					--'52518006', --Amino acid is excluded because it includes the actual drugs
					'81430009' -- TiO2 (Sunscreen)
					)
				AND r.concept_id_1 = r.concept_id_2
			)
	
	UNION ALL
	
	--attribute mappings possible, but aren't built 
	SELECT DISTINCT a.concept_code, 'attribute mappings possible, but aren''t built', 'relationship_to_concept'
	FROM drug_concept_stage a
	LEFT JOIN relationship_to_concept r ON r.concept_code_1 = a.concept_code
	JOIN concept b ON LOWER(b.concept_name) = LOWER(a.concept_name)
		AND b.concept_class_id = a.concept_class_id
	JOIN concept_relationship r2 ON r2.concept_id_1 = b.concept_id
		AND r2.relationship_id IN (
			'Maps to',
			'Source - RxNorm eq'
			)
		AND r2.invalid_reason IS NULL
	JOIN concept c ON r2.concept_id_2 = c.concept_id
	WHERE r.concept_code_1 IS NULL
		AND a.concept_class_id IN (
			'Dose Form',
			'Ingredient',
			'Brand Name',
			'Supplier'
			)
		AND c.invalid_reason IS NULL
	) AS s0
GROUP BY error_type, affected_table;