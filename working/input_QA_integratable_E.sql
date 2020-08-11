
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
* Authors: Christian Reich, Dmitry Dymshyts, Anna Ostropolets, Eduard Korchmar
* Date: 2020
**************************************************************************/
SELECT affected_table, error_type, COUNT(*) AS cnt
FROM (
	--for relationship_to_concept
	--wrong concept_id's 
	SELECT a.concept_code, 'concept_id_2 doesn''t belong to a valid concept' AS error_type, 'relationship_to_concept' AS affected_table
	FROM relationship_to_concept r
	JOIN drug_concept_stage a ON a.concept_code = r.concept_code_1
	LEFT JOIN concept c ON c.concept_id = r.concept_id_2
		AND c.invalid_reason IS NULL
	WHERE c.concept_id IS NULL
	
	UNION ALL
	
	--Wrong vocabulary mapping
	SELECT concept_code_1, 'Wrong vocabulary mapping for an attribute or Unit', 'relationship_to_concept'
	FROM relationship_to_concept a
	JOIN drug_concept_stage c ON c.concept_code = a.concept_code_1
	JOIN concept b ON b.concept_id = a.concept_id_2
	WHERE (c.concept_class_id, b.vocabulary_id) NOT IN (
			('Unit', 'UCUM'),
			('Brand Name', 'RxNorm'),
			('Ingredient', 'RxNorm'),
			('Dose Form', 'RxNorm'),
			('Brand Name', 'RxNorm Extension'),
			('Ingredient', 'RxNorm Extension'),
			('Dose Form', 'RxNorm Extension'),
			('Supplier', 'RxNorm Extension')
			)
		AND c.concept_class_id IN (
			'Unit',
			'Brand Name',
			'Ingredient',
			'Dose Form'
			)
	
	UNION ALL
	
	SELECT concept_code_1, 'concept_code_1 is null', 'relationship_to_concept'
	FROM relationship_to_concept
	WHERE concept_code_1 IS NULL
	
	UNION ALL
	
	SELECT drug_concept_code, 'unmapped unit', 'relationship_to_concept'
	FROM ds_stage
	WHERE denominator_unit NOT IN (
			SELECT concept_code_1
			FROM relationship_to_concept
			)
		OR numerator_unit NOT IN (
			SELECT concept_code_1
			FROM relationship_to_concept
			)
		OR amount_unit NOT IN (
			SELECT concept_code_1
			FROM relationship_to_concept
			)
	
	UNION ALL
	
	SELECT a.concept_code, 'different classes in concept_code_1 and concept_id_2', 'relationship_to_concept'
	FROM relationship_to_concept r
	JOIN drug_concept_stage a ON a.concept_code = r.concept_code_1
	JOIN concept c ON c.concept_id = r.concept_id_2
		AND c.vocabulary_id LIKE 'RxNorm%'
	WHERE a.concept_class_id <> c.concept_class_id
	
	UNION ALL
	
	--name_equal_mapping absence
	SELECT dcs.concept_code, 'Mapping absent despite available full match on name', 'relationship_to_concept'
	FROM drug_concept_stage dcs
	LEFT JOIN relationship_to_concept cr ON cr.concept_code_1 = dcs.concept_code
	WHERE cr.concept_code_1 IS NULL
		AND EXISTS (
			SELECT 1
			FROM concept cc
			WHERE LOWER(cc.concept_name) = LOWER(dcs.concept_name)
				AND cc.concept_class_id = dcs.concept_class_id
				AND cc.vocabulary_id LIKE 'RxNorm%'
				AND cc.invalid_reason IS NULL
			)
		AND dcs.concept_class_id IN (
			'Ingredient',
			'Brand Name',
			'Dose Form',
			'Supplier'
			)
	
	UNION ALL
	
	--concept_code_1, precedence duplicates
	SELECT concept_code_1, 'precedence duplicates', 'relationship_to_concept'
	FROM (
		SELECT concept_code_1, precedence
		FROM relationship_to_concept
		GROUP BY concept_code_1, precedence
		HAVING COUNT(*) > 1
		) AS s1
	
	UNION ALL
	
	--relationship_to_concept
	--concept_code_1, precedence duplicates
	SELECT concept_code_1, 'concept_code_2 duplicates', 'relationship_to_concept'
	FROM (
		SELECT concept_code_1, concept_id_2
		FROM relationship_to_concept
		GROUP BY concept_code_1, concept_id_2
		HAVING COUNT(*) > 1
		) AS s1
	
	UNION ALL
	
	--for internal_relationship_stage
	SELECT concept_code_1, 'internal_relationship_stage full dublicates', 'internal_relationship_stage'
	FROM (
		SELECT concept_code_1, concept_code_2
		FROM internal_relationship_stage
		GROUP BY concept_code_1, concept_code_2
		HAVING COUNT(*) > 1
		) AS s1
	
	UNION ALL
	
	SELECT concept_code_1, 'null values in internal_relationship_stage', 'internal_relationship_stage'
	FROM internal_relationship_stage
	WHERE concept_code_1 IS NULL
		OR concept_code_2 IS NULL
	
	UNION ALL
	
	--Marketed Drugs without the dosage or Drug Form
	SELECT concept_code, 'Marketed Drugs without the dosage or Drug Form', 'internal_relationship_stage'
	FROM drug_concept_stage dcs
	JOIN (
		SELECT irs.concept_code_1
		FROM internal_relationship_stage irs
		JOIN drug_concept_stage dcs ON dcs.concept_code = irs.concept_code_2
			AND dcs.concept_class_id = 'Supplier'
		LEFT JOIN ds_stage ds ON ds.drug_concept_code = irs.concept_code_1
		WHERE ds.drug_concept_code IS NULL
		
		UNION
		
		SELECT irs.concept_code_1
		FROM internal_relationship_stage irs
		JOIN drug_concept_stage dcs ON dcs.concept_code = irs.concept_code_2
			AND dcs.concept_class_id = 'Supplier'
		WHERE irs.concept_code_1 NOT IN (
				SELECT irs_int.concept_code_1
				FROM internal_relationship_stage irs_int
				JOIN drug_concept_stage dcs_int ON dcs_int.concept_code = irs_int.concept_code_2
					AND dcs_int.concept_class_id = 'Dose Form'
				)
		) s ON s.concept_code_1 = dcs.concept_code
	WHERE dcs.concept_class_id = 'Drug Product'
		AND dcs.invalid_reason IS NULL
		AND s.concept_code_1 NOT IN (
			SELECT pack_concept_code
			FROM pc_stage
			)
	
	UNION ALL
	
	--several attributes but should be the only one
	SELECT concept_code_1, 'several attributes where only one is expected', 'internal_relationship_stage'
	FROM (
		SELECT concept_code_1, b.concept_class_id
		FROM internal_relationship_stage a
		JOIN drug_concept_stage b ON b.concept_code = a.concept_code_2
		WHERE b.concept_class_id IN (
				'Supplier',
				'Dose Form',
				'Brand Name'
				)
		GROUP BY a.concept_code_1, b.concept_class_id
		HAVING COUNT(*) > 1
		) AS s1
	
	UNION ALL
	
	SELECT concept_code_1, 'non-drug products with entries in internal_relationship_stage', 'internal_relationship_stage'
	FROM internal_relationship_stage irs
	JOIN drug_concept_stage dcs ON dcs.concept_code = irs.concept_code_1
		AND (concept_class_id, domain_id) <> ('Drug Product', 'Drug')
	
	UNION ALL
	
	--for ds_stage
	SELECT concept_code_1, 'different ingredient count in IRS and ds_stage', 'ds_stage'
	FROM (
		SELECT DISTINCT concept_code_1, COUNT(concept_code_2) OVER (PARTITION BY concept_code_1) AS irs_cnt
		FROM internal_relationship_stage irs
		JOIN drug_concept_stage dcs ON dcs.concept_code = irs.concept_code_2
			AND dcs.concept_class_id = 'Ingredient'
		) irs
	JOIN (
		SELECT DISTINCT drug_concept_code, COUNT(ingredient_concept_code) OVER (PARTITION BY drug_concept_code) AS ds_cnt
		FROM ds_stage
		) ds ON drug_concept_code = concept_code_1
		AND irs_cnt <> ds_cnt
	
	UNION ALL
	
	SELECT drug_concept_code, 'null values in ds_stage', 'ds_stage'
	FROM ds_stage
	WHERE drug_concept_code IS NULL
		OR ingredient_concept_code IS NULL
	
	UNION ALL
	
	--0 in ds_stage values
	SELECT drug_concept_code, '0 in values for an active ingredient', 'ds_stage'
	FROM (
		SELECT drug_concept_code, ingredient_concept_code
		FROM ds_stage
		WHERE amount_value <= 0
		) t
	LEFT JOIN relationship_to_concept rtc ON rtc.concept_code_1 = t.ingredient_concept_code
		AND COALESCE(precedence, 1) = 1
	WHERE rtc.concept_id_2 <> 19127890 --Inert Ingredients
		OR rtc.concept_code_1 IS NULL
	
	UNION ALL
	
	SELECT ds.drug_concept_code, 'ds_stage duplicates after mapping to Rx', 'ds_stage'
	FROM ds_stage ds
	JOIN ds_stage ds2 ON ds2.drug_concept_code = ds.drug_concept_code
		AND ds2.ingredient_concept_code <> ds.ingredient_concept_code
	JOIN relationship_to_concept rc ON rc.concept_code_1 = ds.ingredient_concept_code
	JOIN relationship_to_concept rc2 ON rc2.concept_code_1 = ds2.ingredient_concept_code
	WHERE rc.concept_id_2 = rc2.concept_id_2
	
	UNION ALL
	
	-- drug codes don't exist in a drug_concept_stage but present in ds_stage
	SELECT DISTINCT s.drug_concept_code, 'ds_stage has drug codes absent in drug_concept_stage', 'ds_stage'
	FROM ds_stage s
	LEFT JOIN drug_concept_stage a ON a.concept_code = s.drug_concept_code
		AND a.concept_class_id = 'Drug Product'
	WHERE a.concept_code IS NULL
	
	UNION ALL
	
	-- ingredient codes don't exist in a drug_concept_stage but present in ds_stage
	SELECT DISTINCT s.drug_concept_code, 'ds_stage has ingredient_codes absent in drug_concept_stage', 'ds_stage'
	FROM ds_stage s
	LEFT JOIN drug_concept_stage b ON b.concept_code = s.ingredient_concept_code
		AND b.concept_class_id = 'Ingredient'
	WHERE b.concept_code IS NULL
	
	UNION ALL
	
	--unit is empty, value is not and vice versa
	SELECT DISTINCT s.drug_concept_code, 'Value without unit or vice versa', 'ds_stage'
	FROM ds_stage s
	WHERE amount_value IS NOT NULL
		AND amount_unit IS NULL
		OR (
			denominator_value IS NOT NULL
			AND denominator_unit IS NULL
			)
		OR (
			numerator_value IS NOT NULL
			AND denominator_unit IS NULL
			)
		OR (
			amount_value IS NULL
			AND amount_unit IS NOT NULL
			)
		OR (
			numerator_value IS NULL
			AND numerator_unit IS NOT NULL
			)
	
	UNION ALL
	
	--Different denominator_value or denominator_unit in the same drug
	SELECT DISTINCT a.drug_concept_code, 'Different DENOMINATOR_VALUE or DENOMINATOR_unit in the same drug', 'ds_stage'
	FROM ds_stage a
	JOIN ds_stage b ON a.drug_concept_code = b.drug_concept_code
		AND (
			a.denominator_value IS NULL
			AND b.denominator_value IS NOT NULL
			OR a.denominator_value <> b.denominator_value
			OR a.denominator_unit <> b.denominator_unit
			)
	
	UNION ALL
	
	--ds_stage dublicates
	SELECT drug_concept_code, 'ds_stage dublicate ingredients per drug', 'ds_stage'
	FROM (
		SELECT drug_concept_code, ingredient_concept_code
		FROM ds_stage
		GROUP BY drug_concept_code, ingredient_concept_code
		HAVING COUNT(*) > 1
		) AS s0
	
	UNION ALL
	
	--"<=0" in ds_stage values
	SELECT drug_concept_code, '0 or negative number in numerator/denominator values', 'ds_stage'
	FROM ds_stage
	WHERE denominator_value <= 0
		OR numerator_value <= 0
		OR amount_value < 0 -- it can be 0 when it's Inert ingredient (see above)
	
	UNION ALL
	
	-- dosage > 1 mg/mg'
	SELECT d.drug_concept_code, 'Wrong dosage, more than one unit per same unit', 'ds_stage'
	FROM ds_stage d
	JOIN relationship_to_concept r1 ON r1.concept_code_1 = d.numerator_unit
	JOIN relationship_to_concept r2 ON r2.concept_code_1 = d.denominator_unit
		AND r1.concept_id_2 = r2.concept_id_2
	WHERE d.numerator_value * COALESCE(r1.conversion_factor, 1) / (COALESCE(d.denominator_value, 1) * COALESCE(r2.conversion_factor, 1)) > 1
	
	UNION ALL
	
	SELECT drug_concept_code, 'Null values in ds_stage', 'ds_stage'
	FROM ds_stage
	WHERE COALESCE(amount_value, numerator_value) IS NULL
		-- needs to have at least one value, zeros don't count
		OR COALESCE(amount_unit, numerator_unit) IS NULL
		-- if there is an amount record, there must be a unit
		OR (
			COALESCE(numerator_value, 0) <> 0
			AND COALESCE(numerator_unit, denominator_unit) IS NULL
			)
	-- if there is a concentration record there must be a unit in both numerator and denominator
	
	UNION ALL
	
	SELECT drug_concept_code, 'conflicting or incomplete dosage information', 'ds_stage'
	FROM (
		SELECT a.drug_concept_code
		FROM ds_stage a
		JOIN ds_stage b ON a.drug_concept_code = b.drug_concept_code
			AND a.ingredient_concept_code <> b.ingredient_concept_code
			AND a.amount_unit IS NULL
			AND b.amount_unit IS NOT NULL
		--the dosage should be always present if UNIT is not null (checked before)
		
		UNION
		
		SELECT a.drug_concept_code
		FROM ds_stage a
		JOIN ds_stage b ON b.drug_concept_code = a.drug_concept_code
			AND b.ingredient_concept_code <> a.ingredient_concept_code
		WHERE a.numerator_unit IS NULL
			AND b.numerator_unit IS NOT NULL
			--the dosage should be always present if UNIT is not null (checked before)
		) AS s0
	
	UNION ALL
	
	SELECT drug_concept_code, 'drug-ingredient relationship is missing from irs', 'ds_stage'
	FROM ds_stage
	WHERE (drug_concept_code, ingredient_concept_code) NOT IN (
			SELECT concept_code_1, concept_code_2
			FROM internal_relationship_stage
			)
	
	UNION ALL
	
	SELECT drug_concept_code, 'Amount and denominator/numerator fields for the same drug', 'ds_stage'
	FROM ds_stage
	WHERE COALESCE(amount_value::VARCHAR, amount_unit) IS NOT NULL
		AND COALESCE(numerator_value::VARCHAR, numerator_unit, denominator_value::VARCHAR, denominator_unit) IS NOT NULL
	
	UNION ALL
	
	SELECT drug_concept_code, 'Box_size is specified for nonquantified drugs', 'ds_stage'
	FROM ds_stage
	WHERE numerator_value IS NOT NULL
		AND denominator_value IS NULL
		AND box_size IS NOT NULL
	
	UNION ALL
	
	SELECT drug_concept_code, 'Box_size information without Dose Form', 'ds_stage'
	FROM ds_stage
	WHERE drug_concept_code NOT IN (
			SELECT drug_concept_code
			FROM ds_stage ds
			JOIN internal_relationship_stage i ON i.concept_code_1 = ds.drug_concept_code
			JOIN drug_concept_stage dcs ON dcs.concept_code = i.concept_code_2
				AND dcs.concept_class_id = 'Dose Form'
			WHERE ds.box_size IS NOT NULL
			)
		AND box_size IS NOT NULL
	--for drug_concept_stage
	
	UNION ALL
	
	SELECT a.concept_code, 'New OMOP code for the existing entity', 'drug_concept_stage'
	FROM drug_concept_stage a
	JOIN concept b ON b.concept_code <> a.concept_code
		AND (LOWER(a.concept_name), a.concept_class_id, a.vocabulary_id) = (LOWER(b.concept_name), b.concept_class_id, b.vocabulary_id)
	WHERE a.concept_code LIKE 'OMOP%'
	
	UNION ALL
	
	--4.drug_concept_stage
	--duplicates in drug_concept_stage table
	SELECT concept_code, 'Duplicate concept codes in drug_concept_stage', 'drug_concept_stage'
	FROM (
		SELECT concept_code
		FROM drug_concept_stage
		GROUP BY concept_code
		HAVING COUNT(*) > 1
		) AS s0
	
	UNION ALL
	
	--important fields contain null values
	SELECT concept_code, 'important fields contain null values', 'drug_concept_stage'
	FROM drug_concept_stage
	WHERE concept_name IS NULL
		OR concept_code IS NULL
		OR concept_class_id IS NULL
		OR domain_id IS NULL
		OR vocabulary_id IS NULL
	
	UNION ALL
	
	--Improper valid_end_date
	SELECT concept_code, 'Improper valid_end_date', 'drug_concept_stage'
	FROM drug_concept_stage
	WHERE (valid_end_date > TO_DATE('20991231', 'YYYYMMDD'))
		OR valid_end_date IS NULL
	
	UNION ALL
	
	--Improper valid_start_date
	SELECT concept_code, 'Improper valid_start_date', 'drug_concept_stage'
	FROM drug_concept_stage
	WHERE valid_start_date > CURRENT_DATE
		OR valid_start_date IS NULL
		OR valid_start_date > valid_end_date
		OR valid_start_date < TO_DATE('19000101', 'YYYYMMDD')
	
	UNION ALL
	
	--concept falls outside validity period
	SELECT concept_code, 'invalid_reason conflicts with validity period', 'drug_concept_stage'
	FROM drug_concept_stage
	WHERE (
			valid_end_date < CURRENT_DATE
			AND invalid_reason IS NULL
			)
		OR (
			valid_end_date > CURRENT_DATE
			AND invalid_reason IS NOT NULL
			)
	
	UNION ALL
	
	--wrong domains
	SELECT concept_code, 'wrong domain_id', 'drug_concept_stage'
	FROM drug_concept_stage
	WHERE domain_id NOT IN (
			'Drug',
			'Device'
			)
	
	UNION ALL
	
	SELECT 'X', 'latest_update script not executed for source vocabulary', 'drug_concept_stage'
	WHERE NOT EXISTS (
			SELECT 1
			FROM information_schema.columns
			WHERE table_schema = current_schema
				AND table_name = 'vocabulary'
				AND column_name = 'latest_update'
			)
	
	UNION ALL
	
	SELECT concept_code, 'Unknown concept_class_id', 'drug_concept_stage'
	FROM drug_concept_stage d
	LEFT JOIN concept_class c ON c.concept_class_id = COALESCE(d.source_concept_class_id, d.concept_class_id)
	WHERE c.concept_class_id IS NULL
	
	UNION ALL
	
	--standard but invalid concept
	SELECT concept_code, 'standard invalid concept', 'drug_concept_stage'
	FROM drug_concept_stage
	WHERE standard_concept IS NOT NULL
		AND invalid_reason IS NOT NULL
	
	UNION ALL
	
	SELECT vocabulary_id, 'multiple VOCABULARY_ID in drug_concept_stage is not supported', 'drug_concept_stage'
	FROM (
		SELECT vocabulary_id
		FROM drug_concept_stage
		GROUP BY vocabulary_id
		HAVING COUNT(DISTINCT vocabulary_id) > 1
		) a
	
	UNION ALL
	
	SELECT pack_concept_code, 'Redundant box_size equal to 1 in pc_stage', 'pc_stage'
	FROM pc_stage
	WHERE box_size = 1
	
	UNION ALL
	
	--sequence intersection
	SELECT a.concept_code, 'OMOP codes sequence intersection', 'drug_concept_stage'
	FROM drug_concept_stage a
	JOIN concept b ON b.concept_code = a.concept_code
		AND (lower(a.concept_name), a.concept_class_id, a.vocabulary_id) <> (lower(b.concept_name), b.concept_class_id, b.vocabulary_id)
	WHERE a.concept_code LIKE 'OMOP%'
	--pc_stage
	
	UNION ALL
	
	--pc_stage issues
	--pc_stage duplicates
	SELECT pack_concept_code, 'pc_stage duplicates', 'pc_stage'
	FROM (
		SELECT pack_concept_code, drug_concept_code, box_size
		FROM pc_stage
		GROUP BY drug_concept_code, pack_concept_code, box_size
		HAVING COUNT(*) > 1
		) AS s1
	
	UNION ALL
	
	--non drug as a pack component
	SELECT drug_concept_code, 'non-drug product as a pack component', 'pc_stage'
	FROM pc_stage pc
	JOIN drug_concept_stage dcs ON dcs.concept_code = pc.drug_concept_code
		AND concept_class_id <> 'Drug Product'
	
	UNION ALL
	
	SELECT p.pack_concept_code, 'no ds_stage entries for pack component', 'pc_stage'
	FROM pc_stage p
	LEFT JOIN ds_stage d ON d.drug_concept_code = p.drug_concept_code
	WHERE d.drug_concept_code IS NULL
	
	UNION ALL
	
	SELECT p.pack_concept_code, 'no dose form info for pack component', 'pc_stage'
	FROM pc_stage p
	WHERE drug_concept_code NOT IN (
			SELECT concept_code_1
			FROM internal_relationship_stage irs
			JOIN drug_concept_stage dcs ON dcs.concept_code = irs.concept_code_2
				AND dcs.concept_class_id = 'Dose Form'
			)
	
	UNION ALL
	
	--pack(drug)_concept_code doesn't exist in drug_concept_stage
	SELECT drug_concept_code, 'pack content code is missing from drug_concept_stage', 'pc_stage'
	FROM pc_stage
	WHERE drug_concept_code NOT IN (
			SELECT concept_code
			FROM drug_concept_stage
			)
	
	UNION ALL
	
	SELECT pack_concept_code, 'null values in pc_stage', 'pc_stage'
	FROM pc_stage
	WHERE drug_concept_code IS NULL
		OR pack_concept_code IS NULL
	
	UNION ALL
	
	SELECT pack_concept_code, 'pack code is missing from drug_concept_stage', 'pc_stage'
	FROM pc_stage
	WHERE pack_concept_code NOT IN (
			SELECT concept_code
			FROM drug_concept_stage
			)
	
	UNION ALL
	
	--concept_synonym_stage
	SELECT synonym_concept_code, 'language_concept_id doesn''t point to a Standard concept', 'concept_synonym_stage'
	FROM concept_synonym_stage s
	LEFT JOIN concept c ON s.language_concept_id = c.concept_id
	WHERE c.concept_id IS NULL
	
	UNION ALL
	
	SELECT synonym_concept_code, 'Full duplicates in concept_synonym_stage', 'concept_synonym_stage'
	FROM (
		SELECT synonym_concept_code, language_concept_id, synonym_name
		FROM concept_synonym_stage
		GROUP BY synonym_concept_code, language_concept_id, synonym_name
		HAVING COUNT(*) > 1
		) s
	
	UNION ALL
	
	--Drugs that needs to be Devices
  select distinct a.concept_code as device_code, 
  'Drugs that needs to be Devices',
  'drug_concept_stage'
  from drug_concept_stage a
  join internal_relationship_stage i on i.concept_code_1 = a.concept_code
  join relationship_to_concept r on i.concept_code_2 = r.concept_code_1
  where r.concept_id_2 in (

    select distinct c2.concept_id
    from dev_dmd.ancestor_snomed ca
    join concept c on
	   ca.descendant_concept_id = c.concept_id and
	   c.vocabulary_id = 'SNOMED'
    join concept_relationship r on
    	r.relationship_id = 'RxNorm - SNOMED eq' and
	    r.concept_id_2 = ca.descendant_concept_id
    join concept c2 on
	   c2.concept_id = r.concept_id_1
    join concept d on
	   d.concept_id = ca.ancestor_concept_id and
	   d.concept_code in
    	(
		  '407935004','385420005', --Contrast Media
		  '767234009', --Gadolinium (salt) -- also contrast
	  	'255922001', --Dental material
		  '764087006',	--Product containing genetically modified T-cell
	   	'89457008',	--Radioactive isotope
		  '37521911000001102', --Radium-223
		  '420884001',	--Human mesenchymal stem cell
--		'52518006', --Amino acid is excluded because it includes the actual drugs
	   	'81430009' -- TiO2 (Sunscreen)
	) )

	UNION ALL
	
	--for concept_relationship_manual
	SELECT m.concept_code_1, 'attributes present for a concept mapped manually', 'concept_relationship_manual'
	FROM concept_relationship_manual m
	WHERE m.relationship_id = 'Maps to'
		AND m.invalid_reason IS NULL
		AND m.concept_code_1 IN (
			SELECT concept_code_1
			FROM internal_relationship_stage
			
			UNION ALL
			
			SELECT concept_code_1
			FROM relationship_to_concept
			
			UNION ALL
			
			SELECT drug_concept_code
			FROM ds_stage
			
			UNION ALL
			
			SELECT pack_concept_code
			FROM pc_stage
			)
	) AS s0
GROUP BY error_type, affected_table;
