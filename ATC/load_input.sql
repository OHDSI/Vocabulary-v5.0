/**************************************************************************
* Copyright 2016 Observational Health Data Sciences AND Informatics (OHDSI)
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may NOT use this file except IN compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to IN writing, software
* distributed under the License is distributed ON an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*
* Authors: Anna Ostropolets, Polina Talapova
* Date: 2022
**************************************************************************/
DROP TABLE IF EXISTS drug_concept_stage;
DROP TABLE IF EXISTS internal_relationship_stage;
DROP TABLE IF EXISTS relationship_to_concept;
DROP TABLE IF EXISTS concept_rx;
-- ds_stage AND pc_stage are not used in the ATC deployment

CREATE TABLE drug_concept_stage (
	concept_name VARCHAR(255),
	vocabulary_id VARCHAR(20),
	concept_class_id VARCHAR(20),
	standard_concept VARCHAR(1),
	concept_code VARCHAR, --increase the length for concept_code field to infinity
	possible_excipient VARCHAR(1),
	domain_id VARCHAR(20),
	valid_start_date DATE,
	valid_end_date DATE,
	invalid_reason VARCHAR(1),
	source_concept_class_id VARCHAR(20)
	);

CREATE TABLE internal_relationship_stage
	--increase the length for concept_code_1 and concept_code_2 fields to infinity
	(
	concept_code_1 VARCHAR,
	concept_code_2 VARCHAR
	);

CREATE TABLE relationship_to_concept (
	concept_code_1 VARCHAR, --increase the length for concept_code_1 field to infinity
	vocabulary_id_1 VARCHAR(20),
	concept_id_2 INT,
	precedence INT2,
	conversion_factor NUMERIC
	);

--create a small table to speed up some queries
CREATE UNLOGGED TABLE concept_rx AS
SELECT *
FROM concept
WHERE vocabulary_id LIKE 'RxNorm%';

CREATE INDEX idx_rx_name ON concept_rx (UPPER(concept_name)) WITH (FILLFACTOR=100);
CREATE INDEX idx_rx_concept_id ON concept_rx (concept_id) WITH (FILLFACTOR=100);
CREATE INDEX idx_rx_concept_class_id ON concept_rx (concept_class_id) WITH (FILLFACTOR=100) WHERE concept_class_id IN ('Ingredient', 'Dose Form');

ANALYZE concept_rx;


/*************************************************
***** Mono ATC to internal_relationship_stage ****
**************************************************/

----------------
-- Dose Forms --
----------------

-- create a temporary table with all ATC-related RxN/RxE Dose Forms (using Dose Form Groups)
DROP TABLE IF EXISTS dev_form;
CREATE UNLOGGED TABLE dev_form AS
	WITH dev_oral -- 1 - Oral forms
		AS (
			SELECT DISTINCT d.*
			FROM concept_relationship r
			JOIN concept c ON c.concept_id = r.concept_id_1
			JOIN concept d ON d.concept_id = r.concept_id_2
				AND d.invalid_reason IS NULL
				AND d.concept_class_id = 'Dose Form'
			WHERE r.concept_id_1 IN (
					36217214,
					36244020,
					36217223,
					36244035,
					36217215,
					36244032,
					36244021,
					36244031, -- Oral Product |Buccal Product |Paste product |Chewable Product|Dental Product|Disintegrating Oral Product|Lozenge Product|Wafer Product
					36244030,
					36244029,
					36217220,
					36244027,
					36244036,
					36244033,
					36217216
					) -- Oral Powder Product|Oral Paste Product|Oral Liquid Product|Granule Product|Flake Product|Pellet Product|Pill
				AND r.relationship_id = 'RxNorm inverse is a'
				AND r.invalid_reason IS NULL
			), --  sublingual route is included as well despite the fact it is processed separately
		dev_sub -- 2 - Sublingual forms
		AS (
			SELECT DISTINCT d.*
			FROM concept_relationship r
			JOIN concept c ON c.concept_id = r.concept_id_1
			JOIN concept d ON d.concept_id = r.concept_id_2
				AND d.invalid_reason IS NULL
				AND d.concept_class_id = 'Dose Form'
			WHERE r.concept_id_1 IN (
					36217214,
					36244020
					) -- Sublingual Product|Buccal Product
				AND r.relationship_id = 'RxNorm inverse is a'
				AND r.invalid_reason IS NULL
				AND d.concept_name ILIKE '%sublingual%'
			), -- should be separated FROM oral forms in the ATC vocabulary.
		dev_parenteral -- 3 - Parenteral forms
		AS (
			SELECT DISTINCT d.*
			FROM concept_relationship r
			JOIN concept c ON c.concept_id = r.concept_id_1
			JOIN concept d ON d.concept_id = r.concept_id_2
				AND d.invalid_reason IS NULL
				AND d.concept_class_id = 'Dose Form'
			WHERE r.concept_id_1 IN (
					36217210,
					36248213,
					36217221
					) -- Injectable Product|Intratracheal Product|Intraperitoneal Product
				AND r.relationship_id = 'RxNorm inverse is a'
				AND r.invalid_reason IS NULL
			), -- returns all children of Injectable Product
		dev_nasal -- 4 - Nasal forms
		AS (
			SELECT d.*
			FROM concept_relationship r
			JOIN concept c ON c.concept_id = r.concept_id_1
			JOIN concept d ON d.concept_id = r.concept_id_2
				AND d.invalid_reason IS NULL
				AND d.concept_class_id = 'Dose Form'
			WHERE r.concept_id_1 = 36217213 -- Nasal Product
				AND r.relationship_id = 'RxNorm inverse is a'
				AND r.invalid_reason IS NULL
			), -- returns all children of Nasal Product
		dev_topic -- 5 - Topical forms
		AS (
			SELECT DISTINCT d.*
			FROM concept_relationship r
			JOIN concept c ON c.concept_id = r.concept_id_1
			JOIN concept d ON d.concept_id = r.concept_id_2
				AND d.invalid_reason IS NULL
				AND d.concept_class_id = 'Dose Form'
			WHERE r.concept_id_1 IN (
					36217206,
					36244040,
					36244034,
					36217219,
					36217222,
					36217208, -- Topical Product|Soap Product|Shampoo Product|Drug Implant Product|Irrigation Product |Medicated Pad or Tape
					36217223,
					36217212,
					36217224,
					36217225,
					1146249,
					36217221
					) -- Paste Product|Mucosal Product|Prefilled Applicator Product|Urethral Product|Pyelocalyceal Product|Intraperitoneal Product
				AND r.relationship_id = 'RxNorm inverse is a'
				AND r.invalid_reason IS NULL
			),
		dev_mouth -- 6 - Local oral forms
		AS (
			SELECT DISTINCT d.*
			FROM concept_relationship r
			JOIN concept c ON c.concept_id = r.concept_id_1
			JOIN concept d ON d.concept_id = r.concept_id_2
				AND d.invalid_reason IS NULL
				AND d.concept_class_id = 'Dose Form'
			WHERE r.concept_id_1 IN (
					36244022,
					36217223,
					36217214,
					36244020,
					36217215,
					36244021,
					36244026, -- Mouthwash Product|Paste Product|Sublingual Product|Buccal Product|Dental Product|Lozenge Product|Toothpaste Product
					36244037,
					36244023,
					36244041,
					37498345,
					36244028,
					36244024
					) -- Oral Spray Product|Oral Ointment Product|Oral Gel Product |Oral Film Product| Oral Foam Product|	Oral Cream Product
				AND r.relationship_id = 'RxNorm inverse is a'
				AND d.concept_name ILIKE '%mouthwash%'
				AND r.invalid_reason IS NULL
			),
		dev_rectal -- 7 - Rectal forms
		AS (
			SELECT d.*
			FROM concept_relationship r
			JOIN concept c ON c.concept_id = r.concept_id_1
			JOIN concept d ON d.concept_id = r.concept_id_2
				AND d.invalid_reason IS NULL
				AND d.concept_class_id = 'Dose Form'
			WHERE r.concept_id_1 = 36217211 -- Rectal Product
				AND r.relationship_id = 'RxNorm inverse is a'
				AND r.invalid_reason IS NULL
			),
		dev_vaginal -- 8 - Vaginal forms
		AS (
			SELECT d.*
			FROM concept_relationship r
			JOIN concept c ON c.concept_id = r.concept_id_1
			JOIN concept d ON d.concept_id = r.concept_id_2
				AND d.invalid_reason IS NULL
				AND d.concept_class_id = 'Dose Form'
			WHERE r.concept_id_1 = 36217209
				AND r.relationship_id = 'RxNorm inverse is a'
				AND r.invalid_reason IS NULL
			), -- Vaginal Product
		dev_urethral AS -- 9 - Urethral forms
		(
			SELECT d.*
			FROM concept_relationship r
			JOIN concept c ON c.concept_id = r.concept_id_1
			JOIN concept d ON d.concept_id = r.concept_id_2
				AND d.invalid_reason IS NULL
				AND d.concept_class_id = 'Dose Form'
			WHERE r.concept_id_1 = 36217225 -- Urethral Product
				AND r.relationship_id = 'RxNorm inverse is a'
				AND r.invalid_reason IS NULL
			),
		dev_opht -- 10 - Ophthalmic forms
		AS (
			SELECT DISTINCT d.*
			FROM concept_relationship r
			JOIN concept c ON c.concept_id = r.concept_id_1
			JOIN concept d ON d.concept_id = r.concept_id_2
				AND d.invalid_reason IS NULL
				AND d.concept_class_id = 'Dose Form'
			WHERE r.concept_id_1 IN (
					36217218,
					36217224
					) -- Ophthalmic Product | Prefilled Applicator  (Dose Form Group)
				AND r.relationship_id = 'RxNorm inverse is a'
				AND r.invalid_reason IS NULL
				AND d.concept_name ILIKE '%ophthalmic%'
			),
		dev_otic -- 11 - Otic forms
		AS (
			SELECT d.*
			FROM concept_relationship r
			JOIN concept c ON c.concept_id = r.concept_id_1
			JOIN concept d ON d.concept_id = r.concept_id_2
				AND d.invalid_reason IS NULL
				AND d.concept_class_id = 'Dose Form'
			WHERE r.concept_id_1 = 36217217 -- Otic Product (Dose Form Group)
				AND r.relationship_id = 'RxNorm inverse is a'
				AND r.invalid_reason IS NULL
			),
		dev_inhal -- 12 - Inhalation forms
		AS (
			SELECT DISTINCT d.*
			FROM concept_relationship r
			JOIN concept c ON c.concept_id = r.concept_id_1
			JOIN concept d ON d.concept_id = r.concept_id_2
				AND d.invalid_reason IS NULL
				AND d.concept_class_id = 'Dose Form'
			WHERE r.concept_id_1 IN (
					36217207,
					36244037
					) -- Inhalant Product| Oral Spray Product
				AND r.relationship_id = 'RxNorm inverse is a'
				AND r.invalid_reason IS NULL
			),
		dev_irrig AS (
			SELECT d.*
			FROM concept_relationship r
			JOIN concept c ON c.concept_id = r.concept_id_1
			JOIN concept d ON d.concept_id = r.concept_id_2
				AND d.invalid_reason IS NULL
				AND d.concept_class_id = 'Dose Form'
			WHERE r.concept_id_1 = '36217222' -- Irrigation Product
				AND r.relationship_id = 'RxNorm inverse is a'
				AND r.invalid_reason IS NULL
			)

SELECT *,
	'dev_oral' AS df
FROM dev_oral -- 1

UNION ALL

SELECT *,
	'dev_sub'
FROM dev_sub -- 2

UNION ALL

SELECT *,
	'dev_parenteral'
FROM dev_parenteral -- 3

UNION ALL

SELECT *,
	'dev_nasal'
FROM dev_nasal -- 4

UNION ALL

SELECT *,
	'dev_topic'
FROM dev_topic -- 5

UNION ALL

SELECT *,
	'dev_mouth'
FROM dev_mouth -- 6

UNION ALL

SELECT *,
	'dev_rectal'
FROM dev_rectal -- 7

UNION ALL

SELECT *,
	'dev_vaginal'
FROM dev_vaginal -- 8

UNION ALL

SELECT *,
	'dev_urethral'
FROM dev_urethral -- 9

UNION ALL

SELECT *,
	'dev_opht'
FROM dev_opht -- 10

UNION ALL

SELECT *,
	'dev_otic'
FROM dev_otic -- 11

UNION ALL

SELECT *,
	'dev_inhal'
FROM dev_inhal -- 12

UNION ALL

SELECT *,
	'dev_irrig'
FROM dev_irrig; -- 13

-- connect all existing RxN/RxE forms of interest from dev_form to the ATC
DROP TABLE IF EXISTS atc_to_form;
CREATE UNLOGGED TABLE atc_to_form AS
SELECT DISTINCT a.concept_name,
	a.concept_code || ' ' || b.concept_name AS concept_code_1, -- ATC code + Dose Form name AS a code
	b.concept_name AS concept_code_2 -- OMOP Dose Form name treated AS a code
FROM dev_form b
JOIN concept_manual a ON a.invalid_reason IS NULL
	AND a.concept_class_id = 'ATC 5th'
WHERE (
		(
			a.concept_name ~* 'oral|systemic|chewing gum'
			AND b.df = 'dev_oral'
			) -- 1
		OR (
			a.concept_name ILIKE '%sublingual%'
			AND b.df = 'dev_sub'
			) -- 2
		OR (
			a.concept_name ~* 'parenteral|systemic|instillat'
			AND b.df = 'dev_parenteral'
			) -- 3
		OR (
			a.concept_name ILIKE '%nasal%'
			AND b.df = 'dev_nasal'
			) -- 4
		OR (
			a.concept_name ILIKE '%topical%'
			AND b.df = 'dev_topic'
			) -- 5
		OR (
			a.concept_name ~* 'transdermal|implant|systemic'
			AND b.df = 'dev_topical'
			AND b.concept_name ~* 'transdermal|Drug Implant'
			)
		OR (
			a.concept_name ILIKE '%local oral%'
			AND b.df = 'dev_mouth'
			) -- 7
		OR (
			a.concept_name ILIKE '%rectal%'
			AND b.df = 'dev_rectal'
			)
		OR (
			a.concept_name ILIKE '%vaginal%'
			AND b.df = 'dev_vaginal'
			)
		OR (
			a.concept_name ILIKE '%urethral%'
			AND b.df = 'dev_urethral'
			)
		OR (
			a.concept_name ILIKE '%ophthalmic%'
			AND b.df = 'dev_opht'
			)
		OR (
			a.concept_name ~* '\yotic'
			AND b.df = 'dev_otic'
			)
		OR (
			a.concept_name ~* 'inhalant|systemic'
			AND b.df = 'dev_inhal'
			)
		OR (
			a.concept_name ~* '\yirrigat'
			AND b.df = 'dev_irrig'
			)
		);

-- add links connecting ATC Drug Classes with the specified administration route AND RxN/RxE Dose Forms using atc_to_form
INSERT INTO internal_relationship_stage (
	concept_code_1,
	concept_code_2
	)
SELECT DISTINCT concept_code_1,
	concept_code_2
FROM atc_to_form;

CREATE INDEX idx_irs_complex ON internal_relationship_stage (
	concept_code_1,
	concept_code_2
	);

CREATE INDEX idx_irs_up_cc2 ON internal_relationship_stage (UPPER(concept_code_2));

ANALYZE internal_relationship_stage;

-- add links connecting ATC Drug Classes with the specified administration route AND Standard Ingredients using the concept_synonym table
INSERT INTO internal_relationship_stage
SELECT DISTINCT a.concept_code_1, -- ATC code + Dose Form name AS a code
	c.concept_name AS concept_code_2 -- Standard Ingredient name treated AS a code
FROM atc_to_form a
JOIN concept_rx c ON UPPER(c.concept_name) = UPPER(TRIM(REGEXP_REPLACE(a.concept_name, ';.*$', ''))) -- remove all unnecessary information after the semicolon
	AND c.standard_concept = 'S'
	AND c.concept_class_id = 'Ingredient'
	AND c.invalid_reason IS NULL
LEFT JOIN internal_relationship_stage irs ON irs.concept_code_1 = a.concept_code_1
	AND irs.concept_code_2 = c.concept_name
WHERE irs.concept_code_1 IS NULL;

-- add links between ATC Drug Classes AND Standard Ingredients using the concept_synonym table
INSERT INTO internal_relationship_stage
SELECT DISTINCT a.concept_code_1, -- ATC code + Dose Form name AS a code
	c.concept_name AS concept_code_2 -- Standard Ingredient name AS a code
FROM atc_to_form a
JOIN concept_synonym b ON UPPER(b.concept_synonym_name) = UPPER(TRIM(REGEXP_REPLACE(a.concept_name, ';.*$', '')))
JOIN concept_rx c ON c.concept_id = b.concept_id
	AND c.standard_concept = 'S'
	AND c.concept_class_id = 'Ingredient'
	AND c.invalid_reason IS NULL
LEFT JOIN internal_relationship_stage irs ON irs.concept_code_1 = a.concept_code_1
	AND irs.concept_code_2 = c.concept_name
WHERE irs.concept_code_1 IS NULL;

-----------------------------
-- Mono ATC W/O Dose Forms --
-----------------------------

-- add IRS links connecting ATC Drug Classes W/O Dose Forms and Standard Ingredients using the concept table
INSERT INTO internal_relationship_stage (
	concept_code_1,
	concept_code_2
	)
SELECT DISTINCT a.concept_code AS concept_code_1, -- for such Drug Classes use ATC code only 
	c.concept_name AS concept_code_2
FROM concept_manual a
JOIN concept_rx c ON TRIM(UPPER(REGEXP_REPLACE(c.concept_name, '\s+|\W+', '', 'g'))) = TRIM(UPPER(REGEXP_REPLACE(a.concept_name, '\s+|\W+| \(.*\)|, combinations.*|;.*$', '', 'g'))) -- to neglect spaces, non-word characters, additional information and dose forms
	AND c.standard_concept = 'S'
	AND c.concept_class_id = 'Ingredient'
	AND c.invalid_reason IS NULL
WHERE a.concept_class_id = 'ATC 5th'
	AND (
		a.concept_code,
		c.concept_name
		) NOT IN (
		SELECT SPLIT_PART(concept_code_1, ' ', 1),
			concept_code_2
		FROM internal_relationship_stage
		);
 
-- add links connecting ATC Drug Classes W/O Dose Forms and Standard Ingredients using the concept_synonym table
INSERT INTO internal_relationship_stage (
	concept_code_1,
	concept_code_2
	)
SELECT DISTINCT a.concept_code AS concept_code_1, -- for such Drug Classes use ATC code only 
	c.concept_name AS concept_code_2 -- Standard Ingredient name AS a code
FROM concept_manual a
JOIN concept_synonym b ON TRIM(UPPER(REGEXP_REPLACE(b.concept_synonym_name, '\s+|\W+', '', 'g'))) = TRIM(UPPER(REGEXP_REPLACE(a.concept_name, '\s+|\W+|, combinations.*|;.*$', '', 'g')))
JOIN concept_rx c ON c.concept_id = b.concept_id
	AND c.standard_concept = 'S'
	AND c.concept_class_id = 'Ingredient'
	AND c.invalid_reason IS NULL
WHERE a.concept_class_id = 'ATC 5th'
	AND (
		a.concept_code,
		c.concept_name
		) NOT IN (
		SELECT SPLIT_PART(concept_code_1, ' ', 1),
			concept_code_2
		FROM internal_relationship_stage
		);

ANALYZE internal_relationship_stage;

-- note, name matching with Non-standard OMOP drugs and cross-walk to Standard via concept_relationship gives a lot of errors (clean up is required). That is why this step is ignored here.
/**************************
**** ATC Combo Classes ****
***************************/

-- assemble all Multicomponent ATC Classes into one table
DROP TABLE IF EXISTS combo_pull;
CREATE UNLOGGED TABLE combo_pull AS
SELECT DISTINCT concept_code AS class_code,
	concept_name AS class_name,
	SPLIT_PART(concept_name, ';', 1) AS nm
FROM concept_manual
WHERE (
		SPLIT_PART(concept_name, ';', 1) ~* ' and |\ywith|\ycomb|preparations|acids|animals|antiinfectives|compounds|lytes\y|flowers|grass pollen|\yresins|tree pollen|dust mites|multienzymes'
		OR SPLIT_PART(concept_name, ';', 1) ~* 'organisms|antiseptics|feather|diastase|emulsions|immunoglobulins|substitutes|glycosides|cannabinoids|typhoid-|\ydrugs|\/|antiserum'
		OR SPLIT_PART(concept_name, ';', 1) ~* 'diphtheria-|carbohydrates|diphtheria-hepatitis B|edetates|insects|medicated shampoos|phospholipids|various|bacillus|^oil|alkaloids'
		)
	AND invalid_reason IS NULL
	AND concept_class_id = 'ATC 5th'
	AND concept_name !~* 'varicella/zoster|tositumomab/iodine|\yIUD\y|ferric oxide polymaltose'
	AND concept_code <> 'G02BB02';-- vaginal ring with progestogen; vaginal

-- create a table for Multicomponent ATC Class mappings to Standard Ingredient, start with the 1st ATC Combo Ingredient using the concept table and full name match
DROP TABLE IF EXISTS dev_combo;
CREATE UNLOGGED TABLE dev_combo AS
SELECT DISTINCT a.class_code,
	a.class_name,
	SPLIT_PART(a.nm, ' and ', 1) AS class,
	c.concept_id,
	c.concept_name,
	1 AS rnk -- stands for the Primary lateral relationship
FROM combo_pull a
JOIN concept c ON UPPER(c.concept_name) = TRIM(UPPER(SPLIT_PART(a.nm, ' and ', 1)))
WHERE c.standard_concept = 'S'
	AND c.concept_class_id = 'Ingredient'
	AND c.vocabulary_id LIKE 'RxNorm%';

-- add the 1st ATC Combo Ingredient using the concept table and full name match
INSERT INTO dev_combo
SELECT DISTINCT a.class_code,
	a.class_name,
	SPLIT_PART(a.nm, ' and ', 1) AS class,
	c.concept_id,
	c.concept_name,
	1 AS rnk -- stands for the Primary lateral relationship
FROM combo_pull a
JOIN concept_rx c ON UPPER(c.concept_name) = SUBSTRING(TRIM(UPPER(SPLIT_PART(a.nm, ' and ', 1))), '\w*\s*-?\s*\w+')
	AND c.standard_concept = 'S'
	AND c.concept_class_id = 'Ingredient'
LEFT JOIN dev_combo d USING (class_code, concept_id)
WHERE d.class_code IS NULL;

-- add the 1st ATC Combo Ingredient using the concept_synonym table and full name match
INSERT INTO dev_combo
SELECT DISTINCT a.class_code,
	a.class_name,
	SPLIT_PART(a.nm, ' and ', 1) AS class,
	d.concept_id,
	d.concept_name,
	1 AS rnk -- stands for the Primary lateral relationship
FROM combo_pull a
JOIN concept_synonym cs ON UPPER(cs.concept_synonym_name) IN (
		TRIM(UPPER(SPLIT_PART(a.nm, ' and ', 1))),
		SUBSTRING(TRIM(UPPER(SPLIT_PART(a.nm, ' and ', 1))), '\w*\s*-?\s*\w+')
		)
JOIN concept_rx d ON d.concept_id = cs.concept_id
	AND d.standard_concept = 'S'
	AND d.concept_class_id = 'Ingredient'
LEFT JOIN dev_combo dc ON dc.class_code = a.class_code
	AND dc.concept_id = d.concept_id
WHERE dc.class_code IS NULL;

-- add the the 1st ATC Combo Ingredient using the concept table and partial name match
INSERT INTO dev_combo
SELECT DISTINCT a.class_code,
	a.class_name,
	SPLIT_PART(a.nm, ' and ', 1) AS class,
	c.concept_id,
	c.concept_name,
	1 AS rnk -- stands for the Primary lateral relationship
FROM combo_pull a
JOIN concept_rx c ON UPPER(c.concept_name) = SUBSTRING(TRIM(UPPER(SPLIT_PART(a.nm, ' and ', 1))), '^\w+')
	AND c.standard_concept = 'S'
	AND c.concept_class_id = 'Ingredient'
LEFT JOIN dev_combo d USING (class_code)
WHERE d.class_code IS NULL;

-- add the 2nd ATC Combo Ingredient using the concept table and full name match
INSERT INTO dev_combo
SELECT DISTINCT a.class_code,
	a.class_name,
	SPLIT_PART(a.nm, ' and ', 2) AS class,
	c.concept_id,
	c.concept_name,
	2 AS rnk -- stands for the Secondary lateral relationship
FROM combo_pull a
JOIN concept_rx c ON UPPER(c.concept_name) = TRIM(UPPER(SPLIT_PART(a.nm, ' and ', 2)))
WHERE c.standard_concept = 'S'
	AND c.concept_class_id = 'Ingredient';

-- add the 2nd ATC Combo Ingredient using the concept table and partial name match
INSERT INTO dev_combo
SELECT DISTINCT a.class_code,
	a.class_name,
	SPLIT_PART(a.nm, ' and ', 2) AS class,
	c.concept_id,
	c.concept_name,
	2 AS rnk
FROM combo_pull a
JOIN concept_rx c ON UPPER(c.concept_name) = SUBSTRING(TRIM(UPPER(SPLIT_PART(a.nm, ' and ', 2))), '\w*\s*-?\s*\w+')
	AND c.standard_concept = 'S'
	AND c.concept_class_id = 'Ingredient'
	AND c.concept_id NOT IN (
		19049024,
		19136048
		)
LEFT JOIN dev_combo d USING (class_code, concept_id)
WHERE d.class_code IS NULL;

-- add the 2nd ATC Combo Ingredient using the concept_synonym table and partial name match
INSERT INTO dev_combo
SELECT DISTINCT a.class_code,
	a.class_name,
	SPLIT_PART(a.nm, ' and ', 2) AS class,
	d.concept_id,
	d.concept_name,
	2 AS rnk
FROM combo_pull a
JOIN concept_synonym cs ON UPPER(cs.concept_synonym_name) IN (
		TRIM(LOWER(SPLIT_PART(a.nm, ' and ', 2))),
		SUBSTRING(TRIM(LOWER(SPLIT_PART(a.nm, ' and ', 2))), '\w*\s*-?\s*\w+')
		)
JOIN concept_rx d ON d.concept_id = cs.concept_id
	AND d.standard_concept = 'S'
	AND d.concept_class_id = 'Ingredient'
LEFT JOIN dev_combo dc ON dc.class_code = a.class_code
	AND dc.concept_id = d.concept_id
WHERE dc.class_code IS NULL;

-- add to dev_combo the 2nd ATC Combo Ingredient using the concept table and partial name match
INSERT INTO dev_combo
SELECT DISTINCT a.class_code,
	a.class_name,
	SPLIT_PART(a.nm, ' and ', 2) AS class,
	c.concept_id,
	c.concept_name,
	2 AS rnk
FROM combo_pull a
JOIN concept_rx c ON UPPER(c.concept_name) = SUBSTRING(TRIM(UPPER(SPLIT_PART(a.nm, ' and ', 2))), '^\w+')
	AND c.standard_concept = 'S'
	AND c.concept_class_id = 'Ingredient'
	AND c.concept_id NOT IN (
		19049024,
		19136048
		)
LEFT JOIN dev_combo d USING (class_code, concept_id)
WHERE d.class_code IS NULL
	AND a.class_code IN (
		'R03AK10',
		'R03AL01',
		'R03AL03',
		'R03AL04',
		'R03AL05',
		'R03AL06',
		'R03AL07',
		'R03AL10'
		);

-- add manual mappings for ATC Combos using concept_relationship_manual 
INSERT INTO dev_combo
SELECT DISTINCT class_code,
	a.class_name,
	c.concept_name AS class, -- leave it empty
	c.concept_id,
	c.concept_name,
	CASE 
		WHEN relationship_id = 'ATC - RxNorm pr lat'
			THEN 1
		WHEN relationship_id = 'ATC - RxNorm sec lat'
			THEN 2
		WHEN relationship_id = 'ATC - RxNorm pr up'
			THEN 3
		ELSE 4 -- stands for 'ATC - RxNorm sec up' 
		END AS rnk
FROM combo_pull a
JOIN concept_relationship_manual r ON r.concept_code_1 = a.class_code
	AND r.relationship_id IN (
		'ATC - RxNorm pr lat',
		'ATC - RxNorm sec lat',
		'ATC - RxNorm pr up',
		'ATC - RxNorm sec up'
		)
	AND r.invalid_reason IS NULL
JOIN concept_rx c ON c.concept_code = r.concept_code_2
	AND c.concept_class_id = 'Ingredient'
	AND c.standard_concept = 'S'
LEFT JOIN dev_combo d USING (class_code, concept_id)
WHERE d.class_code IS NULL;

-- add mappings to those Ingredients, which have problems with name matching using the hardcoding
-- add Acetylsalicylic acid 
INSERT INTO dev_combo
SELECT DISTINCT d.class_code,
	d.class_name,
	'acetylsalicylic acid',
	1112807,
	'aspirin',
	CASE WHEN d.class_name LIKE 'acetylsalicylic%' THEN 1 ELSE 2 END AS rnk
FROM dev_combo d
WHERE (
		d.class_code,
		d.concept_id
		) NOT IN (
		SELECT class_code,
			1112807
		FROM dev_combo
		WHERE class_name ILIKE '%acetylsalicylic%'
		)
	AND d.class_name ILIKE '%acetylsalicylic%';

-- add Ethinylestradiol 
INSERT INTO dev_combo
SELECT DISTINCT d.class_code,
	d.class_name,
	'ethinylestradiol',
	1549786,
	'ethinyl estradiol',
	CASE WHEN d.class_name ILIKE 'ethinylestradiol%' THEN 1 ELSE 2 END
FROM dev_combo d
WHERE (
		d.class_code,
		d.concept_id
		) NOT IN (
		SELECT class_code,
			1549786
		FROM dev_combo
		WHERE class_name ILIKE '%ethinylestradiol%'
		)
	AND d.class_name ILIKE '%ethinylestradiol%';
 
-- add Estrogen
INSERT INTO dev_combo
SELECT d.class_code,
	d.class_name,
	'estrogens',
	19049228,
	'estrogens',
	CASE WHEN SPLIT_PART(d.class_name, ';', 1) ~* '^estrogens|^conjugated estrogens' THEN 1 ELSE 2 END
FROM dev_combo d
WHERE (
		d.class_code,
		d.concept_id
		) NOT IN (
		SELECT class_code,
			19049228
		FROM dev_combo
		WHERE class_name ILIKE '%estrogen%'
		)
	AND SPLIT_PART(d.class_name, ';', 1) LIKE '%estrogen%'

UNION

SELECT d.class_code,
	d.class_name,
	'estrogens',
	1549080,
	'estrogens, conjugated (USP)',
	CASE WHEN SPLIT_PART(d.class_name, ';', 1) ~* '^estrogens|^conjugated estrogens' THEN 1 ELSE 2 END
FROM dev_combo d
WHERE (
		d.class_code,
		d.concept_id
		) NOT IN (
		SELECT class_code,
			1549080
		FROM dev_combo
		WHERE class_name ILIKE '%estrogen%'
		)
	AND SPLIT_PART(d.class_name, ';', 1) LIKE '%estrogen%'

UNION

SELECT d.class_code,
	d.class_name,
	'estrogens',
	1551673,
	'estrogens, esterified (USP)',
	CASE WHEN SPLIT_PART(d.class_name, ';', 1) ~* '^estrogens|^conjugated estrogens' THEN 1 ELSE 2 END
FROM dev_combo d
WHERE (
		d.class_code,
		d.concept_id
		) NOT IN (
		SELECT class_code,
			1551673
		FROM dev_combo
		WHERE class_name ILIKE '%estrogen%'
		)
	AND SPLIT_PART(d.class_name, ';', 1) LIKE '%estrogen%'

UNION

SELECT d.class_code,
	d.class_name,
	'estrogens',
	1596779,
	'synthetic conjugated estrogens, A',
	CASE WHEN SPLIT_PART(d.class_name, ';', 1) ~* '^estrogens|^conjugated estrogens' THEN 1 ELSE 2 END
FROM dev_combo d
WHERE (
		d.class_code,
		d.concept_id
		) NOT IN (
		SELECT class_code,
			1596779
		FROM dev_combo
		WHERE class_name ILIKE '%estrogen%'
		)
	AND SPLIT_PART(d.class_name, ';', 1) ILIKE '%estrogen%'

UNION

SELECT d.class_code,
	d.class_name,
	'estrogens' AS class,
	1586808,
	'synthetic conjugated estrogens, B',
	CASE WHEN SPLIT_PART(d.class_name, ';', 1) ~* '^estrogens|^conjugated estrogens' THEN 1 ELSE 2 END
FROM dev_combo d
WHERE (
		d.class_code,
		d.concept_id
		) NOT IN (
		SELECT class_code,
			1586808
		FROM dev_combo
		WHERE class_name ILIKE '%estrogen%'
		)
	AND SPLIT_PART(d.class_name, ';', 1) ILIKE '%estrogen%';

-- remove erroneous mapping of strontium ranelate to strontium
DELETE
FROM dev_combo
WHERE class_code = 'M05BX53'
	AND concept_id = 19000815;-- strontium

/**********************************************
**** Combo to internal_realtionship_stage  ****
***********************************************/

-- add links between Multicomponent Oral ATC Drug Classes AND Standard Ingredients using the tables of dev_combo and concept table.
INSERT INTO internal_relationship_stage (
	concept_code_1,
	concept_code_2
	)
WITH t1 AS (
		SELECT DISTINCT a.class_code || ' ' || b.concept_name AS concept_code_1, -- ATC code + Dose Form name AS a code
			a.concept_id
		FROM dev_combo a
		JOIN dev_form b ON b.df = 'dev_oral'
		JOIN concept_manual c ON c.concept_name ~* 'oral|systemic|chewing gum'
			AND c.concept_code = a.class_code
		)
SELECT a.concept_code_1, -- ATC code + Dose Form name AS a code
	c.concept_name AS concept_code_2 -- Standard Ingredient name treated AS a code
FROM t1 a
JOIN concept_rx c ON c.concept_id = a.concept_id
	AND c.standard_concept = 'S'
	AND c.concept_class_id = 'Ingredient'
LEFT JOIN internal_relationship_stage irs ON irs.concept_code_1 = a.concept_code_1
	AND irs.concept_code_2 = c.concept_name
WHERE irs.concept_code_1 IS NULL;

-- add links between Multicomponent Parenteral ATC Drug Classes AND Standard Ingredients using the tables of dev_combo and concept table.
INSERT INTO internal_relationship_stage (
	concept_code_1,
	concept_code_2
	)
WITH t1 AS (
		SELECT DISTINCT a.class_code || ' ' || b.concept_name AS concept_code_1, -- ATC code + Dose Form name AS a code
			a.concept_id
		FROM dev_combo a
		JOIN dev_form b ON b.df = 'dev_parenteral'
		JOIN concept_manual c ON c.concept_name ~ 'parenteral|systemic'
			AND c.concept_code = a.class_code
		)
SELECT a.concept_code_1, -- ATC code + Dose Form name AS a code
	c.concept_name AS concept_code_2 -- Standard Ingredient name treated AS a code
FROM t1 a
JOIN concept_rx c ON c.concept_id = a.concept_id
	AND c.standard_concept = 'S'
	AND c.concept_class_id = 'Ingredient'
LEFT JOIN internal_relationship_stage irs ON irs.concept_code_1 = a.concept_code_1
	AND irs.concept_code_2 = c.concept_name
WHERE irs.concept_code_1 IS NULL;
 
-- add links between Multicomponent Vaginal ATC Drug Classes AND Standard Ingredients using the tables of dev_combo and concept table
INSERT INTO internal_relationship_stage (
	concept_code_1,
	concept_code_2
	)
WITH t1 AS (
		SELECT DISTINCT a.class_code || ' ' || b.concept_name AS concept_code_1, -- ATC code + Dose Form name AS a code
			a.concept_id
		FROM dev_combo a
		JOIN dev_form b ON b.df = 'dev_vaginal'
		JOIN concept_manual c ON c.concept_name ILIKE '%vaginal%'
			AND c.concept_code = a.class_code
		)
SELECT a.concept_code_1, -- ATC code + Dose Form name AS a code
	c.concept_name AS concept_code_2 -- Standard Ingredient name treated AS a code
FROM t1 a
JOIN concept_rx c ON c.concept_id = a.concept_id
	AND c.standard_concept = 'S'
	AND c.concept_class_id = 'Ingredient'
LEFT JOIN internal_relationship_stage irs ON irs.concept_code_1 = a.concept_code_1
	AND irs.concept_code_2 = c.concept_name
WHERE irs.concept_code_1 IS NULL;

 ------------------------------
-- Combo ATC W/O Dose Forms ---
-------------------------------

-- add links between Multicomponent ATC Drug Classes W/O Dose Forms AND Standard Ingredients using the tables of dev_combo and concept table
INSERT INTO internal_relationship_stage (
	concept_code_1,
	concept_code_2
	)
WITH t1 AS (
		SELECT DISTINCT class_code AS concept_code_1, -- ATC code + Dose Form name AS a code
			concept_id
		FROM dev_combo
		WHERE class_name NOT LIKE '%;%'
		)
SELECT a.concept_code_1, -- ATC code + Dose Form name AS a code
	c.concept_name AS concept_code_2 -- Standard Ingredient name treated AS a code
FROM t1 a
JOIN concept_rx c ON c.concept_id = a.concept_id
	AND c.standard_concept = 'S'
	AND c.concept_class_id = 'Ingredient'
WHERE (
		a.concept_code_1,
		c.concept_name
		) NOT IN (
		SELECT SPLIT_PART(concept_code_1, ' ', 1),
			concept_code_2
		FROM internal_relationship_stage
		);

/******************************
******* manual mapping ********
*******************************/

-- add manually created maps between ATC Classes and equivalent Standard Ingredients using crm
INSERT INTO internal_relationship_stage (
	concept_code_1,
	concept_code_2
	)
WITH t1 AS (
		SELECT DISTINCT a.concept_code_1,
			c.concept_name AS concept_code_2
		FROM concept_relationship_manual a
		JOIN concept_manual b ON b.concept_code = a.concept_code_1
		JOIN concept_rx c ON c.concept_code = a.concept_code_2
			AND c.vocabulary_id = a.vocabulary_id_2
			AND c.standard_concept = 'S'
			AND c.concept_class_id = 'Ingredient'
		WHERE a.invalid_reason IS NULL
			AND a.relationship_id IN (
				'ATC - RxNorm pr lat',
				'ATC - RxNorm sec lat',
				'ATC - RxNorm pr up',
				'ATC - RxNorm sec up'
				)
		) -- use ATC-specific relationships only
SELECT concept_code_1,
	concept_code_2 -- OMOP Ingredient name AS an ATC Drug Attribute code,
FROM t1
WHERE (
		concept_code_1,
		concept_code_2
		) NOT IN (
		SELECT SPLIT_PART(concept_code_1, ' ', 1),
			concept_code_2
		FROM internal_relationship_stage
		);

/**********************************
******* drug_concept_stage ********
***********************************/

-- add to DCS ATC Drug Classes as Drug Products using the internal_relationship_stage table
INSERT INTO drug_concept_stage (
	concept_name,
	vocabulary_id,
	concept_class_id,
	standard_concept,
	concept_code,
	possible_excipient,
	domain_id,
	valid_start_date,
	valid_end_date
	)
SELECT DISTINCT concept_code_1 AS concept_name, -- ATC code + name
	'ATC' AS vocabulary_id,
	'Drug Product' AS concept_class_id,
	NULL AS standard_concept,
	concept_code_1 AS concept_code,
	NULL AS possible_excipient,
	'Drug' AS domain_id,
	TO_DATE('19700101', 'YYYYMMDD') AS valid_start_date,
	TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date
FROM internal_relationship_stage;

ANALYZE internal_relationship_stage;

-- add ATC Drug Attributes in the form of Rx Dose Form names using the internal_relationship_stage table
INSERT INTO drug_concept_stage (
	concept_name,
	vocabulary_id,
	concept_class_id,
	standard_concept,
	concept_code,
	possible_excipient,
	domain_id,
	valid_start_date,
	valid_end_date
	)
SELECT DISTINCT irs.concept_code_2 AS concept_name, -- ATC pseudo-attribute IN the form of OMOP Dose Form name
	'ATC' AS vocabulary_id,
	'Dose Form' AS concept_class_id,
	NULL AS standard_concept,
	irs.concept_code_2 AS concept_code,
	NULL AS possible_excipient,
	'Drug' AS domain_id,
	TO_DATE('19700101', 'YYYYMMDD') AS valid_start_date,
	TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date
FROM internal_relationship_stage irs
JOIN concept_rx c ON c.concept_name = irs.concept_code_2
	AND c.concept_class_id = 'Dose Form'
	AND c.invalid_reason IS NULL;

CREATE UNIQUE INDEX dcs_unique_cc_idx ON drug_concept_stage (concept_code);
ANALYZE drug_concept_stage;

-- add ATC Drug Attributes in the form of Standard Ingredient names using the internal_relationship_stage table
INSERT INTO drug_concept_stage (
	concept_name,
	vocabulary_id,
	concept_class_id,
	standard_concept,
	concept_code,
	possible_excipient,
	domain_id,
	valid_start_date,
	valid_end_date
	)
SELECT DISTINCT concept_code_2 AS concept_name, -- ATC pseudo-attribute IN the form of OMOP Ingredient name
	'ATC' AS vocabulary_id,
	'Ingredient' AS concept_class_id,
	NULL AS standard_concept,
	concept_code_2 AS concept_code,
	NULL AS possible_excipient,
	'Drug' AS domain_id,
	TO_DATE('19700101', 'YYYYMMDD') AS valid_start_date,
	TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date
FROM internal_relationship_stage irs
JOIN concept_rx c ON UPPER(c.concept_name) = UPPER(irs.concept_code_2)
	AND c.concept_class_id = 'Ingredient'
	AND c.standard_concept = 'S'
	AND c.invalid_reason IS NULL
LEFT JOIN drug_concept_stage dcs ON dcs.concept_code = irs.concept_code_2
WHERE dcs.concept_code IS NULL;

-- obtain additional Ingredients for those ATC Classes which are still unmapped using fuzzy match
INSERT INTO internal_relationship_stage
WITH t1 AS (
		-- define concepts to map
		SELECT DISTINCT class_code,
			class_name
		FROM class_drugs_scraper cds
		WHERE (
				-- totally lost
				cds.class_code NOT IN (
					SELECT SPLIT_PART(concept_code, ' ', 1)
					FROM drug_concept_stage
					)
				AND LENGTH(cds.class_code) = 7
				AND class_code NOT IN (
					SELECT concept_code_1
					FROM concept_relationship_manual
					WHERE relationship_id IN (
							'ATC - RxNorm pr lat',
							'ATC - RxNorm sec lat',
							'ATC - RxNorm pr up',
							'ATC - RxNorm sec up'
							)
						AND invalid_reason IS NULL
					)
				AND cds.class_code NOT IN (
					'B03AD04',
					'V09GX01',
					'V09XX03'
					) -- ferric oxide polymaltose complexes | thallium (201Tl) chloride | selenium (75Se) norcholesterol
				AND cds.class_name !~* '^indium|^iodine|^yttrium|^RIFAMPICIN|coagulation factor'
				AND cds.change_type IN (
					'',
					'A'
					)
				)
			OR (
				-- absent IN the internal_relationship_stage
				cds.class_code IN (
					SELECT SPLIT_PART(concept_code, ' ', 1)
					FROM drug_concept_stage
					)
				AND cds.class_code NOT IN (
					SELECT SPLIT_PART(concept_code_1, ' ', 1)
					FROM internal_relationship_stage a
					JOIN concept_rx c ON c.concept_name = a.concept_code_2
						AND c.standard_concept = 'S'
						AND c.concept_class_id = 'Ingredient'
					)
				AND LENGTH(cds.class_code) = 7
				)
			OR
			-- with absent Ingredient in drug_relationship_stage
			(
				cds.class_code IN (
					SELECT SPLIT_PART(concept_code_1, ' ', 1)
					FROM internal_relationship_stage
					GROUP BY concept_code_1
					HAVING COUNT(*) = 1
					)
				AND cds.class_code NOT IN (
					SELECT SPLIT_PART(concept_code_1, ' ', 1)
					FROM internal_relationship_stage a
					JOIN concept_rx c ON UPPER(c.concept_name) = UPPER(a.concept_code_2)
						AND c.concept_class_id = 'Ingredient'
						AND c.standard_concept = 'S'
					)
				)
		),
	-- fuzzy macth using name similarity
	t2 AS (
		SELECT a.*,
			c.*
		FROM t1 a
		JOIN concept_synonym b ON UPPER(b.concept_synonym_name) LIKE '%' || UPPER(a.class_name) || '%'
		JOIN concept_rx c ON c.concept_id = b.concept_id
			AND c.concept_class_id = 'Ingredient'
			AND c.standard_concept = 'S'
		),
	-- fuzzy match WITH levenshtein
	t3 AS (
		SELECT *
		FROM t1 a
		JOIN concept_rx c ON devv5.LEVENSHTEIN(UPPER(a.class_name), UPPER(c.concept_name)) = 1
			AND c.concept_class_id = 'Ingredient'
			AND c.standard_concept = 'S'
			AND a.class_code NOT IN (
				SELECT class_code
				FROM t2
				)
		),
	-- match with non-standard and crosswalk to Standard 
	t4 AS (
		SELECT a.*,
			d.*
		FROM t1 a
		JOIN concept c ON UPPER(REGEXP_REPLACE(c.concept_name, '\s+|\W+', '', 'g')) = UPPER(TRIM(REGEXP_REPLACE(a.class_name, ';.*$|, combinations?|IN combinations?', '', 'g')))
			AND c.domain_id = 'Drug'
		JOIN concept_relationship r ON r.concept_id_1 = c.concept_id
			AND r.invalid_reason IS NULL
		JOIN concept_rx d ON d.concept_id = r.concept_id_2
			AND d.standard_concept = 'S'
			AND d.concept_class_id = 'Ingredient'
		),
	t5 AS (
		SELECT *
		FROM t1 a
		JOIN concept_rx c ON UPPER(c.concept_name) = UPPER(SUBSTRING(a.class_name, '\w+'))
			AND c.concept_class_id = 'Ingredient'
			AND c.standard_concept = 'S'
		WHERE a.class_code NOT IN (
				SELECT concept_code_1
				FROM concept_relationship_manual
				)
			AND c.concept_id NOT IN (
				19018544,
				19071128,
				1195334,
				19124906,
				19049024,
				40799093,
				19136048
				) --calcium|copper|choline|magnesium|potassium|Serum|sodium
			AND a.class_code NOT IN (
				SELECT class_code
				FROM t2
				)
			AND a.class_code NOT IN (
				SELECT class_code
				FROM t3
				)
		),
	t6 AS (
		SELECT class_code,
			concept_id,
			concept_name
		FROM t2
		
		UNION ALL
		
		SELECT class_code,
			concept_id,
			concept_name
		FROM t3
		
		UNION ALL
		
		SELECT class_code,
			concept_id,
			concept_name
		FROM t4
		
		UNION ALL
		
		SELECT class_code,
			concept_id,
			concept_name
		FROM t5
		)
SELECT DISTINCT class_code,
	concept_name
FROM t6 t
LEFT JOIN internal_relationship_stage irs ON irs.concept_code_1 = t.class_code
	AND irs.concept_code_2 = t.concept_name
WHERE irs.concept_code_1 IS NULL
	AND t.concept_id <> 43013482;-- butyl ester of methyl vinyl ether-maleic anhydride copolymer (125 kD)

ANALYZE internal_relationship_stage;

/**********************************
*** FUTHER WORK WITH ATC COMBOS ***
***********************************/
-- assemble mappings for ATC Classes indicating Ingredient Groups using the concept_ancestor AND/OR concept tables along WITH word pattern matching
-- add descendants of Acid preparations
INSERT INTO dev_combo
SELECT DISTINCT a.concept_code,
	a.concept_name,
	'acid preparations' AS class,
	c.concept_id,
	c.concept_name,
	CASE WHEN a.concept_name ILIKE 'acid%' THEN 3 ELSE 4 END AS rnk
FROM concept_manual a -- ATC
JOIN concept_ancestor ca ON ca.ancestor_concept_id = 21600704 -- ATC code of Acid preparations
JOIN concept_rx c ON c.concept_id = ca.descendant_concept_id
	AND c.concept_class_id = 'Ingredient'
WHERE SPLIT_PART(a.concept_name, ';', 1) ILIKE '%acid preparations%'
	AND a.invalid_reason IS NULL
	AND a.concept_class_id = 'ATC 5th';

-- add descendants of Sulfonamides
INSERT INTO dev_combo
SELECT DISTINCT a.concept_code,
	a.concept_name,
	'sulfonamides' AS class,
	c.concept_id,
	c.concept_name,
	CASE WHEN a.concept_name ~* '^sulfonamides|^combinations of sulfonamides' THEN 3 ELSE 4 END AS rnk
FROM concept_manual a -- ATC
JOIN concept_ancestor ca ON ca.ancestor_concept_id = 21603038 -- ATC code of sulfonamides
JOIN concept_rx c ON c.concept_id = ca.descendant_concept_id
	AND c.concept_class_id = 'Ingredient'
WHERE SPLIT_PART(a.concept_name, ';', 1) ILIKE '%sulfonamides%'
	AND SPLIT_PART(a.concept_name, ';', 1) !~* '^short-acting sulfonamides|^intermediate-acting sulfonamides|^long-acting sulfonamides'
	AND a.invalid_reason IS NULL
	AND a.concept_class_id = 'ATC 5th'
	AND EXISTS (
		SELECT 1
		FROM concept_relationship cr_int
		WHERE cr_int.concept_id_1 = ca.ancestor_concept_id
			AND cr_int.relationship_id = 'ATC - RxNorm pr lat'
			AND cr_int.invalid_reason IS NULL
		);
 
-- add descendants of Amino acids
INSERT INTO dev_combo
SELECT DISTINCT a.concept_code,
	a.concept_name,
	'amino acids',
	c.concept_id,
	c.concept_name,
	CASE WHEN SPLIT_PART(a.concept_name, ';', 1) ILIKE 'amino acids%' THEN 3 ELSE 4 END AS rnk
FROM concept_manual a -- ATC
JOIN concept_ancestor ca ON ca.ancestor_concept_id IN (
		21601215,
		21601034
		) -- 21601215	B05XB	Amino acids| 21601034	B02AA	Amino acids
JOIN concept_rx c ON c.concept_id = ca.descendant_concept_id
	AND c.concept_class_id = 'Ingredient'
WHERE SPLIT_PART(a.concept_name, ';', 1) ~* 'amino\s*acid'
	AND a.concept_code <> 'B03AD01'
	AND a.invalid_reason IS NULL
	AND a.concept_class_id = 'ATC 5th';--ferrous amino acid complex

-- add descendants of Analgesics
INSERT INTO dev_combo
SELECT DISTINCT a.concept_code,
	a.concept_name,
	'analgesics',
	c.concept_id,
	c.concept_name,
	CASE WHEN SPLIT_PART(a.concept_name, ';', 1) ILIKE 'analgesics%' THEN 3 ELSE 4 END AS rnk
FROM concept_manual a
JOIN concept_ancestor ca ON ca.ancestor_concept_id IN (21604253) -- 21604253	N02	ANALGESICS	ATC 2nd
JOIN concept_rx c ON c.concept_id = ca.descendant_concept_id
	AND c.concept_class_id = 'Ingredient'
	AND c.concept_id NOT IN (
		939506,
		950435,
		964407
		) --	sodium bicarbonate|citric acid|salicylic acid
WHERE SPLIT_PART(a.concept_name, ';', 1) ~* 'analgesics?'
	AND SPLIT_PART(a.concept_name, ';', 1) !~* '\yexcl'
	AND a.invalid_reason IS NULL
	AND a.concept_class_id = 'ATC 5th';
 
-- add ingredients indicating Animals
INSERT INTO dev_combo
SELECT DISTINCT a.concept_code,
	a.concept_name,
	'animals',
	c.concept_id,
	c.concept_name,
	CASE WHEN SPLIT_PART(a.concept_name, ';', 1) ILIKE 'animals%' THEN 3 ELSE 4 END AS rnk
FROM concept c
JOIN concept_manual a ON SPLIT_PART(a.concept_name, ';', 1) ILIKE '%Animals%'
	AND a.invalid_reason IS NULL
	AND a.concept_class_id = 'ATC 5th'
WHERE (
		c.concept_id IN (
			19091701,
			19056189,
			40170543,
			40170448,
			40170341,
			40170416,
			40175840,
			40175865,
			40170916,
			40175984,
			40161698,
			40170420,
			19095690,
			40170741,
			40170848,
			40161809,
			40161813,
			45892235,
			40171114,
			45892234,
			37496548,
			40170660,
			40172147,
			40175843,
			40175898,
			40175933,
			40171110,
			40175911,
			40171275,
			40172704,
			40171317,
			40175983,
			40171135,
			35201802,
			40238446,
			40175899,
			40227400,
			40175938,
			19061053,
			19112547,
			43013524,
			40170475,
			40170818,
			40161805,
			40167658,
			1340875,
			42903998,
			963757,
			40171594,
			37496553,
			40172160,
			35201545,
			40175931,
			35201783,
			789889,
			35201778,
			40175951,
			35201548,
			40161124,
			42709317,
			40161676,
			40161750,
			40170521,
			40161754,
			40170973,
			40170979,
			40170876,
			40175917
			)
		OR (
			c.concept_name ~* 'rabbit|\ycow\y|\ydog\y|\ycat\y|goose|\yhog\y|\ygland\y|hamster|\yduck|oyster|\yhorse\y|\ylamb|pancreas|brain|kidney|\ybone\y|heart|spleen|lungs|^Pacific|\yfish|\yegg\y|\ypork|shrimp|\yveal|\ytuna|chicken'
			AND c.concept_name ILIKE '%extract%'
			AND c.vocabulary_id LIKE 'RxNorm%'
			AND c.standard_concept = 'S'
			AND c.concept_class_id = 'Ingredient'
			AND c.concept_id NOT IN (
				46276144,
				40170814,
				40226703,
				43560374,
				40227355,
				42903998,
				40227484,
				19086386
				)
			)
		);

-- add descendants of Antiinfectives 
INSERT INTO dev_combo
SELECT DISTINCT a.concept_code,
	a.concept_name,
	'antiinfectives',
	c.concept_id,
	c.concept_name,
	CASE WHEN SPLIT_PART(a.concept_name, ';', 1) ILIKE 'antiinfectives%' THEN 3 ELSE 4 END AS rnk
FROM concept_manual a
JOIN concept_ancestor ca ON ca.ancestor_concept_id IN (
		21605189,
		21603552,
		21605145,
		21601168,
		21605188,
		21605146
		) -- Antiinfectives|	ANTIINFECTIVES|	ANTIINFECTIVES | 	Antiinfectives |	Antiinfectives
JOIN concept_rx c ON c.concept_id = ca.descendant_concept_id
	AND c.concept_class_id = 'Ingredient'
	AND c.concept_id <> 19044522 -- zinc sulfate
WHERE SPLIT_PART(a.concept_name, ';', 1) ~* 'antiinfectives?' --AND class_name ~* '\yexcl'
	AND a.invalid_reason IS NULL
	AND a.concept_class_id = 'ATC 5th';

-- add ingredients indicating Cadmium compounds
INSERT INTO dev_combo
SELECT DISTINCT a.concept_code,
	a.concept_name,
	'cadmium compounds',
	c.concept_id,
	c.concept_name,
	CASE WHEN SPLIT_PART(a.concept_name, ';', 1) ILIKE 'cadmium compounds%' THEN 3 ELSE 4 END AS rnk -- groups don't have primary lateral ings
FROM concept_manual a
JOIN concept_rx c ON c.concept_name ILIKE '%cadmium %'
	AND c.concept_class_id = 'Ingredient'
	AND c.concept_id <> 45775350
WHERE SPLIT_PART(a.concept_name, ';', 1) ~* 'cadmium compounds?' --AND class_name ~* '\yexcl'
	AND a.invalid_reason IS NULL
	AND a.concept_class_id = 'ATC 5th';

-- add ingredients indicating Calcium (different salts)
INSERT INTO dev_combo
SELECT DISTINCT a.concept_code,
	a.concept_name,
	'calcium (different salts IN combination)',
	c.concept_id,
	c.concept_name,
	CASE WHEN SPLIT_PART(a.concept_name, ';', 1) ILIKE 'calcium (different salts IN combination)%' THEN 3 ELSE 4 END AS rnk
FROM concept_manual a
JOIN concept_rx c ON c.concept_name ~* '\ycalcium\y'
	AND c.concept_class_id = 'Ingredient'
	AND c.concept_id NOT IN (
		42903945,
		43533002,
		1337191,
		19007595,
		43532262,
		19051475
		) -- calcium ion|calcium hydride|calcium hydroxide|calcium oxide|calcium peroxide|anhydrous calcium iodide
WHERE SPLIT_PART(a.concept_name, ';', 1) ILIKE '%calcium%'
	AND SPLIT_PART(a.concept_name, ';', 1) ~* '\ysalt'
	AND a.invalid_reason IS NULL
	AND a.concept_class_id = 'ATC 5th';

-- add ingredients indicating Calcium compounds
INSERT INTO dev_combo
SELECT DISTINCT a.concept_code,
	a.concept_name,
	'calcium compounds',
	c.concept_id,
	c.concept_name,
	CASE WHEN SPLIT_PART(a.concept_name, ';', 1) ILIKE 'calcium compounds%' THEN 3 ELSE 4 END AS rnk
FROM concept_manual a
JOIN concept_rx c ON c.concept_name ~* '\ycalcium\y'
	AND c.concept_class_id = 'Ingredient'
	AND c.concept_id NOT IN (
		19014944,
		42903945
		)
WHERE SPLIT_PART(a.concept_name, ';', 1) ILIKE '%calcium%'
	AND SPLIT_PART(a.concept_name, ';', 1) ~* '\ycompound'
	AND a.invalid_reason IS NULL
	AND a.concept_class_id = 'ATC 5th';

-- add descendants of Laxatives
INSERT INTO dev_combo
SELECT DISTINCT a.concept_code,
	a.concept_name,
	'contact laxatives',
	c.concept_id,
	c.concept_name,
	CASE WHEN SPLIT_PART(a.concept_name, ';', 1) ILIKE 'contact laxatives%' THEN 3 ELSE 4 END AS rnk
FROM concept_manual a
JOIN concept_ancestor ca ON ca.ancestor_concept_id = 21600537
JOIN concept_rx c ON c.concept_id = ca.descendant_concept_id
	AND c.concept_class_id = 'Ingredient'
WHERE SPLIT_PART(a.concept_name, ';', 1) ILIKE '%contact%'
	AND SPLIT_PART(a.concept_name, ';', 1) ~* 'laxatives?'
	AND a.invalid_reason IS NULL
	AND a.concept_class_id = 'ATC 5th';

-- add descendants of Corticosteroids
INSERT INTO dev_combo
SELECT DISTINCT a.concept_code,
	a.concept_name,
	'corticosteroids',
	c.concept_id,
	c.concept_name,
	CASE WHEN SPLIT_PART(a.concept_name, ';', 1) ~* '^corticosteroids?|^combinations of corticosteroids?' THEN 3 ELSE 4 END AS rnk
FROM concept_manual a
JOIN concept_ancestor ca ON ca.ancestor_concept_id IN (
		21605042,
		21605164,
		21605200,
		21605165,
		21605199,
		21601607,
		975125
		)
JOIN concept_rx c ON c.concept_id = ca.descendant_concept_id
	AND c.concept_class_id = 'Ingredient'
WHERE SPLIT_PART(a.concept_name, ';', 1) ~* 'corticosteroids?'
	AND a.invalid_reason IS NULL
	AND a.concept_class_id = 'ATC 5th';

-- add descendants of Cough suppressants
INSERT INTO dev_combo
SELECT DISTINCT a.concept_code,
	a.concept_name,
	'cough suppressants',
	c.concept_id,
	c.concept_name,
	CASE WHEN SPLIT_PART(a.concept_name, ';', 1) ~* '^cough suppressants|^other cough suppressants' THEN 3 ELSE 4 END AS rnk
FROM concept_manual a
JOIN concept_ancestor ca ON ca.ancestor_concept_id IN (
		21603440,
		21603366,
		21603409,
		21603395,
		21603436
		)
JOIN concept_rx c ON c.concept_id = ca.descendant_concept_id
	AND c.concept_class_id = 'Ingredient'
	AND c.concept_id NOT IN (
		943191,
		1139042,
		1189220,
		1781321,
		19008366,
		19039512,
		19041843,
		19050346,
		19058933,
		19071861,
		19088167,
		19095266,
		42904041
		)
WHERE SPLIT_PART(a.concept_name, ';', 1) ILIKE '%cough%'
	AND SPLIT_PART(a.concept_name, ';', 1) ~* 'suppressants?'
	AND a.invalid_reason IS NULL
	AND a.concept_class_id = 'ATC 5th';

-- add descendants of Diuretics
INSERT INTO dev_combo
SELECT DISTINCT a.concept_code,
	a.concept_name,
	'diuretics',
	c.concept_id,
	c.concept_name,
	CASE WHEN SPLIT_PART(a.concept_name, ';', 1) ILIKE 'diuretics%' THEN 3 ELSE 4 END AS rnk
FROM concept_manual a
JOIN concept_ancestor ca ON ca.ancestor_concept_id = 21601461
JOIN concept_rx c ON c.concept_id = ca.descendant_concept_id
	AND c.concept_class_id = 'Ingredient'
WHERE SPLIT_PART(a.concept_name, ';', 1) ~* 'diuretics?'
	AND a.invalid_reason IS NULL
	AND a.concept_class_id = 'ATC 5th';

-- add descendants of Magnesium (different salts IN combination)
INSERT INTO dev_combo
SELECT DISTINCT a.concept_code,
	a.concept_name,
	'magnesium (different salts IN combination)',
	c.concept_id,
	c.concept_name,
	CASE WHEN SPLIT_PART(a.concept_name, ';', 1) ILIKE 'magnesium (different salts IN combination)%' THEN 3 ELSE 4 END AS rnk
FROM concept_manual a -- ATC
JOIN concept_ancestor ca ON ca.ancestor_concept_id = 21600892
JOIN concept_rx c 
	ON c.concept_id = ca.descendant_concept_id
	AND c.concept_class_id = 'Ingredient'
WHERE SPLIT_PART(a.concept_name, ';', 1) ILIKE '%magnesium%'
	AND SPLIT_PART(a.concept_name, ';', 1) ILIKE '%salt%'
	AND a.invalid_reason IS NULL
	AND a.concept_class_id = 'ATC 5th';

-- add ingredients indicating Magnesium (different salts IN combination)
INSERT INTO dev_combo
SELECT DISTINCT a.concept_code,
	a.concept_name,
	'magnesium (different salts IN combination)',
	c.concept_id,
	c.concept_name,
	CASE WHEN SPLIT_PART(a.concept_name, ';', 1) ILIKE 'magnesium (different salts IN combination)%' THEN 3 ELSE 4 END AS rnk
FROM concept_manual a
JOIN concept_rx c ON c.concept_name LIKE '%magnesium%'
	AND c.standard_concept = 'S'
	AND c.concept_class_id = 'Ingredient'
	AND c.concept_id NOT IN (
		43532017,
		37498676
		) -- magnesium cation | magnesium Mg-28
WHERE SPLIT_PART(a.concept_name, ';', 1) ILIKE '%magnesium%'
	AND SPLIT_PART(a.concept_name, ';', 1) ILIKE '%salt%'
	AND a.invalid_reason IS NULL
	AND a.concept_class_id = 'ATC 5th'
	AND (
		a.concept_code,
		c.concept_id
		) NOT IN (
		SELECT class_code,
			concept_id
		FROM dev_combo
		);

-- add ingredients indicating Multivitamins
INSERT INTO dev_combo
SELECT DISTINCT a.concept_code,
	a.concept_name,
	'multivitamins',
	c.concept_id,
	c.concept_name,
	CASE WHEN SPLIT_PART(a.concept_name, ';', 1) ILIKE 'multivitamins%' THEN 1 ELSE 2 END AS rnk
FROM concept_manual a
JOIN concept c ON c.concept_id = 36878782
WHERE SPLIT_PART(a.concept_name, ';', 1) ~* 'multivitamins?'
	AND a.invalid_reason IS NULL
	AND a.concept_class_id = 'ATC 5th';

-- add descendants of Opium alkaloids WITH morphine
INSERT INTO dev_combo
SELECT DISTINCT a.concept_code,
	a.concept_name,
	'opium alkaloids WITH morphine',
	c.concept_id,
	c.concept_name,
	CASE WHEN SPLIT_PART(a.concept_name, ';', 1) ILIKE 'opium alkaloids WITH morphine%' THEN 3 ELSE 4 END AS rnk
FROM concept_manual a
JOIN concept_ancestor ca ON ca.ancestor_concept_id = 21604255 -- Natural opium alkaloids
JOIN concept_rx c ON c.concept_id = ca.descendant_concept_id
	AND c.concept_class_id = 'Ingredient'
	AND c.concept_id <> 19112635
WHERE SPLIT_PART(a.concept_name, ';', 1) ILIKE '%opium alkaloids WITH morphine%'
	AND a.invalid_reason IS NULL
	AND a.concept_class_id = 'ATC 5th';

-- add descendants of Opium derivatives
INSERT INTO dev_combo
SELECT DISTINCT a.concept_code,
	a.concept_name,
	'opium derivatives',
	c.concept_id,
	c.concept_name,
	CASE WHEN SPLIT_PART(a.concept_name, ';', 1) ILIKE 'opium derivatives%' THEN 3 ELSE 4 END AS rnk
FROM concept_manual a
JOIN concept_ancestor ca ON ca.ancestor_concept_id = 21603396
JOIN concept_rx c ON c.concept_id = ca.descendant_concept_id
	AND c.concept_class_id = 'Ingredient'
	AND c.concept_id NOT IN (
		19021930,
		1201620
		)
WHERE SPLIT_PART(a.concept_name, ';', 1) ILIKE '%opium derivatives%'
	AND a.invalid_reason IS NULL
	AND a.concept_class_id = 'ATC 5th';
 
-- add descendants of Organic nitrates
INSERT INTO dev_combo
SELECT DISTINCT a.concept_code,
	a.concept_name,
	'organic nitrates',
	c.concept_id,
	c.concept_name,
	CASE WHEN SPLIT_PART(a.concept_name, ';', 1) ILIKE 'organic nitrates%' THEN 3 ELSE 4 END AS rnk
FROM concept_manual a
JOIN concept_ancestor ca ON ca.ancestor_concept_id = 21600316
JOIN concept_rx c ON c.concept_id = ca.descendant_concept_id
	AND c.concept_class_id = 'Ingredient'
WHERE SPLIT_PART(a.concept_name, ';', 1) ILIKE '%organic nitrates%'
	AND a.invalid_reason IS NULL
	AND a.concept_class_id = 'ATC 5th';

-- add descendants of Psycholeptics
INSERT INTO dev_combo
SELECT a.concept_code,
	a.concept_name,
	'psycholeptics',
	c.concept_id,
	c.concept_name,
	CASE WHEN SPLIT_PART(a.concept_name, ';', 1) ILIKE 'psycholeptics%' THEN 3 WHEN SPLIT_PART(a.concept_name, ';', 1) LIKE '%excl. psycholeptics%' THEN 0 ELSE 4 END AS rnk -- 0 stands for excluded drugs
FROM concept_manual a
JOIN concept_ancestor ca ON ca.ancestor_concept_id = 21604489 -- Crotarbital|butabarbital|Phenobarbital|butalbital
JOIN concept_rx c ON c.concept_id = ca.descendant_concept_id
	AND c.concept_class_id = 'Ingredient'
	AND c.standard_concept = 'S'
	AND c.concept_id <> 742594
WHERE SPLIT_PART(a.concept_name, ';', 1) ~* 'psycholeptics?' --AND class_name NOT ILIKE '%excl. psycholeptics%'
	AND a.invalid_reason IS NULL
	AND a.concept_class_id = 'ATC 5th'

UNION

SELECT a.concept_code,
	a.concept_name,
	'psycholeptics',
	c.concept_id,
	c.concept_name,
	CASE WHEN SPLIT_PART(a.concept_name, ';', 1) ILIKE 'psycholeptics%' THEN 3 WHEN SPLIT_PART(a.concept_name, ';', 1) LIKE '%excl. psycholeptics%' THEN 0 ELSE 4 END AS rnk -- 0 stands for excluded drugs
FROM concept_manual a
JOIN concept_rx c ON c.concept_name ILIKE ANY (ARRAY 
		['%Butalbital%','%Lorazepam%','%Ethchlorvynol%','%Ziprasidone%','%Talbutal%','%Pentobarbital%','%Olanzapine%','%Clobazam%','%Clozapine%','%Meprobamate%',
		'%Sulpiride%','%Eszopiclone%','%Alprazolam%','%Loxapine%','%Remoxipride%','%Secobarbital%','%Promazine%','%Zolpidem%','%Prochlorperazine%','%Droperidol%',
		'%Methohexital%','%Chlordiazepoxide%','%Chlorpromazine%','%Buspirone%','%Haloperidol%','%Triflupromazine%','%Adinazolam%','%Hydroxyzine%','%Thiopental%',
		'%Fluphenazine%','%Dexmedetomidine%','%Thioridazine%','%Midazolam%','%Flurazepam%','%Risperidone%','%Propiomazine%','%Primidone%','%Halazepam%','%Diazepam%',
		'%Trifluoperazine%','%Oxazepam%','%Methylphenobarbital%','%Perphenazine%','%Flupentixol%','%Triazolam%','%Mesoridazine%','%Zaleplon%','%Ramelteon%',
		'%Acetophenazine%','%Melatonin%','%Pimozide%','%Methyprylon%','%Thiamylal%','%Phenobarbital%','%Zopiclone%','%Estazolam%','%Quetiapine%','%Aripiprazole%',
		'%Chlorprothixene%','%Paliperidone%','%Amobarbital%','%Aprobarbital%','%Butobarbital%','%Heptabarbital%','%Hexobarbital%','%Methotrimeprazine%','%Glutethimide%',
		'%Barbital%','%Camazepam%','%Dichloralphenazone%','%Flunitrazepam%','%Ethyl loflazepate%','%Cloxazolam%','%Bromazepam%','%Clotiazepam%','%Chloral hydrate%',
		'%Fludiazepam%','%Ketazolam%','%Prazepam%','%Quazepam%','%Cinolazepam%','%Nitrazepam%','%Periciazine%','%Acepromazine%','%Molindone%','%Pipotiazine%','%Thioproperazine%',
		'%Thiothixene%','%Zuclopenthixol%','%Methaqualone%','%Fluspirilene%','%Iloperidone%','%Cariprazine%','%Sertindole%','%Asenapine%','%Amisulpride%','%Clomethiazole%',
		'%Triclofos%','%Mebutamate%','%Tofisopam%']
		) -- obtained from https://go.drugbank.com/categories/DBCAT002185
	AND c.concept_id <> 742594
	AND c.concept_class_id = 'Ingredient'
	AND c.standard_concept = 'S'
WHERE SPLIT_PART(a.concept_name, ';', 1) ~* 'psycholeptics?' --AND class_name NOT ILIKE '%excl. psycholeptics%'
	AND a.invalid_reason IS NULL
	AND a.concept_class_id = 'ATC 5th'
	AND EXISTS (
		SELECT 1
		FROM concept_ancestor ca
		WHERE ca.descendant_concept_id = c.concept_id
		);

-- add descendants of Selenium compounds
INSERT INTO dev_combo
SELECT DISTINCT a.concept_code,
	a.concept_name,
	'selenium compounds',
	c.concept_id,
	c.concept_name,
	CASE WHEN SPLIT_PART(a.concept_name, ';', 1) ILIKE 'selenium compounds%' THEN 3 ELSE 4 END AS rnk
FROM concept_manual a
JOIN concept_ancestor ca ON ca.ancestor_concept_id = 21600908
JOIN concept_rx c ON c.concept_id = ca.descendant_concept_id
	AND c.concept_class_id = 'Ingredient'
WHERE SPLIT_PART(a.concept_name, ';', 1) ILIKE '%selenium compounds%'
	AND a.invalid_reason IS NULL
	AND a.concept_class_id = 'ATC 5th';

-- add descendants of Silver compounds
INSERT INTO dev_combo
SELECT DISTINCT a.concept_code,
	a.concept_name,
	'silver compounds',
	c.concept_id,
	c.concept_name,
	CASE WHEN SPLIT_PART(a.concept_name, ';', 1) ILIKE 'silver compounds%' THEN 3 ELSE 4 END AS rnk
FROM concept_manual a
JOIN concept_ancestor ca ON ca.ancestor_concept_id = 21602248
JOIN concept_rx c ON c.concept_id = ca.descendant_concept_id
	AND c.concept_class_id = 'Ingredient'
WHERE SPLIT_PART(a.concept_name, ';', 1) ILIKE '%silver compounds%'
	AND a.invalid_reason IS NULL
	AND a.concept_class_id = 'ATC 5th';
 
-- add ingredients indicating Silver
INSERT INTO dev_combo
SELECT DISTINCT a.concept_code,
	a.concept_name,
	'silver compounds',
	c.concept_id,
	c.concept_name,
	CASE WHEN SPLIT_PART(a.concept_name, ';', 1) ILIKE 'silver compounds%' THEN 3 ELSE 4 END AS rnk
FROM concept_manual a
JOIN concept_rx c ON c.concept_class_id = 'Ingredient'
	AND c.concept_name ~* 'silver\y'
WHERE SPLIT_PART(a.concept_name, ';', 1) ILIKE '%silver compounds%'
	AND a.invalid_reason IS NULL
	AND a.concept_class_id = 'ATC 5th'
	AND (
		'silver compounds',
		c.concept_id
		) NOT IN (
		SELECT class,
			concept_id
		FROM dev_combo
		);

-- add descendants of Sulfonylureas
INSERT INTO dev_combo
SELECT DISTINCT a.concept_code,
	a.concept_name,
	'sulfonylureas',
	c.concept_id,
	c.concept_name,
	CASE WHEN SPLIT_PART(a.concept_name, ';', 1) ~* '^sulfonylureas?' THEN 3 ELSE 4 END AS rnk
FROM concept_manual a
JOIN concept_ancestor ca ON ca.ancestor_concept_id = 21600749
JOIN concept_rx c ON c.concept_id = ca.descendant_concept_id
	AND c.concept_class_id = 'Ingredient'
WHERE SPLIT_PART(a.concept_name, ';', 1) ~* 'sulfonylureas?'
	AND a.invalid_reason IS NULL
	AND a.concept_class_id = 'ATC 5th';

-- add ingredients indicating Snake venom antiserum
INSERT INTO dev_combo
SELECT DISTINCT a.concept_code,
	a.concept_name,
	'snake venom antiserum',
	c.concept_id,
	c.concept_name,
	CASE WHEN SPLIT_PART(a.concept_name, ';', 1) ILIKE 'snake venom antiserum%' THEN 3 ELSE 4 END AS rnk
FROM concept_manual a
JOIN concept_rx c ON c.concept_class_id = 'Ingredient'
	AND c.standard_concept = 'S'
	AND c.concept_name ILIKE '%antiserum%'
	AND c.concept_name ILIKE '%snake%'
WHERE SPLIT_PART(a.concept_name, ';', 1) ILIKE '%snake venom antiserum%'
	AND a.invalid_reason IS NULL
	AND a.concept_class_id = 'ATC 5th';

-- add ingredients indicating Aluminium preparations
INSERT INTO dev_combo
SELECT DISTINCT a.concept_code,
	a.concept_name,
	'aluminium preparations',
	c.concept_id,
	c.concept_name,
	CASE WHEN SPLIT_PART(a.concept_name, ';', 1) ILIKE 'aluminium preparations%' THEN 3 ELSE 4 END AS rnk
FROM concept_manual a
JOIN concept_rx c ON c.concept_class_id = 'Ingredient'
	AND c.standard_concept = 'S'
	AND c.concept_name ~* 'aluminium|aluminum'
WHERE SPLIT_PART(a.concept_name, ';', 1) ILIKE '%aluminium preparations%'
	AND a.invalid_reason IS NULL
	AND a.concept_class_id = 'ATC 5th';
 
-- add ingredients indicating Aluminium compounds
INSERT INTO dev_combo
SELECT DISTINCT a.concept_code,
	a.concept_name,
	'aluminium compounds',
	c.concept_id,
	c.concept_name,
	CASE WHEN SPLIT_PART(a.concept_name, ';', 1) ILIKE 'aluminium compounds%' THEN 3 ELSE 4 END AS rnk
FROM concept_manual a
JOIN concept_rx c ON c.concept_class_id = 'Ingredient'
	AND c.standard_concept = 'S'
	AND c.concept_name ~* 'aluminium|aluminum'
WHERE SPLIT_PART(a.concept_name, ';', 1) ILIKE '%aluminium compounds%'
	AND a.invalid_reason IS NULL
	AND a.concept_class_id = 'ATC 5th';
 
-- add ingredients indicating Lactic acid producing organisms
INSERT INTO dev_combo
SELECT DISTINCT a.concept_code,
	a.concept_name,
	'lactic acid producing organisms',
	c.concept_id,
	c.concept_name,
	CASE WHEN SPLIT_PART(a.concept_name, ';', 1) ILIKE 'lactic acid producing organisms%' THEN 3 ELSE 4 END AS rnk
FROM concept_manual a
JOIN concept_rx c ON c.concept_class_id = 'Ingredient'
	AND c.standard_concept = 'S'
	AND c.concept_name ILIKE '%lactobacil%'
WHERE SPLIT_PART(a.concept_name, ';', 1) ILIKE '%lactic acid producing organisms%'
	AND a.invalid_reason IS NULL
	AND a.concept_class_id = 'ATC 5th';

-- add ingredients indicating Lactobacillus  
INSERT INTO dev_combo
SELECT DISTINCT a.concept_code,
	a.concept_name,
	'lactobacillus',
	c.concept_id,
	c.concept_name,
	CASE WHEN SPLIT_PART(a.concept_name, ';', 1) ILIKE 'lactobacillus%' THEN 3 ELSE 4 END AS rnk
FROM concept_manual a
JOIN concept_rx c ON c.concept_class_id = 'Ingredient'
	AND c.standard_concept = 'S'
	AND c.concept_name ILIKE '%lactobacil%'
WHERE SPLIT_PART(a.concept_name, ';', 1) ILIKE '%lactobacillus%'
	AND a.invalid_reason IS NULL
	AND a.concept_class_id = 'ATC 5th';

-- add ingredients indicating Magnesium compounds
INSERT INTO dev_combo
SELECT DISTINCT a.concept_code,
	a.concept_name,
	'magnesium compounds',
	c.concept_id,
	c.concept_name,
	CASE WHEN SPLIT_PART(a.concept_name, ';', 1) ILIKE 'magnesium compounds%' THEN 3 ELSE 4 END AS rnk
FROM concept_manual a
JOIN concept_rx c ON c.concept_class_id = 'Ingredient'
	AND c.standard_concept = 'S'
	AND c.concept_name ILIKE '%magnesium%'
WHERE SPLIT_PART(a.concept_name, ';', 1) ILIKE '%magnesium compounds%'
	AND a.invalid_reason IS NULL
	AND a.concept_class_id = 'ATC 5th';

-- add ingredients indicating Grass pollen
INSERT INTO dev_combo
SELECT DISTINCT a.concept_code,
	a.concept_name,
	'grass pollen',
	c.concept_id,
	c.concept_name,
	CASE WHEN SPLIT_PART(a.concept_name, ';', 1) ILIKE 'grass pollen%' THEN 3 ELSE 4 END AS rnk
FROM concept_manual a
JOIN concept_rx c ON c.concept_class_id = 'Ingredient'
	AND c.standard_concept = 'S'
	AND c.concept_name ILIKE '%grass%'
	AND c.concept_name ILIKE '%pollen%'
WHERE SPLIT_PART(a.concept_name, ';', 1) ILIKE '%grass pollen%'
	AND a.invalid_reason IS NULL
	AND a.concept_class_id = 'ATC 5th';

-- add ingredients indicating Oil
INSERT INTO dev_combo
SELECT DISTINCT a.concept_code,
	a.concept_name,
	'oil',
	c.concept_id,
	c.concept_name,
	3 -- hardcoded
FROM concept_manual a
JOIN concept_rx c ON c.concept_class_id = 'Ingredient'
	AND c.standard_concept = 'S'
	AND c.concept_name ~* '\yoil\y|\yoleum\y'
WHERE SPLIT_PART(a.concept_name, ';', 1) ILIKE 'oil%'
	AND a.invalid_reason IS NULL
	AND a.concept_class_id = 'ATC 5th';

-- add ingredients indicating Flowers
INSERT INTO dev_combo
SELECT DISTINCT a.concept_code,
	a.concept_name,
	'flowers',
	c.concept_id,
	c.concept_name,
	CASE WHEN SPLIT_PART(a.concept_name, ';', 1) ILIKE 'flowers%' THEN 3 ELSE 4 END AS rnk
FROM concept_manual a
JOIN concept_rx c ON c.concept_class_id = 'Ingredient'
	AND c.standard_concept = 'S'
	AND c.concept_name ~* '\yflower\y'
	AND c.concept_name ILIKE '%extract%'
WHERE SPLIT_PART(a.concept_name, ';', 1) ILIKE 'flowers%'
	AND a.invalid_reason IS NULL
	AND a.concept_class_id = 'ATC 5th';
 
-- add ingredients indicating Fumaric acid derivatives
INSERT INTO dev_combo
SELECT DISTINCT a.concept_code,
	a.concept_name,
	'fumaric acid derivatives',
	c.concept_id,
	c.concept_name,
	CASE WHEN SPLIT_PART(a.concept_name, ';', 1) ILIKE 'fumaric acid derivatives%' THEN 3 ELSE 4 END AS rnk
FROM concept_manual a
JOIN concept_rx c ON c.concept_class_id = 'Ingredient'
	AND c.standard_concept = 'S'
	AND c.concept_name ~* 'fumarate\y'
WHERE SPLIT_PART(a.concept_name, ';', 1) ILIKE '%fumaric acid derivatives%'
	AND a.invalid_reason IS NULL
	AND a.concept_class_id = 'ATC 5th';

-- add descendants of Proton pump inhibitors
INSERT INTO dev_combo
SELECT DISTINCT a.concept_code,
	a.concept_name,
	'proton pump inhibitors',
	c.concept_id,
	c.concept_name,
	CASE WHEN SPLIT_PART(a.concept_name, ';', 1) ILIKE 'proton pump inhibitors%' THEN 3 ELSE 4 END AS rnk
FROM concept_manual a
JOIN concept_ancestor ca ON ca.ancestor_concept_id = 21600095
JOIN concept_rx c ON c.concept_id = ca.descendant_concept_id
	AND c.concept_class_id = 'Ingredient'
	AND c.standard_concept = 'S'
WHERE SPLIT_PART(a.concept_name, ';', 1) ~* 'proton pump inhibitors?'
	AND a.invalid_reason IS NULL
	AND a.concept_class_id = 'ATC 5th';

-- add descendants of Thiazides
INSERT INTO dev_combo
SELECT DISTINCT a.concept_code,
	a.concept_name,
	'thiazides',
	c.concept_id,
	c.concept_name,
	CASE WHEN SPLIT_PART(a.concept_name, ';', 1) ILIKE 'thiazides%' THEN 3 ELSE 4 END AS rnk
FROM concept_manual a
JOIN concept_ancestor ca ON ca.ancestor_concept_id = 21601463
JOIN concept_rx c ON c.concept_id = ca.descendant_concept_id
	AND c.concept_class_id = 'Ingredient'
	AND c.standard_concept = 'S'
WHERE SPLIT_PART(a.concept_name, ';', 1) ILIKE '%thiazides%'
	AND a.invalid_reason IS NULL
	AND a.concept_class_id = 'ATC 5th';

-- add ingredients indicating Electrolytes
INSERT INTO dev_combo
SELECT DISTINCT a.concept_code,
	a.concept_name,
	'electrolytes',
	c.concept_id,
	c.concept_name,
	3 -- hardcoded rank for electrolytes (no 4)
FROM concept_manual a
JOIN concept_rx c ON c.concept_class_id = 'Ingredient'
	AND c.standard_concept = 'S'
	AND c.concept_name ~* ('^magnesium sulfate|^ammonium chloride|^sodium chloride|^sodium acetate|^magnesium chloride^|potassium lactate|^sodium glycerophosphate|^magnesium phosphate|^potassium chloride|^calcium chloride'
	|| '^sodium bicarbonate|^hydrochloric acid|^potassium acetate|^zinc chloride|^sodium phosphate|^potassium bicarbonate|^succinic acid|^sodium lactate|^sodium gluconate|^sodium fumarate')
WHERE SPLIT_PART(a.concept_name, ';', 1) ILIKE '%electrolytes%'
	AND a.invalid_reason IS NULL
	AND a.concept_class_id = 'ATC 5th';

-- add ingredients indicating bismuth preparations
INSERT INTO dev_combo
SELECT DISTINCT a.concept_code,
	a.concept_name,
	'bismuth preparations',
	c.concept_id,
	c.concept_name,
	3 -- hardcoded rank for bismuth preparations (no 4)
FROM concept_manual a
JOIN concept_rx c ON c.concept_class_id = 'Ingredient'
	AND c.standard_concept = 'S'
	AND c.concept_name ~* '\ybismuth'
WHERE SPLIT_PART(a.concept_name, ';', 1) ILIKE '%bismuth preparations%'
	AND a.invalid_reason IS NULL
	AND a.concept_class_id = 'ATC 5th';

-- add ingredients indicating Artificial Tears 
INSERT INTO dev_combo
SELECT DISTINCT a.concept_code,
	a.concept_name,
	'artificial tears',
	c.concept_id,
	c.concept_name,
	3 -- hardcoded rank 
FROM concept_manual a
JOIN concept_rx c ON c.standard_concept = 'S'
	AND c.concept_name ~* 'carboxymethylcellulose$|carboxypolymethylene|polyvinyl alcohol$|hydroxypropyl methylcellulose$|^hypromellose$|hydroxypropyl cellulose|^hyaluronate'
	AND c.concept_class_id = 'Ingredient'
WHERE SPLIT_PART(a.concept_name, ';', 1) ILIKE '%artificial tears%'
	AND a.invalid_reason IS NULL
	AND a.concept_class_id = 'ATC 5th';

-- add ingredients indicating Potassium-sparing agents	
INSERT INTO dev_combo
SELECT DISTINCT a.concept_code,
	a.concept_name,
	'potassium-sparing agents',
	c.concept_id,
	c.concept_name,
	CASE WHEN SPLIT_PART(a.concept_name, ';', 1) ILIKE 'potassium-sparing agents%' THEN 3 ELSE 4 END AS rnk
FROM concept_manual a
JOIN concept_rx c ON c.concept_class_id = 'Ingredient'
	AND c.standard_concept = 'S'
	AND c.concept_name ~* '\yamiloride|triamterene|spironolactone|eplerenone|finerenone|canrenone|canrenoic acid'
WHERE SPLIT_PART(a.concept_name, ';', 1) ILIKE '%potassium-sparing agents%'
	AND a.invalid_reason IS NULL
	AND a.concept_class_id = 'ATC 5th';

-- add ingredients indicating Ethiodized oil
INSERT INTO dev_combo
SELECT DISTINCT a.concept_code,
	a.concept_name,
	'ethyl esters of iodised fatty acids',
	c.concept_id,
	c.concept_name,
	1 -- hardcoded
FROM concept_manual a
JOIN concept_rx c ON c.concept_class_id = 'Ingredient'
	AND c.standard_concept = 'S'
	AND c.concept_name ILIKE '%ethiodized oil%'
WHERE SPLIT_PART(a.concept_name, ';', 1) ILIKE 'ethyl esters of iodised fatty acids%'
	AND a.invalid_reason IS NULL
	AND a.concept_class_id = 'ATC 5th';

-- add ingredients indicating Ophthalmic Antibiotics
INSERT INTO dev_combo
SELECT DISTINCT a.concept_code,
	a.concept_name,
	'antibiotics ophthalmic',
	c.concept_id,
	c.concept_name,
	3 -- hradcoded
FROM concept_manual a
JOIN concept_rx c ON c.concept_class_id = 'Ingredient'
	AND c.standard_concept = 'S'
	AND LOWER(SUBSTRING(c.concept_name, '\w+')) IN (
		'azithromycin',
		'bacitracin',
		'besifloxacin',
		'ciprofloxacin',
		'erythromycin',
		'gatifloxacin',
		'gentamicin',
		'levofloxacin',
		'moxifloxacin',
		'ofloxacin',
		'sulfacetamide',
		'tobramycin',
		'polymyxin B',
		'trimethoprim',
		'sulfacetamide',
		'neomycin',
		'gramicidin'
		)
WHERE SPLIT_PART(a.concept_name, ';', 1) ILIKE ALL (ARRAY['%antibiotics%','%combination%','%ophthalmic%'])
	AND a.invalid_reason IS NULL
	AND a.concept_class_id = 'ATC 5th';

-- add ingredients indicating Topical Antibiotics
INSERT INTO dev_combo
SELECT DISTINCT a.concept_code,
	a.concept_name,
	'antibiotics topical',
	c.concept_id,
	c.concept_name,
	4 -- hradcoded
FROM concept_manual a
JOIN concept_rx c ON c.concept_class_id = 'Ingredient'
	AND c.standard_concept = 'S'
WHERE SPLIT_PART(a.concept_name, ';', 1) ILIKE ALL (ARRAY ['%antibiotics%','%combination%','%topical%'])
	AND UPPER(c.concept_name) IN (
		'MUPIROCIN',
		'SULFACETAMIDE',
		'RETAPAMULIN',
		'SILVER SULFADIAZINE',
		'POLYMYXIN B',
		'BACITRACIN',
		'NEOMYCIN',
		'OZENOXACIN',
		'ERYTHROMYCIN',
		'MAFENIDE',
		'GENTAMICIN',
		'DEMECLOCYCLINE',
		'RETAPAMULIN',
		'CHLORTETRACYCLINE',
		'VIRGINIAMYCIN',
		'CHLORAMPHENICOL',
		'OXYTETRACYCLINE',
		'TETRACYCLINE'
		)
	AND a.invalid_reason IS NULL
	AND a.concept_class_id = 'ATC 5th';

-- add excluded Trimethoprim
INSERT INTO dev_combo
SELECT DISTINCT a.concept_code,
	a.concept_name,
	'excl. trimethoprim',
	c.concept_id,
	c.concept_name,
	0 -- hardcoded rank
FROM concept_manual a -- ATC
JOIN concept_rx c ON c.concept_class_id = 'Ingredient'
	AND c.standard_concept = 'S'
	AND c.concept_name ILIKE '%trimethoprim%'
WHERE SPLIT_PART(a.concept_name, ';', 1) ILIKE '%excl. trimethoprim%'
	AND a.invalid_reason IS NULL
	AND a.concept_class_id = 'ATC 5th';

-- perform dev_combo cleanup
-- fix Vitamin D AND analogues IN combination
UPDATE dev_combo
SET rnk = 3
WHERE rnk = 1
	AND class_code = 'A11CC20';

-- fix erroneous rnk of 1 for Ingredient groups 
UPDATE dev_combo
SET rnk = 3
WHERE class_code IN (
		SELECT class_code
		FROM dev_combo
		WHERE rnk = 3
		)
	AND class_code NOT IN (
		SELECT class_code
		FROM dev_combo
		WHERE rnk IN (
				2,
				4
				)
		)
	AND rnk = 1;

-- add missing codeine
INSERT INTO dev_combo
SELECT DISTINCT class_code,
	class_name,
	'codeine',
	1189596,
	'dihydrocodeine',
	1
FROM dev_combo
WHERE class_code = 'N02AA59';

-- remove doubling ingredients with different rank, remaining those which are Primary lateral
DELETE
FROM dev_combo
WHERE (
		class_code,
		concept_id,
		rnk
		) IN (
		SELECT a.class_code,
			a.concept_id,
			a.rnk
		FROM dev_combo a
		JOIN dev_combo b ON b.class_code = a.class_code
			AND b.concept_id = a.concept_id
			AND b.rnk = 1
		WHERE a.rnk > 1
		);

DELETE
FROM dev_combo
WHERE class_name LIKE '%antiinfectives%'
	AND rnk = 4
	AND concept_id IN (
		19010309,
		19136048,
		1036884,
		19049024,
		989878,
		961145,
		19018544,
		917006,
		914335
		);

UPDATE dev_combo
SET rnk = 3
WHERE class_name LIKE '%lactic acid producing organisms%'
	AND rnk = 4
	AND concept_name ~* 'Saccharomyces|Bacillus|Bifidobacterium|Enterococcus|Escherichia|Streptococcus';

DELETE
FROM dev_combo
WHERE class_name LIKE '%lactic acid producing organisms%'
	AND rnk = 4;

UPDATE dev_combo
SET rnk = 3
WHERE class_name LIKE '%opium derivatives%'
	AND rnk = 1;

DELETE
FROM dev_combo
WHERE class_code = 'R05FB01'
	AND class_name = 'cough suppressants and mucolytics'
	AND class = 'cough suppressants'
	AND concept_id = 19057932
	AND rnk = 3;

UPDATE dev_combo
SET rnk = 4
WHERE class_code = 'R05FB01'
	AND class_name = 'cough suppressants and mucolytics'
	AND class = 'cough suppressants'
	AND concept_id = 19071999
	AND rnk = 3;

UPDATE dev_combo
SET rnk = 4
WHERE class_code = 'J01RA02'
	AND class = 'sulfonamides'
	AND concept_id = 1790868
	AND rnk = 3;-- 1 

UPDATE dev_combo
SET rnk = 4
WHERE class_code = 'J01RA02'
	AND class = 'sulfonamides'
	AND concept_id = 1734104
	AND rnk = 3;-- 1

UPDATE dev_combo
SET rnk = 4
WHERE class_code = 'J01RA02'
	AND class = 'sulfonamides'
	AND concept_id = 1748975
	AND rnk = 3;-- 1

UPDATE dev_combo
SET rnk = 4
WHERE class_code = 'J01RA02'
	AND class = 'sulfonamides'
	AND concept_id = 1778162
	AND rnk = 3;

UPDATE dev_combo
SET rnk = 4
WHERE class_code = 'J01RA02'
	AND class = 'sulfonamides'
	AND concept_id = 1797513
	AND rnk = 3;

UPDATE dev_combo
SET rnk = 4
WHERE class_code = 'J01RA02'
	AND class = 'sulfonamides'
	AND concept_id = 1754994
	AND rnk = 3;

UPDATE dev_combo
SET rnk = 4
WHERE class_code = 'J01RA02'
	AND class = 'sulfonamides'
	AND concept_id = 1742253
	AND rnk = 3;

UPDATE dev_combo
SET rnk = 4
WHERE class_code = 'J01RA02'
	AND class = 'sulfonamides'
	AND concept_id = 1707164
	AND rnk = 3;

UPDATE dev_combo
SET rnk = 4
WHERE class_code = 'J01RA02'
	AND class = 'sulfonamides'
	AND concept_id = 1721543
	AND rnk = 3;

UPDATE dev_combo
SET rnk = 4
WHERE class_code = 'J01RA02'
	AND class = 'sulfonamides'
	AND concept_id = 923081
	AND rnk = 3;

UPDATE dev_combo
SET rnk = 4
WHERE class_code = 'J01RA02'
	AND class = 'sulfonamides'
	AND concept_id = 19023254
	AND rnk = 3;

UPDATE dev_combo
SET rnk = 4
WHERE class_code = 'J01RA02'
	AND class = 'sulfonamides'
	AND concept_id = 19024197
	AND rnk = 3;

UPDATE dev_combo
SET rnk = 4
WHERE class_code = 'J01RA02'
	AND class = 'sulfonamides'
	AND concept_id = 19037983
	AND rnk = 3;

UPDATE dev_combo
SET rnk = 4
WHERE class_code = 'J01RA02'
	AND class = 'sulfonamides'
	AND concept_id = 19070251
	AND rnk = 3;

UPDATE dev_combo
SET rnk = 4
WHERE class_code = 'J01RA02'
	AND class = 'sulfonamides'
	AND concept_id = 1836948
	AND rnk = 3;

UPDATE dev_combo
SET rnk = 4
WHERE class_code = 'J01RA02'
	AND class = 'sulfonamides'
	AND concept_id = 1702559
	AND rnk = 3;

UPDATE dev_combo
SET rnk = 4
WHERE class_code = 'R05FB02'
	AND class = 'cough suppressants'
	AND concept_id = 43012226
	AND rnk = 3;

UPDATE dev_combo
SET rnk = 4
WHERE class_code = 'R05FB02'
	AND class = 'cough suppressants'
	AND concept_id = 912362
	AND rnk = 3;

UPDATE dev_combo
SET rnk = 4
WHERE class_code = 'R05FB02'
	AND class = 'cough suppressants'
	AND concept_id = 19060831
	AND rnk = 3;

UPDATE dev_combo
SET rnk = 3
WHERE class_code = 'R05FB02'
	AND class = ''
	AND concept_id = 1140088
	AND rnk = 4;

UPDATE dev_combo
SET rnk = 4
WHERE class_code = 'R05FB02'
	AND class = 'cough suppressants'
	AND concept_id = 19063951
	AND rnk = 3;

UPDATE dev_combo
SET rnk = 4
WHERE class_code = 'R05FB02'
	AND class = 'cough suppressants'
	AND concept_id = 1103137
	AND rnk = 3;

/*******************************************
**** ADD ODDMENTS TO THE INPUT TABLES *****
********************************************/

-- add to links between ATC Classes indicating Ingredient Groups AND ATC Drug Attributes in the form of RxN/RxE Standard Ingredient names using the dev_combo table
INSERT INTO internal_relationship_stage (
	concept_code_1,
	concept_code_2
	)
SELECT DISTINCT class_code, -- ATC
	c.concept_name -- OMOP Ingredient name AS an ATC Drug Attribute code
FROM dev_combo a
JOIN concept c ON c.concept_id = a.concept_id
	AND c.standard_concept = 'S'
	AND (
		a.class_code,
		c.concept_name
		) NOT IN (
		SELECT SPLIT_PART(concept_code_1, ' ', 1),
			concept_code_2
		FROM internal_relationship_stage
		)
WHERE LENGTH(class_code) = 7
	AND rnk <> 0;

-- add more links between ATC Classes indicating Ingredient Groups AND ATC Drug Attributes in the form of RxN/RxE Standard Ingredient names using the dev_combo table
INSERT INTO internal_relationship_stage (
	concept_code_1,
	concept_code_2
	)
SELECT DISTINCT class_code, -- ATC
	c.concept_name -- OMOP Ingredient name AS an ATC Drug Attribute code
FROM dev_combo a
JOIN concept c ON UPPER(c.concept_name) = UPPER(a.concept_name)
	AND c.standard_concept = 'S'
	AND (
		a.class_code,
		c.concept_name
		) NOT IN (
		SELECT SPLIT_PART(concept_code_1, ' ', 1),
			concept_code_2
		FROM internal_relationship_stage
		)
WHERE LENGTH(class_code) = 7
	AND rnk <> 0;

-- add ATC Classes of Ingredient Groups AS Drug Products using the internal_relationship_stage and class_drugs_scraper tables
INSERT INTO drug_concept_stage (
	concept_name,
	vocabulary_id,
	concept_class_id,
	standard_concept,
	concept_code,
	possible_excipient,
	domain_id,
	valid_start_date,
	valid_end_date
	)
SELECT DISTINCT b.class_name AS concept_name,
	'ATC' AS vocabulary_id,
	'Drug Product' AS concept_class_id,
	NULL AS standard_concept,
	concept_code_1 AS concept_code,
	NULL AS possible_excipient,
	'Drug' AS domain_id,
	TO_DATE('19700101', 'YYYYMMDD') AS valid_start_date,
	TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date
FROM internal_relationship_stage a
JOIN class_drugs_scraper b ON b.class_code = SPLIT_PART(a.concept_code_1, ' ', 1)
LEFT JOIN drug_concept_stage dcs ON dcs.concept_code = a.concept_code_1
WHERE dcs.concept_code IS NULL;

-- add ATC Drug Attributes IN the form of Standard Ingredient names using the internal_relationship_stage and concept tables
INSERT INTO drug_concept_stage (
	concept_name,
	vocabulary_id,
	concept_class_id,
	standard_concept,
	concept_code,
	possible_excipient,
	domain_id,
	valid_start_date,
	valid_end_date
	)
SELECT DISTINCT concept_code_2 AS concept_name, -- ATC pseudo-attribute IN the form of OMOP Dose Form name
	'ATC' AS vocabulary_id,
	c.concept_class_id AS concept_class_id,
	NULL AS standard_concept, -- check all standard_concept values
	irs.concept_code_2 AS concept_code,
	NULL AS possible_excipient,
	'Drug' AS domain_id,
	TO_DATE('19700101', 'YYYYMMDD') AS valid_start_date,
	TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date
FROM internal_relationship_stage irs
JOIN concept_rx c ON UPPER(c.concept_name) = UPPER(irs.concept_code_2)
	AND c.concept_class_id = 'Ingredient'
	AND c.invalid_reason IS NULL
LEFT JOIN drug_concept_stage dcs ON dcs.concept_code = irs.concept_code_2
WHERE dcs.concept_code IS NULL;

ANALYZE drug_concept_stage;

-- remove dead deprecated or updated ATC codes 
DELETE
FROM internal_relationship_stage
WHERE SUBSTRING(concept_code_1, '\w+') IN (
		SELECT concept_code
		FROM concept_manual
		WHERE invalid_reason IS NOT NULL
		);

DELETE
FROM drug_concept_stage
WHERE concept_code IN (
		SELECT concept_code
		FROM concept_manual
		WHERE invalid_reason IS NOT NULL
		);

-- remove mappings of ATC Classes which are nonexistent in OMOP (old and wrong)
DELETE
FROM drug_concept_stage
WHERE concept_code IN (
		SELECT class_code
		FROM atc_inexistent
		)
	AND concept_code NOT IN (
		SELECT class_code
		FROM dev_combo
		);

DELETE
FROM internal_relationship_stage
WHERE SUBSTRING(concept_code_1, '\w+') IN (
		SELECT class_code
		FROM atc_inexistent
		)
	AND SUBSTRING(concept_code_1, '\w+') NOT IN (
		SELECT class_code
		FROM dev_combo
		)
	AND concept_code_1 !~ '\s+';

-- remove mappings which have been deprecated in concept_relationship_manual
DELETE
FROM dev_combo
WHERE class_code || concept_id IN (
		SELECT a.class_code || c.concept_id
		FROM dev_combo a
		JOIN concept c ON c.concept_id = a.concept_id
		JOIN concept_relationship_manual crm ON crm.concept_code_1 = a.class_code
			AND crm.concept_code_2 = c.concept_code
			AND crm.relationship_id IN (
				'ATC - RxNorm pr lat',
				'ATC - RxNorm sec up',
				'ATC - RxNorm pr up',
				'ATC - RxNorm sec lat'
				)
			AND crm.invalid_reason IS NOT NULL
		);

-- clean up sulfonamides
DELETE
FROM dev_combo
WHERE class_code || concept_id NOT IN (
		SELECT class_code || concept_id
		FROM dev_combo
		WHERE class_name LIKE '%sulfonamides%'
			AND (
				concept_id IN (
					SELECT concept_id
					FROM dev_combo
					WHERE class_code = 'J01EB20'
					)
				OR concept_name ILIKE 'sulfa%'
				)
			AND rnk = 3
		)
	AND class_name LIKE '%sulfonamides%'
	AND rnk = 3;-- 16 

-- add missing sulfonamides
INSERT INTO dev_combo
WITH t1
AS (
	SELECT concept_id,
		concept_name,
		rnk
	FROM dev_combo
	WHERE class_name LIKE '%sulfonamides%'
		AND (
			concept_id IN (
				SELECT concept_id
				FROM dev_combo
				WHERE class_code = 'J01EB20'
				)
			OR concept_name ILIKE 'sulfa%'
			)
		AND rnk = 3
	)
SELECT DISTINCT class_code,
	class_name,
	'sulfonamides',
	b.*
FROM dev_combo a
CROSS JOIN t1 b
WHERE a.class_name LIKE '%sulfonamides%'
	AND class_code || b.concept_id NOT IN (
		SELECT class_code || concept_id
		FROM dev_combo
		);--40

-- assign correct rnk 529303	798304	diphtheria toxoid vaccine, inactivated
UPDATE dev_combo
SET rnk = 2
WHERE concept_id = 529303
	AND class_code = 'J07AM51';

-- remove wrong rank for the Mono ATC of B03AD02	ferrous fumarate, combinations
DELETE
FROM dev_combo
WHERE class_code = 'B03AD02'
	AND rnk = 2;

-- remove duplicates (to do: prevent the entry of duplicates in previous steps)
DELETE
FROM dev_combo d
WHERE EXISTS (
		SELECT 1
		FROM dev_combo d_int
		WHERE d_int.class_code = d.class_code
			AND d_int.class_name = d.class_name
			AND d_int.concept_id = d.concept_id
			AND d_int.rnk = d.rnk
			AND d_int.ctid > d.ctid
		);

/***************************************
******* relationship_to_concept ********
****************************************/

-- add mappings of ATC Drug Attributes to OMOP Equivalents (Standard for the Ingredients and valid for the Dose Forms)
INSERT INTO relationship_to_concept (
	concept_code_1,
	vocabulary_id_1,
	concept_id_2
	)
SELECT DISTINCT irs.concept_code_2 AS concept_code_1, -- ATC attribute IN the form of OMOP Dose Form OR Ingredient name
	'ATC' AS vocabulary_id_1,
	c.concept_id AS concept_id_2 -- OMOP concept_id
FROM internal_relationship_stage irs
JOIN concept_rx c ON UPPER(c.concept_name) = UPPER(irs.concept_code_2)
	AND c.invalid_reason IS NULL;-- 5699

--clean up
DROP TABLE concept_rx,
	dev_form,
	atc_to_form;

-- run load_interim.sql