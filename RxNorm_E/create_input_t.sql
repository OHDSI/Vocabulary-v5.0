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
* Authors: Anna Ostropolets, Christian Reich, Timur Vakhitov
* Date: 2017
**************************************************************************/

--1 Revive relationships in order to use them in list item #22
UPDATE concept_relationship
SET invalid_reason = NULL,
	valid_end_date = TO_DATE('20991231', 'YYYYMMDD')
WHERE relationship_id IN (
		'RxNorm has dose form',
		'RxNorm dose form of'
		)
	AND invalid_reason = 'D';

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


--1 Add new temporary vocabulary named Rxfix to the vocabulary table
INSERT INTO concept (
	concept_id,
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
VALUES (
	100,
	'Rxfix',
	'Drug',
	'Vocabulary',
	'Vocabulary',
	NULL,
	'OMOP generated',
	TO_DATE('19700101', 'yyyymmdd'),
	TO_DATE('20991231', 'yyyymmdd'),
	NULL
	);

INSERT INTO vocabulary (
	vocabulary_id,
	vocabulary_name,
	vocabulary_concept_id
	)
VALUES (
	'Rxfix',
	'Rxfix',
	100
	);

--2 Update latest_update field to new date 
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'Rxfix',
	pVocabularyDate			=> CURRENT_DATE,
	pVocabularyVersion		=> 'Rxfix '||CURRENT_DATE,
	pVocabularyDevSchema	=> 'DEV_RXE'
);
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'RxNorm Extension',
	pVocabularyDate			=> CURRENT_DATE,
	pVocabularyVersion		=> 'RxNorm Extension '||CURRENT_DATE,
	pVocabularyDevSchema	=> 'DEV_RXE',
	pAppendVocabulary		=> TRUE
);
END $_$;

--3 create input tables 
DROP TABLE drug_concept_stage; --temporary!!!!! later we should to move all drops to the end of this script (or cndv?)
DROP TABLE ds_stage;
DROP TABLE internal_relationship_stage;
DROP TABLE pc_stage;
DROP TABLE relationship_to_concept;

--3.1 1st input table: drug_concept_stage
CREATE TABLE drug_concept_stage (
	concept_name VARCHAR(255),
	vocabulary_id VARCHAR(20),
	concept_class_id VARCHAR(20),
	standard_concept VARCHAR(1),
	concept_code VARCHAR(50),
	possible_excipient VARCHAR(1),
	domain_id VARCHAR(20),
	valid_start_date DATE,
	valid_end_date DATE,
	invalid_reason VARCHAR(1),
	source_concept_class_id VARCHAR(20)
	);

--3.2 2nd input table: ds_stage
CREATE TABLE ds_stage (
	drug_concept_code VARCHAR(50),
	ingredient_concept_code VARCHAR(50),
	box_size INT,
	amount_value FLOAT,
	amount_unit VARCHAR(50),
	numerator_value FLOAT,
	numerator_unit VARCHAR(50),
	denominator_value FLOAT,
	denominator_unit VARCHAR(50)
	);

--3.3 3rd input table: internal_relationship_stage
CREATE TABLE internal_relationship_stage (
	concept_code_1 VARCHAR(50),
	concept_code_2 VARCHAR(50)
	);

--3.4 4th input table: pc_stage
CREATE TABLE pc_stage (
	pack_concept_code VARCHAR(50),
	drug_concept_code VARCHAR(50),
	amount FLOAT,
	box_size INT
	);

--3.5 5th input table: relationship_to_concept
CREATE TABLE relationship_to_concept (
	concept_code_1 VARCHAR(50),
	vocabulary_id_1 VARCHAR(20),
	concept_id_2 INT,
	precedence INT,
	conversion_factor FLOAT
	);

--4 Create Concepts
--4.1 Get products
INSERT INTO drug_concept_stage (
	concept_name,
	vocabulary_id,
	concept_class_id,
	standard_concept,
	concept_code,
	possible_excipient,
	domain_id,
	valid_start_date,
	valid_end_date,
	invalid_reason,
	source_concept_class_id
	)
SELECT concept_name,
	'Rxfix',
	'Drug Product',
	NULL,
	concept_code,
	NULL,
	domain_id,
	valid_start_date,
	valid_end_date,
	invalid_reason,
	concept_class_id
FROM concept
WHERE
	-- all the "Drug" Classes
	(
		concept_class_id LIKE '%Drug%'
		OR concept_class_id LIKE '%Pack%'
		OR concept_class_id LIKE '%Box%'
		OR concept_class_id LIKE '%Marketed%'
		)
	AND vocabulary_id = 'RxNorm Extension'
	AND invalid_reason IS NULL

UNION ALL

-- Get Dose Forms, Brand Names, Supplier, including RxNorm
SELECT c.concept_name,
	'Rxfix',
	c.concept_class_id,
	NULL,
	c.concept_code,
	NULL,
	c.domain_id,
	c.valid_start_date,
	c.valid_end_date,
	c.invalid_reason,
	c.concept_class_id
FROM concept c
--their attributes
WHERE c.concept_class_id IN (
		'Dose Form',
		'Brand Name',
		'Supplier'
		)
	AND c.vocabulary_id LIKE 'Rx%'
	AND c.invalid_reason IS NULL
	AND EXISTS (
		SELECT 1
		FROM concept_relationship cr
		JOIN concept c_int ON c_int.concept_id = cr.concept_id_1
			-- the same list of the products
			AND (
				c_int.concept_class_id LIKE '%Drug%'
				OR c_int.concept_class_id LIKE '%Pack%'
				OR c_int.concept_class_id LIKE '%Box%'
				OR c_int.concept_class_id LIKE '%Marketed%'
				)
			AND c_int.vocabulary_id = 'RxNorm Extension'
		WHERE cr.concept_id_2 = c.concept_id
			AND cr.invalid_reason IS NULL
		);

INSERT INTO drug_concept_stage (
	concept_name,
	vocabulary_id,
	concept_class_id,
	standard_concept,
	concept_code,
	possible_excipient,
	domain_id,
	valid_start_date,
	valid_end_date,
	invalid_reason,
	source_concept_class_id
	)
--Get RxNorm pack components from RxNorm
SELECT c2.concept_name,
	'Rxfix',
	'Drug Product',
	NULL,
	c2.concept_code,
	NULL,
	c2.domain_id,
	c2.valid_start_date,
	c2.valid_end_date,
	c2.invalid_reason,
	c2.concept_class_id
FROM pack_content pc
JOIN concept c ON c.concept_id = pc.pack_concept_id
	AND c.vocabulary_id = 'RxNorm Extension'
JOIN concept c2 ON c2.concept_id = pc.drug_concept_id
	AND c2.vocabulary_id = 'RxNorm'
	AND c2.invalid_reason IS NULL

UNION

SELECT c3.concept_name,
	'Rxfix',
	'Drug Product',
	NULL,
	c3.concept_code,
	NULL,
	c3.domain_id,
	c3.valid_start_date,
	c3.valid_end_date,
	c3.invalid_reason,
	c3.concept_class_id
FROM pack_content pc
JOIN concept c ON c.concept_id = pc.pack_concept_id
	AND c.vocabulary_id = 'RxNorm Extension'
JOIN concept c2 ON c2.concept_id = pc.drug_concept_id
	AND c2.vocabulary_id = 'RxNorm'
	AND c2.invalid_reason = 'U'
JOIN concept_relationship cr ON cr.concept_id_1 = c2.concept_id
	AND relationship_id = 'Concept replaced by'
JOIN concept c3 ON c3.concept_id = concept_id_2

UNION

SELECT c.concept_name,
	'Rxfix',
	'Drug Product',
	NULL,
	c.concept_code,
	NULL,
	c.domain_id,
	c.valid_start_date,
	c.valid_end_date,
	c.invalid_reason,
	c.concept_class_id
FROM concept c
JOIN concept_relationship cr ON c.concept_id = cr.concept_id_1
JOIN concept c2 ON c2.concept_id = concept_id_2
	AND c2.vocabulary_id = 'RxNorm Extension'
	AND c2.concept_class_id LIKE '%Pack%'
WHERE relationship_id = 'Contained in'
	AND c.concept_code NOT IN (
		SELECT concept_code
		FROM drug_concept_stage
		);

--4.2 Get upgraded Dose Forms, Brand Names, Supplier
INSERT INTO drug_concept_stage (
	concept_name,
	vocabulary_id,
	concept_class_id,
	standard_concept,
	concept_code,
	possible_excipient,
	domain_id,
	valid_start_date,
	valid_end_date,
	invalid_reason,
	source_concept_class_id
	)
SELECT c.concept_name,
	'Rxfix',
	c.concept_class_id,
	NULL,
	c.concept_code,
	NULL,
	c.domain_id,
	c.valid_start_date,
	c.valid_end_date,
	c.invalid_reason,
	c.concept_class_id
FROM concept c
-- add fresh attributes instead of invalid
WHERE EXISTS (
		SELECT 1
		FROM concept_relationship cr
		JOIN concept c_int1 ON c_int1.concept_id = cr.concept_id_1
			AND (
				c_int1.concept_class_id LIKE '%Drug%'
				OR c_int1.concept_class_id LIKE '%Pack%'
				OR c_int1.concept_class_id LIKE '%Box%'
				OR c_int1.concept_class_id LIKE '%Marketed%'
				)
			AND c_int1.vocabulary_id = 'RxNorm Extension'
		JOIN concept c_int2 ON c_int2.concept_id = cr.concept_id_2
			AND c_int2.concept_class_id IN (
				'Dose Form',
				'Brand Name',
				'Supplier'
				)
			AND c_int2.vocabulary_id LIKE 'Rx%'
			AND c_int2.invalid_reason IS NOT NULL
		--get last fresh attributes
		JOIN (
			WITH recursive hierarchy_concepts(ancestor_concept_id, descendant_concept_id, root_ancestor_concept_id, full_path) AS (
					SELECT ancestor_concept_id,
						descendant_concept_id,
						ancestor_concept_id AS root_ancestor_concept_id,
						ARRAY [descendant_concept_id] AS full_path
					FROM concepts
					
					UNION ALL
					
					SELECT c.ancestor_concept_id,
						c.descendant_concept_id,
						root_ancestor_concept_id,
						hc.full_path || c.descendant_concept_id AS full_path
					FROM concepts c
					JOIN hierarchy_concepts hc ON hc.descendant_concept_id = c.ancestor_concept_id
					WHERE c.descendant_concept_id <> ALL (full_path)
					),
				concepts AS (
					SELECT r.concept_id_1 AS ancestor_concept_id,
						r.concept_id_2 AS descendant_concept_id
					FROM concept_relationship r
					JOIN concept c1 ON c1.concept_id = r.concept_id_1
						AND c1.concept_class_id IN (
							'Dose Form',
							'Brand Name',
							'Supplier'
							)
						AND c1.vocabulary_id LIKE 'Rx%'
					JOIN concept c2 ON c2.concept_id = r.concept_id_2
						AND c2.concept_class_id IN (
							'Dose Form',
							'Brand Name',
							'Supplier'
							)
						AND c2.vocabulary_id LIKE 'Rx%'
					WHERE r.relationship_id = 'Concept replaced by'
						AND r.invalid_reason IS NULL
					)
			SELECT hc.root_ancestor_concept_id AS root_concept_id_1,
				hc.descendant_concept_id AS concept_id_2
			FROM hierarchy_concepts hc
			WHERE NOT EXISTS (
					/*same as oracle's CONNECT_BY_ISLEAF*/
					SELECT 1
					FROM hierarchy_concepts hc_int
					WHERE hc_int.ancestor_concept_id = hc.descendant_concept_id
					)
			) lf ON lf.root_concept_id_1 = c_int2.concept_id
		WHERE lf.concept_id_2 = c.concept_id
			AND cr.invalid_reason IS NULL
		)
	AND NOT EXISTS (
		SELECT 1
		FROM drug_concept_stage dcs
		WHERE dcs.concept_code = c.concept_code
			AND dcs.domain_id = c.domain_id
			AND dcs.concept_class_id = c.concept_class_id
			AND dcs.source_concept_class_id = c.concept_class_id
		);

--4.3 Ingredients: Need to check what happens to deprecated
-- Get ingredients from drug_strength
INSERT INTO drug_concept_stage (
	concept_name,
	vocabulary_id,
	concept_class_id,
	standard_concept,
	concept_code,
	possible_excipient,
	domain_id,
	valid_start_date,
	valid_end_date,
	invalid_reason,
	source_concept_class_id
	)
SELECT c.concept_name,
	'Rxfix',
	'Ingredient',
	'S',
	c.concept_code,
	NULL,
	c.domain_id,
	c.valid_start_date,
	c.valid_end_date,
	c.invalid_reason,
	'Ingredient'
FROM concept c
WHERE c.invalid_reason IS NULL
	AND c.vocabulary_id LIKE 'Rx%'
	AND EXISTS (
		SELECT 1
		FROM drug_strength ds
		JOIN concept c_int ON c_int.concept_id = ds.drug_concept_id
			AND c_int.vocabulary_id = 'RxNorm Extension'
		WHERE ds.ingredient_concept_id = c.concept_id
		)
	AND NOT EXISTS (
		SELECT 1
		FROM drug_concept_stage dcs
		WHERE dcs.concept_code = c.concept_code
			AND dcs.domain_id = c.domain_id
			AND dcs.concept_class_id = 'Ingredient'
			AND dcs.source_concept_class_id = 'Ingredient'
		);

--4.4 Get ingredients from hierarchy
INSERT INTO drug_concept_stage (
	concept_name,
	vocabulary_id,
	concept_class_id,
	standard_concept,
	concept_code,
	possible_excipient,
	domain_id,
	valid_start_date,
	valid_end_date,
	invalid_reason,
	source_concept_class_id
	)
SELECT c.concept_name,
	'Rxfix',
	'Ingredient',
	'S',
	c.concept_code,
	NULL,
	c.domain_id,
	c.valid_start_date,
	c.valid_end_date,
	c.invalid_reason,
	'Ingredient'
FROM concept c
WHERE c.concept_class_id = 'Ingredient'
	AND c.vocabulary_id LIKE 'Rx%'
	--add ingredients from ancestor
	AND EXISTS (
		SELECT 1
		FROM concept_ancestor ca
		JOIN concept c_int ON c_int.concept_id = ca.descendant_concept_id
			AND c_int.vocabulary_id = 'RxNorm Extension'
		WHERE ca.ancestor_concept_id = c.concept_id
		)
	AND NOT EXISTS (
		SELECT 1
		FROM drug_concept_stage dcs
		WHERE dcs.concept_code = c.concept_code
			AND dcs.domain_id = c.domain_id
			AND dcs.concept_class_id = 'Ingredient'
			AND dcs.source_concept_class_id = 'Ingredient'
		);

--4.5 Insert Kentucky grass
INSERT INTO drug_concept_stage (
	concept_name,
	vocabulary_id,
	concept_class_id,
	standard_concept,
	concept_code,
	possible_excipient,
	domain_id,
	valid_start_date,
	valid_end_date,
	invalid_reason,
	source_concept_class_id
	)
SELECT c.concept_name,
	'Rxfix',
	'Ingredient',
	'S',
	c.concept_code,
	NULL,
	c.domain_id,
	c.valid_start_date,
	c.valid_end_date,
	c.invalid_reason,
	'Ingredient'
FROM concept c
WHERE c.concept_name IN ('Kentucky bluegrass pollen extract')
	AND c.vocabulary_id = 'RxNorm';

--4.6 Get all Units
INSERT INTO drug_concept_stage (
	concept_name,
	vocabulary_id,
	concept_class_id,
	standard_concept,
	concept_code,
	possible_excipient,
	domain_id,
	valid_start_date,
	valid_end_date,
	invalid_reason,
	source_concept_class_id
	)
SELECT c.concept_name,
	'Rxfix',
	'Unit',
	NULL,
	c.concept_code,
	NULL,
	'Drug',
	c.valid_start_date,
	c.valid_end_date,
	NULL,
	'Unit'
FROM concept c
WHERE c.concept_id IN (
		SELECT ds.units
		FROM (
			SELECT amount_unit_concept_id AS units,
				drug_concept_id
			FROM drug_strength
			WHERE amount_unit_concept_id IS NOT NULL
			
			UNION
			
			SELECT numerator_unit_concept_id AS units,
				drug_concept_id
			FROM drug_strength
			WHERE numerator_unit_concept_id IS NOT NULL
			
			UNION
			
			SELECT denominator_unit_concept_id AS units,
				drug_concept_id
			FROM drug_strength
			WHERE denominator_unit_concept_id IS NOT NULL
			) ds
		JOIN concept c_int ON c_int.concept_id = ds.drug_concept_id
			AND c_int.vocabulary_id = 'RxNorm Extension'
		)

UNION

SELECT c.concept_name,
	'Rxfix',
	'Unit',
	NULL,
	c.concept_code,
	NULL,
	'Drug',
	c.valid_start_date,
	c.valid_end_date,
	NULL,
	'Unit'
FROM concept c
WHERE c.concept_id = 45744815;

--4.7 Get a supplier that hadn't been connected to any drug
INSERT INTO drug_concept_stage (
	concept_name,
	vocabulary_id,
	concept_class_id,
	standard_concept,
	concept_code,
	possible_excipient,
	domain_id,
	valid_start_date,
	valid_end_date,
	invalid_reason,
	source_concept_class_id
	)
SELECT c.concept_name,
	'Rxfix',
	c.concept_class_id,
	NULL,
	c.concept_code,
	NULL,
	c.domain_id,
	c.valid_start_date,
	c.valid_end_date,
	c.invalid_reason,
	c.concept_class_id
FROM concept c
WHERE c.concept_name = 'Hawgreen Ltd'
	AND c.vocabulary_id = 'RxNorm Extension'
	AND NOT EXISTS (
		SELECT 1
		FROM drug_concept_stage dcs
		WHERE dcs.concept_code = c.concept_code
			AND dcs.domain_id = c.domain_id
			AND dcs.concept_class_id = c.concept_class_id
			AND dcs.source_concept_class_id = c.concept_class_id
		);

--5 Remove all where there is less than total of 0.05 mL
DELETE
FROM drug_concept_stage
WHERE concept_code IN (
		SELECT concept_code
		FROM concept c
		JOIN drug_strength ds ON ds.drug_concept_id = c.concept_id
		WHERE c.vocabulary_id = 'RxNorm Extension'
			AND c.invalid_reason IS NULL
			AND ds.denominator_value < 0.05
			AND ds.denominator_unit_concept_id = 8587
		);

--6 delete isopropyl as it is not an ingrediend + drugs containing it
DELETE
FROM drug_concept_stage
WHERE concept_code IN (
		SELECT c.concept_code
		FROM concept_ancestor a
		JOIN concept c ON c.concept_id = descendant_concept_id
			AND ancestor_concept_id = 43563483
		);

DELETE
FROM drug_concept_stage
WHERE concept_code IN (
		'OMOP881482',
		'OMOP341519',
		'OMOP346740',
		'OMOP714610',
		'721654',
		'1021221',
		'317004',
		'1371041',
		'OMOP881524',
		'236340'
		) --apo-trastumab,gas etc.
	OR (
		concept_name ilike '%apotheke%'
		AND concept_class_id = 'Supplier'
		);

/* Remove wrong brand names (need to save for the later clean up)
DELETE
FROM drug_concept_stage
WHERE concept_code IN (
		SELECT dcs.concept_code
		FROM drug_concept_stage dcs
		JOIN concept c ON LOWER(dcs.concept_name) = LOWER(c.concept_name)
			AND c.concept_class_id IN (
				'ATC 5th',
				'ATC 4th',
				'ATC 3rd',
				'AU Substance',
				'AU Qualifier',
				'Chemical Structure',
				'CPT4 Hierarchy',
				'Gemscript',
				'Gemscript THIN',
				'GPI',
				'Ingredient',
				'Substance',
				'LOINC Hierarchy',
				'Main Heading',
				'Organism',
				'Pharma Preparation'
				)
		WHERE dcs.concept_class_id = 'Brand Name'
		
		UNION
		
		SELECT concept_code
		FROM drug_concept_stage
		WHERE concept_class_id = 'Brand Name'
			AND concept_name ~ 'Comp\s|Comp$|Praeparatum'
			AND NOT concept_name ~ 'Ratioph|Zentiva|Actavis|Teva|Hormosan|Dura|Ass|Provas|Rami|Al |Pharma|Abz|-Q|Peritrast|Beloc|Hexal|Corax|Solgar|Winthrop'
		);
*/
--7 filling drug_strength
--just turn drug_strength into ds_stage replacing concept_ids with concept_codes
INSERT INTO ds_stage (
	drug_concept_code,
	ingredient_concept_code,
	box_size,
	amount_value,
	amount_unit,
	numerator_value,
	numerator_unit,
	denominator_value,
	denominator_unit
	)
SELECT drug_concept_code,
	CASE 
		WHEN ingredient_concept_code = '314375'
			THEN '852834' --ALLERGENIC EXTRACT, GRASS, KENTUCKY BLUE
		WHEN ingredient_concept_code = 'OMOP332154'
			THEN '748794' --Inert Ingredients
		WHEN ingredient_concept_code = '314329'
			THEN '1309815' --ALLERGENIC EXTRACT, BIRCH
		WHEN ingredient_concept_code = '1428040'
			THEN '1406' --STYRAX BENZOIN RESIN  
		WHEN ingredient_concept_code = '236340'
			THEN '644634'
		WHEN ingredient_concept_code = '11384'
			THEN 'OMOP418532' --Yeasts
		ELSE ingredient_concept_code
		END,
	box_size,
	amount_value,
	amount_unit,
	numerator_value,
	numerator_unit,
	denominator_value,
	denominator_unit
FROM (
	SELECT c.concept_code AS drug_concept_code,
		c2.concept_code AS ingredient_concept_code,
		ds.box_size,
		CASE 
			WHEN c3.concept_code = 'ug'
				THEN amount_value / 1000
			WHEN c3.concept_code = 'ukat'
				THEN amount_value * 1000000
			WHEN c3.concept_code = '[CCID_50]'
				THEN amount_value * 0.7
			WHEN c3.concept_code = '10*9'
				THEN amount_value * 1000000000
			WHEN c3.concept_code = '10*6'
				THEN amount_value * 1000000
			ELSE amount_value
			END AS amount_value,
		CASE 
			WHEN c3.concept_code = 'ug'
				THEN 'mg'
			WHEN c3.concept_code = 'ukat'
				THEN '[U]'
			WHEN c3.concept_code = '[CCID_50]'
				THEN '[PFU]'
			WHEN c3.concept_code IN (
					'10*9',
					'10*6'
					)
				THEN '{bacteria}'
			ELSE c3.concept_code
			END AS amount_unit,
		CASE 
			WHEN c4.concept_code = 'ug'
				THEN ds.numerator_value / 1000
			WHEN c4.concept_code = '[CCID_50]'
				THEN ds.numerator_value * 0.7
			WHEN c4.concept_code = '10*9'
				THEN ds.numerator_value * 1000000000
			WHEN c4.concept_code = '10*6'
				THEN ds.numerator_value * 1000000
			ELSE ds.numerator_value
			END AS numerator_value,
		CASE 
			WHEN c4.concept_code = 'ug'
				THEN 'mg'
			WHEN c4.concept_code = '[CCID_50]'
				THEN '[PFU]'
			WHEN c4.concept_code IN (
					'10*9',
					'10*6'
					)
				THEN '{bacteria}'
			ELSE c4.concept_code
			END AS numerator_unit,
		ds.denominator_value,
		c5.concept_code AS denominator_unit
	FROM concept c
	JOIN drug_concept_stage dc ON dc.concept_code = c.concept_code
		AND dc.concept_class_id = 'Drug Product'
	JOIN drug_strength ds ON ds.drug_concept_id = c.concept_id
		AND c.vocabulary_id LIKE 'RxNorm%'
		AND c.invalid_reason IS NULL
	JOIN concept c2 ON c2.concept_id = ds.ingredient_concept_id
		AND (
			c2.invalid_reason = 'D'
			OR c2.invalid_reason IS NULL
			)
	LEFT JOIN concept c3 ON c3.concept_id = ds.amount_unit_concept_id
	LEFT JOIN concept c4 ON c4.concept_id = ds.numerator_unit_concept_id
	LEFT JOIN concept c5 ON c5.concept_id = ds.denominator_unit_concept_id
	
	UNION ALL --add fresh concepts
	
	SELECT c1.concept_code,
		lf.concept_code,
		ds.box_size,
		amount_value,
		c3.concept_code,
		ds.numerator_value,
		c4.concept_code,
		ds.denominator_value,
		c5.concept_code
	FROM concept c1
	JOIN drug_strength ds ON c1.concept_id = ds.drug_concept_id
		AND c1.vocabulary_id = 'RxNorm Extension'
		AND c1.invalid_reason IS NULL
	JOIN (
		WITH recursive hierarchy_concepts(ancestor_concept_id, descendant_concept_id, root_ancestor_concept_id, full_path, concept_code) AS (
				SELECT ancestor_concept_id,
					descendant_concept_id,
					ancestor_concept_id AS root_ancestor_concept_id,
					ARRAY [descendant_concept_id] AS full_path,
					concept_code
				FROM concepts
				
				UNION ALL
				
				SELECT c.ancestor_concept_id,
					c.descendant_concept_id,
					root_ancestor_concept_id,
					hc.full_path || c.descendant_concept_id AS full_path,
					c.concept_code
				FROM concepts c
				JOIN hierarchy_concepts hc ON hc.descendant_concept_id = c.ancestor_concept_id
				WHERE c.descendant_concept_id <> ALL (full_path)
				),
			concepts AS (
				SELECT r.concept_id_1 AS ancestor_concept_id,
					r.concept_id_2 AS descendant_concept_id,
					c2.concept_code
				FROM concept_relationship r
				JOIN concept c1 ON c1.concept_id = r.concept_id_1
					AND c1.concept_class_id = 'Ingredient'
					AND c1.vocabulary_id LIKE 'Rx%'
				JOIN concept c2 ON c2.concept_id = r.concept_id_2
					AND c2.concept_class_id = 'Ingredient'
					AND c2.vocabulary_id LIKE 'Rx%'
				WHERE r.relationship_id = 'Concept replaced by'
					AND r.invalid_reason IS NULL
				)
		SELECT hc.root_ancestor_concept_id AS root_concept_id_1,
			hc.concept_code
		FROM hierarchy_concepts hc
		WHERE NOT EXISTS (
				/*same as oracle's CONNECT_BY_ISLEAF*/
				SELECT 1
				FROM hierarchy_concepts hc_int
				WHERE hc_int.ancestor_concept_id = hc.descendant_concept_id
				)
		) lf ON lf.root_concept_id_1 = ds.ingredient_concept_id
	LEFT JOIN concept c3 ON c3.concept_id = ds.amount_unit_concept_id
	LEFT JOIN concept c4 ON c4.concept_id = ds.numerator_unit_concept_id
	LEFT JOIN concept c5 ON c5.concept_id = ds.denominator_unit_concept_id
	) AS s0
WHERE ingredient_concept_code != 'OMOP881482';

--8 Manually add absent units in drug_strength (due to source table issues)
UPDATE ds_stage
SET amount_unit = '[U]'
WHERE ingredient_concept_code = '560'
	AND drug_concept_code IN (
		'OMOP467711',
		'OMOP467709',
		'OMOP467706',
		'OMOP467710',
		'OMOP467715',
		'OMOP467705',
		'OMOP467712',
		'OMOP467708',
		'OMOP467714',
		'OMOP467713'
		);

UPDATE ds_stage
SET amount_value = 25,
	amount_unit = 'mg',
	numerator_value = NULL,
	numerator_unit = NULL
WHERE drug_concept_code IN (
		'OMOP420731',
		'OMOP420834',
		'OMOP420835',
		'OMOP420833'
		)
	AND ingredient_concept_code = '2409';

UPDATE ds_stage
SET amount_value = 100,
	amount_unit = 'mg',
	numerator_value = NULL,
	numerator_unit = NULL
WHERE drug_concept_code IN (
		'OMOP420832',
		'OMOP420835',
		'OMOP420834',
		'OMOP420833'
		)
	AND ingredient_concept_code = '1202';

--9 create consolidated denominator unit for drugs that have soluble and solid ingredients
-- in the same drug (if some drug-ingredient row row has amount, another - nominator)
UPDATE ds_stage ds
SET numerator_value = amount_value,
	numerator_unit = amount_unit,
	amount_unit = NULL,
	amount_value = NULL,
	denominator_unit = 'mL'
WHERE drug_concept_code IN (
		SELECT drug_concept_code
		FROM ds_stage a
		JOIN ds_stage b USING (drug_concept_code)
		WHERE a.amount_value IS NOT NULL
			AND b.numerator_value IS NOT NULL
			AND b.denominator_unit = 'mL'
		)
	AND amount_value IS NOT NULL;

UPDATE ds_stage ds
SET numerator_value = amount_value,
	numerator_unit = amount_unit,
	amount_unit = NULL,
	amount_value = NULL,
	denominator_unit = 'mg'
WHERE drug_concept_code IN (
		SELECT drug_concept_code
		FROM ds_stage a
		JOIN ds_stage b USING (drug_concept_code)
		WHERE a.amount_value IS NOT NULL
			AND b.numerator_value IS NOT NULL
			AND b.denominator_unit = 'mg'
		)
	AND amount_value IS NOT NULL;

--10 update different denominator units
UPDATE ds_stage ds
SET denominator_value = d.cx
FROM (
	SELECT DISTINCT a.drug_concept_code,
		substring(c.concept_name, '^(\d+(\.\d+)?)')::FLOAT AS cx -- choose denominator from the Name
	FROM ds_stage a
	JOIN ds_stage b ON b.drug_concept_code = a.drug_concept_code
	JOIN concept_stage c ON c.concept_code = a.drug_concept_code
		AND c.vocabulary_id = 'RxNorm Extension'
	WHERE a.denominator_value != b.denominator_value
	) d
WHERE d.drug_concept_code = ds.drug_concept_code;

--11 Fix solid forms with denominator
UPDATE ds_stage
SET amount_unit = numerator_unit,
	amount_value = numerator_value,
	numerator_value = NULL,
	numerator_unit = NULL,
	denominator_value = NULL,
	denominator_unit = NULL
WHERE drug_concept_code IN (
		SELECT a.concept_code
		FROM concept a
		JOIN drug_strength d ON concept_id = drug_concept_id
			AND denominator_unit_concept_id IS NOT NULL
			AND (
				concept_name LIKE '%Tablet%'
				OR concept_name LIKE '%Capsule%'
				) -- solid forms defined by their forms
			AND vocabulary_id = 'RxNorm Extension'
		);

--12 Put percent into the numerator, not amount
UPDATE ds_stage
SET numerator_unit = amount_unit,
	numerator_value = amount_value,
	amount_value = NULL,
	amount_unit = NULL
WHERE amount_unit = '%';

--13 Fixes of various ill-defined drugs violating with RxNorm editorial policies 
UPDATE ds_stage
SET numerator_value = 25
WHERE drug_concept_code IN (
		'OMOP303266',
		'OMOP303267',
		'OMOP303268'
		);

UPDATE ds_stage
SET numerator_value = 1
WHERE drug_concept_code IN (
		'OMOP317478',
		'OMOP317479',
		'OMOP317480'
		);

UPDATE ds_stage
SET numerator_value = 10000,
	denominator_unit = 'mL'
WHERE INGREDIENT_concept_code = '8536'
	AND drug_concept_code IN (
		'OMOP420658',
		'OMOP420659',
		'OMOP420660',
		'OMOP420661'
		);

--14 Change %/actuat into mg/mL
UPDATE ds_stage
SET numerator_value = numerator_value * 10,
	numerator_unit = 'mg',
	denominator_value = NULL,
	denominator_unit = 'mL'
WHERE denominator_unit = '{actuat}'
	AND numerator_unit = '%';

-- Manual fixes with strange % values
UPDATE ds_stage
SET numerator_value = 100,
	denominator_value = NULL,
	denominator_unit = NULL
WHERE numerator_unit = '%'
	AND numerator_value IN (
		0.000283,
		0.1,
		35.3
		);

--15 Do all sorts of manual fixes
--15.1 Fentanyl buccal film
-- amount_value instead of numerator_value
UPDATE ds_stage
SET amount_value = numerator_value,
	amount_unit = numerator_unit,
	denominator_value = NULL,
	denominator_unit = NULL,
	numerator_unit = NULL,
	numerator_value = NULL
WHERE drug_concept_code IN (
		SELECT drug_concept_code
		FROM ds_stage a
		JOIN drug_concept_stage b ON a.drug_concept_code = b.concept_code
		WHERE coalesce(a.amount_unit, a.numerator_unit) IN (
				'cm',
				'mm'
				)
			OR (
				a.denominator_unit IN (
					'cm',
					'mm'
					)
				AND (
					b.concept_name LIKE '%Buccal Film%'
					OR b.concept_name LIKE '%Breakyl Start%'
					OR a.numerator_value IN (
						0.808,
						1.21,
						1.62
						)
					)
				)
		);

--15.2 Add denominator to trandermal patch
-- manualy defined dosages
UPDATE ds_stage
SET numerator_value = 0.012,
	denominator_value = NULL,
	denominator_unit = 'h',
	amount_unit = NULL,
	amount_value = NULL,
	numerator_unit = 'mg'
WHERE drug_concept_code IN (
		SELECT drug_concept_code
		FROM ds_stage a
		JOIN drug_concept_stage b ON a.drug_concept_code = b.concept_code
		--also found like 0.4*5.25 cm=2.1 mg=0.012/h 
		WHERE b.concept_name LIKE '%Fentanyl%Transdermal%'
			AND a.amount_value IN (
				2.55,
				2.1,
				2.5,
				0.4,
				1.38
				)
		);

UPDATE ds_stage
SET numerator_value = 0.025,
	denominator_value = NULL,
	denominator_unit = 'h',
	amount_unit = NULL,
	amount_value = NULL,
	numerator_unit = 'mg'
WHERE drug_concept_code IN (
		SELECT drug_concept_code
		FROM ds_stage a
		JOIN drug_concept_stage b ON a.drug_concept_code = b.concept_code
		WHERE b.concept_name LIKE '%Fentanyl%Transdermal%'
			AND a.amount_value IN (
				0.275,
				2.75,
				3.72,
				4.2,
				5.1,
				0.6,
				0.319,
				0.25,
				5,
				4.8
				)
		);

UPDATE ds_stage
SET numerator_value = 0.05,
	denominator_value = NULL,
	denominator_unit = 'h',
	amount_unit = NULL,
	amount_value = NULL,
	numerator_unit = 'mg'
WHERE drug_concept_code IN (
		SELECT drug_concept_code
		FROM ds_stage a
		JOIN drug_concept_stage b ON a.drug_concept_code = b.concept_code
		WHERE b.concept_name LIKE '%Fentanyl%Transdermal%'
			AND a.amount_value IN (
				5.5,
				10.2,
				7.5,
				8.25,
				8.4,
				0.875,
				9.6,
				14.4,
				15.5
				)
		);

UPDATE ds_stage
SET numerator_value = 0.075,
	denominator_value = NULL,
	denominator_unit = 'h',
	amount_unit = NULL,
	amount_value = NULL,
	numerator_unit = 'mg'
WHERE drug_concept_code IN (
		SELECT drug_concept_code
		FROM ds_stage a
		JOIN drug_concept_stage b ON a.drug_concept_code = b.concept_code
		WHERE b.concept_name LIKE '%Fentanyl%Transdermal%'
			AND a.amount_value IN (
				12.6,
				15.3,
				12.4,
				19.2,
				23.1
				)
		);

UPDATE ds_stage
SET numerator_value = 0.1,
	denominator_value = NULL,
	denominator_unit = 'h',
	amount_unit = NULL,
	amount_value = NULL,
	numerator_unit = 'mg'
WHERE drug_concept_code IN (
		SELECT drug_concept_code
		FROM ds_stage a
		JOIN drug_concept_stage b ON a.drug_concept_code = b.concept_code
		WHERE b.concept_name LIKE '%Fentanyl%Transdermal%'
			AND a.amount_value IN (
				16.8,
				10,
				11,
				20.4,
				16.5
				)
		);

--15.3 Fentanyl topical
UPDATE ds_stage
SET numerator_value = 0.012,
	denominator_value = NULL,
	denominator_unit = 'h'
WHERE drug_concept_code IN (
		SELECT drug_concept_code
		FROM ds_stage a
		JOIN drug_concept_stage b ON a.drug_concept_code = b.concept_code
		--also found like 0.4*5.25 cm=2.1 mg=0.012/h
		WHERE coalesce(a.amount_unit, a.numerator_unit) IN (
				'cm',
				'mm'
				)
			OR (
				a.denominator_unit IN (
					'cm',
					'mm'
					)
				AND b.concept_name LIKE '%Fentanyl%'
				AND a.numerator_value IN (
					2.55,
					2.1,
					2.5,
					0.4
					)
				)
		);

UPDATE ds_stage
SET numerator_value = 0.025,
	denominator_value = NULL,
	denominator_unit = 'h'
WHERE drug_concept_code IN (
		SELECT drug_concept_code
		FROM ds_stage a
		JOIN drug_concept_stage b ON a.drug_concept_code = b.concept_code
		WHERE coalesce(a.amount_unit, a.numerator_unit) IN (
				'cm',
				'mm'
				)
			OR (
				a.denominator_unit IN (
					'cm',
					'mm'
					)
				AND b.concept_name LIKE '%Fentanyl%'
				AND a.numerator_value IN (
					0.275,
					2.75,
					3.72,
					4.2,
					5.1,
					0.6,
					0.319,
					0.25,
					5
					)
				)
		);

UPDATE ds_stage
SET numerator_value = 0.05,
	denominator_value = NULL,
	denominator_unit = 'h'
WHERE drug_concept_code IN (
		SELECT drug_concept_code
		FROM ds_stage a
		JOIN drug_concept_stage b ON a.drug_concept_code = b.concept_code
		WHERE coalesce(a.amount_unit, a.numerator_unit) IN (
				'cm',
				'mm'
				)
			OR (
				a.denominator_unit IN (
					'cm',
					'mm'
					)
				AND b.concept_name LIKE '%Fentanyl%'
				AND a.numerator_value IN (
					5.5,
					10.2,
					7.5,
					8.25,
					8.4,
					0.875
					)
				)
		);

UPDATE ds_stage
SET numerator_value = 0.075,
	denominator_value = NULL,
	denominator_unit = 'h'
WHERE drug_concept_code IN (
		SELECT drug_concept_code
		FROM ds_stage a
		JOIN drug_concept_stage b ON a.drug_concept_code = b.concept_code
		WHERE coalesce(a.amount_unit, a.numerator_unit) IN (
				'cm',
				'mm'
				)
			OR (
				a.denominator_unit IN (
					'cm',
					'mm'
					)
				AND b.concept_name LIKE '%Fentanyl%'
				AND a.numerator_value IN (
					12.6,
					15.3
					)
				)
		);

UPDATE ds_stage
SET numerator_value = 0.1,
	denominator_value = NULL,
	denominator_unit = 'h'
WHERE drug_concept_code IN (
		SELECT drug_concept_code
		FROM ds_stage a
		JOIN drug_concept_stage b ON a.drug_concept_code = b.concept_code
		WHERE coalesce(a.amount_unit, a.numerator_unit) IN (
				'cm',
				'mm'
				)
			OR (
				a.denominator_unit IN (
					'cm',
					'mm'
					)
				AND b.concept_name LIKE '%Fentanyl%'
				AND a.numerator_value IN (
					16.8,
					10,
					11,
					20.4
					)
				)
		);

--15.4 rivastigmine
UPDATE ds_stage
SET numerator_value = 13.3,
	denominator_value = 24,
	denominator_unit = 'h'
WHERE drug_concept_code IN (
		SELECT drug_concept_code
		FROM ds_stage a
		JOIN drug_concept_stage b ON a.drug_concept_code = b.concept_code
		WHERE coalesce(a.amount_unit, a.numerator_unit) IN (
				'cm',
				'mm'
				)
			OR (
				a.denominator_unit IN (
					'cm',
					'mm'
					)
				AND b.concept_name LIKE '%rivastigmine%'
				AND a.numerator_value = 27
				)
		);

UPDATE ds_stage
SET numerator_value = CASE 
		WHEN denominator_value IS NULL
			THEN numerator_value * 24
		ELSE numerator_value / denominator_value * 24
		END,
	denominator_value = 24,
	denominator_unit = 'h'
WHERE drug_concept_code IN (
		SELECT drug_concept_code
		FROM ds_stage a
		JOIN drug_concept_stage b ON a.drug_concept_code = b.concept_code
		WHERE coalesce(amount_unit, numerator_unit) IN (
				'cm',
				'mm'
				)
			OR (
				denominator_unit IN (
					'cm',
					'mm'
					)
				AND b.concept_name LIKE '%rivastigmine%'
				)
		);

--15.5 nicotine
UPDATE ds_stage
SET numerator_value = CASE 
		WHEN denominator_value IS NULL
			THEN numerator_value * 16
		ELSE numerator_value / denominator_value * 16
		END,
	denominator_value = 16,
	denominator_unit = 'h'
WHERE drug_concept_code IN (
		SELECT drug_concept_code
		FROM ds_stage a
		JOIN drug_concept_stage b ON a.drug_concept_code = b.concept_code
		WHERE coalesce(a.amount_unit, a.numerator_unit) IN (
				'cm',
				'mm'
				)
			OR (
				a.denominator_unit IN (
					'cm',
					'mm'
					)
				AND b.concept_name LIKE '%Nicotine%'
				AND numerator_value IN (
					0.625,
					0.938,
					1.56,
					35.2
					)
				)
		);

UPDATE ds_stage
SET numerator_value = 14,
	denominator_value = 24,
	denominator_unit = 'h'
WHERE drug_concept_code IN (
		SELECT drug_concept_code
		FROM ds_stage a
		JOIN drug_concept_stage b ON a.drug_concept_code = b.concept_code
		WHERE coalesce(a.amount_unit, a.numerator_unit) IN (
				'cm',
				'mm'
				)
			OR (
				a.denominator_unit IN (
					'cm',
					'mm'
					)
				AND b.concept_name LIKE '%Nicotine%'
				AND a.numerator_value IN (
					5.57,
					5.14,
					36,
					78
					)
				)
		);

--15.6 Povidone-Iodine
UPDATE ds_stage
SET numerator_value = 100,
	denominator_value = NULL,
	denominator_unit = 'mL'
WHERE drug_concept_code IN (
		SELECT drug_concept_code
		FROM ds_stage a
		JOIN drug_concept_stage b ON a.drug_concept_code = b.concept_code
		WHERE coalesce(a.amount_unit, a.numerator_unit) IN (
				'cm',
				'mm'
				)
			OR (
				a.denominator_unit IN (
					'cm',
					'mm'
					)
				AND b.concept_name LIKE '%Povidone-Iodine%'
				)
		);

UPDATE ds_stage
SET numerator_value = 1.4,
	numerator_unit = 'mg',
	denominator_value = NULL
WHERE drug_concept_code IN (
		SELECT drug_concept_code
		FROM ds_stage a
		JOIN drug_concept_stage b ON a.drug_concept_code = b.concept_code
		WHERE (
				(
					a.numerator_value IS NOT NULL
					AND a.numerator_unit IS NULL
					)
				OR (
					a.denominator_value IS NOT NULL
					AND a.denominator_unit IS NULL
					)
				OR (
					a.amount_value IS NOT NULL
					AND a.amount_unit IS NULL
					)
				)
			AND b.concept_name LIKE '%Aprotinin 10000 /ML%'
		);

--15.7 update wrong dosages in Varicella Virus Vaccine
UPDATE ds_stage
SET numerator_unit = '[U]',
	numerator_value = 29800
WHERE drug_concept_code IN (
		SELECT drug_concept_code
		FROM ds_stage a
		JOIN drug_concept_stage ds ON a.drug_concept_code = ds.concept_code
		WHERE ds.concept_name LIKE '%Varicella Virus Vaccine Live (Oka-Merck) strain 29800 /ML%'
		);

--15.8 update wrong dosages in alpha-amylase
UPDATE ds_stage
SET numerator_unit = '[U]'
WHERE drug_concept_code IN (
		SELECT drug_concept_code
		FROM ds_stage a
		JOIN drug_concept_stage ds ON a.drug_concept_code = ds.concept_code
		WHERE (
				(
					a.numerator_value IS NOT NULL
					AND a.numerator_unit IS NULL
					)
				OR (
					a.denominator_value IS NOT NULL
					AND a.denominator_unit IS NULL
					)
				OR (
					a.amount_value IS NOT NULL
					AND a.amount_unit IS NULL
					)
				)
			AND ds.concept_name LIKE '%alpha-amylase 200 /ML%'
		);

--15.9 delete drugs that are missing units. delete drugs from DCS to remove them totally
DELETE
FROM drug_concept_stage
WHERE concept_code IN (
		SELECT drug_concept_code
		FROM ds_stage
		WHERE (
				numerator_value IS NOT NULL
				AND numerator_unit IS NULL
				)
			OR (
				denominator_value IS NOT NULL
				AND denominator_unit IS NULL
				)
			OR (
				amount_value IS NOT NULL
				AND amount_unit IS NULL
				)
		);

--15.10 delete drugs that are missing units
DELETE
FROM ds_stage
WHERE (
		numerator_value IS NOT NULL
		AND numerator_unit IS NULL
		)
	OR (
		denominator_value IS NOT NULL
		AND denominator_unit IS NULL
		)
	OR (
		amount_value IS NOT NULL
		AND amount_unit IS NULL
		);

--15.11 working on drugs that presented in way of mL/mL
UPDATE ds_stage
SET numerator_unit = 'mg'
WHERE drug_concept_code IN (
		SELECT drug_concept_code
		FROM ds_stage
		JOIN drug_concept_stage ON drug_concept_code = concept_code
			AND concept_name LIKE '%Paclitaxel%'
			AND numerator_unit = 'mL'
			AND denominator_unit = 'mL'
		);

UPDATE ds_stage
SET numerator_unit = 'mg',
	numerator_value = CASE 
		WHEN denominator_value IS NOT NULL
			THEN denominator_value * 1000
		ELSE 1
		END
WHERE drug_concept_code IN (
		SELECT drug_concept_code
		FROM ds_stage
		JOIN drug_concept_stage ON drug_concept_code = concept_code
			AND concept_name LIKE '%Water%'
			AND numerator_unit = 'mL'
			AND denominator_unit = 'mL'
		);

--15.12 cromolyn Inhalation powder change to 5mg/actuat
UPDATE ds_stage
SET numerator_value = amount_value,
	numerator_unit = amount_unit,
	denominator_unit = '{actuat}',
	amount_value = NULL,
	amount_unit = NULL
WHERE drug_concept_code IN (
		'OMOP391197',
		'OMOP391198',
		'OMOP391199'
		);

--15.13 update all the gases
UPDATE ds_stage
SET numerator_unit = '%',
	numerator_value = '95',
	denominator_unit = NULL,
	denominator_value = NULL
WHERE drug_concept_code IN (
		SELECT concept_code
		FROM drug_concept_stage
		JOIN ds_stage ON concept_code = drug_concept_code
		WHERE concept_name ~ 'Oxygen\s((950 MG/ML)|(0.95 MG/MG)|(950 MG/MG)|(950000 MG/ML)|(950000000 MG/ML))'
		)
	AND ingredient_concept_code = '7806'
	AND numerator_unit != '%';

UPDATE ds_stage
SET numerator_unit = '%',
	numerator_value = '5',
	denominator_unit = NULL,
	denominator_value = NULL
WHERE drug_concept_code IN (
		SELECT concept_code
		FROM drug_concept_stage
		JOIN ds_stage ON concept_code = drug_concept_code
		WHERE concept_name ~ 'Carbon Dioxide\s((50 MG/)|(0.05 MG/MG)|(50000 MG/ML)|(50000000 MG/ML))'
		)
	AND ingredient_concept_code = '2034'
	AND numerator_unit != '%';

UPDATE ds_stage
SET numerator_unit = '%',
	numerator_value = '50',
	denominator_unit = NULL,
	denominator_value = NULL
WHERE drug_concept_code IN (
		SELECT concept_code
		FROM drug_concept_stage
		JOIN ds_stage ON concept_code = drug_concept_code
		WHERE concept_name ~ '(Nitrous Oxide|Oxygen|Carbon Dioxide)\s((500 MG/.*ML)|(500000000 MG/.*ML)|(270 MG/.*ML)|(500000 MG/ML)|(500 MG/MG)|(0.00025 ML/ML))'
			AND numerator_unit != '%'
		);

UPDATE ds_stage
SET numerator_unit = '%',
	numerator_value = '79',
	denominator_unit = NULL,
	denominator_value = NULL
WHERE drug_concept_code IN (
		SELECT concept_code
		FROM drug_concept_stage
		JOIN ds_stage ON concept_code = drug_concept_code
		WHERE concept_name LIKE '%Helium%79%MG/%'
		)
	AND ingredient_concept_code = '5140'
	AND numerator_unit != '%';

UPDATE ds_stage
SET numerator_unit = '%',
	numerator_value = '21',
	denominator_unit = NULL,
	denominator_value = NULL
WHERE drug_concept_code IN (
		SELECT concept_code
		FROM drug_concept_stage
		JOIN ds_stage ON concept_code = drug_concept_code
		WHERE concept_name LIKE '%Oxygen%21%MG/%'
		)
	AND ingredient_concept_code = '7806'
	AND numerator_unit != '%';

UPDATE ds_stage
SET numerator_unit = '%',
	numerator_value = CASE 
		WHEN numerator_unit = 'mg'
			AND denominator_unit = 'mL'
			THEN numerator_value / coalesce(denominator_value, 1) * 0.1
		WHEN numerator_value / coalesce(denominator_value, 1) < 0.09
			THEN numerator_value / coalesce(denominator_value, 1) * 1000
		ELSE numerator_value / coalesce(denominator_value, 1) * 100
		END,
	denominator_unit = NULL,
	denominator_value = NULL
WHERE drug_concept_code IN (
		SELECT concept_code
		FROM drug_concept_stage
		JOIN ds_stage ON concept_code = drug_concept_code
		WHERE concept_name ~ '((Nitrous Oxide)|(Xenon)|(Isoflurane)|(Oxygen)) (\d+\.)?(\d+\s((MG/MG)|(ML/ML)))'
			AND numerator_unit != '%'
		);

--15.14 aprotinin
UPDATE ds_stage
SET numerator_unit = '[U]'
WHERE ingredient_concept_code = '1056'
	AND numerator_unit IS NULL
	AND numerator_value IS NOT NULL;

--15.5 zinc and calcium c/ml
UPDATE ds_stage
SET numerator_unit = 'mmol'
WHERE ingredient_concept_code = '1901'
	AND numerator_unit = '[hp_C]';

UPDATE ds_stage
SET numerator_unit = 'mg',
	numerator_value = numerator_value / 10
WHERE ingredient_concept_code = '39954'
	AND numerator_unit = '[hp_C]';

--16 Delete 3 legged dogs
DELETE
FROM ds_stage
WHERE drug_concept_code IN (
		WITH a AS (
				SELECT drug_concept_id,
					COUNT(drug_concept_id) AS cnt1
				FROM drug_strength
				GROUP BY drug_concept_id
				),
			b AS (
				SELECT descendant_concept_id,
					COUNT(descendant_concept_id) AS cnt2
				FROM concept_ancestor a
				JOIN concept b ON ancestor_concept_id = b.concept_id
					AND concept_class_id = 'Ingredient'
					AND b.vocabulary_id LIKE 'RxNorm%'
				JOIN concept b2 ON descendant_concept_id = b2.concept_id
					AND b2.concept_class_id NOT LIKE '%Comp%'
					AND b2.concept_name LIKE '% / %'
				GROUP BY descendant_concept_id
				)
		SELECT concept_code
		FROM a
		JOIN b ON a.drug_concept_id = b.descendant_concept_id
		JOIN concept c ON drug_concept_id = concept_id
		WHERE cnt1 < cnt2
			AND cnt1 = (
				SELECT length(c.concept_name) - coalesce(length(replace(c.concept_name, ' / ', '')), 0)
				) --emulating regexp_count
			AND c.vocabulary_id != 'RxNorm'
		);

--17 Remove those with less than 0.05 ml in denominator. Delete those drugs from DCS to remove them totally
DELETE
FROM drug_concept_stage
WHERE concept_code IN (
		SELECT drug_concept_code
		FROM ds_stage
		WHERE denominator_value < 0.05
			AND denominator_unit = 'mL'
		);

--17.1 Remove those with less than 0.05 ml in denominator
DELETE
FROM ds_stage
WHERE drug_concept_code IN (
		SELECT drug_concept_code
		FROM ds_stage
		WHERE denominator_value < 0.05
			AND denominator_unit = 'mL'
		);

--18 Fix all the enormous dosages that we can
UPDATE ds_stage
SET numerator_value = '100'
WHERE drug_concept_code IN (
		SELECT concept_code
		FROM drug_concept_stage
		WHERE concept_name LIKE '%Hydrocortisone 140%'
		);

UPDATE ds_stage
SET numerator_value = '20'
WHERE drug_concept_code IN (
		SELECT concept_code
		FROM drug_concept_stage
		WHERE concept_name LIKE '%Benzocaine 120 %'
		);

UPDATE ds_stage
SET numerator_value = numerator_value / 10
WHERE drug_concept_code IN (
		SELECT concept_code
		FROM ds_stage a
		JOIN drug_concept_stage ds ON a.drug_concept_code = ds.concept_code
		WHERE concept_name LIKE '%Albumin Human, USP%'
			AND numerator_value / coalesce(denominator_value, 1) > 1000
		);

UPDATE ds_stage
SET numerator_value = numerator_value / 1000000
WHERE drug_concept_code IN (
		SELECT concept_code
		FROM ds_stage a
		JOIN drug_concept_stage ds ON a.drug_concept_code = ds.concept_code
		WHERE concept_name ~ 'Glucose (100000000|200000000|40000000|50000000)|Gelatin 40000000|Bupivacaine|Fentanyl|sodium citrate|(Glucose 50000000 MG/ML  Injectable Solution)|(Glucose 50000000 MG/ML / Potassium Chloride 1500000 MG/ML)|Potassium Cloride (75000000|4500000|30000000|2000000|1500000)|Sodium|Peracetic acid'
			AND numerator_value / coalesce(denominator_value, 1) > 10000
		);

UPDATE ds_stage
SET numerator_value = numerator_value / 100000
WHERE drug_concept_code IN (
		SELECT concept_code
		FROM ds_stage a
		JOIN drug_concept_stage ds ON a.drug_concept_code = ds.concept_code
		WHERE concept_name ~ '(Morphine (1000000|2000000))|Sorbitol|Mannitol'
			AND numerator_value / coalesce(denominator_value, 1) > 1000
		);

UPDATE ds_stage
SET denominator_unit = 'mL'
WHERE drug_concept_code IN (
		SELECT drug_concept_code
		FROM ds_stage
		JOIN drug_concept_stage ON drug_concept_code = concept_code
		WHERE numerator_unit = 'mg'
			AND denominator_unit = 'mg'
			AND numerator_value / coalesce(denominator_value, 1) > 1
		);

--19 Delete drugs with cm in denominator that we weren't able to fix
DELETE
FROM ds_stage
WHERE drug_concept_code IN (
		SELECT drug_concept_code
		FROM ds_stage a
		JOIN drug_concept_stage b ON a.drug_concept_code = b.concept_code
		WHERE coalesce(amount_unit, numerator_unit) IN (
				'cm',
				'mm'
				)
			OR denominator_unit IN (
				'cm',
				'mm'
				)
		);

--20 Delete combination drugs where denominators don't match
DELETE
FROM ds_stage
WHERE (
		drug_concept_code,
		denominator_value
		) IN (
		SELECT a.drug_concept_code,
			a.denominator_value
		FROM ds_stage a
		JOIN ds_stage b ON a.drug_concept_code = b.drug_concept_code
			AND (
				a.denominator_value IS NULL
				AND b.denominator_value IS NOT NULL
				OR a.denominator_value != b.denominator_value
				OR a.denominator_unit != b.denominator_unit
				)
		JOIN drug_concept_stage ds ON ds.concept_code = a.drug_concept_code
			AND a.denominator_value != substring(ds.concept_name, '(\d+(\.\d+)?)')::FLOAT
		);

--20.1 move homeopathy to numerator
UPDATE ds_stage
SET numerator_value = amount_value,
	numerator_unit = amount_unit,
	amount_value = NULL,
	amount_unit = NULL
WHERE drug_concept_code IN (
		SELECT drug_concept_code
		FROM ds_stage
		WHERE amount_unit IN (
				'[hp_C]',
				'[hp_X]'
				)
		);

--21 Delete impossible dosages. Delete those drugs from DCS to remove them totally
DELETE
FROM drug_concept_stage
WHERE concept_code IN (
		SELECT drug_concept_code
		FROM ds_stage
		WHERE (
				(
					(
						LOWER(numerator_unit) = 'mg'
						AND LOWER(denominator_unit) IN (
							'ml',
							'g'
							)
						)
					OR (
						LOWER(numerator_unit) = 'g'
						AND LOWER(denominator_unit) = 'l'
						)
					)
				AND numerator_value / coalesce(denominator_value, 1) > 1000
				)
			OR (
				LOWER(numerator_unit) = 'g'
				AND LOWER(denominator_unit) = 'ml'
				AND numerator_value / coalesce(denominator_value, 1) > 1
				)
			OR (
				LOWER(numerator_unit) = 'mg'
				AND LOWER(denominator_unit) = 'mg'
				AND numerator_value / coalesce(denominator_value, 1) > 1
				)
			OR (
				(
					amount_unit = '%'
					AND amount_value > 100
					)
				OR (
					numerator_unit = '%'
					AND numerator_value > 100
					)
				)
			OR (
				numerator_unit = '%'
				AND denominator_unit IS NOT NULL
				)
		);

--21.1 Delete impossible dosages
DELETE
FROM ds_stage
WHERE drug_concept_code IN (
		SELECT drug_concept_code
		FROM ds_stage
		WHERE (
				(
					(
						LOWER(numerator_unit) = 'mg'
						AND LOWER(denominator_unit) IN (
							'ml',
							'g'
							)
						)
					OR (
						LOWER(numerator_unit) = 'g'
						AND LOWER(denominator_unit) = 'l'
						)
					)
				AND numerator_value / coalesce(denominator_value, 1) > 1000
				)
			OR (
				LOWER(numerator_unit) = 'g'
				AND LOWER(denominator_unit) = 'ml'
				AND numerator_value / coalesce(denominator_value, 1) > 1
				)
			OR (
				LOWER(numerator_unit) = 'mg'
				AND LOWER(denominator_unit) = 'mg'
				AND numerator_value / coalesce(denominator_value, 1) > 1
				)
			OR (
				(
					amount_unit = '%'
					AND amount_value > 100
					)
				OR (
					numerator_unit = '%'
					AND numerator_value > 100
					)
				)
			OR (
				numerator_unit = '%'
				AND denominator_unit IS NOT NULL
				)
		);

UPDATE ds_stage
SET amount_unit = NULL
WHERE amount_unit IS NOT NULL
	AND amount_value IS NULL;

UPDATE ds_stage
SET numerator_unit = NULL
WHERE numerator_unit IS NOT NULL
	AND numerator_value IS NULL;

DELETE
FROM ds_stage
WHERE amount_unit IS NULL
	AND numerator_unit IS NULL
	AND denominator_unit IS NULL;

TRUNCATE TABLE internal_relationship_stage;
--22 Build internal_relationship_stage 
--Drug to form
INSERT INTO internal_relationship_stage
SELECT DISTINCT dc.concept_code,
	CASE 
		WHEN c2.concept_code = 'OMOP881524'
			THEN '316975' --Rectal Creame and Rectal Cream
		WHEN c2.concept_code = '1021221'
			THEN '316999' --Gas and Gas for Inhalation
		ELSE c2.concept_code
		END AS concept_code_2
FROM drug_concept_stage dc
JOIN concept c ON c.concept_code = dc.concept_code
	AND c.vocabulary_id LIKE 'RxNorm%'
	AND dc.concept_class_id = 'Drug Product'
JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id
	AND cr.relationship_id = 'RxNorm has dose form'
	AND cr.invalid_reason IS NULL
JOIN concept c2 ON c2.concept_id = cr.concept_id_2
	AND c2.concept_class_id = 'Dose Form'
	AND c2.vocabulary_id LIKE 'Rx%'
	AND c2.invalid_reason IS NULL;
	--where c.concept_name ~ c2.concept_name --Problem with Transdermal patch/system

 --Drug to BN
CREATE INDEX idx_irs_cc ON internal_relationship_stage (
	concept_code_1,
	concept_code_2
	);
ANALYZE internal_relationship_stage;

INSERT INTO internal_relationship_stage
SELECT DISTINCT dc.concept_code,
	c2.concept_code
FROM drug_concept_stage dc
JOIN concept c ON c.concept_code = dc.concept_code
	AND c.vocabulary_id LIKE 'RxNorm%'
JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id
	AND cr.relationship_id = 'Has brand name'
	AND cr.invalid_reason IS NULL
JOIN concept c2 ON concept_id_2 = c2.concept_id
	AND c2.concept_class_id = 'Brand Name'
	AND c2.vocabulary_id LIKE 'Rx%'
	AND c.concept_name ILIKE '%' || c2.concept_name || '%'
	AND c2.invalid_reason IS NULL
WHERE dc.concept_class_id = 'Drug Product'
	AND (
		dc.source_concept_class_id NOT LIKE '%Pack%'
		OR (
			dc.source_concept_class_id = 'Marketed Product'
			AND dc.concept_name NOT LIKE '%Pack%'
			)
		)
	AND NOT EXISTS (
		SELECT 1
		FROM internal_relationship_stage irs_int
		WHERE irs_int.concept_code_1 = dc.concept_code
			AND irs_int.concept_code_2 = c2.concept_code
		);
ANALYZE internal_relationship_stage;


 --Packs to BN
INSERT INTO internal_relationship_stage
SELECT DISTINCT l.concept_code_1,
	l.concept_code_2
FROM (
	WITH t AS (
			SELECT dc.concept_code AS concept_code_1,
				c2.concept_code AS concept_code_2,
				c2.concept_name AS concept_name_2,
				c.concept_name AS concept_name_1
			FROM drug_concept_stage dc
			JOIN concept c ON c.concept_code = dc.concept_code
				AND c.vocabulary_id = 'RxNorm Extension'
				AND dc.concept_class_id = 'Drug Product'
				AND dc.concept_name LIKE '%Pack%[%]%'
			JOIN concept_relationship cr ON c.concept_id = concept_id_1
				AND cr.relationship_id = 'Has brand name'
				AND cr.invalid_reason IS NULL
			JOIN concept c2 ON concept_id_2 = c2.concept_id
				AND c2.concept_class_id = 'Brand Name'
				AND c2.vocabulary_id LIKE 'Rx%'
				AND c2.invalid_reason IS NULL
			)
	SELECT concept_code_1,
		concept_code_2
	FROM t
	WHERE concept_name_2 = REGEXP_REPLACE(concept_name_1, '.* Pack .*\[(.*)\]', '\1')
	) l
WHERE NOT EXISTS (
		SELECT 1
		FROM internal_relationship_stage irs_int
		WHERE irs_int.concept_code_1 = l.concept_code_1
			AND irs_int.concept_code_2 = l.concept_code_2
		);

--drug to ingredient
INSERT INTO internal_relationship_stage
SELECT DISTINCT ds.drug_concept_code,
	ds.ingredient_concept_code
FROM ds_stage ds
WHERE NOT EXISTS (
		SELECT 1
		FROM internal_relationship_stage irs_int
		WHERE irs_int.concept_code_1 = ds.drug_concept_code
			AND irs_int.concept_code_2 = ds.ingredient_concept_code
		);
ANALYZE internal_relationship_stage;

--Drug Form to ingredient
CREATE INDEX idx_dcs_cc ON drug_concept_stage (concept_code);
ANALYZE drug_concept_stage;

INSERT INTO internal_relationship_stage
SELECT DISTINCT c.concept_code,
	CASE 
		WHEN c2.concept_code = '11384'
			THEN 'OMOP418532' --Yeasts
		ELSE c2.concept_code
		END
FROM concept c
JOIN drug_concept_stage dc ON dc.concept_code = c.concept_code
	AND c.vocabulary_id LIKE 'RxNorm%'
	AND c.invalid_reason IS NULL
JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id
	AND cr.relationship_id = 'RxNorm has ing'
	AND cr.invalid_reason IS NULL
JOIN concept c2 ON c2.concept_id = cr.concept_id_2
	AND c2.concept_class_id = 'Ingredient'
	AND c2.invalid_reason IS NULL
WHERE c.concept_class_id IN (
		'Clinical Drug Form',
		'Branded Drug Form'
		)
	AND NOT EXISTS (
		SELECT 1
		FROM internal_relationship_stage irs_int
		JOIN drug_concept_stage dcs ON dcs.concept_code = irs_int.concept_code_2
		WHERE irs_int.concept_code_1 = c.concept_code
			AND dcs.concept_class_id = 'Ingredient'
		)
	AND c2.concept_code NOT IN (
		'1371041',
		'OMOP881482'
		);

INSERT INTO internal_relationship_stage (
	concept_code_1,
	concept_code_2
	)
SELECT DISTINCT dc.concept_code,
	CASE 
		WHEN ds.ingredient_concept_code = '11384'
			THEN 'OMOP418532'
		ELSE ds.ingredient_concept_code
		END
FROM concept c
JOIN drug_concept_stage dc ON dc.concept_code = c.concept_code
	AND c.vocabulary_id LIKE 'RxNorm%'
	AND c.invalid_reason IS NULL
	AND c.concept_class_id IN (
		'Clinical Drug Form',
		'Branded Drug Form'
		)
JOIN concept_relationship cr ON concept_id_1 = c.concept_id
	AND cr.invalid_reason IS NULL
JOIN concept c2 ON c2.concept_id = concept_id_2
	AND c.vocabulary_id LIKE 'RxNorm%'
	AND c2.invalid_reason IS NULL
JOIN ds_stage ds ON c2.concept_code = drug_concept_code
WHERE NOT EXISTS (
		SELECT 1
		FROM internal_relationship_stage irs_int
		JOIN drug_concept_stage dcs ON dcs.concept_code = irs_int.concept_code_2
		WHERE irs_int.concept_code_1 = dc.concept_code
			AND dcs.concept_class_id = 'Ingredient'
		)
	AND ds.ingredient_concept_code NOT IN (
		'1371041',
		'OMOP881482'
		);
ANALYZE internal_relationship_stage;

--add all kinds of missing ingredients
DROP TABLE IF EXISTS ing_temp;
CREATE TABLE ing_temp AS
SELECT DISTINCT c.concept_code AS concept_code_1,
	c.concept_name AS concept_name_1,
	c.concept_class_id AS cci1,
	cr2.relationship_id,
	c2.concept_code,
	c2.concept_name,
	c2.concept_class_id
FROM concept c
JOIN drug_concept_stage dc ON dc.concept_code = c.concept_code
	AND c.vocabulary_id LIKE 'RxNorm%'
	AND c.invalid_reason IS NULL
	AND dc.concept_class_id = 'Drug Product'
	AND dc.source_concept_class_id NOT LIKE '%Pack%'
	AND dc.concept_name NOT LIKE '%Pack%'
JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id
	AND cr.invalid_reason IS NULL
JOIN concept_relationship cr2 ON cr2.concept_id_1 = cr.concept_id_2
	AND cr2.invalid_reason IS NULL
	AND cr2.relationship_id IN (
		'Brand name of',
		'RxNorm has ing'
		)
JOIN concept c2 ON c2.concept_id = cr2.concept_id_2
	AND c2.concept_class_id = 'Ingredient'
	AND c2.invalid_reason IS NULL
WHERE NOT EXISTS (
		SELECT 1
		FROM internal_relationship_stage irs_int
		JOIN drug_concept_stage dcs ON dcs.concept_code = irs_int.concept_code_2
		WHERE irs_int.concept_code_1 = c.concept_code
			AND dcs.concept_class_id = 'Ingredient'
		)
	AND c.concept_name ilike '%' || c2.concept_name || '%'
	AND c2.concept_code NOT IN (
		'1371041',
		'OMOP881482'
		);

--ing_temp_2
DROP TABLE IF EXISTS ing_temp_2;
CREATE TABLE ing_temp_2 AS
SELECT c.concept_code_1,
	c.concept_code
FROM (
	SELECT concept_code_1,
		concept_code
	--Aspirin / Aspirin / Caffeine Oral Tablet [Mipyrin]
	FROM ing_temp
	WHERE concept_code_1 IN (
			SELECT i.concept_code_1
			FROM ing_temp i
			JOIN (
				SELECT COUNT(concept_code) OVER (PARTITION BY concept_code_1) AS cnt,
					concept_code_1
				FROM (
					SELECT DISTINCT concept_code_1,
						concept_name_1,
						concept_code,
						concept_name
					FROM ing_temp
					) AS s0
				ORDER BY concept_code
				) a ON i.concept_code_1 = a.concept_code_1
				AND (
					SELECT length(concept_name_1) - coalesce(length(replace(concept_name_1, ' / ', '')), 0)
					) + 1 != a.cnt
				AND (
					concept_name_1 LIKE '%...%'
					OR REGEXP_REPLACE(substring(concept_name_1, '( / \w+(\s\w+)?)'), ' / ', '', 'g') iLIKE '%' || concept_name || '%'
					AND substring(concept_name_1, '(\w+(\s\w+)?)') iLIKE '%' || concept_name || '%'
					)
			)
	
	UNION
	
	SELECT i.concept_code_1,
		concept_code
	FROM ing_temp i
	JOIN (
		SELECT COUNT(concept_code) OVER (PARTITION BY concept_code_1) AS cnt,
			concept_code_1
		FROM (
			SELECT DISTINCT concept_code_1,
				concept_name_1,
				concept_code,
				concept_name
			FROM ing_temp
			) AS s1
		ORDER BY concept_code
		) a ON i.concept_code_1 = a.concept_code_1
	WHERE (
			SELECT length(concept_name_1) - coalesce(length(replace(concept_name_1, ' / ', '')), 0)
			) + 1 = a.cnt
	) c
WHERE NOT EXISTS (
		SELECT 1
		FROM internal_relationship_stage irs_int
		JOIN drug_concept_stage dcs ON dcs.concept_code = irs_int.concept_code_2
		WHERE irs_int.concept_code_1 = c.concept_code_1
			AND dcs.concept_class_id = 'Ingredient'
		);

INSERT INTO internal_relationship_stage (
	concept_code_1,
	concept_code_2
	)
SELECT concept_code_1,
	concept_code
FROM ing_temp_2;

INSERT INTO internal_relationship_stage (
	concept_code_1,
	concept_code_2
	)
SELECT DISTINCT dc.concept_code,
	CASE 
		WHEN c2.concept_code = '11384'
			THEN 'OMOP418532'
		ELSE c2.concept_code
		END
FROM drug_concept_stage dc
JOIN concept c ON dc.concept_code = c.concept_code
	AND c.vocabulary_id LIKE 'RxNorm%'
	AND c.invalid_reason IS NULL
	AND dc.concept_class_id = 'Drug Product'
	AND dc.source_concept_class_id NOT LIKE '%Pack%'
	AND dc.concept_name NOT LIKE '%Pack%'
JOIN concept_ancestor ca ON descendant_concept_id = c.concept_id
JOIN concept c2 ON ancestor_concept_id = c2.concept_id
	AND c2.concept_class_id = 'Ingredient'
WHERE NOT EXISTS (
		SELECT 1
		FROM internal_relationship_stage irs_int
		JOIN drug_concept_stage dcs ON dcs.concept_code = irs_int.concept_code_2
		WHERE irs_int.concept_code_1 = dc.concept_code
			AND dcs.concept_class_id = 'Ingredient'
		)
	AND c.concept_name iLIKE '%' || c2.concept_name || '%'
	AND c2.concept_code NOT IN (
		'1371041',
		'OMOP881482'
		);

--Drug to supplier
INSERT INTO internal_relationship_stage
SELECT DISTINCT dc.concept_code,
	c2.concept_code
FROM drug_concept_stage dc
JOIN concept c ON c.concept_code = dc.concept_code
	AND c.vocabulary_id = 'RxNorm Extension'
JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id
	AND cr.invalid_reason IS NULL
JOIN concept c2 ON concept_id_2 = c2.concept_id
	AND c2.concept_class_id = 'Supplier'
	AND c2.vocabulary_id LIKE 'Rx%'
	AND c2.invalid_reason IS NULL
WHERE dc.concept_class_id = 'Drug Product'
	AND NOT EXISTS (
		SELECT 1
		FROM internal_relationship_stage irs_int
		WHERE irs_int.concept_code_1 = dc.concept_code
			AND irs_int.concept_code_2 = c2.concept_code
		);

ANALYZE internal_relationship_stage;

--insert relationships to those packs that do not have Pack's BN
INSERT INTO internal_relationship_stage
SELECT DISTINCT c.concept_code,
	c3.concept_code
FROM concept c
LEFT JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id
	AND cr.relationship_id = 'Has brand name'
	AND cr.invalid_reason IS NULL
LEFT JOIN concept c2 ON c2.concept_id = cr.concept_id_2
	AND c2.concept_class_id = 'Brand Name'
-- take it from name
LEFT JOIN concept c3 ON c3.concept_name = REGEXP_REPLACE(c.concept_name, '.* Pack .*\[(.*)\]', '\1')
	AND c3.vocabulary_id LIKE 'RxNorm%'
	AND c3.concept_class_id = 'Brand Name'
	AND c3.invalid_reason IS NULL
WHERE c.vocabulary_id = 'RxNorm Extension'
	AND c.concept_class_id LIKE '%Branded%Pack%'
	AND c2.concept_id IS NULL
	AND NOT EXISTS (
		SELECT 1
		FROM internal_relationship_stage irs_int
		WHERE irs_int.concept_code_1 = c.concept_code
			AND irs_int.concept_code_2 = c3.concept_code
		);

--add fresh concepts
INSERT INTO internal_relationship_stage
/*
	  we need DISTINCT because some concepts theoretically  might have one replacement concept
	  e.g. 
	  A some_relatonship_1 B
	  A some_relatonship_2 C
	  but B and C have 'Concept replaced by' on D
	  result: two rows A - D
	  */
SELECT DISTINCT c1.concept_code,
	lf.concept_code
FROM concept c1
JOIN concept_relationship cr ON c1.concept_id = cr.concept_id_1
	AND c1.vocabulary_id = 'RxNorm Extension'
	AND c1.invalid_reason IS NULL
	AND cr.relationship_id NOT IN (
		'Concept replaced by',
		'Concept replaces'
		)
JOIN (
	WITH recursive hierarchy_concepts(ancestor_concept_id, descendant_concept_id, root_ancestor_concept_id, full_path, concept_code) AS (
			SELECT ancestor_concept_id,
				descendant_concept_id,
				ancestor_concept_id AS root_ancestor_concept_id,
				ARRAY [descendant_concept_id] AS full_path,
				concept_code
			FROM concepts
			
			UNION ALL
			
			SELECT c.ancestor_concept_id,
				c.descendant_concept_id,
				root_ancestor_concept_id,
				hc.full_path || c.descendant_concept_id AS full_path,
				c.concept_code
			FROM concepts c
			JOIN hierarchy_concepts hc ON hc.descendant_concept_id = c.ancestor_concept_id
			WHERE c.descendant_concept_id <> ALL (full_path)
			),
		concepts AS (
			SELECT r.concept_id_1 AS ancestor_concept_id,
				r.concept_id_2 AS descendant_concept_id,
				c2.concept_code
			FROM concept_relationship r
			JOIN concept c1 ON c1.concept_id = r.concept_id_1
				AND c1.concept_class_id IN (
					'Dose Form',
					'Brand Name',
					'Supplier',
					'Ingredient'
					)
				AND c1.vocabulary_id LIKE 'Rx%'
			JOIN concept c2 ON c2.concept_id = r.concept_id_2
				AND c2.concept_class_id IN (
					'Dose Form',
					'Brand Name',
					'Supplier',
					'Ingredient'
					)
				AND c2.vocabulary_id LIKE 'Rx%'
			WHERE r.relationship_id = 'Concept replaced by'
				AND r.invalid_reason IS NULL
			)
	SELECT hc.root_ancestor_concept_id AS root_concept_id_1,
		hc.descendant_concept_id AS concept_id_2,
		hc.concept_code
	FROM hierarchy_concepts hc
	WHERE NOT EXISTS (
			/*same as oracle's CONNECT_BY_ISLEAF*/
			SELECT 1
			FROM hierarchy_concepts hc_int
			WHERE hc_int.ancestor_concept_id = hc.descendant_concept_id
			)
	) lf ON lf.root_concept_id_1 = cr.concept_id_2
WHERE c1.concept_code <> lf.concept_code --we don't want duplicates like A - A (A 'Mapped from' B, but B have 'Concept replaced by' A -> so we have A - A in IRS)
	AND NOT EXISTS (
		SELECT 1
		FROM internal_relationship_stage irs_int
		WHERE irs_int.concept_code_1 = c1.concept_code
			AND irs_int.concept_code_2 = lf.concept_code
		);

--23.1 Add all the attributes which relationships are missing in basic tables (separate query to speed up)
INSERT INTO internal_relationship_stage
--missing bn
WITH t AS (
		SELECT DISTINCT dc.concept_code,
			c.concept_name
		FROM drug_concept_stage dc
		JOIN concept c ON c.concept_code = dc.concept_code
			AND c.vocabulary_id = 'RxNorm Extension'
		WHERE dc.concept_class_id = 'Drug Product'
			AND dc.concept_name LIKE '%Pack%[%]%'
		)
SELECT DISTINCT t.concept_code,
	dc2.concept_code
FROM t
JOIN concept dc2 ON dc2.concept_name = REGEXP_REPLACE(t.concept_name, '.* Pack .*\[(.*)\]', '\1')
	AND dc2.concept_class_id = 'Brand Name'
	AND dc2.vocabulary_id LIKE 'Rx%'
	AND dc2.invalid_reason IS NULL
--WHERE  t.concept_code NOT IN (SELECT concept_code_1 FROM internal_relationship_stage irs_int JOIN drug_concept_stage dcs_int ON dcs_int.concept_code=irs_int.concept_code_2 AND dcs_int.concept_class_id = 'Brand Name' );
WHERE NOT EXISTS (
		SELECT 1
		FROM internal_relationship_stage irs_int
		WHERE irs_int.concept_code_1 = t.concept_code
			AND irs_int.concept_code_2 = dc2.concept_code
		);

INSERT INTO internal_relationship_stage
--missing bn
WITH t AS (
		SELECT DISTINCT dc.concept_code,
			c.concept_name
		FROM drug_concept_stage dc
		JOIN concept c ON c.concept_code = dc.concept_code
			AND c.vocabulary_id = 'RxNorm Extension'
		WHERE dc.concept_class_id = 'Drug Product'
			AND dc.concept_name LIKE '%Pack%[%]%'
		)
SELECT DISTINCT t.concept_code,
	dc2.concept_code
FROM t
JOIN concept dc2 ON dc2.concept_name = substring(t.concept_name, '.*\[(.*)\]')
	AND dc2.concept_class_id = 'Brand Name'
	AND dc2.vocabulary_id LIKE 'Rx%'
	AND dc2.invalid_reason IS NULL
--WHERE  t.concept_code NOT IN (SELECT concept_code_1 FROM internal_relationship_stage irs_int JOIN drug_concept_stage dcs_int ON dcs_int.concept_code=irs_int.concept_code_2 AND dcs_int.concept_class_id = 'Brand Name' );
WHERE NOT EXISTS (
		SELECT 1
		FROM internal_relationship_stage irs_int
		WHERE irs_int.concept_code_1 = t.concept_code
			AND irs_int.concept_code_2 = dc2.concept_code
		);

INSERT INTO drug_concept_stage (
	concept_name,
	domain_id,
	vocabulary_id,
	source_concept_class_id,
	concept_class_id,
	standard_concept,
	concept_code,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT DISTINCT concept_name,
	domain_id,
	'Rxfix',
	concept_class_id,
	concept_class_id,
	standard_concept,
	concept_code,
	valid_start_date,
	valid_end_date,
	invalid_reason
FROM internal_relationship_stage a
JOIN concept c ON c.concept_code = concept_code_2
	AND c.vocabulary_id LIKE 'Rx%'
WHERE concept_code_2 NOT IN (
		SELECT concept_code
		FROM drug_concept_stage
		)
	AND concept_code_2 NOT IN (
		'721654',
		'317004',
		'OMOP881524'
		) --unneccesary DF
	;

--24.1 Add missing suppliers
CREATE INDEX idx_dcs_cn ON drug_concept_stage USING GIN (concept_name devv5.gin_trgm_ops);
ANALYZE drug_concept_stage;

INSERT INTO internal_relationship_stage
SELECT DISTINCT dc.concept_code,
	dc2.concept_code
FROM drug_concept_stage dc
JOIN drug_concept_stage dc2 ON dc.concept_name iLIKE '% ' || dc2.concept_name
	AND dc2.concept_class_id = 'Supplier'
WHERE dc.source_concept_class_id = 'Marketed Product'
	AND NOT EXISTS (
		SELECT 1
		FROM internal_relationship_stage irs_int
		WHERE irs_int.concept_code_1 = dc.concept_code
			AND irs_int.concept_code_2 = dc2.concept_code
		);


--24.2 Fix suppliers like Baxter and Baxter ltd
DELETE
FROM internal_relationship_stage
WHERE (
		concept_code_1,
		concept_code_2
		) IN (
		SELECT b2.concept_code_1,
			b2.concept_code_2
		FROM (
			SELECT concept_code_1
			FROM internal_relationship_stage a
			JOIN drug_concept_stage b ON concept_code = concept_code_2
			WHERE b.concept_class_id = 'Supplier'
			GROUP BY concept_code_1,
				b.concept_class_id
			HAVING COUNT(*) > 1
			) a
		JOIN internal_relationship_stage b ON b.concept_code_1 = a.concept_code_1
		JOIN internal_relationship_stage b2 ON b2.concept_code_1 = b.concept_code_1
			AND b.concept_code_2 != b2.concept_code_2
		JOIN drug_concept_stage c ON c.concept_code = b.concept_code_2
			AND c.concept_class_id = 'Supplier'
		JOIN drug_concept_stage c2 ON c2.concept_code = b2.concept_code_2
			AND c2.concept_class_id = 'Supplier'
		WHERE LENGTH(c.concept_name) < LENGTH(c2.concept_name)
		);


--24.3 Cromolyn Inhalation powder
INSERT INTO internal_relationship_stage (concept_code_1,concept_code_2) VALUES ('OMOP391197','317000');
INSERT INTO internal_relationship_stage (concept_code_1,concept_code_2) VALUES ('OMOP391198','317000');
INSERT INTO internal_relationship_stage (concept_code_1,concept_code_2) VALUES ('OMOP391199','317000');
INSERT INTO internal_relationship_stage (concept_code_1,concept_code_2) VALUES ('OMOP391019','317000');
INSERT INTO internal_relationship_stage (concept_code_1,concept_code_2) VALUES ('OMOP391020','317000');

--24.4 Manually add missing ingredients

INSERT INTO  internal_relationship_stage  (concept_code_1,concept_code_2) VALUES ('OMOP418619','10582');
INSERT INTO  internal_relationship_stage  (concept_code_1,concept_code_2) VALUES ('OMOP420104','7994');
INSERT INTO  internal_relationship_stage  (concept_code_1,concept_code_2) VALUES ('OMOP417742','6313');
INSERT INTO  internal_relationship_stage  (concept_code_1,concept_code_2) VALUES ('OMOP417551','5666');
INSERT INTO  internal_relationship_stage  (concept_code_1,concept_code_2) VALUES ('OMOP412170','4141');
INSERT INTO  internal_relationship_stage  (concept_code_1,concept_code_2) VALUES ('OMOP421199','105695');
INSERT INTO  internal_relationship_stage  (concept_code_1,concept_code_2) VALUES ('OMOP421200','105695');
INSERT INTO  internal_relationship_stage  (concept_code_1,concept_code_2) VALUES ('OMOP421053','854930');
INSERT INTO  internal_relationship_stage  (concept_code_1,concept_code_2) VALUES ('OMOP299955','5333');
INSERT INTO  internal_relationship_stage  (concept_code_1,concept_code_2) VALUES ('OMOP419715','3616');

--25 delete multiple relationships to attributes
--25.1 define concept_1, concept_2 pairs need to be deleted
DELETE
FROM internal_relationship_stage
WHERE (
		concept_code_1,
		concept_code_2
		) IN (
		SELECT concept_code_1,
			concept_code_2
		FROM internal_relationship_stage a
		JOIN drug_concept_stage b ON a.concept_code_2 = b.concept_code
			AND b.concept_class_id IN ('Supplier')
		JOIN drug_concept_stage c ON c.concept_code = a.concept_code_1
		WHERE a.concept_code_1 IN (
				SELECT a_int.concept_code_1
				FROM internal_relationship_stage a_int
				JOIN drug_concept_stage b ON b.concept_code = a_int.concept_code_2
				WHERE b.concept_class_id IN ('Supplier')
				GROUP BY a_int.concept_code_1,
					b.concept_class_id
				HAVING COUNT(*) > 1
				)
			--Attribute is not a part of a name
			AND (
				c.concept_name NOT ILIKE '%' || b.concept_name || '%'
				OR substring(c.concept_name, 'Pack\s.*') NOT LIKE '%' || b.concept_name || '%'
				)
		);

DELETE
FROM internal_relationship_stage
WHERE (
		concept_code_1,
		concept_code_2
		) IN (
		SELECT concept_code_1,
			concept_code_2
		FROM internal_relationship_stage a
		JOIN drug_concept_stage b ON a.concept_code_2 = b.concept_code
			AND b.concept_class_id IN ('Dose Form')
		JOIN drug_concept_stage c ON c.concept_code = a.concept_code_1
		WHERE a.concept_code_1 IN (
				SELECT a_int.concept_code_1
				FROM internal_relationship_stage a_int
				JOIN drug_concept_stage b ON b.concept_code = a_int.concept_code_2
				WHERE b.concept_class_id IN ('Dose Form')
				GROUP BY a_int.concept_code_1,
					b.concept_class_id
				HAVING COUNT(*) > 1
				)
			--Attribute is not a part of a name
			AND (
				c.concept_name NOT iLIKE '%' || b.concept_name || '%'
				OR substring(c.concept_name, 'Pack\s.*') NOT LIKE '%' || b.concept_name || '%'
				)
		);

DELETE
FROM internal_relationship_stage
WHERE (
		concept_code_1,
		concept_code_2
		) IN (
		SELECT concept_code_1,
			concept_code_2
		FROM internal_relationship_stage a
		JOIN drug_concept_stage b ON a.concept_code_2 = b.concept_code
			AND b.concept_class_id IN ('Brand Name')
		JOIN drug_concept_stage c ON c.concept_code = a.concept_code_1
		WHERE a.concept_code_1 IN (
				SELECT a_int.concept_code_1
				FROM internal_relationship_stage a_int
				JOIN drug_concept_stage b ON b.concept_code = a_int.concept_code_2
				WHERE b.concept_class_id IN ('Brand Name')
				GROUP BY a_int.concept_code_1,
					b.concept_class_id
				HAVING COUNT(*) > 1
				)
			--Attribute is not a part of a name
			AND (
				c.concept_name NOT iLIKE '%' || b.concept_name || '%'
				OR substring(c.concept_name, 'Pack\s.*') NOT LIKE '%' || b.concept_name || '%'
				)
		);

--25.2 delete 2 brand names that don't fit the rule as the brand name of the pack looks like the brand name of component (e.g. [Risedronate] and [Risedronate EC])
DELETE
FROM internal_relationship_stage
WHERE concept_code_1 IN (
		'OMOP572812',
		'OMOP573077',
		'OMOP573035',
		'OMOP573066',
		'OMOP573376'
		)
	AND concept_code_2 IN (
		'OMOP571371',
		'OMOP569970'
		);

--the same logic but manually
DELETE
FROM internal_relationship_stage
WHERE concept_code_1 = 'OMOP339638'
	AND concept_code_2 = 'OMOP332839';

DELETE
FROM internal_relationship_stage
WHERE concept_code_1 = 'OMOP339724'
	AND concept_code_2 = 'OMOP332839';

DELETE
FROM internal_relationship_stage
WHERE concept_code_1 = 'OMOP339776'
	AND concept_code_2 = 'OMOP334564';

DELETE
FROM internal_relationship_stage
WHERE concept_code_1 = 'OMOP339838'
	AND concept_code_2 = 'OMOP336023';

DELETE
FROM internal_relationship_stage
WHERE concept_code_1 = 'OMOP339891'
	AND concept_code_2 = '220105';

DELETE
FROM internal_relationship_stage
WHERE concept_code_1 = 'OMOP340161'
	AND concept_code_2 = 'OMOP336023';

--25.3 delete precise ingredients
DELETE
FROM internal_relationship_stage
WHERE concept_code_2 IN (
		'236340',
		'1371041',
		'721654',
		'317004',
		'OMOP881524'
		);--unnecessary DF

--25.4 add missing relationship to dose form
INSERT INTO internal_relationship_stage (
	concept_code_1,
	concept_code_2
	)
SELECT dc.concept_code,
	CASE 
		WHEN dc.concept_name LIKE '%Prefilled Syringe%'
			THEN '721656'
		WHEN dc.concept_name LIKE '%Injection%'
			THEN '1649574'
		WHEN dc.concept_name LIKE '%Injectable Solution%'
			OR dc.concept_name LIKE '%Solution for injection%'
			THEN '316949'
		WHEN dc.concept_name LIKE '%Topical Solution%'
			THEN '316986'
		WHEN dc.concept_name LIKE '%Liquid%'
			THEN '19082170'
		WHEN dc.concept_name LIKE '%Powder%'
			THEN '346289'
		ELSE NULL
		END
FROM drug_concept_stage dc
WHERE dc.concept_class_id = 'Drug Product'
	AND dc.source_concept_class_id NOT LIKE '%Comp%'
	AND dc.concept_name NOT LIKE '% Pack %'
	AND dc.source_concept_class_id NOT LIKE '%Pack%'
	AND dc.concept_code NOT IN (
		SELECT concept_code_1
		FROM internal_relationship_stage
		JOIN drug_concept_stage ON concept_code_2 = concept_code
			AND concept_class_id = 'Dose Form'
		);

--need to check ing_temp_1
DELETE
FROM internal_relationship_stage i
WHERE EXISTS (
		SELECT 1
		FROM internal_relationship_stage i_int
		WHERE coalesce(i_int.concept_code_1, '-1') = coalesce(i.concept_code_1, '-1')
			AND coalesce(i_int.concept_code_2, '-1') = coalesce(i.concept_code_2, '-1')
			AND i_int.ctid > i.ctid
		);

DELETE
FROM drug_concept_stage
WHERE concept_class_id = 'Drug Product'
	AND concept_name NOT LIKE '%Pack%'
	AND concept_code NOT IN (
		SELECT concept_code_1
		FROM internal_relationship_stage
		JOIN drug_concept_stage ON concept_code_2 = concept_code
			AND concept_class_id = 'Ingredient'
		);

--26 just take it from the pack_content
INSERT INTO pc_stage (
	pack_concept_code,
	drug_concept_code,
	amount,
	box_size
	)
SELECT c.concept_code,
	c2.concept_code,
	pc.amount,
	pc.box_size
FROM pack_content pc
JOIN concept c ON c.concept_id = pc.pack_concept_id
	AND c.vocabulary_id = 'RxNorm Extension'
JOIN concept c2 ON c2.concept_id = pc.drug_concept_id;

--26.1 fix 2 equal components manualy
DELETE FROM pc_stage WHERE
	( pack_concept_code = 'OMOP339574' AND   drug_concept_code = '197659' AND   amount = 12)
	OR ( pack_concept_code = 'OMOP339579' AND   drug_concept_code = '311704' AND   amount IS NULL)
	OR ( pack_concept_code = 'OMOP339579' AND   drug_concept_code = '317128' AND   amount IS NULL)
	OR ( pack_concept_code = 'OMOP339728' AND   drug_concept_code = '1363273'AND   amount = 7)
	OR ( pack_concept_code = 'OMOP339876' AND   drug_concept_code = '864686' AND   amount IS NULL)
	OR ( pack_concept_code = 'OMOP339876' AND   drug_concept_code = '1117531' AND   amount IS NULL)
	OR ( pack_concept_code = 'OMOP339900' AND   drug_concept_code = '392651' AND   amount IS NULL)
	OR ( pack_concept_code = 'OMOP339900' AND   drug_concept_code = '197662' AND   amount IS NULL)
	OR ( pack_concept_code = 'OMOP339913' AND   drug_concept_code = '199797' AND   amount IS NULL)
	OR ( pack_concept_code = 'OMOP339913' AND   drug_concept_code = '199796' AND   amount IS NULL)
	OR ( pack_concept_code = 'OMOP340051' AND   drug_concept_code = '1363273' AND   amount = 7)
	OR ( pack_concept_code = 'OMOP340128' AND   drug_concept_code = '197659' AND   amount = 12)
	OR ( pack_concept_code = 'OMOP339633' AND   drug_concept_code = '310463' AND   amount = 5)
	OR ( pack_concept_code = 'OMOP339814' AND   drug_concept_code = '310463' AND   amount = 5)
	OR ( pack_concept_code = 'OMOP339886' AND   drug_concept_code = '312309' AND   amount = 6)
	OR ( pack_concept_code = 'OMOP339886' AND   drug_concept_code = '312308' AND   amount = 109)
	OR ( pack_concept_code = 'OMOP339895' AND   drug_concept_code = '312309' AND   amount = 6)
	OR ( pack_concept_code = 'OMOP339895' AND   drug_concept_code = '312308' AND   amount = 109);

UPDATE pc_stage
SET amount = 12
WHERE pack_concept_code = 'OMOP339633'
	AND drug_concept_code = '310463'
	AND amount = 7;

UPDATE pc_stage
SET amount = 12
WHERE pack_concept_code = 'OMOP339814'
	AND drug_concept_code = '310463'
	AND amount = 7;

--27 insert missing packs (only those that have => 2 components) - take them from the source tables
--27.1 AMT
INSERT INTO pc_stage (
	pack_concept_code,
	drug_concept_code,
	amount,
	box_size
	)
SELECT DISTINCT ac.concept_code,
	ac2.concept_code,
	pcs.amount,
	pcs.box_size
FROM dev_amt.pc_stage pcs
JOIN concept c ON c.concept_code = pcs.pack_concept_code
	AND c.vocabulary_id = 'AMT'
	AND c.invalid_reason IS NULL
JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id
	AND cr.relationship_id = 'Maps to'
	AND cr.invalid_reason IS NULL
JOIN concept ac ON ac.concept_id = cr.concept_id_2
	AND ac.vocabulary_id = 'RxNorm Extension'
	AND ac.invalid_reason IS NULL
JOIN concept c2 ON c2.concept_code = pcs.drug_concept_code
	AND c2.vocabulary_id = 'AMT'
	AND c2.invalid_reason IS NULL
JOIN concept_relationship cr2 ON cr2.concept_id_1 = c2.concept_id
	AND cr2.relationship_id = 'Maps to'
	AND cr2.invalid_reason IS NULL
JOIN concept ac2 ON ac2.concept_id = cr2.concept_id_2
	AND ac2.vocabulary_id LIKE 'RxNorm%'
	AND ac2.invalid_reason IS NULL
WHERE c.concept_id NOT IN (
		SELECT pack_concept_id
		FROM pack_content
		)
	AND c.concept_id IN (
		SELECT c.concept_id
		FROM dev_amt.pc_stage pcs
		JOIN concept c ON c.concept_code = pcs.pack_concept_code
			AND c.vocabulary_id = 'AMT'
			AND c.invalid_reason IS NULL
		JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id
			AND cr.relationship_id = 'Maps to'
			AND cr.invalid_reason IS NULL
		JOIN concept ac ON ac.concept_id = cr.concept_id_2
			AND ac.vocabulary_id = 'RxNorm Extension'
			AND ac.invalid_reason IS NULL
		JOIN concept c2 ON c2.concept_code = pcs.drug_concept_code
			AND c2.vocabulary_id = 'AMT'
			AND c2.invalid_reason IS NULL
		JOIN concept_relationship cr2 ON cr2.concept_id_1 = c2.concept_id
			AND cr2.relationship_id = 'Maps to'
			AND cr2.invalid_reason IS NULL
		JOIN concept ac2 ON ac2.concept_id = cr2.concept_id_2
			AND ac2.vocabulary_id LIKE 'RxNorm%'
		WHERE c.concept_id NOT IN (
				SELECT pack_concept_id
				FROM pack_content
				)
		GROUP BY c.concept_id
		HAVING COUNT(c.concept_id) > 1
		)
	AND ac.concept_code NOT IN (
		SELECT pack_concept_code
		FROM pc_stage
		);

--27.2 AMIS
INSERT INTO pc_stage (
	pack_concept_code,
	drug_concept_code,
	amount,
	box_size
	)
SELECT DISTINCT ac.concept_code,
	ac2.concept_code,
	pcs.amount,
	pcs.box_size
FROM dev_amis.pc_stage pcs
JOIN concept c ON c.concept_code = pcs.pack_concept_code
	AND c.vocabulary_id = 'AMIS'
	AND c.invalid_reason IS NULL
JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id
	AND cr.relationship_id = 'Maps to'
	AND cr.invalid_reason IS NULL
JOIN concept ac ON ac.concept_id = cr.concept_id_2
	AND ac.vocabulary_id = 'RxNorm Extension'
	AND ac.invalid_reason IS NULL
JOIN concept c2 ON c2.concept_code = pcs.drug_concept_code
	AND c2.vocabulary_id = 'AMIS'
	AND c2.invalid_reason IS NULL
JOIN concept_relationship cr2 ON cr2.concept_id_1 = c2.concept_id
	AND cr2.relationship_id = 'Maps to'
	AND cr2.invalid_reason IS NULL
JOIN concept ac2 ON ac2.concept_id = cr2.concept_id_2
	AND ac2.vocabulary_id LIKE 'RxNorm%'
	AND ac2.invalid_reason IS NULL
WHERE c.concept_id NOT IN (
		SELECT pack_concept_id
		FROM pack_content
		)
	AND c.concept_id IN (
		SELECT c.concept_id
		FROM dev_amis.pc_stage pcs
		JOIN concept c ON c.concept_code = pcs.pack_concept_code
			AND c.vocabulary_id = 'AMIS'
			AND c.invalid_reason IS NULL
		JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id
			AND cr.relationship_id = 'Maps to'
			AND cr.invalid_reason IS NULL
		JOIN concept ac ON ac.concept_id = cr.concept_id_2
			AND ac.vocabulary_id = 'RxNorm Extension'
			AND ac.invalid_reason IS NULL
		JOIN concept c2 ON c2.concept_code = pcs.drug_concept_code
			AND c2.vocabulary_id = 'AMIS'
		JOIN concept_relationship cr2 ON cr2.concept_id_1 = c2.concept_id
			AND cr2.relationship_id = 'Maps to'
			AND cr2.invalid_reason IS NULL
		JOIN concept ac2 ON ac2.concept_id = cr2.concept_id_2
			AND ac2.vocabulary_id LIKE 'RxNorm%'
		WHERE c.concept_id NOT IN (
				SELECT pack_concept_id
				FROM pack_content
				)
		GROUP BY c.concept_id
		HAVING COUNT(c.concept_id) > 1
		)
	AND ac.concept_code NOT IN (
		SELECT pack_concept_code
		FROM pc_stage
		);

--27.3 BDPM
INSERT INTO pc_stage (
	pack_concept_code,
	drug_concept_code,
	amount,
	box_size
	)
SELECT DISTINCT ac.concept_code,
	ac2.concept_code,
	pcs.amount,
	pcs.box_size
FROM dev_bdpm.pc_stage pcs
JOIN concept c ON c.concept_code = pcs.pack_concept_code
	AND c.vocabulary_id = 'BDPM'
	AND c.invalid_reason IS NULL
JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id
	AND cr.relationship_id = 'Maps to'
	AND cr.invalid_reason IS NULL
JOIN concept ac ON ac.concept_id = cr.concept_id_2
	AND ac.vocabulary_id = 'RxNorm Extension'
	AND ac.invalid_reason IS NULL
JOIN concept c2 ON c2.concept_code = pcs.drug_concept_code
	AND c2.vocabulary_id = 'BDPM'
	AND c2.invalid_reason IS NULL
JOIN concept_relationship cr2 ON cr2.concept_id_1 = c2.concept_id
	AND cr2.relationship_id = 'Maps to'
	AND cr2.invalid_reason IS NULL
JOIN concept ac2 ON ac2.concept_id = cr2.concept_id_2
	AND ac2.vocabulary_id LIKE 'RxNorm%'
	AND ac2.invalid_reason IS NULL
WHERE c.concept_id NOT IN (
		SELECT pack_concept_id
		FROM pack_content
		)
	AND c.concept_id IN (
		SELECT c.concept_id
		FROM dev_bdpm.pc_stage pcs
		JOIN concept c ON c.concept_code = pcs.pack_concept_code
			AND c.vocabulary_id = 'BDPM'
			AND c.invalid_reason IS NULL
		JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id
			AND cr.relationship_id = 'Maps to'
			AND cr.invalid_reason IS NULL
		JOIN concept ac ON ac.concept_id = cr.concept_id_2
			AND ac.vocabulary_id = 'RxNorm Extension'
			AND ac.invalid_reason IS NULL
		JOIN concept c2 ON c2.concept_code = pcs.drug_concept_code
			AND c2.vocabulary_id = 'BDPM'
		JOIN concept_relationship cr2 ON cr2.concept_id_1 = c2.concept_id
			AND cr2.relationship_id = 'Maps to'
			AND cr2.invalid_reason IS NULL
		JOIN concept ac2 ON ac2.concept_id = cr2.concept_id_2
			AND ac2.vocabulary_id LIKE 'RxNorm%'
		WHERE c.concept_id NOT IN (
				SELECT pack_concept_id
				FROM pack_content
				)
		GROUP BY c.concept_id
		HAVING COUNT(c.concept_id) > 1
		)
	AND ac.concept_code NOT IN (
		SELECT pack_concept_code
		FROM pc_stage
		);

--27.4 dm+d
INSERT INTO pc_stage (
	pack_concept_code,
	drug_concept_code,
	amount,
	box_size
	)
SELECT DISTINCT ac.concept_code,
	ac2.concept_code,
	pcs.amount,
	pcs.box_size
FROM dev_dmd.pc_stage pcs
JOIN concept c ON c.concept_code = pcs.pack_concept_code
	AND c.vocabulary_id = 'dm+d'
	AND c.invalid_reason IS NULL
JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id
	AND cr.relationship_id = 'Maps to'
	AND cr.invalid_reason IS NULL
JOIN concept ac ON ac.concept_id = cr.concept_id_2
	AND ac.vocabulary_id = 'RxNorm Extension'
	AND ac.invalid_reason IS NULL
JOIN concept c2 ON c2.concept_code = pcs.drug_concept_code
	AND c2.vocabulary_id = 'dm+d'
	AND c2.invalid_reason IS NULL
JOIN concept_relationship cr2 ON cr2.concept_id_1 = c2.concept_id
	AND cr2.relationship_id = 'Maps to'
	AND cr2.invalid_reason IS NULL
JOIN concept ac2 ON ac2.concept_id = cr2.concept_id_2
	AND ac2.vocabulary_id LIKE 'RxNorm%'
	AND ac2.invalid_reason IS NULL
WHERE c.concept_id NOT IN (
		SELECT pack_concept_id
		FROM pack_content
		)
	AND c.concept_id IN (
		SELECT c.concept_id
		FROM dev_dmd.pc_stage pcs
		JOIN concept c ON c.concept_code = pcs.pack_concept_code
			AND c.vocabulary_id = 'dm+d'
			AND c.invalid_reason IS NULL
		JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id
			AND cr.relationship_id = 'Maps to'
			AND cr.invalid_reason IS NULL
		JOIN concept ac ON ac.concept_id = cr.concept_id_2
			AND ac.vocabulary_id = 'RxNorm Extension'
			AND ac.invalid_reason IS NULL
		JOIN concept c2 ON c2.concept_code = pcs.drug_concept_code
			AND c2.vocabulary_id = 'dm+d'
		JOIN concept_relationship cr2 ON cr2.concept_id_1 = c2.concept_id
			AND cr2.relationship_id = 'Maps to'
			AND cr2.invalid_reason IS NULL
		JOIN concept ac2 ON ac2.concept_id = cr2.concept_id_2
			AND ac2.vocabulary_id LIKE 'RxNorm%'
		WHERE c.concept_id NOT IN (
				SELECT pack_concept_id
				FROM pack_content
				)
		GROUP BY c.concept_id
		HAVING COUNT(c.concept_id) > 1
		)
	AND ac.concept_code NOT IN (
		SELECT pack_concept_code
		FROM pc_stage
		);

--28 fix inert ingredients in contraceptive packs
UPDATE pc_stage
SET amount = 7
WHERE (
		pack_concept_code,
		drug_concept_code
		) IN (
		SELECT p.pack_concept_code,
			p.drug_concept_code
		FROM pc_stage p
		JOIN drug_concept_stage d ON d.concept_code = p.drug_concept_code
			AND concept_name LIKE '%Inert%'
			AND p.amount = 21
		JOIN pc_stage p2 ON p.pack_concept_code = p2.pack_concept_code
			AND p.drug_concept_code != p2.drug_concept_code
			AND p.amount = 21
		);

--29 update Inert Ingredients / Inert Ingredients 1 MG Oral Tablet to Inert Ingredient Oral Tablet
UPDATE pc_stage
SET drug_concept_code = '748796'
WHERE drug_concept_code = 'OMOP285209';

--30 fixing existing packs in order to remove duplicates
DELETE
FROM pc_stage
WHERE pack_concept_code = 'OMOP420950'
	AND drug_concept_code = '310463'
	AND amount = 5;

DELETE
FROM pc_stage
WHERE pack_concept_code = 'OMOP420969'
	AND drug_concept_code = '310463'
	AND amount = 7;

DELETE
FROM pc_stage
WHERE pack_concept_code = 'OMOP420978'
	AND drug_concept_code = '392651'
	AND amount IS NULL;

DELETE
FROM pc_stage
WHERE pack_concept_code = 'OMOP420978'
	AND drug_concept_code = '197662'
	AND amount IS NULL;

DELETE
FROM pc_stage
WHERE pack_concept_code = 'OMOP902613'
	AND drug_concept_code = 'OMOP918399'
	AND amount = 7;

UPDATE pc_stage
SET amount = 12
WHERE pack_concept_code = 'OMOP420950'
	AND drug_concept_code = '310463'
	AND amount = 7;

UPDATE pc_stage
SET amount = 12
WHERE pack_concept_code = 'OMOP420969'
	AND drug_concept_code = '310463'
	AND amount = 5;

UPDATE pc_stage
SET amount = 12
WHERE pack_concept_code = 'OMOP902613'
	AND drug_concept_code = 'OMOP918399'
	AND amount = 5;

DELETE
FROM pc_stage
WHERE pack_concept_code = 'OMOP902009'
	AND drug_concept_code = 'OMOP706163'
	AND amount = 28;

UPDATE pc_stage
SET amount = 31
WHERE pack_concept_code = 'OMOP902009'
	AND drug_concept_code = 'OMOP706163'
	AND amount = 3;

--31.1 Create links to self 
INSERT INTO relationship_to_concept (
	concept_code_1,
	vocabulary_id_1,
	concept_id_2,
	precedence
	)
SELECT a.concept_code,
	a.vocabulary_id,
	b.concept_id,
	1
FROM drug_concept_stage a
JOIN concept b ON b.concept_code = a.concept_code
	AND b.vocabulary_id IN (
		'RxNorm',
		'RxNorm Extension'
		)
WHERE a.concept_class_id IN (
		'Dose Form',
		'Brand Name',
		'Supplier',
		'Ingredient'
		);

--31.2 insert relationship to units
INSERT INTO relationship_to_concept (
	concept_code_1,
	vocabulary_id_1,
	concept_id_2,
	precedence,
	conversion_factor
	)
SELECT a.concept_code,
	a.vocabulary_id,
	b.concept_id,
	1,
	1
FROM drug_concept_stage a
JOIN concept b ON b.concept_code = a.concept_code
	AND b.vocabulary_id = 'UCUM'
WHERE a.concept_class_id = 'Unit';

--31.3 insert additional mapping that doesn't exist in concept
INSERT INTO relationship_to_concept (
	concept_code_1,
	vocabulary_id_1,
	concept_id_2,
	precedence,
	conversion_factor
	)
VALUES (
	'mL',
	'Rxfix',
	8576,
	2,
	1000
	);

INSERT INTO relationship_to_concept (
	concept_code_1,
	vocabulary_id_1,
	concept_id_2,
	precedence,
	conversion_factor
	)
VALUES (
	'mg',
	'Rxfix',
	8587,
	2,
	0.001
	);

INSERT INTO relationship_to_concept (
	concept_code_1,
	vocabulary_id_1,
	concept_id_2,
	precedence,
	conversion_factor
	)
VALUES (
	'[U]',
	'Rxfix',
	8718,
	2,
	1
	);

INSERT INTO relationship_to_concept (
	concept_code_1,
	vocabulary_id_1,
	concept_id_2,
	precedence,
	conversion_factor
	)
VALUES (
	'[iU]',
	'Rxfix',
	8510,
	2,
	1
	);

--31.4 transform micrograms into milligrams
UPDATE relationship_to_concept
SET concept_id_2 = 8576,
	conversion_factor = 0.001
WHERE concept_code_1 = 'ug'
	AND concept_id_2 = 9655;

--32 Before Build_RxE
INSERT INTO vocabulary (
	vocabulary_id,
	vocabulary_name,
	vocabulary_concept_id
	)
VALUES (
	'RxO',
	'RxO',
	0
	);

UPDATE concept
SET vocabulary_id = 'RxO'
WHERE vocabulary_id = 'RxNorm Extension';

UPDATE concept_relationship
SET invalid_reason = 'D',
	valid_end_date = CURRENT_DATE - 1
WHERE concept_id_1 IN (
		SELECT concept_id_1
		FROM concept_relationship
		JOIN concept ON concept_id_1 = concept_id
			AND vocabulary_id = 'RxO'
		)
	OR concept_id_2 IN (
		SELECT concept_id_2
		FROM concept_relationship
		JOIN concept ON concept_id_2 = concept_id
			AND vocabulary_id = 'RxO'
		);

DROP INDEX idx_irs_cc;
DROP INDEX idx_dcs_cc;
DROP INDEX idx_dcs_cn;