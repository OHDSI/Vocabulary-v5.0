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
--1 Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;


--2 Add new temporary vocabulary named Rxfix to the vocabulary table
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

--3 Update latest_update field to new date
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

--4 create input tables 
DROP TABLE IF EXISTS drug_concept_stage; --temporary!!!!! later we should to move all drops to the end of this script (or cndv?)
DROP TABLE IF EXISTS ds_stage;
DROP TABLE IF EXISTS internal_relationship_stage;
DROP TABLE IF EXISTS pc_stage;
DROP TABLE IF EXISTS relationship_to_concept;

--4.1 1st input table: drug_concept_stage
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

--4.2 2nd input table: ds_stage
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

--4.3 3rd input table: internal_relationship_stage
CREATE TABLE internal_relationship_stage (
	concept_code_1 VARCHAR(50),
	concept_code_2 VARCHAR(50)
	);

--4.4 4th input table: pc_stage
CREATE TABLE pc_stage (
	pack_concept_code VARCHAR(50),
	drug_concept_code VARCHAR(50),
	amount FLOAT,
	box_size INT
	);

--4.5 5th input table: relationship_to_concept
CREATE TABLE relationship_to_concept (
	concept_code_1 VARCHAR(50),
	vocabulary_id_1 VARCHAR(20),
	concept_id_2 INT,
	precedence INT,
	conversion_factor FLOAT
	);
	
--create indexes and constraints
		
CREATE INDEX irs_concept_code_1 on internal_relationship_stage (concept_code_1);		
CREATE INDEX irs_concept_code_2 on internal_relationship_stage (concept_code_2);
CREATE INDEX dcs_concept_code on drug_concept_stage (concept_code);
CREATE INDEX ds_drug_concept_code on ds_stage (drug_concept_code);
CREATE INDEX ds_ingredient_concept_code on ds_stage (ingredient_concept_code);
CREATE UNIQUE INDEX dcs_unique_concept_code ON drug_concept_stage (concept_code);
CREATE UNIQUE INDEX irs_unique_concept_code ON internal_relationship_stage (concept_code_1,concept_code_2);


--5 Create Concepts
--5.1 Get products
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

--5.2 Get upgraded Dose Forms, Brand Names, Supplier
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

--5.3 Ingredients: Need to check what happens to deprecated
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

--5.4 Get ingredients from hierarchy
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

--5.5 Get all Units
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
		);

DELETE
FROM drug_concept_stage
WHERE invalid_reason IS NOT NULL;

--6 filling drug_strength
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
	ingredient_concept_code,
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
		amount_value,
		c3.concept_code AS amount_unit,
		ds.numerator_value AS numerator_value,
		c4.concept_code AS numerator_unit,
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
	) AS s0;

--7 Build internal_relationship_stage 
--Drug to form
INSERT INTO internal_relationship_stage
SELECT DISTINCT dc.concept_code,
	c2.concept_code AS concept_code_2
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

 --Drug to BN
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
	AND c2.invalid_reason IS NULL
WHERE dc.concept_class_id = 'Drug Product'
	AND NOT EXISTS (
		SELECT 1
		FROM internal_relationship_stage irs_int
		WHERE irs_int.concept_code_1 = dc.concept_code
			AND irs_int.concept_code_2 = c2.concept_code
		);

 --drug to ingredient
INSERT INTO internal_relationship_stage (
	concept_code_1,
	concept_code_2
	)
SELECT DISTINCT dc.concept_code,
	c2.concept_code
FROM drug_concept_stage dc
JOIN concept c ON dc.concept_code = c.concept_code
	AND c.vocabulary_id LIKE 'RxNorm%'
	AND c.invalid_reason IS NULL
	AND dc.concept_class_id = 'Drug Product'
	AND dc.source_concept_class_id NOT LIKE '%Pack%'
	AND dc.concept_name NOT LIKE '%} Pack%'
JOIN drug_strength ON drug_concept_id = c.concept_id
JOIN concept c2 ON ingredient_concept_id = c2.concept_id
	AND c2.concept_class_id = 'Ingredient';



--drug form to ingr
INSERT INTO internal_relationship_stage
SELECT DISTINCT c.concept_code,
	c2.concept_code
FROM concept c
JOIN drug_concept_stage dc ON dc.concept_code = c.concept_code
	AND c.vocabulary_id LIKE 'RxNorm%'
	AND c.invalid_reason IS NULL
JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id
	AND cr.RELATIONSHIP_ID = 'RxNorm has ing'
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
		WHERE irs_int.concept_code_1 = c.concept_code
			AND irs_int.concept_code_2 = c2.concept_code
		);
		
INSERT INTO internal_relationship_stage (
	concept_code_1,
	concept_code_2
	)
SELECT DISTINCT dc.concept_code,
	c2.concept_code
FROM drug_concept_stage dc
JOIN concept c ON dc.concept_code = c.concept_code
	AND c.vocabulary_id IN ('RxNorm','RxNorm Extension')
	AND c.invalid_reason IS NULL
	AND dc.concept_class_id = 'Drug Product'
	AND dc.source_concept_class_id IN ('Branded Drug','Branded Drug Box','Branded Drug Comp','Branded Drug Form','Clinincal Drug','Clinincal Drug Box','Clinincal Drug Comp','Clinincal Drug Form','Marketed Product','Quant Branded Box','Quant Branded Drug','Quant Clinincal Box','Quant Clinincal Drug' )
	AND dc.concept_name NOT LIKE '%} Pack%'
JOIN concept_ancestor ca ON descendant_concept_id = c.concept_id
JOIN concept c2 ON ancestor_concept_id = c2.concept_id
	AND c2.concept_class_id = 'Ingredient'
WHERE NOT EXISTS (
		SELECT 1
		FROM internal_relationship_stage irs_int
		JOIN drug_concept_stage dcs ON dcs.concept_code = irs_int.concept_code_2
		WHERE irs_int.concept_code_1 = dc.concept_code
			AND dcs.concept_class_id = 'Ingredient'
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
	AND c2.vocabulary_id IN ('RxNorm','RxNorm Extension')
	AND c2.invalid_reason IS NULL
WHERE dc.concept_class_id = 'Drug Product'
	AND NOT EXISTS (
		SELECT 1
		FROM internal_relationship_stage irs_int
		WHERE irs_int.concept_code_1 = dc.concept_code
			AND irs_int.concept_code_2 = c2.concept_code
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

--8 just take it from the pack_content
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

--9 Create links to self 
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

--9.2 insert relationship to units
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

--10 run create_input_vN

--11 Before Build_RxE
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
		);

UPDATE concept_relationship
SET invalid_reason = 'D',
	valid_end_date = CURRENT_DATE - 1
WHERE concept_id_2 IN (
		SELECT concept_id_2
		FROM concept_relationship
		JOIN concept ON concept_id_2 = concept_id
			AND vocabulary_id = 'RxO'
		);