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
	* Date: 2016
	**************************************************************************/ 
	with s0 as
	(
--for relationship_to_concept
		--wrong concept_id's 
		SELECT a.concept_code,
			'concept_id_2 doesn''t belong to a valid concept' AS error_type,
			'relationship_to_concept' as affected_table
		FROM relationship_to_concept r
		JOIN drug_concept_stage a ON a.concept_code = r.concept_code_1
		LEFT JOIN concept c ON c.concept_id = r.concept_id_2 and c.invalid_reason is  null
		WHERE 
			c.concept_name IS NULL 
	
		UNION ALL
	
		SELECT concept_code_1,
			'concept_code_1 is null',
			'relationship_to_concept'
		from relationship_to_concept
		where concept_code_1 is null
		
		UNION ALL
	
		SELECT drug_concept_code,
			'unmapped unit',
			'relationship_to_concept'
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
	
		SELECT a.concept_code,
			'different classes in concept_code_1 and concept_id_2' AS error_type,
			'relationship_to_concept'
		FROM relationship_to_concept r
		JOIN drug_concept_stage a ON a.concept_code = r.concept_code_1
		JOIN concept c ON c.concept_id = r.concept_id_2
			AND c.vocabulary_id LIKE 'RxNorm%'
		WHERE a.concept_class_id != c.concept_class_id
		
		UNION ALL
		
			--name_equal_mapping absence
		SELECT dcs.concept_code,
			'Mapping absent despite available full match on name',
			'relationship_to_concept'
		FROM drug_concept_stage dcs
		JOIN concept cc ON lower(cc.concept_name) = lower(dcs.concept_name)
			AND cc.concept_class_id = dcs.concept_class_id
			AND cc.vocabulary_id LIKE 'RxNorm%'
		LEFT JOIN relationship_to_concept cr ON dcs.concept_code = cr.concept_code_1
		WHERE concept_code_1 IS NULL
			AND cc.invalid_reason IS NULL
			AND dcs.concept_class_id IN (
				'Ingredient',
				'Brand Name',
				'Dose Form',
				'Supplier'
				)
	
		UNION ALL
	
				--concept_code_1, precedence duplicates
		SELECT concept_code_1,
			'precedence duplicates',
			'relationship_to_concept'
		FROM (
			SELECT concept_code_1,
				precedence
			FROM relationship_to_concept
			GROUP BY concept_code_1,
				precedence
			HAVING COUNT(*) > 1
			) AS s1
	
		UNION ALL
	
		--relationship_to_concept
		--concept_code_1, precedence duplicates
		SELECT concept_code_1,
			'concept_code_2 duplicates',
			'relationship_to_concept'
		FROM (
			SELECT concept_code_1,
				concept_id_2
			FROM relationship_to_concept
			GROUP BY concept_code_1,
				concept_id_2
			HAVING COUNT(*) > 1
			) AS s1
	
		UNION ALL
	
	--Wrong vocabulary mapping
		SELECT concept_code_1,
			'Wrong vocabulary mapping',
			'relationship_to_concept'
		FROM relationship_to_concept a
		JOIN concept b ON a.concept_id_2 = b.concept_id
		WHERE b.VOCABULARY_ID NOT IN 
			(
				'UCUM',
				'RxNorm',
				'RxNorm Extension'
			)
		
		UNION ALL
		
--for internal_relationship_stage
		SELECT concept_code_1,
			'internal_relationship_stage full dublicates',
			'internal_relationship_stage'
		FROM (
			SELECT concept_code_1,
				concept_code_2
			FROM internal_relationship_stage
			GROUP BY concept_code_1,
				concept_code_2
			HAVING COUNT(*) > 1
			) AS s1
	
		UNION ALL
		
		SELECT concept_code_1,
			'null values in internal_relationship_stage',
			'internal_relationship_stage'
		from internal_relationship_stage
		where
			concept_code_1 is null or
			concept_code_2 is null
		
		UNION ALL
		
		--Marketed Drugs without the dosage or Drug Form
		SELECT concept_code,
			'Marketed Drugs without the dosage or Drug Form',
			'internal_relationship_stage'
		FROM drug_concept_stage dcs
		JOIN (
			SELECT concept_code_1
			FROM internal_relationship_stage
			JOIN drug_concept_stage ON concept_code_2 = concept_code
				AND concept_class_id = 'Supplier'
			LEFT JOIN ds_stage ON drug_concept_code = concept_code_1
			WHERE drug_concept_code IS NULL
			
			UNION
			
			SELECT concept_code_1
			FROM internal_relationship_stage
			JOIN drug_concept_stage ON concept_code_2 = concept_code
				AND concept_class_id = 'Supplier'
			WHERE concept_code_1 NOT IN (
					SELECT concept_code_1
					FROM internal_relationship_stage
					JOIN drug_concept_stage ON concept_code_2 = concept_code
						AND concept_class_id = 'Dose Form'
					)
			) s ON s.concept_code_1 = dcs.concept_code
		WHERE dcs.concept_class_id = 'Drug Product'
			AND invalid_reason IS NULL
			and concept_code_1 not in (select pack_concept_code from pc_stage)
	
		UNION ALL
		
		--several attributes but should be the only one
		SELECT concept_code_1,
			'several attributes where only one is expected',
			'internal_relationship_stage'
		FROM (
			SELECT concept_code_1,
				b.concept_class_id
			FROM internal_relationship_stage a
			JOIN drug_concept_stage b ON concept_code = concept_code_2
			WHERE b.concept_class_id IN (
					'Supplier',
					'Dose Form',
					'Brand Name'
					)
			GROUP BY concept_code_1,
				b.concept_class_id
			HAVING COUNT(*) > 1
			) AS s1
	
		union all
	
		select concept_code_1,
			'non-drug products with entries in internal_relationship_stage',
			'internal_relationship_stage'
		from internal_relationship_stage
		join drug_concept_stage on
			concept_code = concept_code_1 and
			(concept_class_id,domain_id) != ('Drug Product', 'Drug')
	
		UNION ALL

--for ds_stage

		SELECT concept_code_1,
			'different ingredient count in IRS and ds_stage',
			'ds_stage'
		FROM (
			SELECT DISTINCT concept_code_1,
				COUNT(concept_code_2) OVER (PARTITION BY concept_code_1) AS irs_cnt
			FROM internal_relationship_stage
			JOIN drug_concept_stage ON concept_code = concept_code_2
				AND concept_class_id = 'Ingredient'
			) irs
		JOIN (
			SELECT DISTINCT drug_concept_code,
				COUNT(ingredient_concept_code) OVER (PARTITION BY drug_concept_code) AS ds_cnt
			FROM ds_stage
			) ds ON drug_concept_code = concept_code_1
			AND irs_cnt != ds_cnt
		
		UNION ALL
	
		SELECT drug_concept_code,
			'null values in ds_stage',
			'ds_stage'
		from ds_stage
		where
			drug_concept_code is null or
			ingredient_concept_code is null

        UNION ALL
        --0 in ds_stage values
        SELECT drug_concept_code,
               '0 in values for an active ingredient',
               'ds_stage'
        FROM (
             SELECT drug_concept_code, ingredient_concept_code
             FROM ds_stage
             WHERE amount_value <= 0
             ) t
        LEFT JOIN relationship_to_concept
            ON ingredient_concept_code = concept_code_1 AND
               COALESCE(precedence, 1) = 1
        WHERE concept_id_2 != 19127890 --Inert Ingredients
           OR concept_code_1 IS NULL

		UNION ALL
		
		SELECT ds.drug_concept_code,
			'ds_stage duplicates after mapping to Rx',
			'ds_stage'
		FROM ds_stage ds
		JOIN ds_stage ds2 ON ds.drug_concept_code = ds2.drug_concept_code
			AND ds.ingredient_concept_code != ds2.ingredient_concept_code
		JOIN relationship_to_concept rc ON ds.ingredient_concept_code = rc.concept_code_1
		JOIN relationship_to_concept rc2 ON ds2.ingredient_concept_code = rc2.concept_code_1
		WHERE rc.concept_id_2 = rc2.concept_id_2
		
		UNION ALL
		
		-- drug codes don't exist in a drug_concept_stage but present in ds_stage
		SELECT DISTINCT s.drug_concept_code,
			'ds_stage has drug codes absent in drug_concept_stage',
			'ds_stage'
		FROM ds_stage s
		LEFT JOIN drug_concept_stage a ON a.concept_code = s.drug_concept_code
			AND a.concept_class_id = 'Drug Product'
		WHERE a.concept_code IS NULL
		
		UNION ALL
		
		-- ingredient codes don't exist in a drug_concept_stage but present in ds_stage
		SELECT DISTINCT s.drug_concept_code,
			'ds_stage has ingredient_codes absent in drug_concept_stage',
			'ds_stage'
		FROM ds_stage s
		LEFT JOIN drug_concept_stage b ON b.concept_code = s.INGREDIENT_CONCEPT_CODE
			AND b.concept_class_id = 'Ingredient'
		WHERE b.concept_code IS NULL
		
		UNION ALL
		
		--unit is empty, value is not and vice versa
		SELECT DISTINCT s.drug_concept_code,
			'Value without unit or vice versa',
			'ds_stage'
		FROM ds_stage s
		WHERE AMOUNT_VALUE IS NOT NULL
			AND AMOUNT_UNIT IS NULL
			OR (
				denominator_VALUE IS NOT NULL
				AND denominator_UNIT IS NULL
				)
			OR (
				NUMERATOR_VALUE IS NOT NULL
				AND denominator_UNIT IS NULL
				)
			OR (
				AMOUNT_VALUE IS NULL
				AND AMOUNT_UNIT IS NOT NULL
				)
			OR (
				NUMERATOR_VALUE IS NULL
				AND NUMERATOR_Unit IS NOT NULL
				)
				
		UNION ALL
		
		--Different DENOMINATOR_VALUE or DENOMINATOR_unit in the same drug
		SELECT DISTINCT a.drug_concept_code,
			'Different DENOMINATOR_VALUE or DENOMINATOR_unit in the same drug',
			'ds_stage'
		FROM ds_stage a
		JOIN ds_stage b ON a.drug_concept_code = b.drug_concept_code
			AND (
				a.DENOMINATOR_VALUE IS NULL
				AND b.DENOMINATOR_VALUE IS NOT NULL
				OR a.DENOMINATOR_VALUE != b.DENOMINATOR_VALUE
				OR a.DENOMINATOR_unit != b.DENOMINATOR_unit
				)
		
		UNION ALL
		
		--ds_stage dublicates
		SELECT drug_concept_code,
			'ds_stage dublicate ingredients per drug',
			'ds_stage'
		FROM (
			SELECT drug_concept_code,
				ingredient_concept_code
			FROM ds_stage
			GROUP BY drug_concept_code,
				ingredient_concept_code
			HAVING COUNT(*) > 1
			) AS s0
	
		UNION ALL
	
			--"<=0" in ds_stage values
		SELECT drug_concept_code,
			'0 or negative number in numerator/denominator values',
			'ds_stage'
		FROM ds_stage
		WHERE denominator_value <= 0
			OR numerator_value <= 0
		OR amount_value < 0 -- it can be 0 when it's Inert ingredient (see above)
	
		UNION ALL
	
		-- dosage > 1 mg/mg'
		SELECT d.drug_concept_code,
			'Wrong dosage, more than one unit per same unit',
			'ds_stage'
		FROM ds_stage d
		join relationship_to_concept r1 on
			r1.concept_code_1 = d.numerator_unit
		join relationship_to_concept r2 on
			r2.concept_code_1 = denominator_unit and
			r1.concept_id_2 = r2.concept_id_2
		where
		    d.numerator_value * COALESCE(r1.conversion_factor, 1) / (COALESCE(d.denominator_value, 1) * COALESCE(r2.conversion_factor , 1)) > 1
		UNION ALL
		
		SELECT drug_concept_code,
			'Null values in ds_stage',
			'ds_stage'
		FROM ds_stage
		WHERE COALESCE(amount_value, numerator_value) is null
			-- needs to have at least one value, zeros don't count
			OR COALESCE(amount_unit, numerator_unit) IS NULL
			-- if there is an amount record, there must be a unit
			OR (
				coalesce(numerator_value, 0) != 0
				AND COALESCE(numerator_unit, denominator_unit) IS NULL
				)
		-- if there is a concentration record there must be a unit in both numerator and denominator
	
		UNION ALL
	
			SELECT drug_concept_code,
			'conflicting or incomplete dosage information',
			'ds_stage'
		FROM (
			SELECT a.drug_concept_code
			FROM ds_stage a
			JOIN ds_stage b ON a.drug_concept_code = b.drug_concept_code
				AND a.ingredient_concept_code != b.ingredient_concept_code
				AND a.amount_unit IS NULL
				AND b.amount_unit IS NOT NULL
			--the dosage should be always present if UNIT is not null (checked before)
			UNION
			
			SELECT a.drug_concept_code
			FROM ds_stage a
			JOIN ds_stage b ON a.drug_concept_code = b.drug_concept_code
				AND a.ingredient_concept_code != b.ingredient_concept_code
				AND a.numerator_unit IS NULL
				AND b.numerator_unit IS NOT NULL
				--the dosage should be always present if UNIT is not null (checked before)
			) AS s0
		
		UNION ALL
	
		SELECT drug_concept_code,
			'drug-ingredient relationship is missing from irs',
			'ds_stage'
		FROM ds_Stage
		WHERE (
				drug_concept_code,
				ingredient_concept_code
				) NOT IN (
				SELECT concept_code_1,
					concept_code_2
				FROM internal_relationship_stage
				)
		
		UNION ALL
		
		select drug_concept_code,
			'Amount and denominator/numerator fields for the same drug',
			'ds_stage'
		from ds_stage
		where
			coalesce (AMOUNT_VALUE :: varchar, AMOUNT_UNIT) is not null and
			coalesce (numerator_value :: varchar,numerator_unit,denominator_value :: varchar,denominator_unit) is not null
		
		union all
		
		select drug_concept_code,
			'Box_size is specified for nonquantified drugs',
			'ds_stage'
		from ds_stage
		where
			numerator_value is not null and
			denominator_value is null and
			box_size is not null
		
		union all
			
		SELECT drug_concept_code,
			'dosage with ml',
			'ds_stage'
		FROM ds_stage
		join relationship_to_concept on
			concept_code_1 in (numerator_unit,amount_unit) and
			concept_id_2 = 8587
			-- Drug Comp Box, need to remove box_size
			
		union all
		
		SELECT drug_concept_code,
			'Box_size information without Dose Form',
			'ds_stage'
		FROM ds_stage
		WHERE drug_concept_code NOT IN (
				SELECT drug_concept_code
				FROM ds_stage ds
				JOIN internal_relationship_stage i ON concept_code_1 = drug_concept_code
				JOIN drug_concept_stage ON concept_code = concept_code_2
					AND concept_class_id = 'Dose Form'
				WHERE ds.box_size IS NOT NULL
				)
			AND box_size IS NOT NULL
		
		UNION ALL
		
		select drug_concept_code,
			'Redundant box_size equal to 1 in ds_stage',
			'ds_stage'
		from ds_stage
		where box_size = 1
	
--for drug_concept_stage
		UNION ALL
		
		SELECT a.concept_code,
			'New OMOP code for the existing entity',
			'drug_concept_stage'
		FROM drug_concept_stage a
		JOIN concept b ON 
			a.concept_code != b.concept_code and
			(lower(a.concept_name), a.concept_class_id, a.vocabulary_id) = (lower(b.concept_name), b.concept_class_id, b.vocabulary_id)
		WHERE a.concept_code LIKE 'OMOP%'
		
		UNION ALL
		
		--4.drug_concept_stage
		--duplicates in drug_concept_stage table
		SELECT DISTINCT concept_code,
			'Duplicate concept codes in drug_concept_stage',
			'drug_concept_stage'
		FROM drug_concept_stage
		WHERE concept_code IN (
				SELECT concept_code
				FROM drug_concept_stage
				GROUP BY concept_code
				HAVING COUNT(*) > 1
				)
		
		UNION ALL
		
		--important fields contain null values
		SELECT concept_code,
			'important fields contain null values',
			'drug_concept_stage'
		FROM drug_concept_stage
		WHERE 
			concept_name IS NULL or
			concept_code IS NULL or
			concept_class_id IS NULL or
			domain_id IS NULL or
			vocabulary_id IS NULL
		
		UNION ALL
	
		--Improper valid_end_date
		SELECT concept_code,
			'Improper valid_end_date',
			'drug_concept_stage'
		FROM drug_concept_stage
		WHERE (
				valid_end_date > TO_DATE('20991231', 'YYYYMMDD')
			)
			OR valid_end_date IS NULL
		
		UNION ALL
		
		--Improper valid_start_date
		SELECT concept_code,
			'Improper valid_start_date',
			'drug_concept_stage'
		FROM drug_concept_stage
		WHERE
			valid_start_date > CURRENT_DATE OR
			valid_start_date IS NULL OR
			valid_start_date > valid_end_date OR 
			valid_start_date < TO_DATE('19000101', 'YYYYMMDD')
		
		UNION ALL
		--concept falls outside validity period
		
		select concept_code,
			'invalid_reason conflicts with validity period',
			'drug_concept_stage'
		FROM drug_concept_stage
		WHERE
			(
				valid_end_date < CURRENT_DATE and
				invalid_reason is NULL
			) or
			(
				valid_end_date > CURRENT_DATE and
				invalid_reason is not null
			)
	
		UNION ALL
	
	--wrong domains
		SELECT concept_code,
			'wrong domain_id',
			'drug_concept_stage'
		FROM drug_concept_stage
		WHERE domain_id NOT IN (
				'Drug',
				'Device'
				)
		
		union all
	
		select 'X',
		'latest_update script not executed for source vocabulary',
		'drug_concept_stage'
		where
		not exists
		(
			select 1
			from information_schema.columns
			where
				table_schema=current_schema and
				table_name = 'vocabulary' and
				column_name = 'latest_update'
		)
	
		UNION ALL
		
		select concept_code,
			'Unknown concept_class_id',
			'drug_concept_stage'
		from drug_concept_stage d
		left join concept_class c on coalesce (d.source_concept_class_id,d.concept_class_id) = c.concept_class_id
		where c.concept_class_id is null
		UNION ALL
		
		--standard but invalid concept
		SELECT concept_code,
			'standard invalid concept',
			'drug_concept_stage'
		FROM drug_concept_stage
		WHERE standard_concept IS NOT NULL
			AND invalid_reason IS NOT NULL
		
		union all

        SELECT DISTINCT d1.vocabulary_id,
                        'multiple VOCABULARY_ID in drug_concept_stage',
                        'drug_concept_stage'
        FROM (
             SELECT DISTINCT vocabulary_id
             FROM drug_concept_stage
             ) d1
        JOIN (
             SELECT DISTINCT vocabulary_id
             FROM drug_concept_stage
             ) d2
            ON
                d1.vocabulary_id != d2.vocabulary_id

		UNION ALL

		select pack_concept_code,
			'Redundant box_size equal to 1 in pc_stage',
			'pc_stage'
		from pc_stage
		where box_size = 1
		
		UNION ALL
	
		--sequence intersection
		SELECT a.concept_code,
			'OMOP codes sequence intersection',
			'drug_concept_stage'
		FROM drug_concept_stage a
		JOIN concept b ON 
			a.concept_code = b.concept_code and
			(lower (a.concept_name), a.concept_class_id, a.vocabulary_id) != (lower (b.concept_name), b.concept_class_id, b.vocabulary_id)
		WHERE a.concept_code LIKE 'OMOP%'
	
--pc_stage
		UNION ALL
		--pc_stage issues
		--pc_stage duplicates
		SELECT PACK_CONCEPT_CODE,
			'pc_stage duplicates',
			'pc_stage'
		FROM (
			SELECT PACK_CONCEPT_CODE,
				DRUG_CONCEPT_CODE,
				BOX_SIZE
			FROM pc_stage
			GROUP BY DRUG_CONCEPT_CODE,
				PACK_CONCEPT_CODE,
				BOX_SIZE
			HAVING COUNT(*) > 1
			) AS s1
		
		UNION ALL
		
		--non drug as a pack component
		SELECT DRUG_CONCEPT_CODE,
			'non drug as a pack component',
			'pc_stage'
		FROM pc_stage
		JOIN drug_concept_stage ON DRUG_CONCEPT_CODE = concept_code
			AND concept_class_id != 'Drug Product'
		
		UNION ALL

		SELECT p.pack_CONCEPT_CODE,
			'no ds_stage entries for pack component',
			'pc_stage'
		FROM pc_stage p
		left JOIN ds_stage d ON
			d.DRUG_CONCEPT_CODE = p.drug_concept_code
			
		UNION ALL
	
		SELECT p.pack_CONCEPT_CODE,
			'no dose form info for pack component',
			'pc_stage'
		FROM pc_stage p
		where
			drug_concept_code not in
			(
				select concept_code_1
				from internal_relationship_stage
				join drug_concept_stage on
					concept_class_id = 'Dose Form' and
					concept_code = concept_code_2
			)
			
		UNION ALL
		
		--pack(drug)_concept_code doesn't exist in drug_concept_stage
		SELECT drug_concept_code,
			'pack content is missing from drug_concept_stage',
			'pc_stage'
		FROM pc_stage
		WHERE drug_concept_code NOT IN (
				SELECT concept_code
				FROM drug_concept_stage
				)
	
		UNION ALL
	
		SELECT pack_concept_code,
			'null values in pc_stage',
			'pc_stage'
		from pc_stage
		where
			drug_concept_code is null or
			pack_concept_code is null
	
		UNION ALL
		
		SELECT pack_concept_code,
			'pack is missing from drug_concept_stage',
			'pc_stage'
		FROM pc_stage
		WHERE pack_concept_code NOT IN (
				SELECT concept_code
				FROM drug_concept_stage
				)
		
		UNION ALL

--concept_synonym_stage
		SELECT synonym_concept_code,
			'null values in concept_synonym_stage',
			'concept_synonym_stage'
		from concept_synonym_stage
		where
			synonym_concept_code is null or
			synonym_name is null or
			language_concept_id is null or
			synonym_vocabulary_id is null
	
		UNION ALL
	
		SELECT synonym_concept_code,
			'concept_code & vocabulary_id is absent from drug_concept_stage',
			'concept_synonym_stage'
		from concept_synonym_stage s
		left join drug_concept_stage c on
			(c.concept_code, c.vocabulary_id) = (s.synonym_concept_code, s.synonym_vocabulary_id)
		where c.concept_code is null
		
		UNION ALL
		
		SELECT synonym_concept_code,
			'language_concept_id doesn''t point to a Standard concept',
			'concept_synonym_stage'
		from concept_synonym_stage s
		left join concept c on
			s.language_concept_id = c.concept_id
		where c.concept_id is null
		
		UNION ALL
		
		SELECT synonym_concept_code,
			'Full duplicates in concept_synonym_stage',
			'concept_synonym_stage'
		from
			(
				select synonym_concept_code, language_concept_id, synonym_name
				from concept_synonym_stage
				group by synonym_concept_code, language_concept_id, synonym_name
				having count (*) > 1
			) s
	
		UNION ALL
	
--for concept_relationship_manual
		select m.concept_code_1,
			'attributes present for a concept mapped manually',
			'concept_relationship_manual'
		from concept_relationship_manual m
		where
			m.relationship_id = 'Maps to' and
			m.invalid_reason is null and
			m.concept_code_1 in
				(
					select concept_code_1 from internal_relationship_stage
						union all
					select concept_code_1 from relationship_to_concept
						union all
					select drug_concept_code from ds_stage
						union all
					select pack_concept_code from pc_stage
				)
	)
SELECT affected_table, error_type, COUNT(*) AS cnt
FROM s0
GROUP BY error_type,affected_table
