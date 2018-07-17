/**************************************************************************
* Copyright 2016 Observational Health Data Sciences AND Informatics (OHDSI)
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
* Authors: Christian Reich, Timur Vakhitov
* DATE: 2017
**************************************************************************/

/*********************************************
* Script to CREATE input TABLEs according to *
* http://www.ohdsi.org/web/wiki/doku.php?id=documentation:international_drugs *
* for HCPCS procedure drugs                  *
*********************************************/
CREATE OR REPLACE FUNCTION ProcedureDrug()
  RETURNS void
AS
$BODY$
BEGIN
	-- CREATE products
	DROP TABLE IF EXISTS DRUG_CONCEPT_STAGE;
	CREATE UNLOGGED TABLE DRUG_CONCEPT_STAGE
	(
		domain_id            VARCHAR (20),
		concept_name         VARCHAR (255),
		vocabulary_id        VARCHAR (20),
		concept_class_id     VARCHAR (20),
		concept_code         VARCHAR (255),  -- need a long one because Ingredient AND Dose Form string used AS concept_code
		possible_excipient   VARCHAR (1),
		valid_start_date     DATE,
		valid_end_date       DATE,
		invalid_reason       VARCHAR (1),
		dose_form            VARCHAR (20)   -- temporary till we CREATE relationships, then dropped
	);

	DROP TABLE IF EXISTS RELATIONSHIP_TO_CONCEPT;
	CREATE UNLOGGED TABLE RELATIONSHIP_TO_CONCEPT
	(
		concept_code_1      VARCHAR (255),
		concept_id_2        INTEGER,
		precedence          INTEGER,
		conversion_factor   FLOAT,
		CONSTRAINT r2c_uq_cc1_cid2 UNIQUE (concept_code_1, concept_id_2),
		CONSTRAINT r2c_uq2_cc1_cid2 UNIQUE (concept_code_1, precedence)
	);

	DROP TABLE IF EXISTS INTERNAL_RELATIONSHIP_STAGE;
	CREATE UNLOGGED TABLE INTERNAL_RELATIONSHIP_STAGE
	(
		concept_code_1   VARCHAR (255),
		concept_code_2   VARCHAR (255)
	);

	DROP TABLE IF EXISTS DS_STAGE;
	CREATE UNLOGGED TABLE DS_STAGE
	(
		drug_concept_code         VARCHAR (255), -- The source code of the Drug or Drug Component, either Branded or Clinical.
		ingredient_concept_code   VARCHAR (255), -- The source code for one of the Ingredients.
		amount_value              FLOAT,         -- The numeric value for absolute content (usually solid formulations).
		amount_unit               VARCHAR (255), -- The verbatim unit of the absolute content (solids).
		numerator_value           FLOAT,         -- The numerator value for a concentration (usally liquid formulations).
		numerator_unit            VARCHAR (255), -- The verbatim numerator unit of a concentration (liquids).
		denominator_value         FLOAT,         -- The denominator value for a concentration (usally liquid formulations).
		denominator_unit          VARCHAR (255), -- The verbatim denominator unit of a concentration (liquids).
		box_size                  INTEGER
	);

	/************************************
	* 1. CREATE Procedure Drug products *
	*************************************/
	INSERT INTO drug_concept_stage (
		concept_name,
		domain_id,
		vocabulary_id,
		concept_class_id,
		concept_code,
		possible_excipient,
		valid_start_date,
		valid_end_date,
		invalid_reason,
		dose_form
		)
	SELECT *
	FROM (
		SELECT DISTINCT concept_name,
			'Drug' AS domain_id,
			'HCPCS' AS vocabulary_id,
			'Procedure Drug' AS concept_class_id,
			concept_code,
			NULL AS possible_excipient,
			NULL::DATE AS valid_start_date,
			NULL::DATE AS valid_end_date,
			NULL AS invalid_reason,
			CASE 
				-- things that look like procedure drugs but are not
				WHEN concept_name ilike '%dialysate%'
					THEN 'Device'
				WHEN concept_name ilike 'platelets%'
					THEN 'Device'
				WHEN concept_name ilike 'red blood cells, %'
					THEN 'Device'
				WHEN concept_name ilike 'whole blood%'
					THEN 'Device'
				WHEN concept_name ilike 'granulocytes, %'
					THEN 'Device'
				WHEN concept_name ilike '%pharma supply fee%'
					THEN 'Observation'
				WHEN concept_name ilike 'plasma, %'
					THEN 'Device'
				WHEN concept_name ilike '%frozen plasma%'
					THEN 'Device'
				WHEN concept_name ilike '%nutrition%'
					THEN 'Device'
				WHEN concept_name ilike '%insulin%delivery%device%'
					THEN 'Device'
				WHEN concept_name ilike 'injection%procedure%'
					THEN 'Procedure'
				WHEN concept_name ilike '%ocular implant%'
					THEN 'Device'
				WHEN concept_name ilike '%cochlear implant%'
					THEN 'Device'
				WHEN concept_name ilike '%implant system%'
					AND concept_name NOT ilike '%contraceptive%'
					THEN 'Device'
				WHEN concept_name ilike '%porcine implant%'
					THEN 'Device'
				WHEN concept_name ilike '%eye patch%'
					THEN 'Device'
				WHEN concept_name ilike '%, per visit%'
					THEN 'Procedure'
				WHEN concept_name ilike '%contrast agent%'
					THEN 'Device'
				WHEN concept_name ilike '%contrast material%'
					THEN 'Device'
				WHEN concept_name ilike '%diagnostic%, per %millicurie%'
					THEN 'Device'
				WHEN concept_name ilike '%diagnostic%, per %microcurie%'
					THEN 'Device'
				WHEN concept_name ilike '%diagnostic%up to%millicurie%'
					THEN 'Device'
				WHEN concept_name ilike '%diagnostic%up to%microcurie%'
					THEN 'Device'
				/*WHEN concept_name ilike '%iodine i-131%'
					THEN 'Device'*/
				WHEN concept_name ilike '%technetium%'
					THEN 'Device'
				WHEN concept_name ilike '%dermal%substitute%'
					THEN 'Device'
				WHEN concept_name ilike '%document%'
					THEN 'Observation'
				WHEN concept_name ilike '%enteral formula%'
					THEN 'Device'
				WHEN concept_name ilike '%vaccine status%'
					THEN 'Observation'
				WHEN concept_name ilike '%ordered%'
					THEN 'Observation'
				WHEN concept_name ilike '%prescribed%'
					THEN 'Observation'
				WHEN concept_name ilike '%patient%'
					THEN 'Observation'
				WHEN concept_name ilike '%person%'
					THEN 'Observation'
				WHEN concept_name ilike '%supply fee%'
					THEN 'Observation'
				WHEN concept_name ilike '%matrix%'
					THEN 'Device'
						-- remove inhalant solutions before designating "administered" AS Observation
				WHEN concept_name ilike '%suppository%'
					THEN 'Suppository'
				WHEN concept_name ilike '%injection%'
					THEN 'Injection'
				WHEN concept_name ilike '%capsul%therapeutic%'
					THEN 'Oral'
				WHEN concept_name ilike '%therapeutic%'
					AND concept_name NOT ilike '%caps%'
					THEN 'Injection'
				WHEN concept_name ilike '%inhalation solution%'
					THEN 'Inhalant'
						-- resume taking out non-drug
				WHEN concept_name ilike '%infusion pump%'
					THEN 'Device'
				WHEN concept_name ilike '%administered%'
					AND concept_name NOT ilike '%through dme%'
					AND concept_name NOT ilike '%vaccine%'
					THEN 'Observation'
						-- Procedure drug definitions
				WHEN concept_name ilike '%vaccine%'
					THEN 'Vaccine'
				WHEN concept_name ilike '%immunization%'
					THEN 'Vaccine'
				WHEN concept_name ilike '%dextrose%'
					THEN 'Unknown'
				WHEN concept_name ilike '%nasal spray, %'
					THEN 'Spray'
				WHEN concept_name ilike '%patch, %'
					THEN 'Patch'
				WHEN concept_name ilike 'infusion, %'
					THEN 'Infusion'
				WHEN concept_name ilike '% patch%'
					THEN 'Patch'
				WHEN concept_name ilike '%parenteral, %'
					THEN 'Parenteral' -- ilike Injection, but different parsing. After Ingredient parsing changed to Injection
				WHEN concept_name ilike '%topical, %'
					THEN 'Topical'
				WHEN concept_name ilike '%for topical%'
					THEN 'Topical'
				WHEN concept_name ~* 'implant|intrauterine'
					THEN 'Implant'
				WHEN concept_name ilike '%oral, %'
					THEN 'Oral'
				WHEN concept_name ilike '%, oral%'
					THEN 'Oral'
				WHEN lower(concept_name) = 'netupitant 300 mg and palonosetron 0.5 mg'
					THEN 'Oral'
				WHEN concept_name ilike '% per i.u.%'
					THEN 'Unit' -- ilike Injection, but different parsing. After Ingredient parsing to Injection
				WHEN concept_name ilike '%, each unit%'
					THEN 'Unit' -- ilike Injection, but different parsing. After Ingredient parsing to Injection
				WHEN concept_name ilike '% per instillation%'
					THEN 'Instillation'
				WHEN concept_name ilike '%per dose'
					THEN 'Unknown'
				WHEN concept_name ~* 'cd54\+ cell'
					THEN 'Unknown'
				WHEN concept_name ~* '([;,] |per |up to )[0-9\.,]+ ?(g|mg|ml|microgram|units?|cc)'
					THEN 'Unknown'
				WHEN concept_name = 'Factor xiii (antihemophilic factor, recombinant), tretten, per 10 i.u.'
					THEN 'Injection' --C9134
				END AS dose_form -- will be turned into a relationship
		FROM concept_stage
		WHERE vocabulary_id = 'HCPCS'
		) AS s0
	WHERE dose_form IS NOT NULL
		AND dose_form NOT IN (
			'Device',
			'Procedure',
			'Observation'
			);

	/*******************************
	* 2. CREATE parsed Ingredients *
	********************************/
	-- Fix spelling so parser will find
	UPDATE drug_concept_stage SET concept_name = regexp_replace(lower(concept_name), 'insulin,', 'insulin','g') WHERE concept_name ilike '%insulin%';
	UPDATE drug_concept_stage SET concept_name = regexp_replace(lower(concept_name), 'albuterol.+?ipratropium bromide, ', 'albuterol/ipratropium bromide ','g') WHERE concept_name ilike '%albuterol%ipratropium%';
	UPDATE drug_concept_stage SET concept_name = regexp_replace(lower(concept_name), 'doxorubicin hydrochloride, liposomal', 'doxorubicin hydrochloride liposomal','g') WHERE concept_name ilike '%doxorubicin%';
	UPDATE drug_concept_stage SET concept_name = regexp_replace(lower(concept_name), 'injectin,', 'injection','g') WHERE concept_name ilike 'injectin%';
	UPDATE drug_concept_stage SET concept_name = regexp_replace(lower(concept_name), 'interferon,', 'interferon','g') WHERE concept_name ilike '%interferon%';

	-- Insert new ingredients
	INSERT INTO drug_concept_stage
	-- Injections
	SELECT NULL AS concept_name,
		'Drug' AS domain_id,
		'HCPCS' AS vocabulary_id,
		'Ingredient' AS concept_class_id,
		CASE 
			WHEN concept_name ~ 'Hyaluronan|Ustekinumab'
				THEN SUBSTRING(lower(concept_name), '\w+')
			ELSE regexp_replace(regexp_replace(lower(concept_name), 'injection,? (iv, )?([^,]+).*', '\1|\2', 'g'), '.*?\|(.+)', '\1', 'g')
			END AS concept_code,
		NULL AS possible_excipient,
		NULL::DATE AS valid_start_date,
		NULL::DATE AS valid_end_date,
		NULL AS invalid_reason,
		NULL AS dose_form
	FROM drug_concept_stage
	WHERE dose_form = 'Injection'
		AND concept_name NOT LIKE '%therapeutic%curie%'
	UNION
	-- Injections, radiopharmaceuticals
	SELECT NULL AS concept_name,
		'Drug' AS domain_id,
		'HCPCS' AS vocabulary_id,
		'Ingredient' AS concept_class_id,
		trim(regexp_replace(regexp_replace(lower(concept_name), ',.*', '', 'g'), 'solution|suspension', '', 'g')) AS concept_code,
		NULL AS possible_excipient,
		NULL::DATE AS valid_start_date,
		NULL::DATE AS valid_end_date,
		NULL AS invalid_reason,
		NULL AS dose_form
	FROM drug_concept_stage
	WHERE dose_form = 'Injection'
		AND concept_name LIKE '%therapeutic%curie%'
	UNION
	-- Vaccines
	SELECT NULL AS concept_name,
		'Drug' AS domain_id,
		'HCPCS' AS vocabulary_id,
		'Ingredient' AS concept_class_id,
		regexp_replace(regexp_replace(lower(concept_name), '(.+?vaccine)(.+?for intramuscular use \(.+?\))?(.+vaccine)?', '\1\2','g'), '.+ of ', '','g') AS concept_code,
		NULL AS possible_excipient,
		NULL AS valid_start_date,
		NULL AS valid_end_date,
		NULL AS invalid_reason,
		NULL AS dose_form
	FROM drug_concept_stage
	WHERE dose_form = 'Vaccine'
	UNION
	-- Orals
	SELECT NULL AS concept_name,
		'Drug' AS domain_id,
		'HCPCS' AS vocabulary_id,
		'Ingredient' AS concept_class_id,
		lower(substring(c1_cleanname, '[^,]+')) AS concept_code,
		NULL AS possible_excipient,
		NULL AS valid_start_date,
		NULL AS valid_end_date,
		NULL AS invalid_reason,
		NULL AS dose_form
	FROM (
		SELECT concept_name,
			regexp_replace(concept_name, ',?;? ?oral,? ?', ', ','g') AS c1_cleanname
		FROM drug_concept_stage
		WHERE dose_form = 'Oral'
			AND concept_name NOT LIKE '%netupitant%'
		) AS s0
	UNION
	-- Units
	SELECT NULL AS concept_name,
		'Drug' AS domain_id,
		'HCPCS' AS vocabulary_id,
		'Ingredient' AS concept_class_id,
		regexp_replace(lower(concept_name), '(.+?),? ?(per|each) (unit|i.u.).*', '\1','g') AS concept_code,
		NULL AS possible_excipient,
		NULL AS valid_start_date,
		NULL AS valid_end_date,
		NULL AS invalid_reason,
		NULL AS dose_form
	FROM drug_concept_stage
	WHERE dose_form = 'Unit'
	UNION
	-- Instillations
	SELECT NULL AS concept_name,
		'Drug' AS domain_id,
		'HCPCS' AS vocabulary_id,
		'Ingredient' AS concept_class_id,
		regexp_replace(lower(concept_name), '(.+?),? ?per instillation.*', '\1','g') AS concept_code,
		NULL AS possible_excipient,
		NULL AS valid_start_date,
		NULL AS valid_end_date,
		NULL AS invalid_reason,
		NULL AS dose_form
	FROM drug_concept_stage
	WHERE dose_form = 'Instillation'
	UNION
	-- Patches
	SELECT NULL AS concept_name,
		'Drug' AS domain_id,
		'HCPCS' AS vocabulary_id,
		'Ingredient' AS concept_class_id,
		regexp_replace(regexp_replace(lower(concept_name), '(.+?),? ?(per )?patch.*', '\1','g'), '\d+(%| ?mg)', '','g') AS concept_code,
		NULL AS possible_excipient,
		NULL AS valid_start_date,
		NULL AS valid_end_date,
		NULL AS invalid_reason,
		NULL AS dose_form
	FROM drug_concept_stage
	WHERE dose_form = 'Patch'
	UNION
	-- Sprays
	SELECT NULL AS concept_name,
		'Drug' AS domain_id,
		'HCPCS' AS vocabulary_id,
		'Ingredient' AS concept_class_id,
		regexp_replace(lower(concept_name), '(.+?),? ?(nasal )?spray.*', '\1','g') AS concept_code,
		NULL AS possible_excipient,
		NULL AS valid_start_date,
		NULL AS valid_end_date,
		NULL AS invalid_reason,
		NULL AS dose_form
	FROM drug_concept_stage
	WHERE dose_form = 'Spray'
	UNION
	-- Infusions
	SELECT NULL AS concept_name,
		'Drug' AS domain_id,
		'HCPCS' AS vocabulary_id,
		'Ingredient' AS concept_class_id,
		regexp_replace(lower(concept_name), 'infusion,? (.+?) ?,.*', '\1','g') AS concept_code,
		NULL AS possible_excipient,
		NULL AS valid_start_date,
		NULL AS valid_end_date,
		NULL AS invalid_reason,
		NULL AS dose_form
	FROM drug_concept_stage
	WHERE dose_form = 'Infusion'
	UNION
	-- Guess Topicals
	SELECT NULL AS concept_name,
		'Drug' AS domain_id,
		'HCPCS' AS vocabulary_id,
		'Ingredient' AS concept_class_id,
		regexp_replace(lower(concept_name), '(.+?)(, | for )topical.*', '\1','g') AS concept_code,
		NULL AS possible_excipient,
		NULL AS valid_start_date,
		NULL AS valid_end_date,
		NULL AS invalid_reason,
		NULL AS dose_form
	FROM drug_concept_stage
	WHERE dose_form = 'Topical'
	UNION
	-- Implants
	SELECT NULL AS concept_name,
		'Drug' AS domain_id,
		'HCPCS' AS vocabulary_id,
		'Ingredient' AS concept_class_id,
		regexp_replace(lower(concept_name), '(.+?), implant.*', '\1','g') AS concept_code,
		NULL AS possible_excipient,
		NULL AS valid_start_date,
		NULL AS valid_end_date,
		NULL AS invalid_reason,
		NULL AS dose_form
	FROM drug_concept_stage
	WHERE dose_form = 'Implant'
	UNION
	-- Parenterals
	SELECT NULL AS concept_name,
		'Drug' AS domain_id,
		'HCPCS' AS vocabulary_id,
		'Ingredient' AS concept_class_id,
		regexp_replace(lower(concept_name), '(.+?), parenteral.*', '\1','g') AS concept_code,
		NULL AS possible_excipient,
		NULL AS valid_start_date,
		NULL AS valid_end_date,
		NULL AS invalid_reason,
		NULL AS dose_form
	FROM drug_concept_stage
	WHERE dose_form = 'Parenteral'
	UNION
	-- Suppositories
	SELECT NULL AS concept_name,
		'Drug' AS domain_id,
		'HCPCS' AS vocabulary_id,
		'Ingredient' AS concept_class_id,
		regexp_replace(lower(concept_name), '(.+?),? ?(urethral )?(rectal\/)?suppository.*', '\1','g') AS concept_code,
		NULL AS possible_excipient,
		NULL AS valid_start_date,
		NULL AS valid_end_date,
		NULL AS invalid_reason,
		NULL AS dose_form
	FROM drug_concept_stage
	WHERE dose_form = 'Suppository'
	UNION
	-- Inhalant
	SELECT NULL AS concept_name,
		'Drug' AS domain_id,
		'HCPCS' AS vocabulary_id,
		'Ingredient' AS concept_class_id,
		regexp_replace(lower(concept_name), '(.+?),? ?(administered AS )?(all formulations including separated isomers, )?inhalation solution.*', '\1','g') AS concept_code,
		NULL AS possible_excipient,
		NULL AS valid_start_date,
		NULL AS valid_end_date,
		NULL AS invalid_reason,
		NULL AS dose_form
	FROM drug_concept_stage
	WHERE dose_form = 'Inhalant'
	UNION
	-- Unknown
	SELECT NULL AS concept_name,
		'Drug' AS domain_id,
		'HCPCS' AS vocabulary_id,
		'Ingredient' AS concept_class_id,
		regexp_replace(regexp_replace(lower(concept_name), '(.+?)(, |; | \(?for | gel |sinus implant| implant| per).*', '\1','g'), '(administration AND supply of )?(.+)', '\2','g') AS concept_code,
		NULL AS possible_excipient,
		NULL AS valid_start_date,
		NULL AS valid_end_date,
		NULL AS invalid_reason,
		NULL AS dose_form
	FROM drug_concept_stage
	WHERE dose_form = 'Unknown';

	-- CREATE relationships between Procedure Drugs AND its parsed ingredients
	-- Injections
	INSERT INTO internal_relationship_stage
	SELECT concept_code AS concept_code_1,
		CASE 
			WHEN concept_name ~ 'Hyaluronan|Ustekinumab'
				THEN substring(lower(concept_name), '\w+')
			ELSE regexp_replace(regexp_replace(lower(concept_name), 'injection,? (iv, )?([^,]+).*', '\1|\2', 'g'), '.*?\|(.+)', '\1', 'g')
			END AS concept_code_2
	FROM drug_concept_stage
	WHERE dose_form = 'Injection'
		AND concept_name NOT LIKE '%therapeutic%curie%'
	UNION ALL
	-- Injections,radiopharmaceuticals
	SELECT concept_code AS concept_code_1,
		trim(regexp_replace(regexp_replace(lower(concept_name), ',.*', '', 'g'), 'solution|suspension', '', 'g')) AS concept_code_2
	FROM drug_concept_stage
	WHERE dose_form = 'Injection'
		AND concept_name LIKE '%therapeutic%curie%'
	UNION ALL
	-- Vaccines
	SELECT concept_code AS concept_code_1,
		regexp_replace(regexp_replace(lower(concept_name), '(.+?vaccine)(.+?for intramuscular use \(.+?\))?(.+vaccine)?', '\1\2','g'), '.+ of ', '','g') AS concept_code_2
	FROM drug_concept_stage
	WHERE dose_form = 'Vaccine'
	UNION ALL
	-- Orals
	SELECT concept_code AS concept_code_1,
		lower(substring(c1_cleanname, '[^,]+')) AS concept_code_2
	FROM (
		SELECT concept_code,
			vocabulary_id,
			regexp_replace(concept_name, ',?;? ?oral,? ?', ', ','g') AS c1_cleanname
		FROM drug_concept_stage
		WHERE dose_form = 'Oral'
			AND NOT concept_name ~* 'palonosetron|iodine i-131'
		) AS s0
	UNION ALL
	-- Units
	SELECT concept_code AS concept_code_1,
		regexp_replace(lower(concept_name), '(.+?),? ?(per|each) (unit|i.u.).*', '\1','g') AS concept_code_2
	FROM drug_concept_stage
	WHERE dose_form = 'Unit'
	UNION ALL
	-- Instillations
	SELECT concept_code AS concept_code_1,
		regexp_replace(lower(concept_name), '(.+?),? ?per instillation.*', '\1','g') AS concept_code_2
	FROM drug_concept_stage
	WHERE dose_form = 'Instillation'
	UNION ALL
	-- Patches
	SELECT concept_code AS concept_code_1,
		regexp_replace(regexp_replace(lower(concept_name), '(.+?),? ?(per )?patch.*', '\1','g'), '\d+(%| ?mg)', '','g') AS concept_code_2
	FROM drug_concept_stage
	WHERE dose_form = 'Patch'
	UNION ALL
	-- Sprays
	SELECT concept_code AS concept_code_1,
		regexp_replace(lower(concept_name), '(.+?),? ?(nasal )?spray.*', '\1','g') AS concept_code_2
	FROM drug_concept_stage
	WHERE dose_form = 'Spray'
	UNION ALL
	-- Infusions
	SELECT concept_code AS concept_code_1,
		regexp_replace(lower(concept_name), 'infusion,? (.+?) ?,.*', '\1','g') AS concept_code_2
	FROM drug_concept_stage
	WHERE dose_form = 'Infusion'
	UNION ALL
	-- Guess Topicals
	SELECT concept_code AS concept_code_1,
		regexp_replace(lower(concept_name), '(.+?)(, | for )topical.*', '\1','g') AS concept_code_2
	FROM drug_concept_stage
	WHERE dose_form = 'Topical'
	UNION ALL
	-- Implants
	SELECT concept_code AS concept_code_1,
		regexp_replace(lower(concept_name), '(.+?), implant.*', '\1','g') AS concept_code_2
	FROM drug_concept_stage
	WHERE dose_form = 'Implant'
	UNION ALL
	-- Parenterals
	SELECT concept_code AS concept_code_1,
		regexp_replace(lower(concept_name), '(.+?), parenteral.*', '\1','g') AS concept_code_2
	FROM drug_concept_stage
	WHERE dose_form = 'Parenteral'
	UNION ALL
	-- Suppositories
	SELECT concept_code AS concept_code_1,
		regexp_replace(lower(concept_name), '(.+?),? ?(urethral )?(rectal\/)?suppository.*', '\1','g') AS concept_code_2
	FROM drug_concept_stage
	WHERE dose_form = 'Suppository'
	UNION ALL
	-- Inhalant
	SELECT concept_code AS concept_code_1,
		regexp_replace(lower(concept_name), '(.+?),? ?(administered AS )?(all formulations including separated isomers, )?inhalation solution.*', '\1','g') AS concept_code_2
	FROM drug_concept_stage
	WHERE dose_form = 'Inhalant'
	UNION ALL
	-- Unknown
	SELECT concept_code AS concept_code_1,
		regexp_replace(regexp_replace(lower(concept_name), '(.+?)(, |; | \(?for | gel |sinus implant| implant| per).*', '\1','g'), '(administration AND supply of )?(.+)', '\2','g') AS concept_code_2
	FROM drug_concept_stage
	WHERE dose_form = 'Unknown'
	UNION ALL
	-- Manual
	SELECT 'A9517', 'iodine i-131 sodium iodide'
	UNION ALL
	SELECT 'C9448', 'netupitant'
	UNION ALL
	SELECT 'C9448', 'palonosetron'
	UNION ALL
	SELECT 'J8655', 'netupitant'
	UNION ALL
	SELECT 'J8655', 'palonosetron'
	UNION ALL
	SELECT 'Q9978', 'netupitant'
	UNION ALL
	SELECT 'Q9978', 'palonosetron';

	--Update concept_code_2 that contains '%fda%'
	UPDATE internal_relationship_stage
	SET concept_code_2 = regexp_replace(concept_code_2, ',.*','','g')
	WHERE concept_code_2 LIKE '%fda%';

	-- Manually CREATE mappings FROM Ingredients to RxNorm ingredients
	DO $_$
	BEGIN
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('(e.g. liquid)', NULL, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('5% dextrose/water (500 ml = 1 unit)', 1560524, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('abarelix', 19010868, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('abatacept', 1186087, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('abciximab', 19047423, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('abobotulinumtoxina', 40165377, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('acetaminophen', 1125315, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('acetazolamide sodium', 929435, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('acetylcysteine', 1139042, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('acyclovir', 1703687, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('adalimumab', 1119119, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('adenosine', 1309204, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('adenosine for diagnostic use', 0, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('adenosine for therapeutic use', 1309204, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('administration', 0, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('ado-trastuzumab emtansine', 43525787, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('adrenalin', 1343916, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('aflibercept', 40244266, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('agalsidase beta', 1525746, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('alatrofloxacin mesylate', 19018154, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('albumin (human)', 1344143, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('albuterol', 1154343, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('aldesleukin', 1309770, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('alefacept', 909959, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('alemtuzumab', 1312706, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('alglucerase', 19057354, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('alglucosidase alfa', 19088328, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('alglucosidase alfa (lumizyme)', 19088328, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('alpha 1 proteinase inhibitor (human)', 40181679, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('alprostadil', 1381504, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('alteplase recombinant', 1347450, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('amantadine hydrochloride', 19087090, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('amifostine', 1350040, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('amikacin sulfate', 1790868, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('aminocaproic acid', 1369939, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('aminolevulinic acid hcl', 19025194, NULL); -- it's meant methyl 5-aminolevulinate
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('aminophyllin', 1105775, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('amiodarone hydrochloride', 1309944, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('amitriptyline hcl', 710062, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('amobarbital', 712757, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('amphotericin b', 1717240, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('amphotericin b cholesteryl sulfate complex', 1717240, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('amphotericin b lipid complex', 19056402, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('amphotericin b liposome', 19056402, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('ampicillin sodium', 1717327, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('anastrozole', 1348265, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('anidulafungin', 19026450, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('anistreplase', 19044890, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('anti-inhibitor', 19080406, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('antiemetic drug', NULL, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('antithrombin iii (human)', 1436169, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('antithrombin recombinant', 1436169, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('apomorphine hydrochloride', 837027, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('aprepitant', 936748, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('aprotonin', 19000729, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('arbutamine hcl', 19086330, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('arformoterol', 1111220, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('argatroban', 1322207, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('aripiprazole', 757688, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('arsenic trioxide', 19010961, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('artificial saliva', NULL, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('asparaginase', 19012585, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('asparaginase (erwinaze)', 19055717, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('asparaginase erwinia chrysanthemi', 43533115, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('atropine', 914335, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('atropine sulfate', 914335, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('aurothioglucose', 1163570, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('autologous cultured chondrocytes', 40224705, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('azacitidine', 1314865, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('azathioprine', 19014878, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('azithromycin', 1734104, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('azithromycin dihydrate', 1734104, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('aztreonam', 1715117, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('baclofen', 715233, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('basiliximab', 19038440, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('bcg (intravesical)', 19086176, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('becaplermin', 912476, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('beclomethasone', 1115572, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('belatacept', 40239665, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('belimumab', 40236987, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('belinostat', 45776670, NULL);
		--INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('bendamustine hcl', 19015523, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('benztropine mesylate', 719174, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('betamethasone', 920458, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('betamethasone acetate 3 mg AND betamethasone sodium phosphate 3 mg', 920458, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('betamethasone sodium phosphate', 920458, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('bethanechol chloride', 937439, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('bevacizumab', 1397141, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('biperiden lactate', 724908, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('bitolterol mesylate', 1138050, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('bivalirudin', 19084670, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('blinatumomab', 45892531, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('bleomycin sulfate', 1329241, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('bortezomib', 1336825, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('brentuximab vedotin', 40241969, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('brompheniramine maleate', 1130863, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('budesonide', 939259, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('bumetanide', 932745, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('bupivacaine liposome', 40244151, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('bupivicaine hydrochloride', 732893, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('buprenorphine', 1133201, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('buprenorphine hydrochloride', 1133201, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('bupropion hcl sustained release TABLEt', 750982, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('busulfan', 1333357, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('butorphanol tartrate', 1133732, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('c-1 esterase inhibitor (human)', 45892906, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('c1 esterase inhibitor (human)', 45892906, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('c1 esterase inhibitor (recombinant)', 45892906, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('c-1 esterase inhibitor (recombinant)', 45892906, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('cabazitaxel', 40222431, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('cabergoline', 1558471, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('caffeine citrate', 1134439, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('calcitonin salmon', 1537655, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('calcitriol', 19035631, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('calcitrol', 19035631, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('calcium gluconate', 19037038, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('canakinumab', 40161669, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('cangrelor', 46275677, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('capecitabine', 1337620, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('capsaicin', 939881, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('capsaicin ', 939881, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('carbidopa', 740560, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('carboplatin', 1344905, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('carfilzomib', 42873638, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('carmustine', 1350066, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('caspofungin acetate', 1718054, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('cefazolin sodium', 1771162, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('cefepime hydrochloride', 1748975, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('cefoperazone sodium', 1773402, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('cefotaxime sodium', 1774470, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('cefotetan disodium', 1774932, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('cefoxitin sodium', 1775741, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('ceftaroline fosamil', 40230597, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('ceftazidime', 1776684, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('ceftizoxime sodium', 1777254, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('ceftriaxone sodium', 1777806, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('centruroides (scorpion) immune f(ab)2 (equine)', 40241715, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('centruroides immune f(ab)2', 40241715, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('cephalothin sodium', 19086759, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('cephapirin sodium', 19086790, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('certolizumab pegol', 912263, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('cetuximab', 1315411, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('chlorambucil', 1390051, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('chloramphenicol sodium succinate', 990069, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('chlordiazepoxide hcl', 990678, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('chlorhexidine containing antiseptic', 1790812, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('chloroprocaine hydrochloride', 19049410, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('chloroquine hydrochloride', 1792515, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('chlorothiazide sodium', 992590, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('chlorpromazine hcl', 794852, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('chlorpromazine hydrochloride', 794852, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('chorionic gonadotropin', 1563600, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('cidofovir', 1745072, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('cilastatin sodium; imipenem', 1797258, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('cimetidine hydrochloride', 997276, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('ciprofloxacin for intravenous infusion', 1797513, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('cisplatin', 1397599, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('cladribine', 19054825, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('clevidipine butyrate', 19089969, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('clindamycin phosphate', 997881, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('clofarabine', 19054821, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('clonidine hydrochloride', 1398937, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('clozapine', 800878, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('codeine phosphate', 1201620, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('colchicine', 1101554, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('colistimethate sodium', 1701677, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('collagenase', 980311, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('collagenase clostridium histolyticum', 40172153, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('contraceptive supply, hormone containing', NULL, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('corticorelin ovine triflutate', 19020789, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('corticotropin', 1541079, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('cosyntropin', 19008009, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('cosyntropin (cortrosyn)', 19008009, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('cromolyn sodium', 1152631, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('crotalidae polyvalent immune fab (ovine)', 19071744, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('cryoprecipitate', 0, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('cyclophosphamide', 1310317, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('cyclosporin', 19010482, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('cyclosporine', 19010482, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('cymetra', 0, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('cytarabine', 1311078, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('cytarabine liposome', 40175460, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('cytomegalovirus immune globulin intravenous (human)', 586491, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('d5w', 1560524, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('dacarbazine', 1311409, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('daclizumab', 19036892, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('dactinomycin', 1311443, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('dalbavancin', 45774861, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('dalteparin sodium', 1301065, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('daptomycin', 1786617, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('darbepoetin alfa', 1304643, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('daunorubicin', 1311799, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('daunorubicin citrate', 1311799, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('decitabine', 19024728, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('deferoxamine mesylate', 1711947, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('degarelix', 19058410, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('denileukin diftitox', 19051642, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('denosumab', 40222444, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('depo-estradiol cypionate', 1548195, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('desmopressin acetate', 1517070, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('dexamethasone', 1518254, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('dexamethasone acetate', 1518254, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('dexamethasone intravitreal implant', 1518254, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('dexamethasone sodium phosphate', 1518254, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('dexrazoxane hydrochloride', 1353011, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('dextran 40', 19019122, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('dextran 75', 19019193, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('dextroamphetamine sulfate', 719311, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('dialysis/stress vitamin supplement', NULL, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('diazepam', 723013, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('diazoxide', 1523280, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('dicyclomine hcl', 924724, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('didanosine (ddi)', 1724869, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('diethylstilbestrol diphosphate', 1525866, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('digoxin', 19045317, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('digoxin immune fab (ovine)', 19045317, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('dihydroergotamine mesylate', 1126557, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('dimenhydrinate', 928744, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('dimercaprol', 1728903, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('diphenhydramine hcl', 1129625, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('diphenhydramine hydrochloride', 1129625, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('dipyridamole', 1331270, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('dmso', 928980, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('dobutamine hydrochloride', 1337720, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('docetaxel', 1315942, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('dolasetron mesylate', 903459, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('dopamine hcl', 1337860, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('doripenem', 1713905, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('dornase alfa', 1125443, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('doxercalciferol', 1512446, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('doxorubicin hydrochloride', 1338512, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('doxorubicin hydrochloride liposomal', 19051649, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('dronabinol', 40125879, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('droperidol', 739323, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('dyphylline', 1140088, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('ecallantide', 40168938, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('eculizumab', 19080458, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('edetate calcium disodium', 43013616, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('edetate disodium', 19052936, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('efalizumab', 936429, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('elosulfase alfa', 44814525, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('enfuvirtide', 1717002, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('enoxaparin sodium', 1301025, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('epifix', 0, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('epirubicin hcl', 1344354, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('epoetin alfa', 1301125, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('epoetin beta', 19001311, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('epoprostenol', 1354118, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('eptifibatide', 1322199, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('ergonovine maleate', 1345205, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('eribulin mesylate', 40230712, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('ertapenem sodium', 1717963, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('erythromycin lactobionate', 1746940, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('estradiol valerate', 1548195, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('estrogen  conjugated', 1549080, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('estrone', 1549254, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('etanercept', 1151789, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('ethanolamine oleate', 19095285, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('etidronate disodium', 1552929, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('etoposide', 1350504, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('everolimus', 19011440, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('excellagen', 0, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('exemestane', 1398399, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('factor ix', 1351935, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('factor ix (antihemophilic factor', 1351935, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('factor ix (antihemophilic factor, purified, non-recombinant)', 1351935, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('factor ix (antihemophilic factor, recombinant), alprolix', 1351935, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('factor ix (antihemophilic factor, recombinant), rixubis', 1351935, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('factor ix, complex', 1351935, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('factor viia (antihemophilic factor', 1352141, NULL);
		--INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('factor viii', 1352213, NULL);
		--INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('factor viii (antihemophilic factor', 1352213, NULL);
		--INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('factor viii (antihemophilic factor (porcine))', 1352213, NULL);
		--INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('factor viii (antihemophilic factor, human)', 1352213, NULL);
		--INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('factor viii (antihemophilic factor, recombinant)', 1352213, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('factor xiii (antihemophilic factor', 1352213, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('factor xiii a-subunit', 45776421, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('factor viii fc fusion (recombinant)', 45776421, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('famotidine', 953076, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('fentanyl citrate', 1154029, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('ferric carboxymaltose', 43560392, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('ferric pyrophosphate citrate solution', 46221255, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('ferumoxytol', 40163731, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('filgrastim (g-csf)', 1304850, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('finasteride', 996416, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('floxuridine', 1355509, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('fluconazole', 1754994, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('fludarabine phosphate', 1395557, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('flunisolide', 1196514, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('fluocinolone acetonide', 996541, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('fluocinolone acetonide intravitreal implant', 996541, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('fluorouracil', 955632, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('fluphenazine decanoate', 756018, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('flutamide', 1356461, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('follitropin alfa', 1542948, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('follitropin beta', 1597235, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('fomepizole', 19022479, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('fomivirsen sodium', 19048999, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('fondaparinux sodium', 1315865, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('formoterol', 1196677, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('formoterol fumarate', 1196677, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('fosaprepitant', 19022131, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('foscarnet sodium', 1724700, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('fosphenytoin', 713192, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('fosphenytoin sodium', 713192, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('fulvestrant', 1304044, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('furosemide', 956874, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('gadobenate dimeglumine (multihance multipack)', 19097468, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('gadobenate dimeglumine (multihance)', 19097468, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('gadobutrol', 19048493, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('gadofosveset trisodium', 43012718, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('gadoterate meglumine', 0, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('gadoteridol', 19097463, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('gadoxetate disodium', 0, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('gallium nitrate', 42899259, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('galsulfase', 19078649, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('gamma globulin', 19117912, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('ganirelix acetate', 1536743, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('garamycin', 919345, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('gatifloxacin', 1789276, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('gefitinib', 1319193, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('gemcitabine hydrochloride', 1314924, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('gemtuzumab ozogamicin', 19098566, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('glatiramer acetate', 751889, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('glucagon hydrochloride', 1560278, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('glucarpidase', 42709319, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('glycopyrrolate', 963353, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('gold sodium thiomalate', 1152134, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('golimumab', 19041065, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('gonadorelin hydrochloride', 19089810, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('goserelin acetate', 1366310, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('graftjacket xpress', 0, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('granisetron hydrochloride', 1000772, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('haloperidol', 766529, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('haloperidol decanoate', 766529, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('hemin', 19067303, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('heparin sodium', 1367571, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('hepatitis b immune globulin (hepagam b)', 501343, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('hepatitis b vaccine', 528323, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('hexaminolevulinate hydrochloride', 43532423, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('high risk population (use only with codes for immunization)', 0, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('histrelin', 1366773, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('histrelin acetate', 1366773, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('home infusion therapy', 0, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('human fibrinogen concentrate', 19044986, NULL);
		--INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('human plasma fibrin sealant', 0, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('hyaluronan or derivative', 787787, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('hyaluronidase', 19073699, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('hydralazine hcl', 1373928, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('hydrocortisone acetate', 975125, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('hydrocortisone sodium  phosphate', 975125, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('hydrocortisone sodium succinate', 975125, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('hydromorphone', 1126658, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('hydromorphone hydrochloride', 1126658, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('hydroxyprogesterone caproate', 19077143, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('hydroxyurea', 1377141, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('hydroxyzine hcl', 777221, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('hydroxyzine pamoate', 777221, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('hyoscyamine sulfate', 923672, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('hypertonic saline solution', 967823, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('ibandronate sodium', 1512480, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('ibuprofen', 1177480, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('ibutilide fumarate', 19050087, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('icatibant', 40242044, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('idarubicin hydrochloride', 19078097, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('idursulfase', 19091430, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('ifosfamide', 19078187, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('iloprost', 1344992, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('imatinib', 1304107, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('imiglucerase', 1348407, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('immune globulin', 19117912, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('immune globulin (bivigam)', 19117912, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('immune globulin (gammaplex)', 19117912, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('immune globulin (hizentra)', 19117912, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('immune globulin (privigen)', 19117912, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('immune globulin (vivaglobin)', 19117912, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('immunizations/vaccinations', NULL, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('incobotulinumtoxin a', 40224763, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('infliximab', 937368, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('influenza vaccine, recombinant hemagglutinin antigens, for intramuscular use (flublok)', NULL, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('influenza virus vaccine', NULL, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('influenza virus vaccine, split virus, for intramuscular use (agriflu)', NULL, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('injecTABLE anesthetic', NULL, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('injecTABLE bulking agent', NULL, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('injecTABLE poly-l-lactic acid', 0, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('insulin', NULL, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('insulin intermediate acting (nph or lente)', NULL, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('insulin long acting', NULL, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('insulin most rapid onset (lispro or aspart)', NULL, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('insulin per 5 units', NULL, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('insulin rapid onset', NULL, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('interferon alfa-2a', 1379969, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('interferon alfa-2b', 1380068, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('interferon alfacon-1', 1781314, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('interferon alfa-n3', 1385645, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('interferon beta-1a', 722424, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('interferon beta-1b', 713196, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('interferon gamma 1-b', 1380191, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('pegylated interferon alfa-2a', 1714165, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('pegylated interferon alfa-2b', 1797155, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('intravenous', NULL, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('ipilimumab', 40238188, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('ipratropium bromide', 1112921, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('irinotecan', 1367268, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('iron dextran', 1381661, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('iron dextran 165', 1381661, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('iron dextran 267', 1381661, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('iron sucrose', 1395773, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('irrigation solution', NULL, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('isavuconazonium', 46221284, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('isavuconazonium sulfate', 46221284, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('isoetharine hcl', 1181809, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('isoproterenol hcl', 1183554, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('itraconazole', 1703653, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('ixabepilone', 19025348, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('kanamycin sulfate', 1784749, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('ketorolac tromethamine', 1136980, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('lacosamide', 19087394, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('lanreotide', 1503501, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('lanreotide acetate', 1503501, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('laronidase', 1543229, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('lepirudin', 19092139, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('leucovorin calcium', 1388796, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('levalbuterol', 1192218, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('levodopa', 789578, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('levamisole hydrochloride', 1389464, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('levetiracetam', 711584, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('levocarnitine', 1553610, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('levofloxacin', 1742253, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('levoleucovorin calcium', 40168303, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('levonorgestrel-releasing intrauterine contraceptive system', 1589505, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('levorphanol tartrate', 1189766, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('lidocaine hcl for intravenous infusion', 989878, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('lincomycin hcl', 1790692, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('linezolid', 1736887, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('liquid)', NULL, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('lomustine', 1391846, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('lorazepam', 791967, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('loxapine', 792263, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('lymphocyte immune globulin, antithymocyte globulin, equine', 19003476, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('lymphocyte immune globulin, antithymocyte globulin, rabbit', 19136207, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('magnesium sulfate', 19093848, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('mannitol', 994058, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('mecasermin', 1502877, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('mechlorethamine hydrochloride', 1394337, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('medroxyprogesterone acetate', 1500211, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('medroxyprogesterone acetate for contraceptive use', 1500211, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('megestrol acetate', 1300978, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('melphalan', 1301267, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('melphalan hydrochloride', 1301267, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('menotropins', 19125388, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('meperidine hydrochloride', 1102527, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('mepivacaine hydrochloride', 702774, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('mercaptopurine', 1436650, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('meropenem', 1709170, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('mesna', 1354698, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('metaproterenol sulfate', 1123995, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('metaraminol bitartrate', 19003303, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('methacholine chloride', 19024227, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('methadone', 1103640, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('methadone hcl', 1103640, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('methocarbamol', 704943, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('methotrexate', 1305058, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('methotrexate sodium', 1305058, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('methyl aminolevulinate (mal)', 924120, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('methyldopate hcl', 1305496, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('methylene blue', 905518, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('methylergonovine maleate', 1305637, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('methylnaltrexone', 909841, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('methylprednisolone', 1506270, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('methylprednisolone acetate', 1506270, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('methylprednisolone sodium succinate', 1506270, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('metoclopramide hcl', 906780, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('metronidazole', 1707164, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('micafungin sodium', 19018013, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('midazolam hydrochloride', 708298, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('mifepristone', 1508439, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('milrinone lactate', 1368671, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('minocycline hydrochloride', 1708880, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('minoxidil', 1309068, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('misoprostol', 1150871, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('mitomycin', 1389036, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('mitoxantrone hydrochloride', 1309188, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('mometasone furoate ', 905233, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('morphine sulfate', 1110410, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('morphine sulfate (preservative-free sterile solution)', 1110410, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('moxifloxacin', 1716903, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('multiple vitamins', NULL, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('muromonab-cd3', 19051865, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('mycophenolate mofetil', 19003999, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('mycophenolic acid', 19012565, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('nabilone', 913440, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('nafcillin sodium', 1713930, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('nalbuphine hydrochloride', 1114122, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('naloxone hydrochloride', 1114220, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('naltrexone', 1714319, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('nandrolone decanoate', 1514412, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('nasal vaccine inhalation', NULL, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('natalizumab', 735843, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('nelarabine', 19002912, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('neostigmine methylsulfate', 717136, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('neoxflo or clarixflo', 0, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('nesiritide', 1338985, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('netupitant', 45774966, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('nicotine', 718583, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('nivolumab', 45892628, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('noc drugs', NULL, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('non-radioactive', 0, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('normal saline solution', 967823, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('obinutuzumab', 44507676, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('ocriplasmin', 42904298, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('octafluoropropane microspheres', 0, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('octreotide', 1522957, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('ofatumumab', 40167582, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('ofloxacin', 923081, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('olanzapine', 785788, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('omacetaxine mepesuccinate', 19069046, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('omalizumab', 1110942, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('onabotulinumtoxina', 40165651, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('ondansetron', 1000560, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('ondansetron 1 mg', 1000560, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('ondansetron hydrochloride', 1000560, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('ondansetron hydrochloride 8  mg', 1000560, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('oprelvekin', 1318030, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('oritavancin', 45776147, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('orphenadrine citrate', 724394, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('oseltamivir phosphate', 1799139, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('oxacillin sodium', 1724703, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('oxaliplatin', 1318011, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('oxygen contents', NULL, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('oxymorphone hcl', 1125765, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('oxytetracycline hcl', 925952, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('oxytocin', 1326115, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('paclitaxel', 1378382, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('paclitaxel protein-bound particles', 1378382, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('palifermin', 19038562, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('paliperidone palmitate', 703244, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('paliperidone palmitate extended release', 703244, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('palivizumab-rsv-igm', 537647, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('palonosetron', 911354, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('palonosetron hcl', 911354, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('pamidronate disodium', 1511646, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('panitumumab', 19100985, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('pantoprazole sodium', 948078, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('papaverine hcl', 1326901, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('peramivir', 40167569, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('paricalcitol', 1517740, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('pasireotide long acting', 43012417, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('pegademase bovine', 581480, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('pegaptanib sodium', 19063605, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('pegaspargase', 1326481, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('pegfilgrastim', 1325608, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('peginesatide', 42709327, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('pegloticase', 40226208, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('pembrolizumab', 45775965, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('pemetrexed', 1304919, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('penicillin g benzathine', 1728416, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('penicillin g benzathine AND penicillin g procaine', 1728416, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('penicillin g potassium', 1728416, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('penicillin g procaine', 1728416, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('pentamidine isethionate', 1730370, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('pentastarch', 40161354, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('pentazocine', 1130585, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('pentobarbital sodium', 730729, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('pentostatin', 19031224, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('perflexane lipid microspheres', 45775689, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('perflutren lipid microspheres', 19071160, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('perphenazine', 733008, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('pertuzumab', 42801287, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('phenobarbital sodium', 734275, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('phentolamine mesylate', 1335539, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('phenylephrine hcl', 1135766, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('phenytoin sodium', 740910, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('phytonadione (vitamin k)', 19044727, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('piperacillin sodium', 1746114, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('plasma protein fraction (human)', 19025693, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('platelet rich plasma', 0, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('plerixafor', 19017581, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('plicamycin', 19009165, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('pneumococcal conjugate vaccine', 513909, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('pneumococcal vaccine', 513909, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('porfimer sodium', 19090420, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('potassium chloride', 19049105, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('pralatrexate', 40166461, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('pralidoxime chloride', 1727468, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('prednisolone', 1550557, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('prednisolone acetate', 1550557, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('prednisone', 1551099, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('prescription drug', NULL, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('procainamide hcl', 1351461, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('procarbazine hydrochloride', 1351779, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('prochlorperazine', 752061, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('prochlorperazine maleate', 752061, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('progesterone', 1552310, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('promazine hcl', 19052903, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('promethazine hcl', 1153013, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('promethazine hydrochloride', 1153013, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('propofol', 753626, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('propranolol hcl', 1353766, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('protamine sulfate', 19054242, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('protein c concentrate', 42801108, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('prothrombin complex concentrate (human), kcentra', 44507865, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('protirelin', 19001701, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('pyridoxine hcl', 42903728, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('radiesse', 0, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('ramucirumab', 44818489, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('ranibizumab', 19080982, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('ranitidine hydrochloride', 961047, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('rasburicase', 1304565, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('regadenoson', 19090761, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('respiratory syncytial virus immune globulin', 19013765, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('reteplase', 19024191, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('rho d immune globulin', 535714, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('rho(d) immune globulin (human)', 535714, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('rilonacept', 19023450, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('rimabotulinumtoxinb', 40166020, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('rimantadine hydrochloride', 1763339, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('risperidone', 735979, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('rituximab', 1314273, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('romidepsin', 40168385, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('romiplostim', 19032407, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('ropivacaine hydrochloride', 1136487, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('saquinavir', 1746244, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('sargramostim (gm-csf)', 1308432, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('sculptra', 0, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('secretin', 19066188, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('sermorelin acetate', 19077457, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('sildenafil citrate', 1316262, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('sincalide', 19067803, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('single vitamin/mineral/trace element', NULL, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('sipuleucel-t', 40224095, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('sirolimus', 19034726, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('siltuximab', 44818461, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('sodium chloride', 967823, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('sodium ferric gluconate complex in sucrose injection', 1399177, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('sodium hyaluronate', 787787, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('somatrem', 1578181, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('somatropin', 1584910, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('spectinomycin dihydrochloride', 1701651, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('state supplied vaccine', NULL, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('sterile cefuroxime sodium', 1778162, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('sterile dilutant', NULL, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('sterile saline or water', NULL, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('sterile water', NULL, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('sterile water/saline', NULL, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('streptokinase', 19136187, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('streptomycin', 1836191, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('streptozocin', 19136210, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('succinylcholine chloride', 836208, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('sulfur hexafluoride lipid microsphere', 45892833, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('sumatriptan succinate', 1140643, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('syringe', 0, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('syringe with needle', 0, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('tacrine hydrochloride', 836654, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('tacrolimus', 950637, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('taliglucerase alfa', 42800246, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('taliglucerace alfa', 42800246, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('tamoxifen citrate', 1436678, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('tbo-filgrastim', 1304850, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('tedizolid phosphate', 45775686, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('telavancin', 40166675, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('temozolomide', 1341149, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('temsirolimus', 19092845, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('tenecteplase', 19098548, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('teniposide', 19136750, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('terbutaline sulfate', 1236744, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('teriparatide', 1521987, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('testosterone cypionate', 1636780, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('testosterone enanthate', 1636780, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('testosterone pellet', 1636780, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('testosterone propionate', 1636780, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('testosterone suspension', 1636780, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('testosterone undecanoate', 1636780, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('tetanus immune globulin', 561401, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('tetracycline', 1836948, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('theophylline', 1237049, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('thiamine hcl', 19137312, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('thiethylperazine maleate', 1037358, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('thiotepa', 19137385, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('thyrotropin alpha', 19007721, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('tigecycline', 1742432, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('tinzaparin sodium', 1308473, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('tirofiban hcl', 19017067, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('tissue marker', 0, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('tobramycin', 902722, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('tobramycin sulfate', 902722, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('tocilizumab', 40171288, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('tolazoline hcl', 19002829, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('topotecan', 1378509, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('torsemide', 942350, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('tositumomab', 19068894, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('trastuzumab', 1387104, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('treprostinil', 1327256, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('tretinoin', 903643, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('triamcinolone', 903963, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('triamcinolone acetonide', 903963, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('triamcinolone diacetate', 903963, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('triamcinolone hexacetonide', 903963, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('triflupromazine hcl', 19005104, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('trimethobenzamide hcl', 942799, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('trimethobenzamide hydrochloride', 942799, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('trimetrexate glucuronate', 1750928, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('triptorelin pamoate', 1343039, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('urea', 906914, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('urofollitropin', 1515417, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('urokinase', 1307515, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('ustekinumab', 40161532, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('vaccine for part d drug', NULL, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('valrubicin', 19012543, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('vancomycin hcl', 1707687, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('vascular graft material, synthetic', 0, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('vedolizumab', 45774639, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('velaglucerase alfa', 40174604, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('verteporfin', 912803, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('vinblastine sulfate', 19008264, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('vincristine sulfate', 1308290, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('vincristine sulfate liposome', 1308290, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('vinorelbine tartrate', 1343346, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('vitamin b-12 cyanocobalamin', 1308738, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('von willebrand factor complex', 44785885, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('von willebrand factor complex (human)', 44785885, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('von willebrand factor complex (humate-p)', 44785885, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('voriconazole', 1714277, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('water', NULL, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('zalcitabine (ddc)', 1724827, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('ziconotide', 19005061, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('zidovudine', 1710612, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('ziprasidone mesylate', 712615, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('ziv-aflibercept', 40244266, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('zoledronic acid', 1524674, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('zoledronic acid (reclast)', 1524674, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('zoledronic acid (zometa)', 1524674, NULL);
		--added 20170518
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('hydrocortisone sodium phosphate',975125,1);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('sulfur hexafluoride lipid microspheres',45892833,1);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('estrogen conjugated',1549080,1);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('ondansetron hydrochloride 8 mg',1000560,1);	
	END $_$;

	-- Add ingredients AND their mappings that are not automatically generated
	DO $_$
	BEGIN
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('calcium chloride', 19036781, NULL); -- Ringer
		INSERT INTO drug_concept_stage (concept_code, vocabulary_id, concept_class_id) VALUES ('calcium chloride', 'HCPCS', 'Ingredient');
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('sodium lactate', 19011035, NULL); -- Ringer. Lactate is precise ingredient
		INSERT INTO drug_concept_stage (concept_code, vocabulary_id, concept_class_id) VALUES ('sodium lactate', 'HCPCS', 'Ingredient');
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('dextrose', 1560524, NULL); -- Dextrose
		INSERT INTO drug_concept_stage (concept_code, vocabulary_id, concept_class_id) VALUES ('dextrose', 'HCPCS', 'Ingredient');
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('sodium bicarbonate', 939506, NULL); -- Elliot's
		INSERT INTO drug_concept_stage (concept_code, vocabulary_id, concept_class_id) VALUES ('sodium bicarbonate', 'HCPCS', 'Ingredient');
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('sodium phosphate', 939871, NULL); -- Elliot's
		INSERT INTO drug_concept_stage (concept_code, vocabulary_id, concept_class_id) VALUES ('sodium phosphate', 'HCPCS', 'Ingredient');
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('sulbactam', 1836241, NULL);
		INSERT INTO drug_concept_stage (concept_code, vocabulary_id, concept_class_id) VALUES ('sulbactam', 'HCPCS', 'Ingredient');
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('tazobactam', 1741122, NULL);
		INSERT INTO drug_concept_stage (concept_code, vocabulary_id, concept_class_id) VALUES ('tazobactam', 'HCPCS', 'Ingredient');
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('tetracaine', 1036884, NULL);
		INSERT INTO drug_concept_stage (concept_code, vocabulary_id, concept_class_id) VALUES ('tetracaine', 'HCPCS', 'Ingredient');
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('quinupristin', 1789515, NULL);
		INSERT INTO drug_concept_stage (concept_code, vocabulary_id, concept_class_id) VALUES ('quinupristin', 'HCPCS', 'Ingredient');
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('dalfopristin', 1789517, NULL);
		INSERT INTO drug_concept_stage (concept_code, vocabulary_id, concept_class_id) VALUES ('dalfopristin', 'HCPCS', 'Ingredient');
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('calcium glycerophosphate', 1337159, NULL);
		INSERT INTO drug_concept_stage (concept_code, vocabulary_id, concept_class_id) VALUES ('calcium glycerophosphate', 'HCPCS', 'Ingredient');
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('calcium lactate', 19058896, NULL);
		INSERT INTO drug_concept_stage (concept_code, vocabulary_id, concept_class_id) VALUES ('calcium lactate', 'HCPCS', 'Ingredient');
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('avibactam', 46221507, NULL);
		INSERT INTO drug_concept_stage (concept_code, vocabulary_id, concept_class_id) VALUES ('avibactam', 'HCPCS', 'Ingredient');
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('ceftolozane', 45892599, NULL);
		INSERT INTO drug_concept_stage (concept_code, vocabulary_id, concept_class_id) VALUES ('ceftolozane', 'HCPCS', 'Ingredient');
		INSERT INTO drug_concept_stage (concept_code, vocabulary_id, concept_class_id) VALUES ('netupitant', 'HCPCS', 'Ingredient');
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('sulfamethoxazole', 1836430, NULL);
		INSERT INTO drug_concept_stage (concept_code, vocabulary_id, concept_class_id) VALUES ('sulfamethoxazole', 'HCPCS', 'Ingredient');
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('trimethoprim', 1705674, NULL);
		INSERT INTO drug_concept_stage (concept_code, vocabulary_id, concept_class_id) VALUES ('trimethoprim', 'HCPCS', 'Ingredient');
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('ticarcillin', 1759842, NULL);
		INSERT INTO drug_concept_stage (concept_code, vocabulary_id, concept_class_id) VALUES ('ticarcillin', 'HCPCS', 'Ingredient');
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('clavulanate', 1702364, NULL);
		INSERT INTO drug_concept_stage (concept_code, vocabulary_id, concept_class_id) VALUES ('clavulanate', 'HCPCS', 'Ingredient');
		--new added
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) SELECT  concept_code, 45775540, NULL from drug_concept_stage where concept_code like  'iodine i-131%';
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) SELECT  concept_code, 19065829, NULL from drug_concept_stage where concept_code like  'iodine i-125%';
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) SELECT  concept_code, 43526934, 1 from drug_concept_stage where concept_code like  '%radium ra-223%';
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) SELECT  concept_code, 35603551, 2 from drug_concept_stage where concept_code like  '%radium ra-223%';
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) SELECT  concept_code, 794852, NULL from drug_concept_stage where concept_code like  'chlorpromazine hydrochloride%';
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) SELECT  concept_code, 1519936, NULL from drug_concept_stage where concept_code like  '%etonogestrel%';
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) SELECT  concept_code, 1757803, NULL from drug_concept_stage where concept_code like  '%ganciclovir%';
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) SELECT  concept_code, 1366773, NULL from drug_concept_stage where concept_code like  '%histrelin implant%';
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) SELECT  concept_code, 1589505, NULL from drug_concept_stage where concept_code like  '%levonorgestrel%';
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) SELECT  concept_code, 1351541, NULL from drug_concept_stage where concept_code like  'leuprolide%';
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) SELECT  concept_code, 1352213, NULL from drug_concept_stage where concept_code like  'factor viii%';
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) SELECT  concept_code, 19015523, NULL from drug_concept_stage where concept_code like  'bendamustine%';
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('mepolizumab', 35606631, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('buprenorphine implant, 74.2 mg', 1133201, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('atezolizumab', 42629079, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('aripiprazole lauroxil', 35602825, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('diclofenac sodium', 1124300, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('chromic phosphate p-32', 19011099, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('elotuzumab', 35604032, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('goserelin acetate implant, per 3.6 mg', 1366310, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('hyaluronan', 798336, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('factor x', 44785022, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('fluocinolone acetonide, intravitreal implant', 996541, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('irinotecan liposome', 35603068, 1);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('irinotecan liposome', 1367268, 2);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('mometasone furoate sinus implant, 370 micrograms', 905233, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('necitumumab', 35606215, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('reslizumab', 35603983, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('samarium sm-153 lexidronam', 19018483, 1);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('samarium sm-153 lexidronam', 1338558, 2);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('rolapitant', 46287434, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('sotalol hydrochloride', 1370109, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('sodium phosphate p-32', 19135940, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('talimogene laherparepvec', 42903942, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('trabectedin', 35603017, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('von willebrand factor (recombinant)', 44785885, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('yttrium y-90 ibritumomab tiuxetan', 19068830, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('zanamivir', 1708748, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('fibrinogen', 19054702, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('thrombin', 1300673, NULL);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('factor xiii (antihemophilic factor, recombinant), tretten, per 10 i.u.', 1352213, NULL);
		INSERT INTO drug_concept_stage (domain_id, concept_name, vocabulary_id, concept_class_id, concept_code) VALUES (NULL, 'Drug', 'HCPCS', 'Ingredient', 'chlorpromazine hydrochloride');
		INSERT INTO drug_concept_stage (domain_id, concept_name, vocabulary_id, concept_class_id, concept_code) VALUES (NULL, 'Drug', 'HCPCS', 'Ingredient', 'diphenhydramine hydrochloride');
		INSERT INTO drug_concept_stage (domain_id, concept_name, vocabulary_id, concept_class_id, concept_code) VALUES (NULL, 'Drug', 'HCPCS', 'Ingredient', 'dronabinol');
		INSERT INTO drug_concept_stage (domain_id, concept_name, vocabulary_id, concept_class_id, concept_code) VALUES (NULL, 'Drug', 'HCPCS', 'Ingredient', 'hydroxyzine pamoate');
		INSERT INTO drug_concept_stage (domain_id, concept_name, vocabulary_id, concept_class_id, concept_code) VALUES (NULL, 'Drug', 'HCPCS', 'Ingredient', 'ondansetron 1 mg');
		INSERT INTO drug_concept_stage (domain_id, concept_name, vocabulary_id, concept_class_id, concept_code) VALUES (NULL, 'Drug', 'HCPCS', 'Ingredient', 'carbidopa');
		INSERT INTO drug_concept_stage (domain_id, concept_name, vocabulary_id, concept_class_id, concept_code) VALUES (NULL, 'Drug', 'HCPCS', 'Ingredient', 'levodopa');
		INSERT INTO drug_concept_stage (domain_id, concept_name, vocabulary_id, concept_class_id, concept_code) VALUES (NULL, 'Drug', 'HCPCS', 'Ingredient', 'promethazine hydrochloride');
		INSERT INTO drug_concept_stage (domain_id, concept_name, vocabulary_id, concept_class_id, concept_code) VALUES (NULL, 'Drug', 'HCPCS', 'Ingredient', 'trimethobenzamide hydrochloride');
	END $_$;

	-- Add ingredients for combination products
	DO $_$
	BEGIN
		--human plasma fibrin sealant
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'fibrinogen' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2 = 'human plasma fibrin sealant';

		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'thrombin' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2 = 'human plasma fibrin sealant';

		DELETE FROM internal_relationship_stage WHERE concept_code_2 = 'human plasma fibrin sealant';

		--droperidol and fentanyl citrate
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'droperidol' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2 = 'droperidol and fentanyl citrate';

		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'fentanyl citrate' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2 = 'droperidol and fentanyl citrate';

		DELETE FROM internal_relationship_stage WHERE concept_code_2 = 'droperidol and fentanyl citrate';

		--dcarbidopa 5 mg/levodopa 20 mg enteral suspension
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'carbidopa' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2 LIKE 'carbidopa 5 mg/levodopa 20 mg enteral suspension%';

		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'levodopa' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2 LIKE 'carbidopa 5 mg/levodopa 20 mg enteral suspension%';

		DELETE FROM internal_relationship_stage WHERE concept_code_2 LIKE 'carbidopa 5 mg/levodopa 20 mg enteral suspension%';

		-- 5% dextrose and 0.45% normal saline
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'dextrose' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='5% dextrose AND 0.45% normal saline';
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'normal saline solution' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='5% dextrose AND 0.45% normal saline';
		DELETE FROM internal_relationship_stage WHERE concept_code_2='5% dextrose AND 0.45% normal saline';
		-- 5% dextrose in lactated ringer's
		-- Calcium Chloride 0.001 MEQ/ML / Glucose 50 MG/ML / Potassium Chloride 0.004 MEQ/ML / Sodium Chloride 0.103 MEQ/ML / Sodium Lactate 0.028 MEQ/ML InjecTABLE Solution
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'dextrose' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='5% dextrose in lactated ringer''s';
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'calcium chloride' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='5% dextrose in lactated ringer''s';
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'potassium chloride' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='5% dextrose in lactated ringer''s';
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'normal saline solution' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='5% dextrose in lactated ringer''s';
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'sodium lactate' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='5% dextrose in lactated ringer''s';
		DELETE FROM internal_relationship_stage WHERE concept_code_2='5% dextrose in lactated ringer''s';
		-- 5% dextrose in lactated ringers infusion
		-- Calcium Chloride 0.001 MEQ/ML / Glucose 50 MG/ML / Potassium Chloride 0.004 MEQ/ML / Sodium Chloride 0.103 MEQ/ML / Sodium Lactate 0.028 MEQ/ML InjecTABLE Solution
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'dextrose' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='5% dextrose in lactated ringers infusion';
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'calcium chloride' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='5% dextrose in lactated ringers infusion';
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'potassium chloride' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='5% dextrose in lactated ringers infusion';
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'normal saline solution' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='5% dextrose in lactated ringers infusion';
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'sodium lactate' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='5% dextrose in lactated ringers infusion';
		DELETE FROM internal_relationship_stage WHERE concept_code_2='5% dextrose in lactated ringers infusion';
		-- 5% dextrose with potassium chloride
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'dextrose' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='5% dextrose with potassium chloride';
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'potassium chloride' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='5% dextrose with potassium chloride';
		DELETE FROM internal_relationship_stage WHERE concept_code_2='5% dextrose with potassium chloride';
		-- both ingredients already defined 
		-- 5% dextrose/0.45% normal saline with potassium chloride AND magnesium sulfate
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'dextrose' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='5% dextrose/0.45% normal saline with potassium chloride AND magnesium sulfate';
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'normal saline solution' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='5% dextrose/0.45% normal saline with potassium chloride AND magnesium sulfate';
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'potassium chloride' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='5% dextrose/0.45% normal saline with potassium chloride AND magnesium sulfate';
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'magnesium sulfate' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='5% dextrose/0.45% normal saline with potassium chloride AND magnesium sulfate';
		DELETE FROM internal_relationship_stage WHERE concept_code_2='5% dextrose/0.45% normal saline with potassium chloride AND magnesium sulfate';
		-- all ingredients already defined
		-- 5% dextrose/normal saline (500 ml = 1 unit)
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'dextrose' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='5% dextrose/normal saline (500 ml = 1 unit)';
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'normal saline solution' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='5% dextrose/normal saline (500 ml = 1 unit)';
		DELETE FROM internal_relationship_stage WHERE concept_code_2='5% dextrose/normal saline (500 ml = 1 unit)';
		-- both ingredients already defined
		-- albuterol/ipratropium bromide up to 0.5 mg
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'albuterol' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='albuterol/ipratropium bromide up to 0.5 mg';
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'ipratropium bromide' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='albuterol/ipratropium bromide up to 0.5 mg';
		DELETE FROM internal_relationship_stage WHERE concept_code_2='albuterol/ipratropium bromide up to 0.5 mg';
		-- both ingredients already defined
		-- ampicillin sodium/sulbactam sodium
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'ampicillin sodium' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='ampicillin sodium/sulbactam sodium';
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'sulbactam' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='ampicillin sodium/sulbactam sodium';
		DELETE FROM internal_relationship_stage WHERE concept_code_2='ampicillin sodium/sulbactam sodium';
		-- antihemophilic factor viii/von willebrand factor complex (human)
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'factor viii' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='antihemophilic factor viii/von willebrand factor complex (human)';
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'von willebrand factor complex' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='antihemophilic factor viii/von willebrand factor complex (human)';
		DELETE FROM internal_relationship_stage WHERE concept_code_2='antihemophilic factor viii/von willebrand factor complex (human)';
		-- both ingredients already defined
		-- buprenorphine/naloxone
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'buprenorphine hydrochloride' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='buprenorphine/naloxone';
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'naloxone hydrochloride' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='buprenorphine/naloxone';
		DELETE FROM internal_relationship_stage WHERE concept_code_2='buprenorphine/naloxone';
		-- both ingredients defined already
		-- elliot b solution
		-- Calcium Chloride 0.00136 MEQ/ML / Glucose 0.8 MG/ML / Magnesium Sulfate 0.00122 MEQ/ML / Potassium Chloride 0.00403 MEQ/ML / Sodium Bicarbonate 0.0226 MEQ/ML / Sodium Chloride 0.125 MEQ/ML / sodium phosphate 0.000746 MEQ/ML InjecTABLE Solution [Elliotts B
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'sodium bicarbonate' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='elliotts'' b solution';
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'sodium phosphate' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='elliotts'' b solution';
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'normal saline solution' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='elliotts'' b solution';
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'dextrose' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='elliotts'' b solution';
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'calcium chloride' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='elliotts'' b solution';
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'potassiuim chloride' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='elliotts'' b solution';
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'magnesium sulfate' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='elliotts'' b solution';
		DELETE FROM internal_relationship_stage WHERE concept_code_2='elliotts'' b solution';
		-- some of the ingredients are already defined
		-- immune globulin/hyaluronidase
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'immune globulin' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='immune globulin/hyaluronidase';
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'hyaluronidase' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='immune globulin/hyaluronidase';
		DELETE FROM internal_relationship_stage WHERE concept_code_2='immune globulin/hyaluronidase';
		-- both ingredients definded already
		-- lidocaine /tetracaine 
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'lidocaine hcl for intravenous infusion' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='lidocaine /tetracaine ';
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'tetracaine' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='lidocaine /tetracaine ';
		DELETE FROM internal_relationship_stage WHERE concept_code_2='lidocaine /tetracaine ';
		-- lidocaine already defined
		-- medroxyprogesterone acetate / estradiol cypionate
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'medroxyprogesterone acetate' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='medroxyprogesterone acetate / estradiol cypionate';
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'depo-estradiol cypionate' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='medroxyprogesterone acetate / estradiol cypionate';
		DELETE FROM internal_relationship_stage WHERE concept_code_2='medroxyprogesterone acetate / estradiol cypionate';
		-- both ingredients already defined
		-- piperacillin sodium/tazobactam sodium
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'piperacillin sodium' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='piperacillin sodium/tazobactam sodium';
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'tazobactam' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='piperacillin sodium/tazobactam sodium';
		DELETE FROM internal_relationship_stage WHERE concept_code_2='piperacillin sodium/tazobactam sodium';
		-- piperacillin already defined
		-- quinupristin/dalfopristin
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'quinupristin' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='quinupristin/dalfopristin';
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'dalfopristin' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='quinupristin/dalfopristin';
		DELETE FROM internal_relationship_stage WHERE concept_code_2='quinupristin/dalfopristin';
		-- calcium glycerophosphate AND calcium lactate
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'calcium glycerophosphate' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='calcium glycerophosphate AND calcium lactate';
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'calcium lactate' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='calcium glycerophosphate AND calcium lactate';
		DELETE FROM internal_relationship_stage WHERE concept_code_2='calcium glycerophosphate AND calcium lactate';
		--- ceftazidime AND avibactam
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'ceftazidime' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='ceftazidime AND avibactam';
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'avibactam' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='ceftazidime AND avibactam';
		DELETE FROM internal_relationship_stage WHERE concept_code_2='ceftazidime AND avibactam';
		-- ceftazidime already defined
		-- ceftolozane 50 mg AND tazobactam 25 mg
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'ceftolozane' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='ceftolozane 50 mg AND tazobactam 25 mg';
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'tazobactam' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='ceftolozane 50 mg AND tazobactam 25 mg';
		DELETE FROM internal_relationship_stage WHERE concept_code_2='ceftolozane 50 mg AND tazobactam 25 mg';
		-- tazobactam already defined
		-- droperidol AND fentanyl citrate
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'droperidol' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='droperidol AND fentanyl citrate';
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'fentanyl citrate' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='droperidol AND fentanyl citrate';
		DELETE FROM internal_relationship_stage WHERE concept_code_2='droperidol AND fentanyl citrate';
		-- both ingredients already defined
		-- meperidine AND promethazine hcl
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'meperidine hydrochloride' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='meperidine AND promethazine hcl';
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'promethazine hcl' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='meperidine AND promethazine hcl';
		DELETE FROM internal_relationship_stage WHERE concept_code_2='meperidine AND promethazine hcl';
		-- Both ingredients already defined
		-- netupitant 300 mg AND palonosetron 0.5 mg
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'netupitant' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='netupitant 300 mg AND palonosetron 0.5 mg';
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'palonosetron hcl' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='netupitant 300 mg AND palonosetron 0.5 mg';
		DELETE FROM internal_relationship_stage WHERE concept_code_2='netupitant 300 mg AND palonosetron 0.5 mg';
		-- palonosetron already defined
		-- phenylephrine AND ketorolac
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'phenylephrine hcl' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='phenylephrine AND ketorolac';
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'ketorolac tromethamine' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='phenylephrine AND ketorolac';
		DELETE FROM internal_relationship_stage WHERE concept_code_2='phenylephrine AND ketorolac';
		-- both ingredients already defined
		-- ringers lactate infusion
		-- Calcium Chloride 0.0014 MEQ/ML / Potassium Chloride 0.004 MEQ/ML / Sodium Chloride 0.103 MEQ/ML / Sodium Lactate 0.028 MEQ/ML InjecTABLE Solution
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'calcium chloride' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='ringers lactate infusion';
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'potassium chloride' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='ringers lactate infusion';
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'normal saline solution' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='ringers lactate infusion';
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'sodium lactate' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='ringers lactate infusion';
		DELETE FROM internal_relationship_stage WHERE concept_code_2='ringers lactate infusion';
		-- sulfamethoxazole AND trimethoprim
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'sulfamethoxazole' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='sulfamethoxazole AND trimethoprim';
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'trimethoprim' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='sulfamethoxazole AND trimethoprim';
		DELETE FROM internal_relationship_stage WHERE concept_code_2='sulfamethoxazole AND trimethoprim';
		-- testosterone cypionate AND estradiol cypionate
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'testosterone cypionate' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='testosterone cypionate AND estradiol cypionate';
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'depo-estradiol cypionate' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='testosterone cypionate AND estradiol cypionate';
		DELETE FROM internal_relationship_stage WHERE concept_code_2='testosterone cypionate AND estradiol cypionate';
		-- both ingredients already defined
		-- testosterone enanthate AND estradiol valerate
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'testosterone enanthate' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='testosterone enanthate AND estradiol valerate';
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'estradiol valerate' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='testosterone enanthate AND estradiol valerate';
		DELETE FROM internal_relationship_stage WHERE concept_code_2='testosterone enanthate AND estradiol valerate';
		-- both ingredients already defined
		-- ticarcillin disodium AND clavulanate potassium
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'ticarcillin' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='ticarcillin disodium AND clavulanate potassium';
		INSERT INTO internal_relationship_stage
		SELECT concept_code_1, 'clavulanate' AS concept_code_2 FROM internal_relationship_stage WHERE concept_code_2='ticarcillin disodium AND clavulanate potassium';
		DELETE FROM internal_relationship_stage WHERE concept_code_2='ticarcillin disodium AND clavulanate potassium';

		-- Add AND remove ingredients
		DELETE FROM drug_concept_stage WHERE concept_class_id='Ingredient' AND concept_code NOT IN (SELECT concept_code_2 FROM internal_relationship_stage);
	END $_$;

	/*********************************************
	* 3. CREATE Dose Forms AND links to products *
	*********************************************/
	INSERT INTO drug_concept_stage
	SELECT DISTINCT dose_form AS concept_name,
		'Drug' AS domain_id,
		'HCPCS' AS vocabulary_id,
		'Dose Form' AS concept_class_id,
		dose_form AS concept_code,
		NULL AS possible_excipient,
		NULL::DATE AS valid_start_date,
		NULL::DATE AS valid_end_date,
		NULL AS invalid_reason,
		dose_form
	FROM drug_concept_stage
	WHERE concept_class_id = 'Procedure Drug';

	INSERT INTO internal_relationship_stage
	SELECT d.concept_code AS concept_code_1,
		df.concept_code AS concept_code_2
	FROM drug_concept_stage d
	JOIN drug_concept_stage df ON df.concept_code = d.dose_form
		AND df.concept_class_id = 'Dose Form'
	WHERE d.concept_class_id = 'Procedure Drug';

	-- Manually CREATE Dose Form mapping to RxNorm
	DO $_$
	BEGIN
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Infusion', 19082103, 1);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Infusion', 19082104, 2);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Infusion', 46234469, 3);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Inhalant', 19082259, 2);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Inhalant', 19095898, 1);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Inhalant', 19126918, 3);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Inhalant', 19082162, 4);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Inhalant', 19126919, 5);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Inhalant', 19127579, 6);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Inhalant', 19082258, 7);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Inhalant', 19018195, 8);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Injection', 19082103, 1);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Injection', 19126920, 2);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Injection', 19082104, 3);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Injection', 46234469, 4);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Injection', 46234468, 5);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Injection', 19095913, 6);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Injection', 19095914, 7);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Injection', 19082105, 8);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Injection', 44784844, 9);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Injection', 46234466, 10);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Injection', 46234467, 11);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Injection', 46275062, 12);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Injection', 19095915, 13);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Injection', 19082260, 14);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Oral', 19082573, 1);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Oral', 19082168, 2);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Oral', 19082191, 3);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Oral', 19082170, 4);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Oral', 19082251, 5);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Oral', 19001144, 6);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Oral', 19082652, 7);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Oral', 19095976, 8);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Oral', 19082651, 9);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Oral', 19082253, 10);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Oral', 19082101, 11);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Oral', 19111148, 12);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Oral', 19082169, 13);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Oral', 19001943, 14);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Oral', 19135868, 15);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Oral', 19021887, 16);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Oral', 19082223, 17);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Oral', 19082077, 18);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Oral', 19082079, 19);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Oral', 19082080, 20);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Oral', 44817840, 21);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Oral', 19082255, 22);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Oral', 19001949, 23);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Oral', 19082076, 24);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Oral', 19103220, 25);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Oral', 19082048, 26);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Oral', 19082256, 27);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Oral', 19082050, 28);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Oral', 40164192, 29);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Oral', 40175589, 30);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Oral', 19082222, 31);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Oral', 19082075, 32);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Oral', 19135866, 33);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Oral', 19102296, 34);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Oral', 19018708, 35);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Oral', 19135790, 36);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Oral', 45775489, 37);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Oral', 45775490, 38);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Oral', 45775491, 39);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Oral', 45775492, 40);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Oral', 19111155, 41);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Oral', 19126316, 42);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Oral', 19082285, 43);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Patch', 19082229, 1);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Patch', 19082701, 2);
		-- INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Patch', 19082224, 3); -- Topical cream
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Patch', 19082049, 4);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Patch', 19082071, 5);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Patch', 19082072, 6);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Patch', 19082252, 7);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Patch', 19082073, 8);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Topical', 19082228, 1);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Topical', 19082224, 2);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Topical', 19095912, 3);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Topical', 46234410, 4);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Topical', 19082227, 5);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Topical', 19082226, 6);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Topical', 19082225, 7);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Topical', 19095972, 8);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Topical', 19095973, 9);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Topical', 19082628, 11);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Topical', 19135438, 12);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Topical', 19135446, 13);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Topical', 19135439, 14);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Topical', 19135440, 15);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Topical', 19129401, 16);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Topical', 19082287, 17);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Topical', 19135925, 18);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Topical', 19082194, 19);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Topical', 19095975, 20);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Topical', 19082164, 21);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Topical', 19110977, 22);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Topical', 19082161, 23);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Topical', 19082576, 24);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Topical', 19082169, 25);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Topical', 19082193, 26);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Topical', 19082197, 27);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Topical', 19010878, 28);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Topical', 19112544, 29);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Topical', 19082163, 30);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Topical', 19082166, 31);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Topical', 19095916, 32);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Topical', 19095917, 33);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Topical', 19095974, 35);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Topical', 19010880, 36);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Topical', 19011932, 37);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Topical', 40228565, 38);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Topical', 19095900, 39);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Topical', 19011167, 40);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Topical', 19095911, 41);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Topical', 19082281, 42);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Topical', 19082199, 43);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Topical', 19095899, 44);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Topical', 19112649, 45);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Topical', 19082110, 46);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Topical', 19082165, 47);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Topical', 19082195, 48);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Topical', 45775488, 49);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Topical', 19095977, 50);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Topical', 19082167, 51);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Topical', 19082196, 52);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Topical', 19082102, 53);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Topical', 19010879, 54);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Spray', 19095899, 1);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Spray', 19095911, 2);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Spray', 19011167, 3);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Spray', 19082199, 4);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Spray', 19082281, 5);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Spray', 19095912, 6);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Spray', 19112649, 7);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Spray', 19095900, 8);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Vaccine', 19082104, 1);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Vaccine', 19126920, 2);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Vaccine', 19082103, 3);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Vaccine', 46234469, 4);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Vaccine', 19011167, 5);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Vaccine', 19082191, 6);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Vaccine', 19001949, 7);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Vaccine', 19082255, 8);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Suppository', 19082200, 1);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Suppository', 19093368, 2);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Suppository', 19082575, 3);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19082573, 1);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19082103, 2);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19082168, 3);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19082170, 4);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19082079, 5);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19082224, 6);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19082191, 7);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19082227, 8);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19082228, 9);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19135866, 10);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19082077, 11);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19095973, 12);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19082225, 13);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19129634, 14);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19126920, 15);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19082200, 16);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19082253, 17);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19095912, 18);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19082104, 19);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19001949, 20);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19082229, 21);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19008697, 22);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 46234469, 23);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19095898, 24);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19082076, 25);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19130307, 26);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19082258, 27);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19082255, 28);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19082109, 29);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19135925, 30);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19095916, 31);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19082080, 32);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19082285, 33);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19082286, 34);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19095972, 35);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19011167, 36);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19126590, 37);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19093368, 38);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19082195, 39);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19082165, 40);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19009068, 41);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19082167, 42);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19016586, 43);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19095976, 44);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19082108, 45);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19082226, 46);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19102295, 47);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19010878, 48);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19082627, 49);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19082259, 50);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19082110, 51);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19082651, 52);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 44817840, 53);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19126918, 54);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19124968, 55);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19082251, 56);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19129139, 57);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19095900, 58);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19082197, 59);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19102296, 60);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19082282, 61);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19095911, 62);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 46234468, 63);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19010880, 64);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19126316, 65);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 46234466, 66);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19010962, 67);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19082166, 68);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19126919, 69);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19095918, 70);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19127579, 71);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 46234467, 72);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 40175589, 73);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19082281, 74);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19059413, 75);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19082196, 76);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19082163, 77);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19082169, 78);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19112648, 79);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19095917, 80);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19095971, 81);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19082162, 82);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 40164192, 83);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19082574, 84);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19082105, 85);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19082222, 86);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19082575, 87);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19082652, 88);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 45775489, 89);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 45775491, 90);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19082164, 91);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 40167393, 92);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19082287, 93);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19082194, 94);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19082576, 95);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19095975, 96);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19082628, 97);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 46275062, 98);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19010879, 99);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 46234410, 100);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19135439, 101);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19095977, 102);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19082199, 103);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19082283, 104);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19095974, 105);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19135446, 106);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19130329, 107);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 45775490, 108);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 45775492, 109);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19082101, 110);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19135440, 111);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 19135438, 112);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 45775488, 113);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Unknown', 44784844, 114);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Instillation', 19016586, 1);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Instillation', 46234410, 2);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Instillation', 19082104, 3);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Instillation', 19082103, 4);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Instillation', 46234469, 5);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Implant', 19124968, 1);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Implant', 19082103, 2);
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence) VALUES ('Implant', 19082104, 3);
	END $_$;

	/*********************************
	* 4. CREATE AND link Drug Strength
	*********************************/
	-- Write units
	INSERT INTO drug_concept_stage
	SELECT DISTINCT u AS concept_name,
		'Drug',
		'HCPCS' AS vocabulary_id,
		'Unit' AS concept_class_id,
		u AS concept_code,
		NULL AS possible_excipient,
		NULL::DATE AS valid_start_date,
		NULL::DATE AS valid_end_date,
		NULL AS invalid_reason,
		NULL AS dose_form
	FROM (
		SELECT CASE 
				WHEN snd IS NULL
					THEN NULL
				WHEN trd IS NULL
					THEN 'weird'
				WHEN trd - snd - 1 <= 0
					THEN NULL
				ELSE substr(dose, snd + 1, trd - snd - 1)
				END AS u
		FROM (
			SELECT d.*,
				devv5.instr_nth(dose, '|', 1, 2) AS snd,
				devv5.instr_nth(dose, '|', 1, 3) AS trd
			FROM (
				SELECT regexp_replace(lower(concept_name), '([^0-9]+)([0-9][0-9\.,]*|per) *(mg|ml|micrograms?|units?|i\.?u\.?|grams?|gm|cc|mcg|milligrams?|million units)(.*)', '\1|\2|\3|\4','g') AS dose,
					concept_code
				FROM drug_concept_stage
				) d
			) AS s0
		) AS s1
	WHERE u IS NOT NULL;

	-- write mappings to real units
	DO $_$
	BEGIN
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence, conversion_factor) VALUES ('i.u.', 8718, 1, 1); -- to international unit
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence, conversion_factor) VALUES ('i.u.', 8510, 2, 1); -- to unit
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence, conversion_factor) VALUES ('iu', 8718, 1, 1); -- to international unit
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence, conversion_factor) VALUES ('iu', 8510, 2, 1); -- to unit
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence, conversion_factor) VALUES ('unit', 8510, 1, 1); -- to unit
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence, conversion_factor) VALUES ('unit', 8718, 2, 1); -- to international unit
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence, conversion_factor) VALUES ('units', 8510, 1, 1); -- to unit
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence, conversion_factor) VALUES ('units', 8718, 2, 1); -- to international unit
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence, conversion_factor) VALUES ('million units', 8510, 1, 1000000); -- to unit
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence, conversion_factor) VALUES ('million units', 8718, 2, 1000000); -- to international unit
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence, conversion_factor) VALUES ('gm', 8576, 1, 1000); -- to milligram
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence, conversion_factor) VALUES ('gm', 8587, 2, 1); -- to milliliter
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence, conversion_factor) VALUES ('gram', 8576, 1, 1000); -- to milligram
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence, conversion_factor) VALUES ('gram', 8587, 2, 1); -- to milliliter
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence, conversion_factor) VALUES ('grams', 8576, 1, 1000); -- to milligram
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence, conversion_factor) VALUES ('grams', 8587, 2, 1); -- to milliliter
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence, conversion_factor) VALUES ('mg', 8576, 1, 1); -- to milligram
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence, conversion_factor) VALUES ('milligram', 8576, 1, 1); -- to milligram
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence, conversion_factor) VALUES ('milligrams', 8576, 1, 1); -- to milligram
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence, conversion_factor) VALUES ('mcg', 8576, 1, 0.001); -- to milligram
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence, conversion_factor) VALUES ('meq', 9551, 1, 1); 
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence, conversion_factor) VALUES ('microgram', 8576, 1, 0.001); -- to milligram
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence, conversion_factor) VALUES ('micrograms', 8576, 1, 0.001); -- to milligram
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence, conversion_factor) VALUES ('ml', 8587, 1, 1); -- to milliliter
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence, conversion_factor) VALUES ('ml', 8576, 2, 1000); -- to milligram
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence, conversion_factor) VALUES ('cc', 8587, 1, 1); -- to milliliter
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence, conversion_factor) VALUES ('cc', 8576, 2, 1000); -- to milligram
		INSERT INTO relationship_to_concept (concept_code_1, concept_id_2, precedence, conversion_factor) VALUES ('%', 8554, 2, 1);
	END $_$;

	-- write drug_strength
	INSERT INTO ds_stage
	SELECT DISTINCT d.concept_code AS drug_concept_code,
		i.concept_code_2 AS ingredient_concept_code,
		CASE u
			WHEN '%'
				THEN NULL
			ELSE d.v
			END AS amount_value, -- only percent goes into liquid drug_strength
		CASE u
			WHEN '%'
				THEN NULL
			ELSE d.u
			END AS amount_unit,
		CASE u
			WHEN '%'
				THEN d.v
			ELSE NULL
			END AS numerator_value,
		CASE u
			WHEN '%'
				THEN d.u
			ELSE NULL
			END AS numerator_unit,
		NULL::FLOAT AS denominator_value,
		NULL AS denominator_unit,
		NULL::INT AS box_size
	FROM (
		SELECT concept_code,
			CASE v
				WHEN 'per'
					THEN 1
				ELSE cast(translate(v, 'a,', 'a') AS FLOAT)
				END AS v,
			u
		FROM (
			SELECT concept_code, -- dose,
				CASE 
					WHEN fst IS NULL
						THEN NULL
					WHEN snd IS NULL
						THEN 'weird'
					WHEN snd - fst - 1 <= 0
						THEN NULL
					ELSE substr(dose, fst + 1, snd - fst - 1)
					END AS v,
				CASE 
					WHEN snd IS NULL
						THEN NULL
					WHEN trd IS NULL
						THEN 'weird'
					WHEN trd - snd - 1 <= 0
						THEN NULL
					ELSE substr(dose, snd + 1, trd - snd - 1)
					END AS u
			FROM (
				SELECT d.*,
					devv5.instr_nth(dose, '|', 1, 1) AS fst,
					devv5.instr_nth(dose, '|', 1, 2) AS snd,
					devv5.instr_nth(dose, '|', 1, 3) AS trd
				FROM (
					SELECT regexp_replace(lower(concept_name), '([^0-9]+)([0-9][0-9\.,]*|per) *(mg|ml|micrograms?|units?|i\.?u\.?|grams?|gm|cc|mcg|milligrams?|million units|%)(.*)', '\1|\2|\3|\4','g') AS dose,
						concept_code
					FROM drug_concept_stage
					) d
				) AS s0
			) AS s1
		) d
	LEFT JOIN (
		SELECT r.concept_code_1,
			r.concept_code_2
		FROM internal_relationship_stage r
		JOIN drug_concept_stage i ON i.concept_code = r.concept_code_2
			AND i.concept_class_id = 'Ingredient' -- join the ingredient
		) i ON i.concept_code_1 = d.concept_code
	WHERE d.v IS NOT NULL;

	-- Manually fix the combination products
	DO $_$
	BEGIN
	-- C9285 defined AND correct
	-- C9447 not defined, will pass only AS form or ingredient
	-- C9448 defined:
	UPDATE ds_stage SET amount_value=0.5 WHERE drug_concept_code='C9448' AND ingredient_concept_code='palonosetron hcl';
	-- C9452 defined:
	UPDATE ds_stage SET amount_value=25 WHERE drug_concept_code='C9452' AND ingredient_concept_code='tazobactam';
	-- J0295 only defined for ampicillin
	DELETE FROM ds_stage WHERE drug_concept_code='J0295' AND ingredient_concept_code='sulbactam';
	-- J0571 - J0575 only defined for buprenorphine, will pass only AS form or ingredient
	DELETE FROM ds_stage WHERE drug_concept_code='J0571' AND ingredient_concept_code='naloxone hydrochloride';
	DELETE FROM ds_stage WHERE drug_concept_code='J0572' AND ingredient_concept_code='naloxone hydrochloride';
	DELETE FROM ds_stage WHERE drug_concept_code='J0573' AND ingredient_concept_code='naloxone hydrochloride';
	DELETE FROM ds_stage WHERE drug_concept_code='J0574' AND ingredient_concept_code='naloxone hydrochloride';
	DELETE FROM ds_stage WHERE drug_concept_code='J0575' AND ingredient_concept_code='naloxone hydrochloride';
	-- J0620 not defined, will pass only AS form or ingredient
	-- J0695 defined:
	UPDATE ds_stage SET amount_value=25 WHERE drug_concept_code='J0695' AND ingredient_concept_code='tazobactam';
	-- J0900 not defined, will pass only AS form or ingredient
	-- J1056 defined:
	UPDATE ds_stage SET amount_value=25 WHERE drug_concept_code='J1056' AND ingredient_concept_code='depo-estradiol cypionate';
	-- J1060 not defined, will pass only AS form or ingredient
	-- J1575 not defined, will pass only AS form or ingredient
	-- J1810 not defined, will pass only AS form or ingredient
	-- J2180 defined:
	UPDATE ds_stage SET amount_value=25 WHERE drug_concept_code='J2180' AND ingredient_concept_code='promethazine hcl';
	-- J2543 defined:
	UPDATE ds_stage SET amount_value=125, amount_unit='mg' WHERE drug_concept_code='J2543' AND ingredient_concept_code='tazobactam';
	-- J2770 defined:
	UPDATE ds_stage SET amount_value=350 WHERE drug_concept_code='J2770' AND ingredient_concept_code='quinupristin';
	UPDATE ds_stage SET amount_value=150 WHERE drug_concept_code='J2770' AND ingredient_concept_code='dalfopristin';
	-- J7042 defined:
	UPDATE ds_stage SET amount_value=NULL, amount_unit=NULL, numerator_value=50, numerator_unit='mg', denominator_unit='ml' WHERE drug_concept_code='J7042' AND ingredient_concept_code='dextrose';
	UPDATE ds_stage SET amount_value=NULL, amount_unit=NULL, numerator_value=0.154, numerator_unit='meq', denominator_unit='ml' WHERE drug_concept_code='J7042' AND ingredient_concept_code='normal saline solution';
	-- J7060 defined:
	UPDATE ds_stage SET amount_value=NULL, amount_unit=NULL, numerator_value=50, numerator_unit='mg', denominator_unit='ml' WHERE drug_concept_code='J7060' AND ingredient_concept_code='dextrose';
	-- J7120 defined:
	-- Calcium Chloride 0.0014 MEQ/ML / Potassium Chloride 0.004 MEQ/ML / Sodium Chloride 0.103 MEQ/ML / Sodium Lactate 0.028 MEQ/ML InjecTABLE Solution
	UPDATE ds_stage SET amount_value=NULL, amount_unit=NULL, numerator_value=0.0014, numerator_unit='meq', denominator_unit='ml' WHERE drug_concept_code='J7120' AND ingredient_concept_code='calcium chloride';
	UPDATE ds_stage SET amount_value=NULL, amount_unit=NULL, numerator_value=0.004, numerator_unit='meq', denominator_unit='ml' WHERE drug_concept_code='J7120' AND ingredient_concept_code='potassium chloride';
	UPDATE ds_stage SET amount_value=NULL, amount_unit=NULL, numerator_value=0.103, numerator_unit='meq', denominator_unit='ml' WHERE drug_concept_code='J7120' AND ingredient_concept_code='normal saline solution';
	UPDATE ds_stage SET amount_value=NULL, amount_unit=NULL, numerator_value=0.028, numerator_unit='meq', denominator_unit='ml' WHERE drug_concept_code='J7120' AND ingredient_concept_code='sodium lactate';
	-- J7121 defined:
	-- Calcium Chloride 0.001 MEQ/ML / Glucose 50 MG/ML / Potassium Chloride 0.004 MEQ/ML / Sodium Chloride 0.103 MEQ/ML / Sodium Lactate 0.028 MEQ/ML InjecTABLE Solution
	UPDATE ds_stage SET amount_value=NULL, amount_unit=NULL, numerator_value=50, numerator_unit='mg', denominator_unit='ml' WHERE drug_concept_code='J7121' AND ingredient_concept_code='dextrose';
	UPDATE ds_stage SET amount_value=NULL, amount_unit=NULL, numerator_value=0.001, numerator_unit='meq', denominator_unit='ml' WHERE drug_concept_code='J7121' AND ingredient_concept_code='calcium chloride';
	UPDATE ds_stage SET amount_value=NULL, amount_unit=NULL, numerator_value=0.004, numerator_unit='meq', denominator_unit='ml' WHERE drug_concept_code='J7121' AND ingredient_concept_code='potassium chloride';
	UPDATE ds_stage SET amount_value=NULL, amount_unit=NULL, numerator_value=0.103, numerator_unit='meq', denominator_unit='ml' WHERE drug_concept_code='J7121' AND ingredient_concept_code='normal saline solution';
	UPDATE ds_stage SET amount_value=NULL, amount_unit=NULL, numerator_value=0.028, numerator_unit='meq', denominator_unit='ml' WHERE drug_concept_code='J7121' AND ingredient_concept_code='sodium lactate';
	-- J7620 defined:
	UPDATE ds_stage SET amount_value=2.5 WHERE drug_concept_code='J7620' AND ingredient_concept_code='albuterol';
	-- J9175 defined:
	-- Calcium Chloride 0.00136 MEQ/ML / Glucose 0.8 MG/ML / Magnesium Sulfate 0.00122 MEQ/ML / Potassium Chloride 0.00403 MEQ/ML / Sodium Bicarbonate 0.0226 MEQ/ML / Sodium Chloride 0.125 MEQ/ML / sodium phosphate 0.000746 MEQ/ML InjecTABLE Solution [Elliotts B
	UPDATE ds_stage SET amount_value=NULL, amount_unit=NULL, numerator_value=0.0226, numerator_unit='meq', denominator_unit='ml' WHERE drug_concept_code='J9175' AND ingredient_concept_code='sodium bicarbonate';
	UPDATE ds_stage SET amount_value=NULL, amount_unit=NULL, numerator_value= 0.000746, numerator_unit='meq', denominator_unit='ml' WHERE drug_concept_code='J9175' AND ingredient_concept_code='sodium phosphate';
	UPDATE ds_stage SET amount_value=NULL, amount_unit=NULL, numerator_value=0.125, numerator_unit='meq', denominator_unit='ml' WHERE drug_concept_code='J9175' AND ingredient_concept_code='normal saline solution';
	UPDATE ds_stage SET amount_value=NULL, amount_unit=NULL, numerator_value=0.8, numerator_unit='mg', denominator_unit='ml' WHERE drug_concept_code='J9175' AND ingredient_concept_code='dextrose';
	UPDATE ds_stage SET amount_value=NULL, amount_unit=NULL, numerator_value=0.00136, numerator_unit='meq', denominator_unit='ml' WHERE drug_concept_code='J9175' AND ingredient_concept_code='calcium chloride';
	UPDATE ds_stage SET amount_value=NULL, amount_unit=NULL, numerator_value=0.00403, numerator_unit='meq', denominator_unit='ml' WHERE drug_concept_code='J9175' AND ingredient_concept_code='potassium chloride';
	UPDATE ds_stage SET amount_value=NULL, amount_unit=NULL, numerator_value=0.00122, numerator_unit='meq', denominator_unit='ml' WHERE drug_concept_code='J9175' AND ingredient_concept_code='magnesium sulfate';
	-- S0039: not defined, will pass only AS form or ingredient
	-- S0040 somewhat defined. the 31 mg are in one milliliter andn are a sum of both ingredients:
	UPDATE ds_stage SET amount_value=NULL, amount_unit=NULL, numerator_value=30, numerator_unit='mg', denominator_unit='ml' WHERE drug_concept_code='S0040' AND ingredient_concept_code='ticarcillin';
	UPDATE ds_stage SET amount_value=NULL, amount_unit=NULL, numerator_value=1, numerator_unit='mg', denominator_unit='ml' WHERE drug_concept_code='S0040' AND ingredient_concept_code='clavulanate';
	-- S5010: defined:
	UPDATE ds_stage SET amount_value=NULL, amount_unit=NULL, numerator_value=50, numerator_unit='mg', denominator_unit='ml' WHERE drug_concept_code='S5010' AND ingredient_concept_code='dextrose';
	UPDATE ds_stage SET amount_value=NULL, amount_unit=NULL, numerator_value=0.0769, numerator_unit='meq', denominator_unit='ml' WHERE drug_concept_code='S5010' AND ingredient_concept_code='normal saline solution';
	-- S5011
	-- Calcium Chloride 0.001 MEQ/ML / Glucose 50 MG/ML / Potassium Chloride 0.004 MEQ/ML / Sodium Chloride 0.103 MEQ/ML / Sodium Lactate 0.028 MEQ/ML InjecTABLE Solution
	UPDATE ds_stage SET amount_value=NULL, amount_unit=NULL, numerator_value=50, numerator_unit='mg', denominator_unit='ml' WHERE drug_concept_code='S5011' AND ingredient_concept_code='dextrose';
	UPDATE ds_stage SET amount_value=NULL, amount_unit=NULL, numerator_value=0.001, numerator_unit='meq', denominator_unit='ml' WHERE drug_concept_code='S5011' AND ingredient_concept_code='calcium chloride';
	UPDATE ds_stage SET amount_value=NULL, amount_unit=NULL, numerator_value=0.004, numerator_unit='meq', denominator_unit='ml' WHERE drug_concept_code='S5011' AND ingredient_concept_code='potassium chloride';
	UPDATE ds_stage SET amount_value=NULL, amount_unit=NULL, numerator_value=0.103, numerator_unit='meq', denominator_unit='ml' WHERE drug_concept_code='S5011' AND ingredient_concept_code='normal saline solution';
	UPDATE ds_stage SET amount_value=NULL, amount_unit=NULL, numerator_value=0.028, numerator_unit='meq', denominator_unit='ml' WHERE drug_concept_code='S5011' AND ingredient_concept_code='sodium lactate';
	-- S5012: undefined, including the ingredients. Still:
	UPDATE ds_stage SET amount_value=NULL, amount_unit=NULL, numerator_value=50, numerator_unit='mg', denominator_unit='ml' WHERE drug_concept_code='S5012' AND ingredient_concept_code='dextrose';
	DELETE FROM ds_stage WHERE drug_concept_code='S5012' AND ingredient_concept_code='potassium chloride';
	-- S5013: undefined, but this we know:
	UPDATE ds_stage SET amount_value=NULL, amount_unit=NULL, numerator_value=50, numerator_unit='mg', denominator_unit='ml' WHERE drug_concept_code='S5013' AND ingredient_concept_code='dextrose';
	UPDATE ds_stage SET amount_value=NULL, amount_unit=NULL, numerator_value=0.0769, numerator_unit='meq', denominator_unit='ml' WHERE drug_concept_code='S5013' AND ingredient_concept_code='normal saline solution';
	DELETE FROM ds_stage WHERE drug_concept_code='S5013' AND ingredient_concept_code='potassium chloride';
	DELETE FROM ds_stage WHERE drug_concept_code='S5013' AND ingredient_concept_code='magnesium sulfate';
	-- S5014: undefined, but this we know:
	UPDATE ds_stage SET amount_value=NULL, amount_unit=NULL, numerator_value=50, numerator_unit='mg', denominator_unit='ml' WHERE drug_concept_code='S5014' AND ingredient_concept_code='dextrose';
	UPDATE ds_stage SET amount_value=NULL, amount_unit=NULL, numerator_value=0.0769, numerator_unit='meq', denominator_unit='ml' WHERE drug_concept_code='S5014' AND ingredient_concept_code='normal saline solution';
	DELETE FROM ds_stage WHERE drug_concept_code='S5014' AND ingredient_concept_code='potassium chloride';
	DELETE FROM ds_stage WHERE drug_concept_code='S5014' AND ingredient_concept_code='magnesium sulfate';
	END $_$;

	/******************************
	* 5. CREATE AND link Brand Names *
	******************************/
	-- CREATE relationship FROM drug to brand (direct, need to change to stage-type brandsd
	CREATE INDEX IF NOT EXISTS trgm_brand_idx ON drug_concept_stage USING GIN (concept_name devv5.gin_trgm_ops); --for LIKE patterns
	CREATE UNLOGGED TABLE brandname AS
	SELECT d.concept_code,
		c.concept_id,
		lower(c.concept_name) AS brandname
	FROM drug_concept_stage d
	JOIN concept c ON c.vocabulary_id = 'RxNorm'
		AND c.concept_class_id = 'Brand Name'
		AND d.concept_name ilike '%' || c.concept_name || '%'
		AND lower(d.concept_name) ~ CONCAT (
			'[^a-z]',
			lower(c.concept_name),
			'[^a-z]'
			)
	WHERE d.concept_class_id = 'Procedure Drug';

	INSERT INTO drug_concept_stage
	SELECT DISTINCT brandname AS concept_name,
		'Drug' AS domain_id,
		'HCPCS' AS vocabulary_id,
		'Brand Name' AS concept_class_id,
		brandname AS concept_code,
		NULL AS possible_excipient,
		NULL::DATE AS valid_start_date,
		NULL::DATE AS valid_end_date,
		NULL AS invalid_reason,
		NULL AS dose_form
	FROM brandname;

	INSERT INTO relationship_to_concept
	SELECT DISTINCT brandname AS concept_code_1,
		concept_id AS concept_id_2,
		1 AS precedence,
		NULL::FLOAT AS conversion_factor
	FROM brandname;

	INSERT INTO internal_relationship_stage
	SELECT DISTINCT concept_code AS concept_code_1,
		brandname AS concept_code_2
	FROM brandname;

	/****************************
	* 6. Clean up
	*****************************/
	-- remove dose forms FROM concept_stage TABLE
	ALTER TABLE drug_concept_stage DROP COLUMN dose_form;
	DROP TABLE brandname;
END;
$BODY$
LANGUAGE 'plpgsql' SECURITY INVOKER
SET client_min_messages = error;