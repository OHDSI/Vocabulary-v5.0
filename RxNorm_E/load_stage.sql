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
* Authors: Timur Vakhitov, Anna Ostropolets, Christian Reich
* Date: 2016
**************************************************************************/

--1 Update latest_update field to new date 
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'RxNorm Extension',
	pVocabularyDate			=> CURRENT_DATE,
	pVocabularyVersion		=> 'RxNorm Extension '||CURRENT_DATE,
	pVocabularyDevSchema	=> 'DEV_RXE'
);
END $_$;


--2 Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3 Load full list of RxNorm Extension concepts
INSERT INTO concept_stage (
	concept_name,
	domain_id,
	vocabulary_id,
	concept_class_id,
	standard_concept,
	concept_code,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT concept_name,
	domain_id,
	vocabulary_id,
	concept_class_id,
	standard_concept,
	concept_code,
	valid_start_date,
	valid_end_date,
	invalid_reason
FROM concept
WHERE vocabulary_id = 'RxNorm Extension';

--4 Load full list of RxNorm Extension relationships
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT c1.concept_code,
	c2.concept_code,
	c1.vocabulary_id,
	c2.vocabulary_id,
	r.relationship_id,
	r.valid_start_date,
	r.valid_end_date,
	r.invalid_reason
FROM concept c1,
	concept c2,
	concept_relationship r
WHERE c1.concept_id = r.concept_id_1
	AND c2.concept_id = r.concept_id_2
	AND 'RxNorm Extension' IN (
		c1.vocabulary_id,
		c2.vocabulary_id
		);

--5 Load full list of RxNorm Extension drug strength
INSERT INTO drug_strength_stage (
	drug_concept_code,
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
	)
SELECT c.concept_code,
	c.vocabulary_id,
	c2.concept_code,
	c2.vocabulary_id,
	amount_value,
	amount_unit_concept_id,
	numerator_value,
	numerator_unit_concept_id,
	denominator_value,
	denominator_unit_concept_id,
	ds.valid_start_date,
	ds.valid_end_date,
	ds.invalid_reason
FROM concept c
JOIN drug_strength ds ON ds.drug_concept_id = c.concept_id
JOIN concept c2 ON ds.ingredient_concept_id = c2.concept_id
WHERE c.vocabulary_id IN (
		'RxNorm',
		'RxNorm Extension'
		);

--6 Load full list of RxNorm Extension pack content
INSERT INTO pack_content_stage (
	pack_concept_code,
	pack_vocabulary_id,
	drug_concept_code,
	drug_vocabulary_id,
	amount,
	box_size
	)
SELECT c.concept_code,
	c.vocabulary_id,
	c2.concept_code,
	c2.vocabulary_id,
	amount,
	box_size
FROM pack_content pc
JOIN concept c ON pc.pack_concept_id = c.concept_id
JOIN concept c2 ON pc.drug_concept_id = c2.concept_id;

--7 name and dosage udpates
--fix names and dosage for rxe-concepts with various denominator_unit_concept_id
UPDATE concept_stage
SET concept_name = 'Polymyxin B 10 000 MG/ML / Trimethoprim 1 MG/ML [Polytrim]'
WHERE vocabulary_id = 'RxNorm Extension'
	AND concept_code = 'OMOP420658'
	AND concept_name = 'Polymyxin B 10 IU/MG / Trimethoprim 1 MG/ML [Polytrim]';

UPDATE concept_stage
SET concept_name = 'Polymyxin B 10 000 MG/ML / Trimethoprim 1 MG/ML Ophthalmic Solution'
WHERE vocabulary_id = 'RxNorm Extension'
	AND concept_code = 'OMOP420659'
	AND concept_name = 'Polymyxin B 10 IU/MG / Trimethoprim 1 MG/ML Ophthalmic Solution';

UPDATE concept_stage
SET concept_name = 'Polymyxin B 10 000 MG/ML / Trimethoprim 1 MG/ML Ophthalmic Solution [Polytrim]'
WHERE vocabulary_id = 'RxNorm Extension'
	AND concept_code = 'OMOP420660'
	AND concept_name = 'Polymyxin B 10 IU/MG / Trimethoprim 1 MG/ML Ophthalmic Solution [Polytrim]';

UPDATE concept_stage
SET concept_name = 'Polymyxin B 10 000 MG/ML / Trimethoprim 1 MG/ML Ophthalmic Solution [Polytrim] by PLIVA'
WHERE vocabulary_id = 'RxNorm Extension'
	AND concept_code = 'OMOP420661'
	AND concept_name = 'Polymyxin B 10 IU/MG / Trimethoprim 1 MG/ML Ophthalmic Solution [Polytrim] by PLIVA';

UPDATE drug_strength_stage
SET numerator_value = numerator_value * 1000,
	denominator_unit_concept_id = 8587
WHERE vocabulary_id_1 = 'RxNorm Extension'
	AND drug_concept_code IN (
		'OMOP420658',
		'OMOP420659',
		'OMOP420660',
		'OMOP420661'
		)
	AND denominator_unit_concept_id = 8576;

--8
--normalizing
UPDATE concept_stage cs
SET concept_name = CASE 
		WHEN length(l.new_name) > 255
			THEN substr(substr(l.new_name, 1, 255), 1, length(substr(l.new_name, 1, 255)) - 3) || '...'
		ELSE l.new_name
		END
FROM (
	SELECT DISTINCT cs.concept_code,
		l.new_name
	FROM drug_strength_stage ds,
		concept_stage cs,
		lateral(SELECT STRING_AGG(CASE 
					WHEN ld = '/HR'
						THEN (splitted_name::FLOAT / 1000)::VARCHAR
					ELSE CASE 
							WHEN splitted_name = '/HR'
								THEN 'MG/HR'
							ELSE splitted_name
							END
					END, ' ' ORDER BY lv) new_name FROM (
			SELECT splitted_name,
				lead(splitted_name) OVER (
					ORDER BY lv
					) ld,
				lv
			FROM (
				SELECT *
				FROM unnest(string_to_array(cs.concept_name, ' ')) WITH ordinality AS x(splitted_name, lv)
				) AS s0
			) AS s1) l
	WHERE ds.numerator_unit_concept_id = 9655
		AND ds.drug_concept_code = cs.concept_code
		AND ds.vocabulary_id_1 = cs.vocabulary_id
		AND cs.vocabulary_id = 'RxNorm Extension'
	
	UNION ALL
	
	SELECT DISTINCT cs.concept_code,
		l.new_name
	FROM drug_strength_stage ds,
		concept_stage cs,
		lateral(SELECT STRING_AGG(CASE 
					WHEN substring(splitted_name, '[[:digit:]]+') IS NOT NULL
						THEN (splitted_name::FLOAT / 1000)::VARCHAR || ' MG'
					ELSE splitted_name
					END, ' ' ORDER BY lv) new_name FROM (
			SELECT *
			FROM unnest(string_to_array(cs.concept_name, ' ')) WITH ordinality AS x(splitted_name, lv)
			) AS s0) l
	WHERE ds.amount_unit_concept_id = 9655
		AND ds.drug_concept_code = cs.concept_code
		AND ds.vocabulary_id_1 = cs.vocabulary_id
		AND cs.vocabulary_id = 'RxNorm Extension'
	
	UNION ALL
	
	SELECT DISTINCT cs.concept_code,
		l.new_name
	FROM drug_strength_stage ds,
		concept_stage cs,
		lateral(SELECT STRING_AGG(CASE 
					WHEN splitted_name = '0.9'
						THEN (splitted_name::FLOAT * 1000000)::VARCHAR || ' UNT'
					ELSE splitted_name
					END, ' ' ORDER BY lv) new_name FROM (
			SELECT *
			FROM unnest(string_to_array(cs.concept_name, ' ')) WITH ordinality AS x(splitted_name, lv)
			) AS s0) l
	WHERE ds.amount_unit_concept_id = 44777647
		AND ds.drug_concept_code = cs.concept_code
		AND ds.vocabulary_id_1 = cs.vocabulary_id
		AND cs.vocabulary_id = 'RxNorm Extension'
	
	UNION ALL
	
	SELECT DISTINCT cs.concept_code,
		replace(replace(replace(cs.concept_name, ' IU ', ' UNT '), 'IU/', 'UNT/'), '/IU', '/UNT') new_name
	FROM drug_strength_stage ds,
		concept_stage cs
	WHERE (
			ds.numerator_unit_concept_id = 8718
			OR ds.denominator_unit_concept_id = 8718
			)
		AND ds.drug_concept_code = cs.concept_code
		AND ds.vocabulary_id_1 = cs.vocabulary_id
		AND cs.vocabulary_id = 'RxNorm Extension'
	
	UNION ALL --two merges for amount_unit_concept_id=8718 (one for IU and one for MIU)
	
	SELECT DISTINCT cs.concept_code,
		trim(regexp_replace(cs.concept_name, ' IU | IU$', ' UNT ', '')) new_name
	FROM drug_strength_stage ds,
		concept_stage cs
	WHERE ds.amount_unit_concept_id = 8718
		AND ds.drug_concept_code = cs.concept_code
		AND ds.vocabulary_id_1 = cs.vocabulary_id
		AND cs.vocabulary_id = 'RxNorm Extension'
		AND cs.concept_name LIKE '% IU%'
	
	UNION ALL
	
	SELECT DISTINCT cs.concept_code,
		l.new_name
	FROM drug_strength_stage ds,
		concept_stage cs,
		lateral(SELECT STRING_AGG(CASE 
					WHEN ld = 'MIU'
						THEN (splitted_name::FLOAT * 1e6)::VARCHAR
					ELSE splitted_name
					END, ' ' ORDER BY lv) new_name FROM (
			SELECT splitted_name,
				lead(splitted_name) OVER (
					ORDER BY lv
					) ld,
				lv
			FROM (
				SELECT *
				FROM unnest(string_to_array(cs.concept_name, ' ')) WITH ordinality AS x(splitted_name, lv)
				) AS s0
			) AS s1) l
	WHERE ds.amount_unit_concept_id = 8718
		AND ds.drug_concept_code = cs.concept_code
		AND ds.vocabulary_id_1 = cs.vocabulary_id
		AND cs.vocabulary_id = 'RxNorm Extension'
		AND cs.concept_name LIKE '% MIU%'
	
	UNION ALL
	
	--change the drug strength for homeopathy (p1)
	SELECT DISTINCT cs.concept_code,
		replace(cs.concept_name, '/' || upper(c.concept_code), '') new_name
	FROM drug_strength_stage ds,
		concept_stage cs,
		concept c
	WHERE ds.numerator_unit_concept_id IN (
			9324,
			9325
			)
		AND ds.drug_concept_code = cs.concept_code
		AND ds.vocabulary_id_1 = cs.vocabulary_id
		AND cs.vocabulary_id = 'RxNorm Extension'
		AND c.concept_id = ds.denominator_unit_concept_id
	) l
WHERE cs.concept_code = l.concept_code
	AND cs.vocabulary_id = 'RxNorm Extension'
	AND cs.concept_name <> CASE 
		WHEN length(l.new_name) > 255
			THEN substr(substr(l.new_name, 1, 255), 1, length(substr(l.new_name, 1, 255)) - 3) || '...'
		ELSE l.new_name
		END;

UPDATE drug_strength_stage
SET numerator_unit_concept_id = 8576,
	numerator_value = numerator_value / 1000 -- 'mg'
WHERE numerator_unit_concept_id = 9655 -- 'ug'
	AND vocabulary_id_1 = 'RxNorm Extension';

UPDATE drug_strength_stage
SET amount_unit_concept_id = 8576,
	amount_value = amount_value / 1000 -- 'mg'
WHERE amount_unit_concept_id = 9655 -- 'ug'
	AND vocabulary_id_1 = 'RxNorm Extension';

UPDATE drug_strength_stage
SET amount_unit_concept_id = 8510,
	amount_value = amount_value * 1000000 -- 'U'
WHERE amount_unit_concept_id = 44777647 -- 'ukat'
	AND vocabulary_id_1 = 'RxNorm Extension';

/* temporary disabled
--deprecate concepts with iU
update concept_stage set invalid_reason='D',
valid_end_date=(SELECT latest_update-1 FROM vocabulary WHERE vocabulary_id = 'RxNorm Extension') 
WHERE concept_code in (
	select drug_concept_code from drug_strength_stage
	where (numerator_unit_concept_id=8718 or DENOMINATOR_UNIT_CONCEPT_ID=8718 or amount_unit_concept_id=8718) -- 'iU'
	and vocabulary_id_1='RxNorm Extension'
);
*/

UPDATE drug_strength_stage
SET numerator_unit_concept_id = 8510
WHERE numerator_unit_concept_id = 8718 -- 'iU'
	AND vocabulary_id_1 = 'RxNorm Extension';

UPDATE drug_strength_stage
SET DENOMINATOR_UNIT_CONCEPT_ID = 8510
WHERE DENOMINATOR_UNIT_CONCEPT_ID = 8718 -- 'iU'
	AND vocabulary_id_1 = 'RxNorm Extension';

UPDATE drug_strength_stage
SET amount_unit_concept_id = 8510 -- 'U'
WHERE amount_unit_concept_id = 8718 -- 'iU'
	AND vocabulary_id_1 = 'RxNorm Extension';

--deprecate transdermal patches with cm and mm as unit in order to rebuild them
UPDATE concept_stage
SET invalid_reason = 'D',
	valid_end_date = (
		SELECT latest_update - 1
		FROM vocabulary
		WHERE vocabulary_id = 'RxNorm Extension'
		)
WHERE concept_code IN (
		SELECT drug_concept_code
		FROM drug_strength_stage
		WHERE denominator_unit_concept_id IN (
				8582,
				8588
				)
			AND vocabulary_id_1 = 'RxNorm Extension'
		)
	AND invalid_reason IS NULL;

--change the drug strength for homeopathy (p2)
UPDATE drug_strength_stage ds
SET amount_value = ds.numerator_value,
	amount_unit_concept_id = ds.numerator_unit_concept_id,
	numerator_value = NULL,
	numerator_unit_concept_id = NULL,
	denominator_value = NULL,
	denominator_unit_concept_id = NULL
WHERE ds.numerator_unit_concept_id IN (
		9324,
		9325
		)
	AND ds.vocabulary_id_1 = 'RxNorm Extension';

--direct manual update (names too long)
UPDATE concept_stage
SET concept_name = 'Ascorbic Acid 25 MG/ML / Biotin 0.0138 MG/ML / Cholecalciferol 44 UNT/ML / Folic Acid 0.0828 MG/ML / Niacinamide 9.2 MG/ML / Pantothenic Acid 3.45 MG/ML / Riboflavin 0.828 MG/ML / Thiamine 0.702 MG/ML / ... Prefilled Syringe Box of 1'
WHERE concept_code = 'OMOP441099'
	AND vocabulary_id = 'RxNorm Extension';

UPDATE concept_stage
SET concept_name = 'Bordetella pertussis 0.05 MG/ML / acellular pertussis vaccine, inactivated 0.05 MG/ML / diphtheria toxoid vaccine, inactivated 60 UNT/ML / ... Injectable Suspension [TETRAVAC-ACELLULAIRE] Box of 10'
WHERE concept_code = 'OMOP445896'
	AND vocabulary_id = 'RxNorm Extension';

--9
--create the table with rxe's wrong replacements (concept_code_1 has multiply 'Concept replaced by')
DROP TABLE IF EXISTS wrong_rxe_replacements;
CREATE TABLE wrong_rxe_replacements AS
SELECT concept_code,
	true_concept
FROM (
	SELECT concept_code,
		count(*) OVER (
			PARTITION BY lower(concept_name),
			concept_class_id
			) cnt,
		first_value(concept_code) OVER (
			PARTITION BY lower(concept_name),
			concept_class_id ORDER BY invalid_reason nulls first,
				concept_code
			) true_concept
	FROM concept_stage
	WHERE concept_name NOT LIKE '%...%'
		AND coalesce(invalid_reason, 'x') <> 'D'
		AND vocabulary_id = 'RxNorm Extension'
	) AS s0
WHERE cnt > 1
	AND concept_code <> true_concept;

--deprecate old replacements
UPDATE concept_relationship_stage crs
SET invalid_reason = 'D',
	valid_end_date = (
		SELECT latest_update - 1
		FROM vocabulary
		WHERE vocabulary_id = 'RxNorm Extension'
		)
WHERE concept_code_1 IN (
		SELECT concept_code
		FROM wrong_rxe_replacements
		
		UNION ALL
		
		SELECT true_concept
		FROM wrong_rxe_replacements
		)
	AND concept_code_2 IN (
		SELECT concept_code
		FROM wrong_rxe_replacements
		
		UNION ALL
		
		SELECT true_concept
		FROM wrong_rxe_replacements
		)
	AND crs.vocabulary_id_1 = 'RxNorm Extension'
	AND crs.vocabulary_id_2 = 'RxNorm Extension'
	AND crs.relationship_id IN (
		'Concept replaced by',
		'Concept replaces'
		)
	AND crs.invalid_reason IS NULL;

--build new ones or update existing
UPDATE concept_relationship_stage crs
SET invalid_reason = NULL,
	valid_end_date = to_date('20991231', 'YYYYMMDD')
FROM (
	SELECT concept_code,
		true_concept,
		'Concept replaced by' AS relationship_id
	FROM wrong_rxe_replacements
	
	UNION ALL
	
	SELECT true_concept,
		concept_code,
		'Concept replaces' AS relationship_id
	FROM wrong_rxe_replacements
	) i
WHERE i.concept_code = crs.concept_code_1
	AND crs.vocabulary_id_1 = 'RxNorm Extension'
	AND i.true_concept = crs.concept_code_2
	AND crs.vocabulary_id_2 = 'RxNorm Extension'
	AND crs.relationship_id = i.relationship_id
	AND crs.invalid_reason IS NOT NULL;

INSERT INTO concept_relationship_stage (
	concept_code_1,
	vocabulary_id_1,
	concept_code_2,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT i.concept_code,
	'RxNorm Extension',
	i.true_concept,
	'RxNorm Extension',
	i.relationship_id,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'RxNorm Extension'
		),
	to_date('20991231', 'YYYYMMDD'),
	NULL
FROM (
	SELECT concept_code,
		true_concept,
		'Concept replaced by' AS relationship_id
	FROM wrong_rxe_replacements
	
	UNION ALL
	
	SELECT true_concept,
		concept_code,
		'Concept replaces' AS relationship_id
	FROM wrong_rxe_replacements
	) i
WHERE NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs_int
		WHERE i.concept_code = crs_int.concept_code_1
			AND crs_int.vocabulary_id_1 = 'RxNorm Extension'
			AND i.true_concept = crs_int.concept_code_2
			AND crs_int.vocabulary_id_2 = 'RxNorm Extension'
			AND crs_int.relationship_id = i.relationship_id
		);

--update invalid_reason and standard_concept in the concept
UPDATE concept_stage
SET invalid_reason = NULL,
	valid_end_date = to_date('20991231', 'YYYYMMDD'),
	standard_concept = 'S'
WHERE concept_code IN (
		SELECT true_concept
		FROM wrong_rxe_replacements
		)
	AND vocabulary_id = 'RxNorm Extension'
	AND invalid_reason IS NOT NULL;

UPDATE concept_stage
SET invalid_reason = 'U',
	valid_end_date = (
		SELECT latest_update - 1
		FROM vocabulary
		WHERE vocabulary_id = 'RxNorm Extension'
		),
	standard_concept = NULL
WHERE concept_code IN (
		SELECT concept_code
		FROM wrong_rxe_replacements
		)
	AND vocabulary_id = 'RxNorm Extension'
	AND coalesce(invalid_reason, 'x') <> 'U';

--after rxe name's update we have duplicates with rx. fix it
--build new ones replacements or update existing 
UPDATE concept_relationship_stage crs
SET invalid_reason = NULL,
	valid_end_date = to_date('20991231', 'YYYYMMDD')
FROM (
	SELECT cs.concept_code rxe_code,
		c.concept_code rx_code
	FROM concept_stage cs,
		concept c
	WHERE cs.vocabulary_id = 'RxNorm Extension'
		AND cs.concept_name NOT LIKE '%...%'
		AND cs.invalid_reason IS NULL
		AND c.vocabulary_id = 'RxNorm'
		AND c.invalid_reason IS NULL
		AND lower(cs.concept_name) = lower(c.concept_name)
		AND cs.concept_class_id = c.concept_class_id
	) i
WHERE i.rxe_code = crs.concept_code_1
	AND crs.vocabulary_id_1 = 'RxNorm Extension'
	AND i.rx_code = crs.concept_code_2
	AND crs.vocabulary_id_2 = 'RxNorm'
	AND crs.relationship_id = 'Concept replaced by'
	AND crs.invalid_reason IS NOT NULL;

INSERT INTO concept_relationship_stage (
	concept_code_1,
	vocabulary_id_1,
	concept_code_2,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT i.rxe_code,
	'RxNorm Extension',
	i.rx_code,
	'RxNorm',
	'Concept replaced by',
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'RxNorm Extension'
		),
	to_date('20991231', 'YYYYMMDD'),
	NULL
FROM (
	SELECT cs.concept_code rxe_code,
		c.concept_code rx_code
	FROM concept_stage cs,
		concept c
	WHERE cs.vocabulary_id = 'RxNorm Extension'
		AND cs.concept_name NOT LIKE '%...%'
		AND cs.invalid_reason IS NULL
		AND c.vocabulary_id = 'RxNorm'
		AND c.invalid_reason IS NULL
		AND lower(cs.concept_name) = lower(c.concept_name)
		AND cs.concept_class_id = c.concept_class_id
	) i
WHERE NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs_int
		WHERE i.rxe_code = crs_int.concept_code_1
			AND crs_int.vocabulary_id_1 = 'RxNorm Extension'
			AND i.rx_code = crs_int.concept_code_2
			AND crs_int.vocabulary_id_2 = 'RxNorm'
			AND crs_int.relationship_id = 'Concept replaced by'
		);

--set 'U'
UPDATE concept_stage
SET invalid_reason = 'U',
	valid_end_date = (
		SELECT latest_update - 1
		FROM vocabulary
		WHERE vocabulary_id = 'RxNorm Extension'
		),
	standard_concept = NULL
WHERE concept_code IN (
		SELECT cs.concept_code
		FROM concept_stage cs,
			concept c
		WHERE cs.vocabulary_id = 'RxNorm Extension'
			AND cs.concept_name NOT LIKE '%...%'
			AND cs.invalid_reason IS NULL
			AND c.vocabulary_id = 'RxNorm'
			AND c.invalid_reason IS NULL
			AND lower(cs.concept_name) = lower(c.concept_name)
			AND cs.concept_class_id = c.concept_class_id
		)
	AND vocabulary_id = 'RxNorm Extension'
	AND invalid_reason IS NULL;

-- Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

-- Add mapping from deprecated to fresh concepts, and also from non-standard to standard concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

-- Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

-- Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;

--10 deprecate solid drugs with denominator
UPDATE concept_stage
SET invalid_reason = 'D',
	valid_end_date = (
		SELECT latest_update - 1
		FROM vocabulary
		WHERE vocabulary_id = 'RxNorm Extension'
		)
WHERE concept_code IN (
		SELECT cs.concept_code
		FROM drug_strength_stage ds,
			concept_stage cs
		WHERE ds.denominator_unit_concept_id IS NOT NULL
			AND ds.drug_concept_code = cs.concept_code
			AND ds.vocabulary_id_1 = cs.vocabulary_id
			AND cs.vocabulary_id = 'RxNorm Extension'
			AND (
				cs.concept_name LIKE '%Tablet%'
				OR cs.concept_name LIKE '%Capsule%'
				)
			AND cs.invalid_reason IS NULL
		);

--11
--do a rounding amount_value, numerator_value and denominator_value
UPDATE drug_strength_stage
SET amount_value = round(amount_value::NUMERIC, (3 - floor(log(amount_value)) - 1)::INT),
	numerator_value = round(numerator_value::NUMERIC, (3 - floor(log(numerator_value)) - 1)::INT),
	denominator_value = round(denominator_value::NUMERIC, (3 - floor(log(denominator_value)) - 1)::INT)
WHERE amount_value <> round(amount_value::NUMERIC, (3 - floor(log(amount_value)) - 1)::INT)
	OR numerator_value <> round(numerator_value::NUMERIC, (3 - floor(log(numerator_value)) - 1)::INT)
	OR denominator_value <> round(denominator_value::NUMERIC, (3 - floor(log(denominator_value)) - 1)::INT)
	AND vocabulary_id_1 = 'RxNorm Extension';

--12
--wrong ancestor
UPDATE concept_stage
SET invalid_reason = 'D',
	valid_end_date = (
		SELECT latest_update - 1
		FROM vocabulary
		WHERE vocabulary_id = 'RxNorm Extension'
		)
WHERE concept_code IN (
		SELECT an.concept_code
		FROM concept an
		JOIN concept_ancestor a ON a.ancestor_concept_id = an.concept_id
			AND an.vocabulary_id = 'RxNorm Extension'
		JOIN concept de ON de.concept_id = a.descendant_concept_id
			AND de.vocabulary_id = 'RxNorm'
		)
	AND invalid_reason IS NULL;

--13 
--impossible dosages
UPDATE concept_stage
SET invalid_reason = 'D',
	valid_end_date = (
		SELECT latest_update - 1
		FROM vocabulary
		WHERE vocabulary_id = 'RxNorm Extension'
		)
WHERE (
		concept_code,
		vocabulary_id
		) IN (
		SELECT drug_concept_code,
			vocabulary_id_1
		FROM drug_strength_stage a
		WHERE (
				numerator_unit_concept_id = 8554
				AND denominator_unit_concept_id IS NOT NULL
				)
			OR amount_unit_concept_id = 8554
			OR (
				numerator_unit_concept_id = 8576
				AND denominator_unit_concept_id = 8587
				AND numerator_value / denominator_value > 1000
				)
			OR (
				numerator_unit_concept_id = 8576
				AND denominator_unit_concept_id = 8576
				AND numerator_value / denominator_value > 1
				)
			AND vocabulary_id_1 = 'RxNorm Extension'
		)
	AND invalid_reason IS NULL;

--14 
--wrong pack components
UPDATE concept_stage
SET invalid_reason = 'D',
	valid_end_date = (
		SELECT latest_update - 1
		FROM vocabulary
		WHERE vocabulary_id = 'RxNorm Extension'
		)
WHERE (
		concept_code,
		vocabulary_id
		) IN (
		SELECT pack_concept_code,
			pack_vocabulary_id
		FROM pack_content_stage
		WHERE pack_vocabulary_id = 'RxNorm Extension'
		GROUP BY drug_concept_code,
			drug_vocabulary_id,
			pack_concept_code,
			pack_vocabulary_id
		HAVING count(*) > 1
		)
	AND invalid_reason IS NULL;

--15
--deprecate drugs that have different number of ingredients in ancestor and drug_strength
UPDATE concept_stage
SET invalid_reason = 'D',
	valid_end_date = (
		SELECT latest_update - 1
		FROM vocabulary
		WHERE vocabulary_id = 'RxNorm Extension'
		)
WHERE (
		concept_code,
		vocabulary_id
		) IN (
		WITH a AS (
				SELECT drug_concept_code,
					vocabulary_id_1,
					count(drug_concept_code) AS cnt1
				FROM drug_strength_stage
				WHERE vocabulary_id_1 = 'RxNorm Extension'
				GROUP BY drug_concept_code,
					vocabulary_id_1
				),
			b AS (
				SELECT b2.concept_code AS descendant_concept_code,
					b2.vocabulary_id AS descendant_vocabulary_id,
					count(b2.concept_code) AS cnt2
				FROM concept_ancestor a
				JOIN concept b ON ancestor_concept_id = b.concept_id
					AND concept_class_id = 'Ingredient'
				JOIN concept b2 ON descendant_concept_id = b2.concept_id
				WHERE b2.concept_class_id NOT LIKE '%Comp%'
					AND b2.vocabulary_id = 'RxNorm Extension'
				GROUP BY b2.concept_code,
					b2.vocabulary_id
				)
		SELECT a.drug_concept_code,
			a.vocabulary_id_1
		FROM a
		JOIN b ON a.drug_concept_code = b.descendant_concept_code
			AND a.vocabulary_id_1 = b.descendant_vocabulary_id
		WHERE cnt1 < cnt2
		)
	AND invalid_reason IS NULL;

UPDATE concept_stage
SET invalid_reason = 'D',
	valid_end_date = (
		SELECT latest_update - 1
		FROM vocabulary
		WHERE vocabulary_id = 'RxNorm Extension'
		)
WHERE (
		concept_code,
		vocabulary_id
		) IN (
		WITH a AS (
				SELECT drug_concept_code,
					vocabulary_id_1,
					count(drug_concept_code) AS cnt1
				FROM drug_strength_stage
				WHERE vocabulary_id_1 = 'RxNorm Extension'
				GROUP BY drug_concept_code,
					vocabulary_id_1
				),
			b AS (
				SELECT b2.concept_code AS descendant_concept_code,
					b2.vocabulary_id AS descendant_vocabulary_id,
					count(b2.concept_code) AS cnt2
				FROM concept_ancestor a
				JOIN concept b ON ancestor_concept_id = b.concept_id
					AND concept_class_id = 'Ingredient'
				JOIN concept b2 ON descendant_concept_id = b2.concept_id
				WHERE b2.concept_class_id NOT LIKE '%Comp%'
					AND b2.vocabulary_id = 'RxNorm Extension'
				GROUP BY b2.concept_code,
					b2.vocabulary_id
				),
			c AS (
				SELECT concept_code,
					vocabulary_id,
					(
						SELECT length(concept_name) - coalesce(length(replace(concept_name, ' / ', '')), 0)
						) + 1 AS cnt3
				FROM concept
				WHERE vocabulary_id = 'RxNorm Extension'
				)
		SELECT a.drug_concept_code,
			a.vocabulary_id_1
		FROM a
		JOIN b ON a.drug_concept_code = b.descendant_concept_code
			AND a.vocabulary_id_1 = b.descendant_vocabulary_id
		JOIN c ON c.concept_code = b.descendant_concept_code
			AND c.vocabulary_id = b.descendant_vocabulary_id
		WHERE cnt1 > cnt2
			AND cnt3 > cnt1
		)
	AND invalid_reason IS NULL;

--16
--deprecate drugs that have deprecated ingredients (all)
UPDATE concept_stage c
SET invalid_reason = 'D',
	valid_end_date = (
		SELECT latest_update - 1
		FROM vocabulary
		WHERE vocabulary_id = 'RxNorm Extension'
		)
WHERE (
		concept_code,
		vocabulary_id
		) IN (
		SELECT dss.drug_concept_code,
			dss.vocabulary_id_1
		FROM drug_strength_stage dss,
			concept_stage cs
		WHERE dss.ingredient_concept_code = cs.concept_code
			AND dss.vocabulary_id_2 = cs.vocabulary_id
			AND vocabulary_id_1 = 'RxNorm Extension'
		GROUP BY dss.drug_concept_code,
			dss.vocabulary_id_1
		HAVING count(dss.ingredient_concept_code) = sum(CASE 
					WHEN cs.invalid_reason = 'D'
						THEN 1
					ELSE 0
					END)
		)
	AND invalid_reason IS NULL;

ANALYZE concept_relationship_stage;
ANALYZE drug_strength_stage;

--17
--deprecate drugs that link to each other and has different strength
UPDATE concept_relationship_stage crs
SET invalid_reason = 'D',
	valid_end_date = (
		SELECT latest_update - 1
		FROM vocabulary
		WHERE vocabulary_id = 'RxNorm Extension'
		)
WHERE crs.invalid_reason IS NULL
	AND (
		concept_code_1,
		vocabulary_id_1,
		concept_code_2,
		vocabulary_id_2
		) IN (
		WITH t AS (
				SELECT DISTINCT dss1.drug_concept_code AS concept_code_1,
					dss1.vocabulary_id_1 AS vocabulary_id_1,
					dss2.drug_concept_code AS concept_code_2,
					dss2.vocabulary_id_1 AS vocabulary_id_2
				FROM drug_strength_stage dss1,
					drug_strength_stage dss2
				WHERE dss1.vocabulary_id_1 IN (
						'RxNorm',
						'RxNorm Extension'
						)
					AND dss2.vocabulary_id_1 IN (
						'RxNorm',
						'RxNorm Extension'
						)
					AND dss1.ingredient_concept_code = dss2.ingredient_concept_code
					AND dss1.vocabulary_id_2 = dss2.vocabulary_id_2
					AND NOT (
						dss1.vocabulary_id_1 = 'RxNorm'
						AND dss2.vocabulary_id_1 = 'RxNorm'
						)
					AND EXISTS (
						SELECT 1
						FROM concept_relationship_stage crs
						WHERE crs.concept_code_1 = dss1.drug_concept_code
							AND crs.vocabulary_id_1 = dss1.vocabulary_id_1
							AND crs.concept_code_2 = dss2.drug_concept_code
							AND crs.vocabulary_id_2 = dss2.vocabulary_id_1
							AND crs.invalid_reason IS NULL
						)
					AND (
						coalesce(dss1.amount_value, dss1.numerator_value / coalesce(dss1.denominator_value, 1)) / coalesce(dss2.amount_value, dss2.numerator_value / coalesce(dss2.denominator_value, 1)) > 1.12
						OR coalesce(dss1.amount_value, dss1.numerator_value / coalesce(dss1.denominator_value, 1)) / coalesce(dss2.amount_value, dss2.numerator_value / coalesce(dss2.denominator_value, 1)) < 0.9
						)
					AND coalesce(dss1.amount_unit_concept_id, (dss1.numerator_unit_concept_id + dss1.denominator_unit_concept_id)) = coalesce(dss2.amount_unit_concept_id, (dss2.numerator_unit_concept_id + dss2.denominator_unit_concept_id))
				)
		SELECT concept_code_1,
			vocabulary_id_1,
			concept_code_2,
			vocabulary_id_2
		FROM t
		
		UNION ALL
		--reverse
		SELECT concept_code_2,
			vocabulary_id_2,
			concept_code_1,
			vocabulary_id_1
		FROM t
		);

--18
--deprecate the drugs that have inaccurate dosage due to difference in ingredients subvarieties
--for ingredients with not null amount_value
UPDATE concept_stage c
SET invalid_reason = 'D',
	valid_end_date = (
		SELECT latest_update - 1
		FROM vocabulary
		WHERE vocabulary_id = 'RxNorm Extension'
		)
WHERE (
		concept_code,
		vocabulary_id
		) IN (
		SELECT dss.drug_concept_code,
			dss.vocabulary_id_1
		FROM (
			SELECT ingredient_concept_code,
				dosage,
				flag,
				(
					SELECT count(DISTINCT fl)
					FROM unnest(cnt_flags) AS fl
					) AS cnt_flags,
				true_dosage
			FROM (
				--select ingredient_concept_code, dosage, flag, count(distinct flag) over (partition by ingredient_concept_code, dosage_group) cnt_flags, --ERROR: DISTINCT is not implemented for window functions
				SELECT ingredient_concept_code,
					dosage,
					flag,
					ARRAY_AGG(flag) OVER (
						PARTITION BY ingredient_concept_code,
						dosage_group
						) cnt_flags,
					first_value(dosage) OVER (
						PARTITION BY ingredient_concept_code,
						dosage_group ORDER BY length(regexp_replace(dosage::VARCHAR, '[^1-9]', '', 'g')),
							dosage
						) true_dosage
				FROM (
					SELECT rxe.ingredient_concept_code,
						rxe.dosage,
						rxe.dosage_group,
						coalesce(rx.flag, rxe.flag) AS flag
					FROM (
						SELECT DISTINCT ingredient_concept_code,
							dosage,
							dosage_group,
							'bad' AS flag
						FROM (
							SELECT ingredient_concept_code,
								dosage,
								dosage_group,
								count(*) OVER (
									PARTITION BY ingredient_concept_code,
									dosage_group
									) AS cnt_gr
							FROM (
								SELECT ingredient_concept_code,
									dosage,
									sum(group_trigger) OVER (
										PARTITION BY ingredient_concept_code ORDER BY dosage
										) + 1 dosage_group
								FROM (
									SELECT ingredient_concept_code,
										dosage,
										prev_dosage,
										abs(round((dosage - prev_dosage) * 100 / prev_dosage)) perc_dosage,
										CASE 
											WHEN abs(round((dosage - prev_dosage) * 100 / prev_dosage)) <= 5
												THEN 0
											ELSE 1
											END group_trigger
									FROM (
										SELECT ingredient_concept_code,
											dosage,
											lag(dosage, 1, dosage) OVER (
												PARTITION BY ingredient_concept_code ORDER BY dosage
												) prev_dosage
										FROM (
											SELECT DISTINCT ingredient_concept_code,
												amount_value AS dosage
											FROM drug_strength_stage
											WHERE vocabulary_id_1 = 'RxNorm Extension'
												AND amount_value IS NOT NULL
											) AS s0
										) AS s1
									) AS s2
								) AS s3
							) AS s4
						WHERE cnt_gr > 1
						) rxe
					LEFT JOIN (
						SELECT DISTINCT ingredient_concept_code,
							amount_value AS dosage,
							'good' AS flag
						FROM drug_strength_stage
						WHERE vocabulary_id_1 = 'RxNorm'
							AND amount_value IS NOT NULL
						) rx ON rx.ingredient_concept_code = rxe.ingredient_concept_code
						AND rx.dosage = rxe.dosage
					) AS s5
				) AS s6
			) merged_rxe,
			drug_strength_stage dss
		WHERE (
				merged_rxe.flag = 'bad'
				AND merged_rxe.cnt_flags = 2
				OR merged_rxe.flag = 'bad'
				AND merged_rxe.cnt_flags = 1
				AND dosage <> true_dosage
				)
			AND dss.ingredient_concept_code = merged_rxe.ingredient_concept_code
			AND dss.amount_value = merged_rxe.dosage
			AND dss.vocabulary_id_1 = 'RxNorm Extension'
		)
	AND invalid_reason IS NULL;

--same, but for ingredients with null amount_value (instead, we use numerator_value or numerator_value/denominator_value)
UPDATE concept_stage c
SET invalid_reason = 'D',
	valid_end_date = (
		SELECT latest_update - 1
		FROM vocabulary
		WHERE vocabulary_id = 'RxNorm Extension'
		)
WHERE (
		concept_code,
		vocabulary_id
		) IN (
		SELECT dss.drug_concept_code,
			dss.vocabulary_id_1
		FROM (
			--select ingredient_concept_code, dosage, flag, count(distinct flag) over (partition by ingredient_concept_code, dosage_group) cnt_flags,
			SELECT ingredient_concept_code,
				dosage,
				flag,
				(
					SELECT count(DISTINCT fl)
					FROM unnest(cnt_flags) AS fl
					) AS cnt_flags,
				true_dosage
			FROM (
				SELECT ingredient_concept_code,
					dosage,
					flag,
					ARRAY_AGG(flag) OVER (
						PARTITION BY ingredient_concept_code,
						dosage_group
						) cnt_flags,
					first_value(dosage) OVER (
						PARTITION BY ingredient_concept_code,
						dosage_group ORDER BY length(regexp_replace(dosage::VARCHAR, '[^1-9]', '', 'g')),
							dosage
						) true_dosage
				FROM (
					SELECT rxe.ingredient_concept_code,
						rxe.dosage,
						rxe.dosage_group,
						coalesce(rx.flag, rxe.flag) AS flag
					FROM (
						SELECT DISTINCT ingredient_concept_code,
							dosage,
							dosage_group,
							'bad' AS flag
						FROM (
							SELECT ingredient_concept_code,
								dosage,
								dosage_group,
								count(*) OVER (
									PARTITION BY ingredient_concept_code,
									dosage_group
									) AS cnt_gr
							FROM (
								SELECT ingredient_concept_code,
									dosage,
									sum(group_trigger) OVER (
										PARTITION BY ingredient_concept_code ORDER BY dosage
										) + 1 dosage_group
								FROM (
									SELECT ingredient_concept_code,
										dosage,
										prev_dosage,
										abs(round((dosage - prev_dosage) * 100 / prev_dosage)) perc_dosage,
										CASE 
											WHEN abs(round((dosage - prev_dosage) * 100 / prev_dosage)) <= 5
												THEN 0
											ELSE 1
											END group_trigger
									FROM (
										SELECT ingredient_concept_code,
											dosage,
											lag(dosage, 1, dosage) OVER (
												PARTITION BY ingredient_concept_code ORDER BY dosage
												) prev_dosage
										FROM (
											SELECT DISTINCT ingredient_concept_code,
												round(dosage::NUMERIC, (3 - floor(log(dosage)) - 1)::INT) AS dosage
											FROM (
												SELECT ingredient_concept_code,
													CASE 
														WHEN amount_value IS NULL
															AND denominator_value IS NULL
															THEN numerator_value
														ELSE numerator_value / denominator_value
														END AS dosage
												FROM drug_strength_stage
												WHERE vocabulary_id_1 = 'RxNorm Extension'
													AND amount_value IS NULL
												) AS s0
											) AS s1
										) AS s2
									) AS s3
								) AS s4
							) AS s5
						WHERE cnt_gr > 1
						) rxe
					LEFT JOIN (
						SELECT DISTINCT ingredient_concept_code,
							round(dosage::NUMERIC, (3 - floor(log(dosage)) - 1)::INT) AS dosage,
							'good' AS flag
						FROM (
							SELECT ingredient_concept_code,
								CASE 
									WHEN amount_value IS NULL
										AND denominator_value IS NULL
										THEN numerator_value
									ELSE numerator_value / denominator_value
									END AS dosage
							FROM drug_strength_stage
							WHERE vocabulary_id_1 = 'RxNorm'
								AND amount_value IS NULL
							) AS s6
						) rx ON rx.ingredient_concept_code = rxe.ingredient_concept_code
						AND rx.dosage = rxe.dosage
					) AS s7
				) AS s8
			) merged_rxe,
			drug_strength_stage dss
		WHERE (
				merged_rxe.flag = 'bad'
				AND merged_rxe.cnt_flags = 2
				OR merged_rxe.flag = 'bad'
				AND merged_rxe.cnt_flags = 1
				AND dosage <> true_dosage
				)
			AND dss.ingredient_concept_code = merged_rxe.ingredient_concept_code
			AND CASE 
				WHEN dss.amount_value IS NULL
					AND dss.denominator_value IS NULL
					THEN round(dss.numerator_value::NUMERIC, (3 - floor(log(dss.numerator_value)) - 1)::INT)
				ELSE round((dss.numerator_value / dss.denominator_value)::NUMERIC, (3 - floor(log(dss.numerator_value / dss.denominator_value)) - 1)::INT)
				END = merged_rxe.dosage
			AND dss.vocabulary_id_1 = 'RxNorm Extension'
		)
	AND invalid_reason IS NULL;

--19
--deprecate drugs with insignificant volume
UPDATE concept_stage
SET invalid_reason = 'D',
	valid_end_date = (
		SELECT latest_update - 1
		FROM vocabulary
		WHERE vocabulary_id = 'RxNorm Extension'
		)
WHERE concept_code IN (
		SELECT drug_concept_code
		FROM drug_strength_stage
		WHERE denominator_value < 0.05
			AND vocabulary_id_1 = 'RxNorm Extension'
			AND denominator_unit_concept_id = 8587
		)
	AND vocabulary_id = 'RxNorm Extension'
	AND invalid_reason IS NULL;

--20
--deprecate all impossible drug_strength_stage inputs
UPDATE concept_stage
SET invalid_reason = 'D',
	valid_end_date = (
		SELECT latest_update - 1
		FROM vocabulary
		WHERE vocabulary_id = 'RxNorm Extension'
		)
WHERE concept_code IN (
		SELECT drug_concept_code
		FROM (
			SELECT DISTINCT drug_concept_code,
				denominator_value,
				denominator_unit_concept_id
			FROM drug_strength_stage
			WHERE invalid_reason IS NULL
				AND vocabulary_id_1 = 'RxNorm Extension'
			) AS s0
		GROUP BY drug_concept_code
		HAVING count(*) > 1
		)
	AND vocabulary_id = 'RxNorm Extension'
	AND invalid_reason IS NULL;

--21
--Deprecate concepts that have ingredients both in soluble and solid form
UPDATE concept_stage
SET invalid_reason = 'D',
	valid_end_date = (
		SELECT latest_update - 1
		FROM vocabulary
		WHERE vocabulary_id = 'RxNorm Extension'
		)
WHERE concept_code IN (
		SELECT drug_concept_code
		FROM drug_strength_stage ds
		WHERE ds.amount_value IS NOT NULL
			AND EXISTS (
				SELECT 1
				FROM drug_strength_stage ds_int
				WHERE ds_int.drug_concept_code = ds.drug_concept_code
					AND ds_int.vocabulary_id_1 = ds.vocabulary_id_1
					AND NOT (
						ds_int.ingredient_concept_code = ds.ingredient_concept_code
						AND ds_int.vocabulary_id_2 = ds.vocabulary_id_2
						)
					AND ds_int.numerator_value IS NOT NULL
				)
			AND ds.vocabulary_id_1 = 'RxNorm Extension'
		)
	AND vocabulary_id = 'RxNorm Extension'
	AND invalid_reason IS NULL;

--22
--deprecate all mappings (except 'Maps to' and 'Drug has drug class') if RxE-concept was deprecated 
UPDATE concept_relationship_stage crs
SET invalid_reason = 'D',
	valid_end_date = (
		SELECT latest_update - 1
		FROM vocabulary
		WHERE vocabulary_id = 'RxNorm Extension'
		)
WHERE EXISTS (
		SELECT 1
		FROM concept_stage cs
		WHERE cs.concept_code = crs.concept_code_1
			AND cs.vocabulary_id = crs.vocabulary_id_1
			AND cs.invalid_reason = 'D'
			AND cs.vocabulary_id = 'RxNorm Extension'
		)
	AND crs.relationship_id NOT IN (
		'Maps to',
		'Drug has drug class'
		)
	AND crs.invalid_reason IS NULL;

--reverse
UPDATE concept_relationship_stage crs
SET invalid_reason = 'D',
	valid_end_date = (
		SELECT latest_update - 1
		FROM vocabulary
		WHERE vocabulary_id = 'RxNorm Extension'
		)
WHERE EXISTS (
		SELECT 1
		FROM concept_stage cs
		WHERE cs.concept_code = crs.concept_code_2
			AND cs.vocabulary_id = crs.vocabulary_id_2
			AND cs.invalid_reason = 'D'
			AND cs.vocabulary_id = 'RxNorm Extension'
		)
	AND crs.relationship_id NOT IN (
		'Mapped from',
		'Drug class of drug'
		)
	AND crs.invalid_reason IS NULL;

--23
--create temporary table with old mappings and fresh concepts (after all 'Concept replaced by')
DROP TABLE IF EXISTS rxe_tmp_replaces;
CREATE TABLE rxe_tmp_replaces AS
	WITH src_codes AS (
			--get concepts and all their links, which targets to 'U'
			SELECT crs.concept_code_2 AS src_code,
				crs.vocabulary_id_2 AS src_vocab,
				cs.concept_code upd_code,
				cs.vocabulary_id upd_vocab,
				cs.concept_class_id upd_class_id,
				crs.relationship_id src_rel
			FROM concept_stage cs,
				concept_relationship_stage crs
			WHERE cs.concept_code = crs.concept_code_1
				AND cs.vocabulary_id = crs.vocabulary_id_2
				AND cs.invalid_reason = 'U'
				AND cs.vocabulary_id = 'RxNorm Extension'
				AND crs.invalid_reason IS NULL
				AND crs.relationship_id NOT IN (
					'Concept replaced by',
					'Concept replaces'
					)
			),
		fresh_codes AS (
			--get all fresh concepts (with recursion until the last fresh)
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
					SELECT concept_code_1 AS ancestor_concept_code,
						vocabulary_id_1 AS ancestor_vocabulary_id,
						concept_code_2 AS descendant_concept_code,
						vocabulary_id_2 AS descendant_vocabulary_id
					FROM concept_relationship_stage crs
					WHERE crs.relationship_id = 'Concept replaced by'
						AND crs.invalid_reason IS NULL
					)
			SELECT DISTINCT hc.root_ancestor_concept_code AS upd_code,
				hc.root_ancestor_vocabulary_id AS upd_vocab,
				hc.descendant_concept_code AS new_code,
				hc.descendant_vocabulary_id AS new_vocab
			FROM hierarchy_concepts hc
			WHERE NOT EXISTS (
					/*same as oracle's CONNECT_BY_ISLEAF*/
					SELECT 1
					FROM hierarchy_concepts hc_int
					WHERE hc_int.ancestor_concept_code = hc.descendant_concept_code
						AND hc_int.ancestor_vocabulary_id = hc.descendant_vocabulary_id
					)
			)

SELECT src.src_code,
	src.src_vocab,
	src.upd_code,
	src.upd_vocab,
	src.upd_class_id,
	src.src_rel,
	fr.new_code,
	fr.new_vocab
FROM src_codes src,
	fresh_codes fr
WHERE src.upd_code = fr.upd_code
	AND src.upd_vocab = fr.upd_vocab
	AND NOT (
		src.src_vocab = 'RxNorm'
		AND fr.new_vocab = 'RxNorm'
		);

--deprecate old relationships
UPDATE concept_relationship_stage crs
SET invalid_reason = 'D',
	valid_end_date = (
		SELECT latest_update - 1
		FROM vocabulary
		WHERE vocabulary_id = 'RxNorm Extension'
		)
WHERE (
		crs.concept_code_2,
		crs.vocabulary_id_2,
		crs.concept_code_1,
		crs.vocabulary_id_1,
		crs.relationship_id
		) IN (
		SELECT r.src_code,
			r.src_vocab,
			r.upd_code,
			r.upd_vocab,
			r.src_rel
		FROM rxe_tmp_replaces r
		WHERE r.upd_class_id IN (
				'Brand Name',
				'Ingredient',
				'Supplier',
				'Dose Form'
				)
		)
	AND invalid_reason IS NULL;

--reverse
UPDATE concept_relationship_stage crs
SET invalid_reason = 'D',
	valid_end_date = (
		SELECT latest_update - 1
		FROM vocabulary
		WHERE vocabulary_id = 'RxNorm Extension'
		)
WHERE (
		crs.concept_code_1,
		crs.vocabulary_id_1,
		crs.concept_code_2,
		crs.vocabulary_id_2,
		crs.relationship_id
		) IN (
		SELECT r.upd_code,
			r.upd_vocab,
			r.src_code,
			r.src_vocab,
			rel.reverse_relationship_id
		FROM rxe_tmp_replaces r,
			relationship rel
		WHERE r.upd_class_id IN (
				'Brand Name',
				'Ingredient',
				'Supplier',
				'Dose Form'
				)
			AND r.src_rel = rel.relationship_id
		)
	AND invalid_reason IS NULL;

--build new ones relationships or update existing
UPDATE concept_relationship_stage crs
SET invalid_reason = NULL,
	valid_end_date = to_date('20991231', 'YYYYMMDD')
FROM (
	SELECT *
	FROM rxe_tmp_replaces r
	WHERE r.upd_class_id IN (
			'Brand Name',
			'Ingredient',
			'Supplier',
			'Dose Form'
			)
	) i
WHERE i.src_code = crs.concept_code_1
	AND i.src_vocab = crs.vocabulary_id_1
	AND i.new_code = crs.concept_code_2
	AND i.new_vocab = crs.vocabulary_id_2
	AND i.src_rel = crs.relationship_id
	AND crs.invalid_reason IS NOT NULL;

INSERT INTO concept_relationship_stage (
	concept_code_1,
	vocabulary_id_1,
	concept_code_2,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT i.src_code,
	i.src_vocab,
	i.new_code,
	i.new_vocab,
	i.src_rel,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'RxNorm Extension'
		),
	to_date('20991231', 'YYYYMMDD'),
	NULL
FROM (
	SELECT *
	FROM rxe_tmp_replaces r
	WHERE r.upd_class_id IN (
			'Brand Name',
			'Ingredient',
			'Supplier',
			'Dose Form'
			)
	) i
WHERE NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs_int
		WHERE i.src_code = crs_int.concept_code_2
			AND i.src_vocab = crs_int.vocabulary_id_2
			AND i.new_code = crs_int.concept_code_1
			AND i.new_vocab = crs_int.vocabulary_id_1
			AND i.src_rel = crs_int.relationship_id
		);

--reverse
UPDATE concept_relationship_stage crs
SET invalid_reason = NULL,
	valid_end_date = to_date('20991231', 'YYYYMMDD')
FROM (
	SELECT *
	FROM rxe_tmp_replaces r,
		relationship rel
	WHERE r.upd_class_id IN (
			'Brand Name',
			'Ingredient',
			'Supplier',
			'Dose Form'
			)
		AND r.src_rel = rel.relationship_id
	) i
WHERE i.src_code = crs.concept_code_2
	AND i.src_vocab = crs.vocabulary_id_2
	AND i.new_code = crs.concept_code_1
	AND i.new_vocab = crs.vocabulary_id_1
	AND i.reverse_relationship_id = crs.relationship_id
	AND crs.invalid_reason IS NOT NULL;

INSERT INTO concept_relationship_stage (
	concept_code_2,
	vocabulary_id_2,
	concept_code_1,
	vocabulary_id_1,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT i.src_code,
	i.src_vocab,
	i.new_code,
	i.new_vocab,
	i.reverse_relationship_id,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'RxNorm Extension'
		),
	to_date('20991231', 'YYYYMMDD'),
	NULL
FROM (
	SELECT *
	FROM rxe_tmp_replaces r,
		relationship rel
	WHERE r.upd_class_id IN (
			'Brand Name',
			'Ingredient',
			'Supplier',
			'Dose Form'
			)
		AND r.src_rel = rel.relationship_id
	) i
WHERE NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs_int
		WHERE i.src_code = crs_int.concept_code_2
			AND i.src_vocab = crs_int.vocabulary_id_2
			AND i.new_code = crs_int.concept_code_1
			AND i.new_vocab = crs_int.vocabulary_id_1
			AND i.reverse_relationship_id = crs_int.relationship_id
		);

--same for drugs (only deprecate old relationships except 'Maps to' and 'Drug has drug class' from 'U'
UPDATE concept_relationship_stage crs
SET invalid_reason = 'D',
	valid_end_date = (
		SELECT latest_update - 1
		FROM vocabulary
		WHERE vocabulary_id = 'RxNorm Extension'
		)
WHERE (
		crs.concept_code_1,
		crs.vocabulary_id_1,
		crs.concept_code_2,
		crs.vocabulary_id_2,
		crs.relationship_id
		) IN (
		SELECT r.src_code,
			r.src_vocab,
			r.upd_code,
			r.upd_vocab,
			r.src_rel
		FROM rxe_tmp_replaces r
		WHERE r.upd_class_id NOT IN (
				'Brand Name',
				'Ingredient',
				'Supplier',
				'Dose Form'
				)
			AND r.src_rel NOT IN (
				'Mapped from',
				'Drug class of drug'
				)
		);

--reverse
UPDATE concept_relationship_stage crs
SET invalid_reason = 'D',
	valid_end_date = (
		SELECT latest_update - 1
		FROM vocabulary
		WHERE vocabulary_id = 'RxNorm Extension'
		)
WHERE (
		crs.concept_code_1,
		crs.vocabulary_id_1,
		crs.concept_code_2,
		crs.vocabulary_id_2,
		crs.relationship_id
		) IN (
		SELECT r.upd_code,
			r.upd_vocab,
			r.src_code,
			r.src_vocab,
			rel.reverse_relationship_id
		FROM rxe_tmp_replaces r,
			relationship rel
		WHERE r.upd_class_id NOT IN (
				'Brand Name',
				'Ingredient',
				'Supplier',
				'Dose Form'
				)
			AND r.src_rel = rel.relationship_id
			AND r.src_rel NOT IN (
				'Mapped from',
				'Drug class of drug'
				)
		);

--24
--deprecate relationships to multiple drug forms or suppliers
UPDATE concept_relationship_stage crs
SET invalid_reason = 'D',
	valid_end_date = (
		SELECT latest_update - 1
		FROM vocabulary
		WHERE vocabulary_id = 'RxNorm Extension'
		)
WHERE (
		crs.concept_code_1,
		crs.vocabulary_id_1,
		crs.concept_code_2,
		crs.vocabulary_id_2
		) IN (
		SELECT concept_code_1,
			vocabulary_id_1,
			concept_code_2,
			vocabulary_id_2
		FROM (
			WITH t AS (
					SELECT cs1.concept_code AS concept_code_1,
						cs1.vocabulary_id AS vocabulary_id_1,
						c2.concept_code AS concept_code_2,
						c2.vocabulary_id AS vocabulary_id_2
					FROM concept_stage cs1
					JOIN (
						--for c2 we cannot use stage table, because we need rx classes
						SELECT crs.concept_code_1,
							c2.concept_class_id
						FROM concept_stage cs1,
							concept c2,
							concept_relationship_stage crs
						WHERE cs1.concept_code = crs.concept_code_1
							AND cs1.vocabulary_id = crs.vocabulary_id_1
							AND cs1.vocabulary_id = 'RxNorm Extension'
							AND c2.concept_code = crs.concept_code_2
							AND c2.vocabulary_id = crs.vocabulary_id_2
							AND c2.concept_class_id IN (
								'Dose Form',
								'Supplier'
								)
							AND crs.invalid_reason IS NULL
						GROUP BY crs.concept_code_1,
							c2.concept_class_id
						HAVING count(*) > 1
						) d ON d.concept_code_1 = cs1.concept_code
						AND cs1.concept_class_id NOT IN (
							'Dose Form',
							'Supplier',
							'Ingredient',
							'Brand Name'
							)
						AND cs1.vocabulary_id = 'RxNorm Extension'
					JOIN concept_relationship_stage crs ON crs.concept_code_1 = d.concept_code_1
						AND crs.vocabulary_id_1 = 'RxNorm Extension'
						AND crs.invalid_reason IS NULL
					--for c2 we cannot use stage table, because we need rx classes
					JOIN concept c2 ON c2.concept_code = crs.concept_code_2
						AND c2.vocabulary_id = crs.vocabulary_id_2
						AND c2.concept_class_id = d.concept_class_id
					WHERE cs1.concept_name NOT Ilike '%' || c2.concept_name || '%'
					)
			SELECT concept_code_1,
				vocabulary_id_1,
				concept_code_2,
				vocabulary_id_2
			FROM t
			
			UNION ALL
			--reverse
			SELECT concept_code_2,
				vocabulary_id_2,
				concept_code_1,
				vocabulary_id_1
			FROM t
			) AS s0
		)
	AND crs.invalid_reason IS NULL;

--25
--deprecate relationship from Pack to Brand Names of it's components
UPDATE concept_relationship_stage crs
SET invalid_reason = 'D',
	valid_end_date = (
		SELECT latest_update - 1
		FROM vocabulary
		WHERE vocabulary_id = 'RxNorm Extension'
		)
WHERE (
		crs.concept_code_1,
		crs.vocabulary_id_1,
		crs.concept_code_2,
		crs.vocabulary_id_2
		) IN (
		SELECT concept_code_1,
			vocabulary_id_1,
			concept_code_2,
			vocabulary_id_2
		FROM (
			WITH t AS (
					SELECT cs1.concept_code AS concept_code_1,
						cs1.vocabulary_id AS vocabulary_id_1,
						c2.concept_code AS concept_code_2,
						c2.vocabulary_id AS vocabulary_id_2
					FROM concept_stage cs1
					JOIN (
						--for c2 we cannot use stage table, because we need rx classes
						SELECT crs.concept_code_1
						FROM concept c2,
							concept_relationship_stage crs
						WHERE crs.vocabulary_id_1 = 'RxNorm Extension'
							AND c2.concept_code = crs.concept_code_2
							AND c2.vocabulary_id = crs.vocabulary_id_2
							AND c2.concept_class_id = 'Brand Name'
							AND crs.invalid_reason IS NULL
						GROUP BY crs.concept_code_1,
							c2.concept_class_id
						HAVING count(*) > 1
						) d ON d.concept_code_1 = cs1.concept_code
						AND cs1.concept_class_id NOT IN (
							'Dose Form',
							'Supplier',
							'Ingredient',
							'Brand Name'
							)
						AND cs1.vocabulary_id = 'RxNorm Extension'
					JOIN concept_relationship_stage crs ON crs.concept_code_1 = d.concept_code_1
						AND crs.vocabulary_id_1 = 'RxNorm Extension'
						AND crs.invalid_reason IS NULL
					--for c2 we cannot use stage table, because we need rx classes
					JOIN concept c2 ON c2.concept_code = crs.concept_code_2
						AND c2.vocabulary_id = crs.vocabulary_id_2
						AND c2.concept_class_id = 'Brand Name'
					WHERE lower(regexp_replace(cs1.concept_name, '.* Pack .*\[(.*)\]', '\1', 'g')) <> lower(c2.concept_name)
					)
			SELECT concept_code_1,
				vocabulary_id_1,
				concept_code_2,
				vocabulary_id_2
			FROM t
			
			UNION ALL
			
			SELECT concept_code_2,
				vocabulary_id_2,
				concept_code_1,
				vocabulary_id_1
			FROM t
			) AS s0
		)
	AND crs.invalid_reason IS NULL;

--26 
--deprecate branded packs without links to brand names
UPDATE concept_stage
SET invalid_reason = 'D',
	valid_end_date = (
		SELECT latest_update - 1
		FROM vocabulary
		WHERE vocabulary_id = 'RxNorm Extension'
		)
WHERE concept_code IN (
		SELECT cs1.concept_code
		FROM concept_stage cs1
		WHERE cs1.vocabulary_id = 'RxNorm Extension'
			AND cs1.concept_class_id LIKE '%Branded%Pack%'
			AND NOT EXISTS (
				SELECT 1
				FROM concept_relationship_stage crs,
					concept_stage cs2
				WHERE crs.concept_code_1 = cs1.concept_code
					AND crs.vocabulary_id_1 = cs1.vocabulary_id
					AND crs.concept_code_2 = cs2.concept_code
					AND crs.vocabulary_id_2 = cs2.vocabulary_id
					AND cs2.concept_class_id = 'Brand Name'
					AND cs2.vocabulary_id = 'RxNorm Extension'
					AND crs.invalid_reason IS NULL
				)
		)
	AND vocabulary_id = 'RxNorm Extension'
	AND invalid_reason IS NULL;
!!!
--27
--turn 'Brand name of' and RxNorm ing of to 'Supplier of' (between 'Supplier' and 'Marketed Product')
UPDATE concept_relationship_stage crs
SET invalid_reason = NULL,
	valid_end_date = to_date('20991231', 'YYYYMMDD')
FROM (
	SELECT crs.concept_code_1,
		crs.concept_code_2,
		crs.relationship_id,
		'Supplier of'::VARCHAR new_relationship_id
	FROM concept_stage cs1,
		concept_stage cs2,
		concept_relationship_stage crs
	WHERE cs1.concept_code = crs.concept_code_1
		AND cs1.vocabulary_id = crs.vocabulary_id_1
		AND cs1.vocabulary_id = 'RxNorm Extension'
		AND cs2.concept_code = crs.concept_code_2
		AND cs2.vocabulary_id = crs.vocabulary_id_2
		AND cs2.vocabulary_id = 'RxNorm Extension'
		AND cs1.concept_class_id = 'Supplier'
		AND cs2.concept_class_id = 'Marketed Product'
		AND crs.relationship_id IN (
			'Brand name of',
			'RxNorm ing of'
			)
		AND crs.invalid_reason IS NULL
	) i
WHERE i.concept_code_1 = crs.concept_code_1
	AND crs.vocabulary_id_1 = 'RxNorm Extension'
	AND i.concept_code_2 = crs.concept_code_2
	AND crs.vocabulary_id_2 = 'RxNorm Extension'
	AND i.new_relationship_id = crs.relationship_id
	AND crs.invalid_reason IS NOT NULL;

INSERT INTO concept_relationship_stage (
	concept_code_1,
	vocabulary_id_1,
	concept_code_2,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT i.concept_code_1,
	'RxNorm Extension',
	i.concept_code_2,
	'RxNorm Extension',
	i.new_relationship_id,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'RxNorm Extension'
		),
	to_date('20991231', 'YYYYMMDD'),
	NULL
FROM (
	SELECT crs.concept_code_1,
		crs.concept_code_2,
		crs.relationship_id,
		'Supplier of'::VARCHAR new_relationship_id
	FROM concept_stage cs1,
		concept_stage cs2,
		concept_relationship_stage crs
	WHERE cs1.concept_code = crs.concept_code_1
		AND cs1.vocabulary_id = crs.vocabulary_id_1
		AND cs1.vocabulary_id = 'RxNorm Extension'
		AND cs2.concept_code = crs.concept_code_2
		AND cs2.vocabulary_id = crs.vocabulary_id_2
		AND cs2.vocabulary_id = 'RxNorm Extension'
		AND cs1.concept_class_id = 'Supplier'
		AND cs2.concept_class_id = 'Marketed Product'
		AND crs.relationship_id IN (
			'Brand name of',
			'RxNorm ing of'
			)
		AND crs.invalid_reason IS NULL
	) i
WHERE NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs_int
		WHERE i.concept_code_1 = crs_int.concept_code_1
			AND crs_int.vocabulary_id_1 = 'RxNorm Extension'
			AND i.concept_code_2 = crs_int.concept_code_2
			AND crs_int.vocabulary_id_2 = 'RxNorm Extension'
			AND i.new_relationship_id = crs_int.relationship_id
		);

--turn 'Has brand name' and to 'Has supplier' (reverse)
UPDATE concept_relationship_stage crs
SET invalid_reason = NULL,
	valid_end_date = to_date('20991231', 'YYYYMMDD')
FROM (
	SELECT crs.concept_code_1,
		crs.concept_code_2,
		crs.relationship_id,
		'Has supplier'::VARCHAR new_relationship_id
	FROM concept_stage cs1,
		concept_stage cs2,
		concept_relationship_stage crs
	WHERE cs1.concept_code = crs.concept_code_1
		AND cs1.vocabulary_id = crs.vocabulary_id_1
		AND cs1.vocabulary_id = 'RxNorm Extension'
		AND cs2.concept_code = crs.concept_code_2
		AND cs2.vocabulary_id = crs.vocabulary_id_2
		AND cs2.vocabulary_id = 'RxNorm Extension'
		AND cs1.concept_class_id = 'Marketed Product'
		AND cs2.concept_class_id = 'Supplier'
		AND crs.relationship_id IN (
			'Has brand name',
			'RxNorm has ing'
			)
		AND crs.invalid_reason IS NULL
	) i
WHERE i.concept_code_1 = crs.concept_code_1
	AND crs.vocabulary_id_1 = 'RxNorm Extension'
	AND i.concept_code_2 = crs.concept_code_2
	AND crs.vocabulary_id_2 = 'RxNorm Extension'
	AND i.new_relationship_id = crs.relationship_id
	AND crs.invalid_reason IS NOT NULL;

INSERT INTO concept_relationship_stage (
	concept_code_1,
	vocabulary_id_1,
	concept_code_2,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT i.concept_code_1,
	'RxNorm Extension',
	i.concept_code_2,
	'RxNorm Extension',
	i.new_relationship_id,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'RxNorm Extension'
		),
	to_date('20991231', 'YYYYMMDD'),
	NULL
FROM (
	SELECT crs.concept_code_1,
		crs.concept_code_2,
		crs.relationship_id,
		'Has supplier'::VARCHAR new_relationship_id
	FROM concept_stage cs1,
		concept_stage cs2,
		concept_relationship_stage crs
	WHERE cs1.concept_code = crs.concept_code_1
		AND cs1.vocabulary_id = crs.vocabulary_id_1
		AND cs1.vocabulary_id = 'RxNorm Extension'
		AND cs2.concept_code = crs.concept_code_2
		AND cs2.vocabulary_id = crs.vocabulary_id_2
		AND cs2.vocabulary_id = 'RxNorm Extension'
		AND cs1.concept_class_id = 'Marketed Product'
		AND cs2.concept_class_id = 'Supplier'
		AND crs.relationship_id IN (
			'Has brand name',
			'RxNorm has ing'
			)
		AND crs.invalid_reason IS NULL
	) i
WHERE NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs_int
		WHERE i.concept_code_1 = crs_int.concept_code_1
			AND crs_int.vocabulary_id_1 = 'RxNorm Extension'
			AND i.concept_code_2 = crs_int.concept_code_2
			AND crs_int.vocabulary_id_2 = 'RxNorm Extension'
			AND i.new_relationship_id = crs_int.relationship_id
		);

--deprecate wrong relationship_ids
--('Supplier'<->'Marketed Product' via relationship_id in ('Has brand name','Brand name of','RxNorm has ing','RxNorm ing of'))
UPDATE concept_relationship_stage
SET invalid_reason = 'D',
	valid_end_date = (
		SELECT latest_update - 1
		FROM vocabulary
		WHERE vocabulary_id = 'RxNorm Extension'
		)
WHERE ctid IN (
		SELECT crs.ctid
		FROM concept_stage cs1,
			concept_stage cs2,
			concept_relationship_stage crs
		WHERE cs1.concept_code = crs.concept_code_1
			AND cs1.vocabulary_id = crs.vocabulary_id_1
			AND cs1.vocabulary_id = 'RxNorm Extension'
			AND cs2.concept_code = crs.concept_code_2
			AND cs2.vocabulary_id = crs.vocabulary_id_2
			AND cs2.vocabulary_id = 'RxNorm Extension'
			AND cs1.concept_class_id IN (
				'Supplier',
				'Marketed Product'
				)
			AND cs2.concept_class_id IN (
				'Supplier',
				'Marketed Product'
				)
			AND crs.relationship_id IN (
				'Has brand name',
				'Brand name of',
				'RxNorm has ing',
				'RxNorm ing of'
				)
			AND crs.invalid_reason IS NULL
		);

--28 little manual fixes
--update supplier
UPDATE concept_stage c
SET standard_concept = NULL
WHERE concept_code = 'OMOP897375'
	AND vocabulary_id = 'RxNorm Extension'
	AND standard_concept = 'S';

--deprecate wrong links to brand name because we already have new ones
UPDATE concept_relationship_stage
SET invalid_reason = 'D',
	valid_end_date = (
		SELECT latest_update - 1
		FROM vocabulary
		WHERE vocabulary_id = 'RxNorm Extension'
		)
WHERE concept_code_1 IN (
		'OMOP559924',
		'OMOP560898'
		)
	AND concept_code_2 = '848161'
	AND relationship_id = 'Has brand name'
	AND invalid_reason IS NULL;

--reverse
UPDATE concept_relationship_stage
SET invalid_reason = 'D',
	valid_end_date = (
		SELECT latest_update - 1
		FROM vocabulary
		WHERE vocabulary_id = 'RxNorm Extension'
		)
WHERE concept_code_2 IN (
		'OMOP559924',
		'OMOP560898'
		)
	AND concept_code_1 = '848161'
	AND relationship_id = 'Brand name of'
	AND invalid_reason IS NULL;

UPDATE concept_relationship_stage
SET invalid_reason = 'D',
	valid_end_date = (
		SELECT latest_update - 1
		FROM vocabulary
		WHERE vocabulary_id = 'RxNorm Extension'
		)
WHERE (
		concept_code_1,
		vocabulary_id_1,
		concept_code_2,
		vocabulary_id_2,
		relationship_id
		) IN (
		WITH t AS (
				SELECT crs.concept_code_1,
					crs.vocabulary_id_1,
					crs.concept_code_2,
					crs.vocabulary_id_2,
					crs.relationship_id,
					rl.reverse_relationship_id
				FROM concept_stage cs1,
					concept c2,
					concept_relationship_stage crs,
					relationship rl
				WHERE cs1.concept_code = crs.concept_code_1
					AND cs1.vocabulary_id = crs.vocabulary_id_1
					AND cs1.vocabulary_id = 'RxNorm Extension'
					AND c2.concept_code = crs.concept_code_2
					AND c2.vocabulary_id = crs.vocabulary_id_2
					AND c2.vocabulary_id = 'RxNorm'
					AND cs1.concept_class_id = 'Brand Name'
					AND (
						c2.concept_class_id LIKE '%Drug%'
						OR c2.concept_class_id LIKE '%Pack%'
						OR c2.concept_class_id LIKE '%Box%'
						)
					AND crs.invalid_reason IS NULL
					AND crs.relationship_id = rl.relationship_id
				)
		SELECT concept_code_1,
			vocabulary_id_1,
			concept_code_2,
			vocabulary_id_2,
			relationship_id
		FROM t
		
		UNION ALL
		--reverse
		SELECT concept_code_2,
			vocabulary_id_2,
			concept_code_1,
			vocabulary_id_1,
			reverse_relationship_id
		FROM t
		)
	AND invalid_reason IS NULL;


--29 Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

--30 Add mapping from deprecated to fresh concepts, and also from non-standard to standard concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

--31 Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--32 Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;

--33 Clean up
DROP TABLE rxe_tmp_replaces;
DROP TABLE wrong_rxe_replacements;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script