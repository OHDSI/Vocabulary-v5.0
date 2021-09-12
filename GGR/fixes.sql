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
**************************************************************************/

--Remove devices from our tables
UPDATE drug_concept_stage
SET concept_class_id = 'Device',
	domain_id = 'Device',
	standard_concept = 'S'
WHERE concept_code IN (
		SELECT DRUG_CONCEPT_CODE
		FROM dsfix
		WHERE device IS NOT NULL
		);

DELETE
FROM internal_relationship_stage
WHERE concept_code_1 IN (
		SELECT DRUG_CONCEPT_CODE
		FROM dsfix
		WHERE device IS NOT NULL
		);

DROP TABLE IF EXISTS generated_concepts;
CREATE TABLE generated_concepts AS

SELECT 'OMOP' || nextval('conc_stage_seq') AS concept_code,
	ingredient_concept_name AS concept_name,
	mapped_id
FROM (
	SELECT DISTINCT ingredient_concept_name,
		mapped_id
	FROM dsfix
	WHERE mapped_id IS NOT NULL
	) AS s0;


INSERT INTO drug_concept_stage
SELECT DISTINCT concept_name,
	'GGR' AS vocabulary_ID,
	'Ingredient' AS concept_class_id,
	'Stof' AS source_concept_class_id,
	'S' AS standard_concept,
	concept_code,
	NULL AS possible_excipient,
	'Drug' AS domain_id,
	CURRENT_DATE AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM generated_concepts;

INSERT INTO internal_relationship_stage
SELECT DISTINCT d.drug_concept_code,
	coalesce(d.ingredient_concept_code, g.concept_code)
FROM dsfix d
LEFT JOIN generated_concepts g ON d.ingredient_concept_name = g.concept_name
WHERE d.device IS NULL;

INSERT INTO ds_stage (
	drug_concept_code,
	ingredient_concept_code,
	amount_value,
	amount_unit,
	numerator_value,
	numerator_unit,
	denominator_value,
	denominator_unit,
	box_size
	)
SELECT DISTINCT d.drug_concept_code,
	coalesce(d.ingredient_concept_code, g.concept_code) AS ingredient_concept_code,
	d.amount_value::FLOAT,
	d.amount_unit,
	d.numerator_value::FLOAT,
	d.numerator_unit,
	d.denominator_value::FLOAT,
	d.denominator_unit,
	d.box_size
FROM dsfix d
LEFT JOIN generated_concepts g ON d.ingredient_concept_name = g.concept_name
WHERE d.device IS NULL
	AND coalesce(amount_value, numerator_value) IS NOT NULL;;

INSERT INTO concept_synonym_stage
SELECT NULL::int4 AS synonym_concept_id,
	concept_name AS synonym_concept_name,
	concept_code AS synonym_concept_code,
	'GGR' AS vocabulary_ID,
	4180186 AS language_concept_id --English
FROM generated_concepts

UNION

SELECT NULL::int4 AS synonym_concept_id,
	concept_name AS synonym_concept_name,
	concept_code AS synonym_concept_code,
	'GGR' AS vocabulary_ID,
	4180190 AS language_concept_id --French
FROM generated_concepts

UNION

SELECT NULL::int4 AS synonym_concept_id,
	concept_name AS synonym_concept_name,
	concept_code AS synonym_concept_code,
	'GGR' AS vocabulary_ID,
	4182503 AS language_concept_id --Dutch
FROM generated_concepts;

INSERT INTO relationship_to_concept
SELECT DISTINCT concept_code AS concept_code_1,
	'GGR' AS vocabulary_id_1,
	mapped_id AS concept_id_2,
	1 AS precedence,
	NULL::FLOAT AS conversion_factor
FROM generated_concepts;

DELETE
FROM drug_concept_stage
WHERE concept_code IN (
		-- we have deprecated some Drug Products as Devices, so we remove them
		SELECT a.concept_code
		FROM drug_concept_stage a
		LEFT JOIN internal_relationship_stage b ON a.concept_code = b.concept_code_2
		WHERE a.concept_class_id = 'Brand Name'
			AND b.concept_code_1 IS NULL
		);

DROP TABLE IF EXISTS code_replace;
CREATE TABLE code_replace AS
SELECT 'OMOP' || nextval('new_vocab') AS new_code,
	concept_code AS old_code
FROM (
	SELECT concept_code
	FROM drug_concept_stage
	WHERE concept_code LIKE 'OMOP%'
	GROUP BY concept_code
	ORDER BY LPAD(concept_code, 50, '0')
	) AS s0;

UPDATE drug_concept_stage a
SET concept_code = b.new_code
FROM code_replace b
WHERE a.concept_code = b.old_code;

UPDATE relationship_to_concept a
SET concept_code_1 = b.new_code
FROM code_replace b
WHERE a.concept_code_1 = b.old_code;

UPDATE ds_stage a
SET ingredient_concept_code = b.new_code
FROM code_replace b
WHERE a.ingredient_concept_code = b.old_code;

UPDATE ds_stage a
SET drug_concept_code = b.new_code
FROM code_replace b
WHERE a.drug_concept_code = b.old_code;

UPDATE internal_relationship_stage a
SET concept_code_1 = b.new_code
FROM code_replace b
WHERE a.concept_code_1 = b.old_code;

UPDATE internal_relationship_stage a
SET concept_code_2 = b.new_code
FROM code_replace b
WHERE a.concept_code_2 = b.old_code;

UPDATE pc_stage a
SET drug_concept_code = b.new_code
FROM code_replace b
WHERE a.drug_concept_code = b.old_code;

UPDATE drug_concept_stage
SET standard_concept = NULL
WHERE concept_code IN (
		SELECT concept_code
		FROM drug_concept_stage
		JOIN internal_relationship_stage ON concept_code_1 = concept_code
		WHERE concept_class_id = 'Ingredient'
			AND standard_concept IS NOT NULL
		);
update 
ds_stage
set box_size = null
where box_size = '1';


update 
pc_stage
set box_size = null
where box_size = '1';
