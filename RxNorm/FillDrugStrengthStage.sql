/*----------------------------------------------------------------------------------------
 * (c) 2017 Observational Health Data Science and Informatics
 *
 * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at
 * http://ohdsi.org/publiclicense.
 * 
 * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. Any redistributions of this work or any derivative work or modification based on this work should be accompanied by the following source attribution: "This work is based on work by the Observational Medical Outcomes Partnership (OMOP) and used under license from the FNIH at
 * http://ohdsi.org/publiclicense.
 * 
 * Any scientific publication that is based on this work should include a reference to
 * http://ohdsi.org.
 * --------------------------------------------------------------------------------------- */

/*******************************************************************************
 * This program creates for each drug and ingredient a record with the strength.
 * For drugs with absolute amount strength information, the value and unit are provided as
 * amount_value and amount_unit. For drugs with relative strength (concentration), the 
 * strength is provided as numerator_value, numerator_unit_concept_id and 
 * denominator_unit_concept_id. For Quantified Drugs the denominator_value is also set
 *
 * Version 2.0
 * Author Christian Reich, Timur Vakhitov
********************************************************************************/

CREATE OR REPLACE FUNCTION FillDrugStrengthStage()
  RETURNS void
AS
$BODY$
BEGIN
	/* 1. Prepare components that will set off parser */
	TRUNCATE TABLE drug_strength_stage;
	ANALYZE concept_stage;
	ANALYZE concept_relationship_stage;

	DROP TABLE IF EXISTS component_replace;
	CREATE TABLE component_replace (
		component_name VARCHAR(250),
		replace_with VARCHAR(250)
		);

	-- load replacement component names so that they match ingredient names and unit names and number conventions
	INSERT INTO component_replace
	VALUES ('aspergillus fumigatus fumigatus 1:500', 'Aspergillus fumigatus extract 20 MG/ML'),
		('benzalkonium 1:5000', 'benzalkonium 2 mg/ml'),
		('candida albicans albicans 1:500', 'candida albicans extract 20 MG/ML'),
		('ginkgo biloba leaf leaf 1:2', 'ginkgo biloba leaf 0.5 '),
		('histoplasmin 1:100', 'Histoplasmin 10 MG/ML'),
		('trichophyton preparation 1 :500', 'Trichophyton 2 MG/ML'),
		('interferon alfa-2b million unt/ml', 'Interferon Alfa-2b 10000000 UNT/ML'),
		('papain million unt', 'Papain 1000000 UNT'),
		('penicillin g million unt', 'Penicillin G 1000000 UNT'),
		('poliovirus vaccine, inactivated antigen u/ml', ''),
		('pseudoephedrine', 'Pseudoephedrine 120 MG'),
		('strontium-89 148mbq-4mci', 'strontium-89 4 MCI'),
		('technetium 99m 99m ns', ''),
		('trichopyton mentagrophytes mentagrophytes 1:500', 'Trichophyton 2 MG/ML'),
		('samarium sm 153 lexidronam 1850 mbq/ml', 'samarium-153 lexidronam 1850 mbq/ml'),
		('saw palmetto extract extract 1:5', 'Saw palmetto extract 0.5 '),
		('sodium phosphate, dibasic 88-30 mg/ml', 'Sodium Phosphate, Dibasic 88 MG/ML'),
		('monobasic potassium phosphate 63-30 mg/ml', 'Monobasic potassium phosphate 63 mg/ml'),
		('short ragweed pollen extract 12 amb a 1-u', 'short ragweed pollen extract 12 UNT'),
		('secretin 75 cu/vial', 'Secretin 10 CU/ML'), -- the vial is supposed to be reconstituted in 7.5 mL of saline
		('sars-cov-2 (covid-19) vaccine, mrna-bnt162b2 omicron (ba.4/ba.5) -1 mg/ml', 'sars-cov-2 (covid-19) vaccine, mrna-bnt162b2 omicron (ba.4/ba.5) 1 mg/ml');

	-- Create Unit mapping
	DROP TABLE IF EXISTS unit_to_concept_map;
	CREATE TABLE unit_to_concept_map (
		source_code VARCHAR(50) NOT NULL,
		source_vocabulary_id VARCHAR(20) NOT NULL,
		source_code_description VARCHAR(255) NULL,
		target_concept_id int4 NOT NULL,
		target_vocabulary_id VARCHAR(20) NOT NULL,
		valid_start_date DATE NOT NULL,
		valid_end_date DATE NOT NULL,
		invalid_reason VARCHAR(1)
		);

	INSERT INTO unit_to_concept_map
	VALUES ('%', '0', 'percent', 8554, '11', TO_DATE('19700101','yyyymmdd'), TO_DATE('20991231','yyyymmdd'), NULL),
		('actuat', '0', '{actuat}', 45744809, '11', TO_DATE('19700101','yyyymmdd'), TO_DATE('20991231','yyyymmdd'), NULL),
		('au', '0', 'allergenic unit', 45744811, '11', TO_DATE('19700101','yyyymmdd'), TO_DATE('20991231','yyyymmdd'), NULL),
		('bau', '0', 'bioequivalent allergenic unit', 45744810, '11', TO_DATE('19700101','yyyymmdd'), TO_DATE('20991231','yyyymmdd'), NULL),
		('cells', '0', 'cells', 45744812, '11', TO_DATE('19700101','yyyymmdd'), TO_DATE('20991231','yyyymmdd'), NULL),
		('cfu', '0', 'colony forming unit', 9278, '11', TO_DATE('19700101','yyyymmdd'), TO_DATE('20991231','yyyymmdd'), NULL),
		('cu', '0', 'clinical unit', 45744813, '11', TO_DATE('19700101','yyyymmdd'), TO_DATE('20991231','yyyymmdd'), NULL),
		('hr', '0', 'hour', 8505, '11', TO_DATE('19700101','yyyymmdd'), TO_DATE('20991231','yyyymmdd'), NULL),
		('iu', '0', 'international unit', 8718, '11', TO_DATE('19700101','yyyymmdd'), TO_DATE('20991231','yyyymmdd'), NULL),
		('lfu', '0', 'limit of flocculation unit', 45744814, '11', TO_DATE('19700101','yyyymmdd'), TO_DATE('20991231','yyyymmdd'), NULL),
		('mci', '0', 'millicurie', 44819154, '11', TO_DATE('19700101','yyyymmdd'), TO_DATE('20991231','yyyymmdd'), NULL),
		('meq', '0', 'milliequivalent', 9551, '11', TO_DATE('19700101','yyyymmdd'), TO_DATE('20991231','yyyymmdd'), NULL),
		('mg', '0', 'milligram', 8576, '11', TO_DATE('19700101','yyyymmdd'), TO_DATE('20991231','yyyymmdd'), NULL),
		('mil', '0', 'milliliter', 8587, '11', TO_DATE('19700101','yyyymmdd'), TO_DATE('20991231','yyyymmdd'), NULL),
		('min', '0', 'minim', 9367, '11', TO_DATE('19700101','yyyymmdd'), TO_DATE('20991231','yyyymmdd'), NULL),
		('ml', '0', 'milliliter', 8587, '11', TO_DATE('19700101','yyyymmdd'), TO_DATE('20991231','yyyymmdd'), NULL),
		('mmol', '0', 'millimole', 9573, '11', TO_DATE('19700101','yyyymmdd'), TO_DATE('20991231','yyyymmdd'), NULL),
		('mmole', '0', 'millimole', 9573, '11', TO_DATE('19700101','yyyymmdd'), TO_DATE('20991231','yyyymmdd'), NULL),
		('mu', '0', 'mega-international unit', 9439, '11', TO_DATE('19700101','yyyymmdd'), TO_DATE('20991231','yyyymmdd'), NULL),
		('ns', '0', 'unmapped', '0', '11', TO_DATE('19700101','yyyymmdd'), TO_DATE('20991231','yyyymmdd'), NULL),
		('org', '0', 'unmapped', '0', '11', TO_DATE('19700101','yyyymmdd'), TO_DATE('20991231','yyyymmdd'), NULL),
		('organisms', '0', 'bacteria', 45744815, '11', TO_DATE('19700101','yyyymmdd'), TO_DATE('20991231','yyyymmdd'), NULL),
		('pfu', '0', 'plaque forming unit', 9379, '11', TO_DATE('19700101','yyyymmdd'), TO_DATE('20991231','yyyymmdd'), NULL),
		('pnu', '0', 'protein nitrogen unit', 45744816, '11', TO_DATE('19700101','yyyymmdd'), TO_DATE('20991231','yyyymmdd'), NULL),
		('sqcm', '0', 'square centimeter', 9483, '11', TO_DATE('19700101','yyyymmdd'), TO_DATE('20991231','yyyymmdd'), NULL),
		('tcid', '0', '50% tissue culture infectious dose', 9414, '11', TO_DATE('19700101','yyyymmdd'), TO_DATE('20991231','yyyymmdd'), NULL),
		('unt', '0', 'unit', 8510, '11', TO_DATE('19700101','yyyymmdd'), TO_DATE('20991231','yyyymmdd'), NULL),
		('ir', '0', 'index of reactivity', 9693, '11', TO_DATE('19700101','yyyymmdd'), TO_DATE('20991231','yyyymmdd'), NULL),
		('vector-genomes', 0, 'vector-genomes', 32018, '11', TO_DATE('19700101','yyyymmdd'), TO_DATE('20991231','yyyymmdd'), NULL),
		('sq-hdm', 0, 'standardized quality house dust mite', 32407, '11', TO_DATE('19700101','yyyymmdd'), TO_DATE('20991231','yyyymmdd'), NULL);


	/* 2. Make sure that invalid concepts are standard_concept = NULL */
	UPDATE concept_stage cs
	SET standard_concept = NULL
	WHERE cs.valid_end_date <> TO_DATE('20991231', 'yyyymmdd')
		AND cs.standard_concept IS NOT NULL;

	/* 3. Create RxNorm's concept code ancestor */
	DROP TABLE IF EXISTS rxnorm_ancestor;
	CREATE UNLOGGED TABLE rxnorm_ancestor AS (
		WITH RECURSIVE hierarchy_concepts(ancestor_concept_code, ancestor_vocabulary_id, descendant_concept_code, descendant_vocabulary_id, root_ancestor_concept_code, root_ancestor_vocabulary_id, full_path) AS (
			SELECT ancestor_concept_code,
				ancestor_vocabulary_id,
				descendant_concept_code,
				descendant_vocabulary_id,
				ancestor_concept_code AS root_ancestor_concept_code,
				ancestor_vocabulary_id AS root_ancestor_vocabulary_id,
				ARRAY [ROW (descendant_concept_code, descendant_vocabulary_id)] AS full_path
			FROM concepts
			
			UNION ALL
			
			SELECT c.ancestor_concept_code,
				c.ancestor_vocabulary_id,
				c.descendant_concept_code,
				c.descendant_vocabulary_id,
				root_ancestor_concept_code,
				root_ancestor_vocabulary_id,
				hc.full_path || ROW(c.descendant_concept_code, c.descendant_vocabulary_id) AS full_path
			FROM concepts c
			JOIN hierarchy_concepts hc ON hc.descendant_concept_code = c.ancestor_concept_code
				AND hc.descendant_vocabulary_id = c.ancestor_vocabulary_id
			WHERE ROW(c.descendant_concept_code, c.descendant_vocabulary_id) <> ALL (full_path)
			),
		concepts AS (
			SELECT crs.concept_code_1 AS ancestor_concept_code,
				crs.vocabulary_id_1 AS ancestor_vocabulary_id,
				crs.concept_code_2 AS descendant_concept_code,
				crs.vocabulary_id_2 AS descendant_vocabulary_id
			FROM concept_relationship_stage crs
			JOIN relationship s ON s.relationship_id = crs.relationship_id
				AND s.defines_ancestry = 1
			JOIN concept_stage c1 ON c1.concept_code = crs.concept_code_1
				AND c1.vocabulary_id = crs.vocabulary_id_1
				AND c1.invalid_reason IS NULL
				AND c1.vocabulary_id = 'RxNorm'
			JOIN concept_stage c2 ON c2.concept_code = crs.concept_code_2
				AND c1.vocabulary_id = crs.vocabulary_id_2
				AND c2.invalid_reason IS NULL
				AND c2.vocabulary_id = 'RxNorm'
			WHERE crs.invalid_reason IS NULL
			) SELECT DISTINCT hc.root_ancestor_concept_code AS ancestor_concept_code,
		hc.root_ancestor_vocabulary_id AS ancestor_vocabulary_id,
		hc.descendant_concept_code,
		hc.descendant_vocabulary_id FROM hierarchy_concepts hc JOIN concept_stage cs1 ON cs1.concept_code = hc.root_ancestor_concept_code
		AND cs1.standard_concept IS NOT NULL JOIN concept_stage cs2 ON cs2.concept_code = hc.descendant_concept_code
		AND cs2.standard_concept IS NOT NULL

	UNION ALL
		
		SELECT cs.concept_code,
		cs.vocabulary_id,
		cs.concept_code,
		cs.vocabulary_id FROM concept_stage cs WHERE cs.vocabulary_id = 'RxNorm'
		AND cs.invalid_reason IS NULL
		AND cs.standard_concept IS NOT NULL
		);
	ANALYZE rxnorm_ancestor;

	/* 4. Return proper valid_start_date from concept*/
	UPDATE concept_stage cs
	SET valid_start_date = i.valid_start_date
	FROM (
		SELECT c.concept_code,
			c.valid_start_date
		FROM concept c
		WHERE c.vocabulary_id = 'RxNorm'
		) i
	WHERE cs.concept_code = i.concept_code
		AND cs.vocabulary_id = 'RxNorm'
		AND cs.valid_start_date <> i.valid_start_date;

	/* 5. Fix valid_start_date for incorrect concepts (bad data in sources) */
	UPDATE concept_stage cs
	SET valid_start_date = cs.valid_end_date - 1
	WHERE cs.valid_end_date < cs.valid_start_date
		AND cs.vocabulary_id = 'RxNorm';
	 
	/* 6. Build drug_strength_stage table for '* Drugs' */
	INSERT INTO drug_strength_stage
	SELECT DISTINCT drug_concept_code,
		'RxNorm' AS vocabulary_id_1,
		ingredient_concept_code,
		'RxNorm' AS vocabulary_id_2,
		amount_value,
		amount_unit_concept_id,
		numerator_value,
		numerator_unit_concept_id,
		denominator_value,
		denominator_unit_concept_id,
		valid_start_date,
		valid_end_date,
		NULL AS invalid_reason
	FROM (
		SELECT ds.drug_concept_code,
			ds.ingredient_concept_code,
			denominator_value,
			first_value(amount_value) OVER (
				PARTITION BY drug_concept_code,
				ingredient_concept_code ORDER BY component_concept_code rows BETWEEN unbounded preceding
						AND unbounded following
				) AS amount_value,
			first_value(au.target_concept_id) OVER (
				PARTITION BY drug_concept_code,
				ingredient_concept_code ORDER BY component_concept_code rows BETWEEN unbounded preceding
						AND unbounded following
				) AS amount_unit_concept_id,
			first_value(numerator_value) OVER (
				PARTITION BY drug_concept_code,
				ingredient_concept_code ORDER BY component_concept_code rows BETWEEN unbounded preceding
						AND unbounded following
				) AS numerator_value,
			first_value(nu.target_concept_id) OVER (
				PARTITION BY drug_concept_code,
				ingredient_concept_code ORDER BY component_concept_code rows BETWEEN unbounded preceding
						AND unbounded following
				) AS numerator_unit_concept_id,
			first_value(du.target_concept_id) OVER (
				PARTITION BY drug_concept_code,
				ingredient_concept_code ORDER BY component_concept_code rows BETWEEN unbounded preceding
						AND unbounded following
				) AS denominator_unit_concept_id,
			ds.valid_start_date,
			ds.valid_end_date
		FROM (
			SELECT DISTINCT drug_concept_code,
				ingredient_concept_code,
				component_concept_code,
				sum(amount) OVER (
					PARTITION BY drug_concept_code,
					ingredient_concept_code,
					numerator_unit
					) AS amount_value,
				amount_unit,
				sum(numerator) OVER (
					PARTITION BY drug_concept_code,
					ingredient_concept_code,
					numerator_unit
					) AS numerator_value,
				numerator_unit,
				NULL::NUMERIC AS denominator_value, -- in Clinical/Branded Drugs always normalized to 1
				denominator_unit,
				valid_start_date,
				valid_end_date
			FROM (
				SELECT drug_concept_code,
					ingredient_concept_code,
					component_concept_code,
					CASE 
						WHEN component_name ~ '\/[^-]'
							THEN NULL
						ELSE SUBSTRING(substring(component_name FROM position), '( [0-9]+(\.[0-9]+)? )')
						END::NUMERIC AS amount,
					CASE 
						WHEN component_name ~ '\/[^-]'
							THEN NULL
						ELSE lower(substring(substring(substring(component_name FROM position), ' [0-9\.]+\s+[^0-9\. ]+'), '[^0-9\. ]+'))
						END AS amount_unit,
					CASE 
						WHEN NOT component_name ~ '\/[^-]'
							THEN NULL
						ELSE substring(substring(component_name FROM position), '.* ([0-9.]+) [[:alpha:]-]+')
						END::NUMERIC AS numerator,
					CASE 
						WHEN NOT component_name ~ '\/[^-]'
							THEN NULL
						ELSE lower(substring(substring(component_name FROM position),'.* [0-9.]+ ([[:alpha:]-]+)')) --lower(substring(substring(substring(component_name FROM position), '( [0-9]+(\.[0-9]+)?\s+[^0-9\. \/]+)'), '[^0-9\. \/]+'))
						END AS numerator_unit,
					CASE 
						WHEN NOT component_name ~ '\/[^-]'
							THEN NULL
						ELSE lower(substring(substring(substring(component_name FROM position), '\/[^0-9\.]+\Z'), '[^0-9\. \/]+'))
						END AS denominator_unit,
					component_start_date AS valid_start_date,
					component_end_date AS valid_end_date
				FROM (
					SELECT -- if ingredient name is not part of component name start from position 1, otherwise start after the ingredient name
						drug_concept_code,
						component_name,
						component_start_date,
						component_end_date,
						ingredient_concept_code,
						ingredient_name,
						len,
						CASE position
							WHEN 0
								THEN 1
							ELSE position + len
							END AS position,
						component_concept_code
					FROM (
						SELECT -- get the position of the ingredient inside the component
							drug_concept_code,
							component_name,
							component_start_date,
							component_end_date,
							ingredient_concept_code,
							ingredient_name,
							devv5.instr(component_name, ingredient_name) AS position,
							length(ingredient_name) AS len,
							component_concept_code
						FROM (
							-- provide drugs with cleaned components and ingredients 
							SELECT drug_concept_code,
								ingredient_concept_code,
								component_concept_code,
								regexp_replace(lower(component_name), 'ic\s+acid', 'ate','g') AS component_name,
								min(component_start_date) OVER (PARTITION BY ingredient_concept_code) AS component_start_date,
								max(component_end_date) OVER (PARTITION BY ingredient_concept_code) AS component_end_date,
								-- pick the latest ingredient
								regexp_replace(lower(first_value(ingredient_name) OVER (
											PARTITION BY component_concept_code ORDER BY valid_end_date DESC
											)), 'ic\s+acid', 'ate','g') AS ingredient_name
							FROM (
								SELECT DISTINCT -- select for each drug the drug_component(s) and ingredient(s), and replace the component name if necessary
									d.concept_code AS drug_concept_code,
									c.concept_code AS component_concept_code,
									c.valid_start_date AS component_start_date,
									c.valid_end_date AS component_end_date,
									COALESCE(r.replace_with, c.concept_name) AS component_name,
									i.concept_code AS ingredient_concept_code,
									i.concept_name AS ingredient_name,
									i.valid_end_date
								FROM concept_stage d
								JOIN rxnorm_ancestor a1 ON a1.descendant_concept_code = d.concept_code
									AND a1.descendant_vocabulary_id = d.vocabulary_id
								JOIN concept_stage c ON c.concept_code = a1.ancestor_concept_code
									AND c.vocabulary_id = a1.ancestor_vocabulary_id
									AND c.concept_class_id = 'Clinical Drug Comp'
									AND c.vocabulary_id = 'RxNorm'
								JOIN rxnorm_ancestor a2 ON a2.descendant_concept_code = c.concept_code
									AND a2.descendant_vocabulary_id = c.vocabulary_id
								JOIN concept_stage i ON i.concept_code = a2.ancestor_concept_code
									AND i.vocabulary_id = a2.ancestor_vocabulary_id
									AND i.concept_class_id = 'Ingredient'
									AND i.vocabulary_id = 'RxNorm'
								LEFT JOIN component_replace r ON r.component_name = lower(c.concept_name)
								WHERE d.standard_concept = 'S'
									AND d.concept_class_id IN (
										'Clinical Drug',
										'Branded Drug',
										'Branded Drug Comp'
										)
									AND d.vocabulary_id = 'RxNorm'
								) AS s0
							) AS s1
						) AS s2
					) AS s3
				) AS s4
			) ds
		LEFT JOIN unit_to_concept_map au ON au.source_code = ds.amount_unit
		LEFT JOIN unit_to_concept_map nu ON nu.source_code = ds.numerator_unit
		LEFT JOIN unit_to_concept_map du ON du.source_code = ds.denominator_unit
		) AS s5;

	/* 7. Write 'Clinical Drug Components' */
	INSERT INTO drug_strength_stage
	SELECT drug_concept_code,
		'RxNorm' AS vocabulary_id_1,
		ingredient_concept_code,
		'RxNorm' AS vocabulary_id_2,
		amount_value,
		amount_unit_concept_id,
		numerator_value,
		numerator_unit_concept_id,
		denominator_value,
		denominator_unit_concept_id,
		valid_start_date,
		valid_end_date,
		invalid_reason
	FROM (
		SELECT DISTINCT ds.drug_concept_code,
			ds.ingredient_concept_code,
			denominator_value,
			first_value(amount_value) OVER (
				PARTITION BY drug_concept_code,
				ingredient_concept_code ORDER BY component_concept_code rows BETWEEN unbounded preceding
						AND unbounded following
				) AS amount_value,
			first_value(au.target_concept_id) OVER (
				PARTITION BY drug_concept_code,
				ingredient_concept_code ORDER BY component_concept_code rows BETWEEN unbounded preceding
						AND unbounded following
				) AS amount_unit_concept_id,
			first_value(numerator_value) OVER (
				PARTITION BY drug_concept_code,
				ingredient_concept_code ORDER BY component_concept_code rows BETWEEN unbounded preceding
						AND unbounded following
				) AS numerator_value,
			first_value(nu.target_concept_id) OVER (
				PARTITION BY drug_concept_code,
				ingredient_concept_code ORDER BY component_concept_code rows BETWEEN unbounded preceding
						AND unbounded following
				) AS numerator_unit_concept_id,
			first_value(du.target_concept_id) OVER (
				PARTITION BY drug_concept_code,
				ingredient_concept_code ORDER BY component_concept_code rows BETWEEN unbounded preceding
						AND unbounded following
				) AS denominator_unit_concept_id,
			ds.valid_start_date,
			ds.valid_end_date,
			NULL AS invalid_reason
		FROM (
			SELECT DISTINCT drug_concept_code,
				ingredient_concept_code,
				component_concept_code,
				sum(amount) OVER (
					PARTITION BY drug_concept_code,
					ingredient_concept_code,
					numerator_unit
					) AS amount_value,
				amount_unit,
				sum(numerator) OVER (
					PARTITION BY drug_concept_code,
					ingredient_concept_code,
					numerator_unit
					) AS numerator_value,
				numerator_unit,
				NULL::NUMERIC AS denominator_value, -- denominator_value, in Clinical/Branded Drugs always normalized to 1
				denominator_unit,
				valid_start_date,
				valid_end_date
			FROM (
				SELECT drug_concept_code,
					ingredient_concept_code,
					component_concept_code,
					CASE 
						WHEN component_name ~ '\/[^-]'
							THEN NULL
						ELSE substring(substring(component_name FROM position), '( [0-9]+(\.[0-9]+)? )')
						END::NUMERIC AS amount,
					CASE 
						WHEN component_name ~ '\/[^-]'
							THEN NULL
						ELSE lower(substring(substring(substring(component_name FROM position), ' [0-9\.]+\s+[^0-9\. ]+'), '[^0-9\. ]+'))
						END AS amount_unit,
					CASE 
						WHEN NOT component_name ~ '\/[^-]'
							THEN NULL
						ELSE substring(substring(component_name FROM position), '.* ([0-9.]+) [[:alpha:]-]+')
						END::NUMERIC AS numerator,
					CASE 
						WHEN NOT component_name ~ '\/[^-]'
							THEN NULL
						ELSE lower(substring(substring(component_name FROM position),'.* [0-9.]+ ([[:alpha:]-]+)')) --lower(substring(substring(substring(component_name FROM position), '( [0-9]+(\.[0-9]+)?\s+[^0-9\. \/]+)'), '[^0-9\. \/]+'))
						END AS numerator_unit,
					CASE 
						WHEN NOT component_name ~ '\/[^-]'
							THEN NULL
						ELSE lower(substring(substring(substring(component_name FROM position), '\/[^0-9\.]+\Z'), '[^0-9\. \/]+'))
						END AS denominator_unit,
					component_start_date AS valid_start_date,
					component_end_date AS valid_end_date
				FROM (
					SELECT -- if ingredient name is not part of component name start from position 1, otherwise start after the ingredient name
						drug_concept_code,
						component_name,
						component_start_date,
						component_end_date,
						ingredient_concept_code,
						ingredient_name,
						len,
						CASE position
							WHEN 0
								THEN 1
							ELSE position + len
							END AS position,
						component_concept_code
					FROM (
						SELECT -- get the position of the ingredient inside the component
							drug_concept_code,
							component_name,
							component_start_date,
							component_end_date,
							ingredient_concept_code,
							ingredient_name,
							devv5.instr(component_name, ingredient_name) AS position,
							length(ingredient_name) AS len,
							component_concept_code
						FROM (
							-- provide drugs with cleaned components and ingredients 
							SELECT drug_concept_code,
								ingredient_concept_code,
								component_concept_code,
								regexp_replace(lower(component_name), 'ic\s+acid', 'ate','g') AS component_name,
								min(component_start_date) OVER (PARTITION BY ingredient_concept_code) AS component_start_date,
								max(component_end_date) OVER (PARTITION BY ingredient_concept_code) AS component_end_date,
								-- pick the latest ingredient
								regexp_replace(lower(first_value(ingredient_name) OVER (
											PARTITION BY component_concept_code ORDER BY valid_end_date DESC
											)), 'ic\s+acid', 'ate','g') AS ingredient_name
							FROM (
								SELECT DISTINCT -- select for each drug the drug_component(s) and ingredient(s), and replace the component name if necessary
									c.concept_code AS drug_concept_code,
									c.concept_code AS component_concept_code,
									c.valid_start_date AS component_start_date,
									c.valid_end_date AS component_end_date,
									COALESCE(r.replace_with, c.concept_name) AS component_name,
									i.concept_code AS ingredient_concept_code,
									i.concept_name AS ingredient_name,
									i.valid_end_date
								FROM concept_stage c
								JOIN rxnorm_ancestor a2 ON a2.descendant_concept_code = c.concept_code
									AND a2.descendant_vocabulary_id = c.vocabulary_id
								JOIN concept_stage i ON i.concept_code = a2.ancestor_concept_code
									AND i.vocabulary_id = a2.ancestor_vocabulary_id
									AND i.concept_class_id = 'Ingredient'
									AND i.vocabulary_id = 'RxNorm'
								LEFT JOIN component_replace r ON r.component_name = lower(c.concept_name)
								WHERE c.standard_concept = 'S'
									AND c.concept_class_id = 'Clinical Drug Comp'
									AND c.vocabulary_id = 'RxNorm'
								) AS s0
							) AS s1
						) AS s2
					) AS s3
				) AS s4
			) ds
		LEFT JOIN unit_to_concept_map au ON au.source_code = ds.amount_unit
		LEFT JOIN unit_to_concept_map nu ON nu.source_code = ds.numerator_unit
		LEFT JOIN unit_to_concept_map du ON du.source_code = ds.denominator_unit
		) AS s5;

	/* 8. Write 'Quantified * Drugs from Clinical Drugs */
	-- Quantity provided in "ACTUAT": They only exist for concentrations of ingredients
	INSERT INTO drug_strength_stage
	SELECT DISTINCT drug_concept_code,
		vocabulary_id_1,
		ingredient_concept_code,
		vocabulary_id_2,
		amount_value,
		amount_unit_concept_id,
		numerator_value,
		numerator_unit_concept_id,
		denominator_value,
		denominator_unit_concept_id,
		valid_start_date,
		valid_end_date,
		invalid_reason
	FROM (
		SELECT drug_concept_code, -- of the quantified
			vocabulary_id_1,
			ingredient_concept_code, -- of the original non-quantified
			vocabulary_id_2,
			NULL::NUMERIC AS amount_value,
			NULL::INT4 AS amount_unit_concept_id,
			v * numerator_value AS numerator_value,
			numerator_unit_concept_id,
			v AS denominator_value, -- newly added amount
			denominator_unit_concept_id,
			valid_start_date,
			valid_end_date,
			NULL::VARCHAR AS invalid_reason
		FROM (
			SELECT q.concept_code AS drug_concept_code,
				ds.vocabulary_id_1,
				ds.ingredient_concept_code,
				ds.vocabulary_id_2,
				ds.numerator_value,
				ds.numerator_unit_concept_id,
				ds.denominator_unit_concept_id, -- Actuations never have values in the amount section
				ds.valid_start_date,
				ds.valid_end_date,
				substring(q.concept_name, '^[0-9\.]+')::NUMERIC AS v
			FROM drug_strength_stage ds
			JOIN concept_stage d ON d.concept_code = ds.drug_concept_code
				AND d.vocabulary_id = ds.vocabulary_id_1
				AND d.concept_class_id IN (
					'Clinical Drug',
					'Branded Drug'
					)
				AND d.vocabulary_id = 'RxNorm'
			JOIN concept_relationship_stage r ON r.concept_code_1 = ds.drug_concept_code
				AND r.vocabulary_id_1 = ds.vocabulary_id_1
				AND r.invalid_reason IS NULL
			JOIN concept_stage q ON q.concept_code = r.concept_code_2
				AND q.vocabulary_id = r.vocabulary_id_2
				AND q.concept_class_id LIKE 'Quant%'
				AND q.standard_concept = 'S'
				AND q.vocabulary_id = 'RxNorm'
				AND substring(q.concept_name, '[^ 0-9\.]+') = 'ACTUAT' -- parsing out the quantity
			) AS s0
		) AS s1;

	-- Quantity provided in "DAY". Treat equivalent to 24 hours
	INSERT INTO drug_strength_stage
	SELECT DISTINCT drug_concept_code,
		vocabulary_id_1,
		ingredient_concept_code,
		vocabulary_id_2,
		amount_value,
		amount_unit_concept_id,
		numerator_value,
		numerator_unit_concept_id,
		denominator_value,
		denominator_unit_concept_id,
		valid_start_date,
		valid_end_date,
		invalid_reason
	FROM (
		SELECT drug_concept_code, -- of the quantified
			vocabulary_id_1,
			ingredient_concept_code, -- of the original non-quantified
			vocabulary_id_2,
			NULL::NUMERIC AS amount_value,
			NULL::INT4 AS amount_unit_concept_id,
			v * numerator_value * 24 AS numerator_value,
			numerator_unit_concept_id,
			v * 24 AS denominator_value, -- newly added amount
			denominator_unit_concept_id,
			valid_start_date,
			valid_end_date,
			NULL::VARCHAR AS invalid_reason
		FROM (
			SELECT q.concept_code AS drug_concept_code,
				ds.vocabulary_id_1,
				ds.ingredient_concept_code,
				ds.vocabulary_id_2,
				ds.numerator_value,
				ds.numerator_unit_concept_id,
				ds.denominator_unit_concept_id, -- Actuations never have values in the amount section
				ds.valid_start_date,
				ds.valid_end_date,
				substring(q.concept_name, '^[0-9\.]+')::NUMERIC AS v
			FROM drug_strength_stage ds
			JOIN concept_stage d ON d.concept_code = ds.drug_concept_code
				AND d.vocabulary_id = ds.vocabulary_id_1
				AND d.concept_class_id IN (
					'Clinical Drug',
					'Branded Drug'
					)
				AND d.vocabulary_id = 'RxNorm'
			JOIN concept_relationship_stage r ON r.concept_code_1 = ds.drug_concept_code
				AND r.vocabulary_id_1 = ds.vocabulary_id_1
				AND r.invalid_reason IS NULL
			JOIN concept_stage q ON q.concept_code = r.concept_code_2
				AND q.vocabulary_id = r.vocabulary_id_2
				AND q.concept_class_id LIKE 'Quant%'
				AND q.standard_concept = 'S'
				AND q.vocabulary_id = 'RxNorm'
				AND substring(q.concept_name, '[^ 0-9\.]+') = 'DAY' -- parsing out the quantity
			) AS s0
		) AS s1;

	-- Quantity provided in "Unit": the amount is the total dose, not the total volume
	INSERT INTO drug_strength_stage
	SELECT DISTINCT drug_concept_code,
		vocabulary_id_1,
		ingredient_concept_code,
		vocabulary_id_2,
		amount_value,
		amount_unit_concept_id,
		numerator_value,
		numerator_unit_concept_id,
		denominator_value,
		denominator_unit_concept_id,
		valid_start_date,
		valid_end_date,
		invalid_reason
	FROM (
		SELECT drug_concept_code, -- of the quantified
			vocabulary_id_1,
			ingredient_concept_code, -- of the original non-quantified
			vocabulary_id_2,
			NULL::NUMERIC AS amount_value,
			NULL::int4 AS amount_unit_concept_id,
			v AS numerator_value,
			numerator_unit_concept_id,
			v / numerator_value AS denominator_value, -- newly added amount
			denominator_unit_concept_id,
			valid_start_date,
			valid_end_date,
			NULL::VARCHAR AS invalid_reason
		FROM (
			SELECT q.concept_code AS drug_concept_code,
				ds.vocabulary_id_1,
				ds.ingredient_concept_code,
				ds.vocabulary_id_2,
				ds.numerator_value,
				ds.numerator_unit_concept_id,
				ds.denominator_unit_concept_id, -- Actuations never have values in the amount section
				ds.valid_start_date,
				ds.valid_end_date,
				substring(q.concept_name, '^[0-9\.]+')::NUMERIC AS v
			FROM drug_strength_stage ds
			JOIN concept_stage d ON d.concept_code = ds.drug_concept_code
				AND d.vocabulary_id = ds.vocabulary_id_1
				AND d.concept_class_id IN (
					'Clinical Drug',
					'Branded Drug'
					)
				AND d.vocabulary_id = 'RxNorm'
			JOIN concept_relationship_stage r ON r.concept_code_1 = ds.drug_concept_code
				AND r.vocabulary_id_1 = ds.vocabulary_id_1
				AND r.invalid_reason IS NULL
			JOIN concept_stage q ON q.concept_code = r.concept_code_2
				AND q.vocabulary_id = r.vocabulary_id_2
				AND q.concept_class_id LIKE 'Quant%'
				AND q.standard_concept = 'S'
				AND q.vocabulary_id = 'RxNorm'
				AND substring(q.concept_name, '[^ 0-9\.]+') = 'UNT' -- parsing out the quantity
			) AS s0
		) AS s1;

	-- Quantity provided in "MG": the amount volume of a gel usually, which is given in /mg or /mL concentrations
	INSERT INTO drug_strength_stage
	SELECT DISTINCT drug_concept_code,
		vocabulary_id_1,
		ingredient_concept_code,
		vocabulary_id_2,
		amount_value,
		amount_unit_concept_id,
		numerator_value,
		numerator_unit_concept_id,
		denominator_value,
		denominator_unit_concept_id,
		valid_start_date,
		valid_end_date,
		invalid_reason
	FROM (
		SELECT drug_concept_code, -- of the quantified
			vocabulary_id_1,
			ingredient_concept_code, -- of the original non-quantified
			vocabulary_id_2,
			NULL::NUMERIC AS amount_value,
			NULL::int4 AS amount_unit_concept_id,
			CASE denominator_unit_concept_id
				WHEN 8587
					THEN v * numerator_value / 1000 -- ml, convert to mg
				ELSE v * numerator_value
				END AS numerator_value,
			numerator_unit_concept_id,
			CASE denominator_unit_concept_id
				WHEN 8587
					THEN v / 1000 -- ml, convert to mg
				ELSE v
				END AS denominator_value,
			denominator_unit_concept_id,
			valid_start_date,
			valid_end_date,
			NULL::VARCHAR AS invalid_reason
		FROM (
			SELECT q.concept_code AS drug_concept_code,
				ds.vocabulary_id_1,
				ds.ingredient_concept_code,
				ds.vocabulary_id_2,
				ds.numerator_value,
				ds.numerator_unit_concept_id,
				ds.denominator_unit_concept_id, -- Actuations never have values in the amount section
				ds.valid_start_date,
				ds.valid_end_date,
				substring(q.concept_name, '^[0-9\.]+')::NUMERIC AS v
			FROM drug_strength_stage ds
			JOIN concept_stage d ON d.concept_code = ds.drug_concept_code
				AND d.vocabulary_id = ds.vocabulary_id_1
				AND d.concept_class_id IN (
					'Clinical Drug',
					'Branded Drug'
					)
				AND d.vocabulary_id = 'RxNorm'
			JOIN concept_relationship_stage r ON r.concept_code_1 = ds.drug_concept_code
				AND r.vocabulary_id_1 = ds.vocabulary_id_1
				AND r.invalid_reason IS NULL
			JOIN concept_stage q ON q.concept_code = r.concept_code_2
				AND q.vocabulary_id = r.vocabulary_id_2
				AND q.concept_class_id LIKE 'Quant%'
				AND q.standard_concept = 'S'
				AND q.vocabulary_id = 'RxNorm'
				AND substring(q.concept_name, '[^ 0-9\.]+') = 'MG' -- parsing out the quantity
			) AS s0
		) AS s1;

	-- Quantity provided in "HR": The situation is complex. 
	-- If the drug a solids, in that case the entire amounts becomes the numerator, the hours the denominator
	-- If the drug is given as concentration and the denominator is hours, both the numerator and denominator is multiplied with the hours
	-- If the drug is given as concentration, it is assumed that the total amount is a unit of 1 (mg or ml) and all of that gets released in the given amount of hours. This is probabl not true
	INSERT INTO drug_strength_stage
	SELECT DISTINCT drug_concept_code,
		vocabulary_id_1,
		ingredient_concept_code,
		vocabulary_id_2,
		amount_value,
		amount_unit_concept_id,
		numerator_value,
		numerator_unit_concept_id,
		denominator_value,
		denominator_unit_concept_id,
		valid_start_date,
		valid_end_date,
		invalid_reason
	FROM (
		SELECT drug_concept_code, -- of the quantified
			vocabulary_id_1,
			ingredient_concept_code, -- of the original non-quantified
			vocabulary_id_2,
			NULL::NUMERIC AS amount_value,
			NULL::int4 AS amount_unit_concept_id,
			CASE 
				WHEN amount_unit_concept_id = 8510
					THEN amount_value -- unit in numerator
				WHEN amount_unit_concept_id = 8576
					THEN amount_value -- mg in numerator
				WHEN denominator_unit_concept_id = 8505
					THEN numerator_value * v -- hour in denominator
				ELSE numerator_value -- if concentration given assume entire concent will release over the given hours
				END AS numerator_value,
			COALESCE(amount_unit_concept_id, numerator_unit_concept_id) AS numerator_unit_concept_id,
			v AS denominator_value,
			8505 AS denominator_unit_concept_id, -- everything is going to be unit/hour
			valid_start_date,
			valid_end_date,
			NULL::VARCHAR AS invalid_reason
		FROM (
			SELECT q.concept_code AS drug_concept_code,
				ds.vocabulary_id_1,
				ds.ingredient_concept_code,
				ds.vocabulary_id_2,
				ds.amount_value,
				ds.amount_unit_concept_id,
				ds.numerator_value,
				ds.numerator_unit_concept_id,
				ds.denominator_unit_concept_id, -- Actuations never have values in the amount section
				ds.valid_start_date,
				ds.valid_end_date,
				substring(q.concept_name, '^[0-9\.]+')::NUMERIC AS v
			FROM drug_strength_stage ds
			JOIN concept_stage d ON d.concept_code = ds.drug_concept_code
				AND d.vocabulary_id = ds.vocabulary_id_1
				AND d.concept_class_id IN (
					'Clinical Drug',
					'Branded Drug'
					)
				AND d.vocabulary_id = 'RxNorm'
			JOIN concept_relationship_stage r ON r.concept_code_1 = ds.drug_concept_code
				AND r.vocabulary_id_1 = ds.vocabulary_id_1
				AND r.invalid_reason IS NULL
			JOIN concept_stage q ON q.concept_code = r.concept_code_2
				AND q.vocabulary_id = r.vocabulary_id_2
				AND q.concept_class_id LIKE 'Quant%'
				AND q.standard_concept = 'S'
				AND q.vocabulary_id = 'RxNorm'
				AND substring(q.concept_name, '[^ 0-9\.]+') = 'HR' -- parsing out the quantity
			) AS s0
		) AS s1;

	-- Quantity provided in "ML": The situation is complex. 
	-- If the drug a solids, in that case the entire amounts becomes the numerator, the mL the denominator
	-- If the drug is given as concentration and the denominator is milligram instead of milliliter, both values are multiplied by 1000
	-- Otherwise, the concentration is multiplied with the mL
	INSERT INTO drug_strength_stage
	SELECT drug_concept_code,
		vocabulary_id_1,
		ingredient_concept_code,
		vocabulary_id_2,
		amount_value,
		amount_unit_concept_id,
		numerator_value,
		numerator_unit_concept_id,
		denominator_value,
		denominator_unit_concept_id,
		valid_start_date,
		valid_end_date,
		invalid_reason
	FROM (
		SELECT DISTINCT drug_concept_code, -- of the quantified
			vocabulary_id_1,
			ingredient_concept_code, -- of the original non-quantified
			vocabulary_id_2,
			NULL::NUMERIC AS amount_value,
			NULL::int4 AS amount_unit_concept_id,
			CASE 
				WHEN amount_unit_concept_id = 8510
					THEN amount_value -- unit (doesn't happen yet)
				WHEN amount_unit_concept_id = 8576
					THEN amount_value -- mg 
				WHEN denominator_unit_concept_id = 8576
					THEN numerator_value * v * 1000 -- if mg in denominator
				ELSE numerator_value * v -- if concentration given assume entire concent will release over the given hours
				END AS numerator_value,
			COALESCE(amount_unit_concept_id, numerator_unit_concept_id) AS numerator_unit_concept_id,
			CASE 
				WHEN denominator_unit_concept_id = 8576
					THEN v * 1000 -- milliliter to milligram
				ELSE v
				END AS denominator_value,
			CASE 
				WHEN amount_unit_concept_id IS NOT NULL
					THEN 8587 -- ml
				ELSE denominator_unit_concept_id
				END AS denominator_unit_concept_id,
			valid_start_date,
			valid_end_date,
			NULL::VARCHAR AS invalid_reason
		FROM (
			SELECT q.concept_code AS drug_concept_code,
				ds.vocabulary_id_1,
				ds.ingredient_concept_code,
				ds.vocabulary_id_2,
				ds.amount_value,
				ds.amount_unit_concept_id,
				ds.numerator_value,
				ds.numerator_unit_concept_id,
				ds.denominator_unit_concept_id,
				ds.valid_start_date,
				ds.valid_end_date,
				substring(q.concept_name, '^[0-9\.]+')::NUMERIC AS v
			FROM drug_strength_stage ds
			JOIN concept_stage d ON d.concept_code = ds.drug_concept_code
				AND d.vocabulary_id = ds.vocabulary_id_1
				AND d.concept_class_id IN (
					'Clinical Drug',
					'Branded Drug'
					)
				AND d.vocabulary_id = 'RxNorm'
			JOIN concept_relationship_stage r ON r.concept_code_1 = ds.drug_concept_code
				AND r.vocabulary_id_1 = ds.vocabulary_id_1
				AND r.invalid_reason IS NULL
			JOIN concept_stage q ON q.concept_code = r.concept_code_2
				AND q.vocabulary_id = r.vocabulary_id_2
				AND q.concept_class_id LIKE 'Quant%'
				AND q.standard_concept = 'S'
				AND q.vocabulary_id = 'RxNorm'
				AND substring(q.concept_name, '[^ 0-9\.]+') = 'ML' -- parsing out the quantity
			) AS s0
		) AS s1;

	/* 9. Shift percent from amount to numerator */
	UPDATE drug_strength_stage
	SET numerator_value = amount_value,
		numerator_unit_concept_id = 8554,
		amount_value = NULL,
		amount_unit_concept_id = NULL
	WHERE amount_unit_concept_id = 8554;

	/* 10. Final diagnostic and clean up */
	-- check unparsed records
	--select * from drug_strength_stage where amount_unit_concept_id is null and numerator_unit_concept_id is null;
	ALTER TABLE drug_strength_stage ADD CONSTRAINT ds_check_units CHECK (COALESCE(amount_unit_concept_id, numerator_unit_concept_id, - 1) <> - 1);
	ALTER TABLE drug_strength_stage DROP CONSTRAINT ds_check_units;
	-- check that numbers are all valid
	--select * from drug_strength_stage where (amount_value=0 or numerator_value=0);
	ALTER TABLE drug_strength_stage ADD CONSTRAINT ds_check_values CHECK (COALESCE(amount_value, 1) > 0 AND COALESCE(numerator_value, 1) > 0);
	ALTER TABLE drug_strength_stage DROP CONSTRAINT ds_check_values;

	/*
	-- check that all units are valid
	select a.concept_name as amount_unit, n.concept_name as numerator_unit, d.concept_name as denominator_unit, count(8) as cnt
	from drug_strength_stage 
	left join concept a on a.concept_id=amount_unit_concept_id
	left join concept n on n.concept_id=numerator_unit_concept_id
	left join concept d on d.concept_id=denominator_unit_concept_id
	group by a.concept_name, n.concept_name, d.concept_name
	order by 4 desc;
	*/

	-- clean up
	DROP TABLE component_replace;
	DROP TABLE unit_to_concept_map;
	DROP TABLE rxnorm_ancestor;

	-- delete unparsable records
	DELETE
	FROM drug_strength_stage
	WHERE COALESCE(amount_unit_concept_id, 0) = 0
		AND COALESCE(numerator_unit_concept_id, 0) = 0;
END;
$BODY$
LANGUAGE 'plpgsql' SECURITY INVOKER 
SET client_min_messages = error;