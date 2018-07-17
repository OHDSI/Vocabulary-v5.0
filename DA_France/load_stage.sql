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
* Authors: Eldar Allakhverdiiev, Dmitry Dymshyts, Christian Reich
* Date: 2017
**************************************************************************/
DROP TABLE IF EXISTS non_drugs;
DROP TABLE IF EXISTS france_1;
DROP TABLE IF EXISTS pre_ingr;
DROP TABLE IF EXISTS ingr;
DROP TABLE IF EXISTS brand;
DROP TABLE IF EXISTS forms;
DROP TABLE IF EXISTS unit;
DROP TABLE IF EXISTS drug_products;
DROP TABLE IF EXISTS list_temp;
DROP TABLE IF EXISTS ds_for_prolonged;
DROP TABLE IF EXISTS ds_complex;

DROP SEQUENCE IF EXISTS conc_stage_seq;
DROP SEQUENCE IF EXISTS new_vocab;

TRUNCATE TABLE drug_concept_stage;
TRUNCATE TABLE internal_relationship_stage;
TRUNCATE TABLE ds_stage;
TRUNCATE TABLE relationship_to_concept;
TRUNCATE TABLE pc_stage;

--delete duplicates
DELETE
FROM france f
WHERE EXISTS (
		SELECT 1
		FROM france f_int
		WHERE f_int.pfc = f.pfc
			AND f_int.ctid > f.ctid
		);

DROP TABLE IF EXISTS non_drugs;
CREATE TABLE non_drugs AS
	SELECT product_desc,
		form_desc,
		dosage,
		dosage_add,
		volume,
		packsize,
		claatc,
		pfc,
		molecule,
		cd_nfc_3,
		english,
		lb_nfc_3,
		descr_pck,
		strg_unit,
		strg_meas,
		NULL::VARCHAR(250) AS concept_type
	FROM france
	WHERE molecule ~* 'BANDAGES|DEVICES|CARE PRODUCTS|DRESSING|CATHETERS|EYE OCCLUSION PATCH|INCONTINENCE COLLECTION APPLIANCES|SOAP|CREAM|HAIR|SHAMPOO|LOTION|FACIAL CLEANSER|LIP PROTECTANTS|CLEANSING AGENTS|SKIN|TONICS|TOOTHPASTES|MOUTH|SCALP LOTIONS|UREA 13|BARIUM|CRYSTAL VIOLET'
		OR molecule ~* 'LENS SOLUTIONS|INFANT |DISINFECTANT|ANTISEPTIC|CONDOMS|COTTON WOOL|GENERAL NUTRIENTS|LUBRICANTS|INSECT REPELLENTS|FOOD|SLIMMING PREPARATIONS|SPECIAL DIET|SWAB|WOUND|GADOBUTROL|GADODIAMIDE|GADOBENIC ACID|GADOTERIC ACID|GLUCOSE 1-PHOSPHATE|BRAN|PADS$|IUD'
		OR molecule ~* 'AFTER SUN PROTECTANTS|BABY MILKS|INCONTINENCE PADS|INSECT REPELLENTS|WIRE|CORN REMOVER|DDT|DECONGESTANT RUBS|EYE MAKE-UP REMOVERS|FIXATIVES|FOOT POWDERS|FIORAVANTI BALSAM|LOW CALORIE FOOD|NUTRITION|TETRAMETHRIN|OTHERS|NON MEDICATED|NON PHARMACEUTICAL|TRYPAN BLUE'
		OR (
			molecule LIKE '% TEST%'
			AND molecule NOT LIKE 'TUBERCULIN%'
			)
		OR descr_pck LIKE '%KCAL%'
		OR english = 'Non Human Usage Products'
		OR lb_nfc_3 LIKE '%NON US.HUMAIN%';

--list of ingredients
DROP TABLE IF EXISTS pre_ingr;
CREATE TABLE pre_ingr AS
SELECT DISTINCT ingred AS concept_name,
	pfc,
	'Ingredient'::VARCHAR AS concept_class_id
FROM (
	SELECT UNNEST(regexp_matches(molecule, '[^\+]+', 'g')) AS ingred,
		pfc
	FROM france
	WHERE pfc NOT IN (
			SELECT pfc
			FROM non_drugs
			)
	) AS s0
WHERE ingred != 'NULL';

 -- extract ingredients where it is obvious for molecule like 'NULL'
DROP TABLE IF EXISTS france_1;
CREATE TABLE france_1 AS
SELECT *
FROM france
WHERE molecule <> 'NULL'
UNION
SELECT product_desc,
	form_desc,
	dosage,
	dosage_add,
	volume,
	packsize,
	claatc,
	a.pfc,
	CASE 
		WHEN concept_name IS NOT NULL
			THEN concept_name
		ELSE 'NULL'
		END,
	cd_nfc_3,
	english,
	lb_nfc_3,
	descr_pck,
	strg_unit,
	strg_meas
FROM france a
LEFT JOIN pre_ingr b ON trim(replace(product_desc, 'DCI', '')) = upper(concept_name)
WHERE molecule = 'NULL';

--list of ingredients
DROP TABLE IF EXISTS ingr;
CREATE TABLE ingr AS
SELECT DISTINCT ingred AS concept_name,
	pfc,
	'Ingredient'::VARCHAR AS concept_class_id
FROM (
	SELECT UNNEST(regexp_matches(molecule, '[^\+]+', 'g')) AS ingred,
		pfc
	FROM france_1
	WHERE pfc NOT IN (
			SELECT pfc
			FROM non_drugs
			)
	) AS s0
WHERE ingred != 'NULL';

--list of Brand Names
DROP TABLE IF EXISTS brand;
CREATE TABLE brand AS
SELECT product_desc AS concept_name,
	pfc,
	'Brand Name'::VARCHAR AS concept_class_id
FROM france_1
WHERE pfc NOT IN (
		SELECT pfc
		FROM non_drugs
		)
	AND pfc NOT IN (
		SELECT pfc
		FROM france_1
		WHERE molecule = 'NULL'
		)
	AND product_desc NOT LIKE '%DCI%'
	AND NOT product_desc ~ 'L\.IND|LAB IND|^VAC |VACCIN'
	AND upper(product_desc) NOT IN (
		SELECT upper(concept_name)
		FROM devv5.concept
		WHERE concept_class_id LIKE 'Ingredient'
			AND standard_concept = 'S'
		);

UPDATE brand
SET concept_name = 'UMULINE PROFIL'
WHERE concept_name LIKE 'UMULINE PROFIL%';

UPDATE brand
SET concept_name = 'CALCIPRAT'
WHERE concept_name = 'CALCIPRAT D3';

UPDATE brand
SET concept_name = 'DOMPERIDONE ZENTIVA'
WHERE concept_name LIKE 'DOMPERIDONE ZENT%';

--list of Dose Forms
DROP TABLE IF EXISTS forms;
CREATE TABLE forms AS
SELECT DISTINCT trim(dose_form_name) AS concept_name,
	'Dose Form'::VARCHAR AS concept_class_id
FROM france_names_translation a
JOIN france_1 b ON a.dose_form = b.LB_NFC_3
WHERE b.molecule != 'NULL'
	AND pfc NOT IN (
		SELECT pfc
		FROM non_drugs
		)
	AND trim(dose_form_name) NOT IN (
		'Dose Form for Promotional Purposes',
		'Miscellaneous External Form',
		'Unknown Form'
		);

-- units, take units used for volume and strength definition
DROP TABLE IF EXISTS unit;
CREATE TABLE unit AS
SELECT strg_meas AS concept_name,
	'Unit'::VARCHAR AS concept_class_id,
	strg_meas AS concept_code
FROM (
	SELECT strg_meas
	FROM france_1
	WHERE pfc NOT IN (
			SELECT pfc
			FROM non_drugs
			)
	UNION
	SELECT regexp_replace(volume, '[[:digit:]\.]', '','g')
	FROM france_1
	WHERE strg_meas != 'NULL'
		AND pfc NOT IN (
			SELECT pfc
			FROM non_drugs
			)
	) a
WHERE a.strg_meas NOT IN (
		'CH',
		'NULL'
		);

INSERT INTO unit VALUES ('UI', 'Unit', 'UI');
INSERT INTO unit VALUES ('MUI', 'Unit', 'MUI');
INSERT INTO unit VALUES ('DOS', 'Unit', 'DOS');
INSERT INTO unit VALUES ('GM', 'Unit', 'GM');
INSERT INTO unit VALUES ('H', 'Unit', 'H');

--no inf. about suppliers
DROP TABLE IF EXISTS drug_products;
CREATE TABLE drug_products AS
SELECT DISTINCT CASE 
		WHEN d.pfc IS NOT NULL
			THEN trim(regexp_replace(replace(CONCAT (
								volume,
								' ',
								substr((replace(molecule, '+', ' / ')), 1, 175) --To avoid names length more than 255
								,
								'  ',
								c.dose_form_name,
								' [' || product_desc || ']',
								' Box of ',
								a.packsize
								), 'NULL', ''), '\s+', ' ', 'g'))
		ELSE trim(regexp_replace(replace(CONCAT (
							volume,
							' ',
							substr((replace(molecule, '+', ' / ')), 1, 175) --To avoid names length more than 255
							,
							' ',
							c.dose_form_name,
							' Box of ',
							a.packsize
							), 'NULL', ''), '\s+', ' ', 'g'))
		END AS concept_name,
	'Drug Product'::VARCHAR AS concept_class_id,
	a.pfc AS concept_code
FROM france_1 a
LEFT JOIN brand d ON d.concept_name = a.product_desc
LEFT JOIN france_names_translation c ON a.lb_nfc_3 = c.dose_form -- france_names_translation is manually created table containing Form translation to English 
WHERE a.pfc NOT IN (
		SELECT pfc
		FROM non_drugs
		)
	AND molecule <> 'NULL';

--SEQUENCE FOR OMOP-GENERATED CODES


DROP SEQUENCE IF EXISTS conc_stage_seq;
CREATE SEQUENCE conc_stage_seq MINVALUE 100 MAXVALUE 1000000 START WITH 100 INCREMENT BY 1 CACHE 20;

DROP TABLE IF EXISTS list_temp;
CREATE TABLE list_temp AS
SELECT concept_name,
	concept_class_id,
	'OMOP' || nextval('conc_stage_seq') AS concept_code
FROM (
	SELECT concept_name,
		concept_class_id
	FROM ingr
	UNION
	SELECT concept_name,
		concept_class_id
	FROM Brand
	WHERE concept_name NOT IN (
			SELECT concept_name
			FROM ingr
			)
	UNION
	SELECT concept_name,
		concept_class_id
	FROM forms
	) AS s0;

--fill drug_concept_stage
INSERT INTO drug_concept_stage (
	concept_name,
	vocabulary_id,
	domain_id,
	concept_class_id,
	standard_concept,
	concept_code,
	possible_excipient,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT concept_name,
	'DA_France',
	'Drug',
	concept_class_id,
	'S',
	concept_code,
	NULL,
	CURRENT_DATE AS valid_start_date, --check start date
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL
FROM (
	SELECT *
	FROM list_temp
	UNION
	SELECT *
	FROM drug_products
	UNION
	SELECT *
	FROM unit
	) AS s0;

--DEVICES (rebuild names)
INSERT INTO drug_concept_stage (
	concept_name,
	vocabulary_id,
	domain_id,
	concept_class_id,
	standard_concept,
	concept_code,
	possible_excipient,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT DISTINCT substr(CONCAT (
			volume,
			' ',
			CASE molecule
				WHEN 'NULL'
					THEN NULL
				ELSE CONCAT (
						molecule,
						' '
						)
				END,
			CASE dosage
				WHEN 'NULL'
					THEN NULL
				ELSE CONCAT (
						dosage,
						' '
						)
				END,
			CASE dosage_add
				WHEN 'NULL'
					THEN NULL
				ELSE CONCAT (
						dosage_add,
						' '
						)
				END,
			CASE form_desc
				WHEN 'NULL'
					THEN NULL
				ELSE form_desc
				END,
			CASE product_desc
				WHEN 'NULL'
					THEN NULL
				ELSE CONCAT (
						' [',
						product_desc,
						']'
						)
				END,
			' Box of ',
			packsize
			), 1, 255) AS concept_name,
	'DA_France',
	'Device',
	'Device',
	'S',
	pfc,
	NULL,
	CURRENT_DATE AS valid_start_date, --check start date
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL
FROM non_drugs;

--fill IRS
--Drug to Ingredients
INSERT INTO internal_relationship_stage
SELECT DISTINCT pfc,
	concept_code
FROM list_temp a
JOIN ingr USING (
		concept_name,
		concept_class_id
		);

--drug to Brand Name
INSERT INTO internal_relationship_stage
SELECT DISTINCT pfc,
	concept_code
FROM list_temp a
JOIN brand using (
		concept_name,
		concept_class_id
		);

--drug to Dose Form
INSERT INTO internal_relationship_stage
SELECT DISTINCT pfc,
	concept_code
FROM france_1 a
JOIN france_names_translation b ON a.lb_nfc_3 = b.dose_form
JOIN drug_concept_stage c ON b.dose_form_name = c.concept_name
	AND concept_class_id = 'Dose Form'
WHERE pfc IN (
		SELECT concept_code
		FROM drug_concept_stage
		WHERE concept_class_id = 'Drug Product'
		);

--fill ds_stage
--manually found dosages
INSERT INTO ds_stage
SELECT DISTINCT pfc,
	concept_code,
	packsize,
	amount_value,
	amount_unit,
	numerator_value,
	numerator_unit,
	denominator_value,
	denominator_unit
FROM ds_stage_manual f
JOIN drug_concept_stage dcs ON upper(molecule) = upper(concept_name)
	AND dcs.concept_class_id = 'Ingredient';

--insulins
INSERT INTO ds_stage (
	drug_concept_code,
	ingredient_concept_code,
	numerator_value,
	numerator_unit,
	denominator_value,
	denominator_unit,
	box_size
	)
SELECT pfc,
	concept_code_2,
	strg_unit::FLOAT * substring(volume, '([[:digit:]]+(\.[[:digit:]]+)?)')::FLOAT AS numerator_value,
	strg_meas AS numerator_unit,
	substring(volume, '([[:digit:]]+(\.[[:digit:]]+)?)')::FLOAT AS denominator_value,
	regexp_replace(volume, '([[:digit:]]+(\.[[:digit:]]+)?)', '', 'g') AS denominator_unit,
	packsize::INT
FROM france_1 f
JOIN internal_relationship_stage irs ON f.pfc = irs.concept_code_1
JOIN drug_concept_stage dcs ON concept_code_2 = dcs.concept_code
	AND dcs.concept_class_id = 'Ingredient'
WHERE volume != 'NULL'
	AND strg_meas NOT IN (
		'%',
		'NULL'
		)
	AND molecule NOT LIKE '%+%'
	AND molecule LIKE '%INSULIN%'
	AND pfc NOT IN (
		SELECT drug_concept_code
		FROM ds_stage
		);

-- for delayed (mh/H) drugs
DROP TABLE IF EXISTS ds_for_prolonged;
CREATE TABLE ds_for_prolonged AS
SELECT pfc,
	concept_code,
	descr_pck,
	substring(descr_pck, '(\d+(\.\d+)*)\w*/\d+H') AS numerator_value,
	'MG'::VARCHAR AS numerator_unit,
	substring(descr_pck, '\d+(?:\.\d+)*\w*/(\d+)H') AS denominator_value,
	'H'::VARCHAR AS denominator_unit,
	packsize
FROM france_1 f
JOIN internal_relationship_stage irs ON f.pfc = irs.concept_code_1
JOIN drug_concept_stage dcs ON concept_code_2 = dcs.concept_code
	AND dcs.concept_class_id = 'Ingredient'
WHERE descr_pck ~ '/\d+\s?H'
	AND molecule NOT LIKE '%+%'
	AND pfc NOT IN (
		SELECT drug_concept_code
		FROM ds_stage
		);

UPDATE ds_for_prolonged
SET numerator_value = 0.025
WHERE pfc IN (
		'1512103',
		'2227001',
		'3420009',
		'1230210',
		'3235240',
		'1128703',
		'2414501',
		'2323107',
		'9737636',
		'9737629',
		'9737634',
		'9737615'
		);

UPDATE ds_for_prolonged
SET numerator_value = 0.037
WHERE pfc IN (
		'1128708',
		'3420001',
		'1230202',
		'2427205',
		'9737621'
		);

UPDATE ds_for_prolonged
SET numerator_value = 0.04
WHERE pfc = '2784501';

UPDATE ds_for_prolonged
SET numerator_value = 0.05
WHERE pfc IN (
		'3235245',
		'1128705',
		'2590301',
		'2414503',
		'1512101',
		'1856301',
		'3420003',
		'1230203',
		'2427201',
		'1856601',
		'2323108',
		'2323108',
		'2227003',
		'9737641',
		'9737606',
		'9737630',
		'9737610',
		'9737609',
		'9737639',
		'9737607',
		'9737605',
		'9737608'
		);

UPDATE ds_for_prolonged
SET numerator_value = 0.06
WHERE pfc = '2784503';

UPDATE ds_for_prolonged
SET numerator_value = 0.075
WHERE pfc IN (
		'1128710',
		'2427207',
		'2323109',
		'1230204',
		'3420005',
		'2414505',
		'1856603'
		);

UPDATE ds_for_prolonged
SET numerator_value = 0.075
WHERE pfc IN (
		'9737642',
		'2784505',
		'9737638',
		'9737633',
		'9737616',
		'9737631'
		);

UPDATE ds_for_prolonged
SET numerator_value = 0.1
WHERE pfc IN (
		'1128706',
		'2427203',
		'3235250'
		);

INSERT INTO ds_stage (
	drug_concept_code,
	ingredient_concept_code,
	numerator_value,
	numerator_unit,
	denominator_value,
	denominator_unit,
	box_size
	)
SELECT pfc,
	concept_code,
	numerator_value::FLOAT,
	numerator_unit,
	denominator_value::FLOAT,
	denominator_unit,
	packsize::INT
FROM ds_for_prolonged;

--doesn't have a volume and drug has only one ingredient
INSERT INTO ds_stage (
	drug_concept_code,
	ingredient_concept_code,
	amount_value,
	amount_unit,
	box_size
	)
SELECT pfc,
	concept_code_2,
	strg_unit::FLOAT,
	strg_meas,
	packsize::INT
FROM france_1 f
JOIN internal_relationship_stage irs ON f.pfc = irs.concept_code_1
JOIN drug_concept_stage dcs ON concept_code_2 = dcs.concept_code
	AND dcs.concept_class_id = 'Ingredient'
WHERE volume = 'NULL'
	AND strg_unit != 'NULL'
	AND molecule NOT LIKE '%+%'
	AND strg_meas != '%'
	AND molecule <> 'NULL'
	AND pfc NOT IN (
		SELECT drug_concept_code
		FROM ds_stage
		);

--one ingredient and volume present (descr_pck not like '%/%')
INSERT INTO ds_stage (
	drug_concept_code,
	ingredient_concept_code,
	numerator_value,
	numerator_unit,
	denominator_value,
	denominator_unit,
	box_size
	)
SELECT pfc,
	concept_code_2,
	strg_unit::FLOAT,
	strg_meas,
	substring(volume, '([[:digit:]]+(\.[[:digit:]]+)?)')::FLOAT AS denominator_value,
	regexp_replace(volume, '[[:digit:]]+(\.[[:digit:]]+)?', '', 'g') AS denominator_unit,
	packsize::INT
FROM france_1 f
JOIN internal_relationship_stage irs ON f.pfc = irs.concept_code_1
JOIN drug_concept_stage dcs ON concept_code_2 = dcs.concept_code
	AND dcs.concept_class_id = 'Ingredient'
WHERE volume != 'NULL'
	AND strg_meas NOT IN (
		'%',
		'NULL'
		)
	AND molecule NOT LIKE '%+%'
	AND descr_pck NOT LIKE '%/%'
	AND molecule <> 'NULL'
	AND pfc NOT IN (
		SELECT drug_concept_code
		FROM ds_stage
		);

--one ingredient and volume present (descr_pck like '%/%') volume not like '%G'
INSERT INTO ds_stage (
	drug_concept_code,
	ingredient_concept_code,
	numerator_value,
	numerator_unit,
	denominator_value,
	denominator_unit,
	box_size
	)
WITH a AS (
		SELECT packsize::INT,
			pfc,
			substring(volume, '([[:digit:]]+(\.[[:digit:]]+)?)')::FLOAT AS denominator_value,
			regexp_replace(volume, '[[:digit:]]+(\.[[:digit:]]+)?', '', 'g') AS denominator_unit,
			strg_unit::FLOAT,
			strg_meas,
			nullif(substring(DESCR_PCK, '/(\d*)'), '')::FLOAT AS num_coef
		FROM france_1
		WHERE volume != 'NULL'
			AND volume NOT LIKE '%G'
			AND strg_meas NOT IN (
				'%',
				'NULL'
				)
			AND molecule NOT LIKE '%+%'
			AND descr_pck LIKE '%/%'
			AND molecule <> 'NULL'
			AND pfc NOT IN (
				SELECT drug_concept_code
				FROM ds_stage
				)
		)
SELECT DISTINCT pfc,
	concept_code_2,
	coalesce(((strg_unit * denominator_value) / num_coef), (strg_unit * denominator_value)) AS numerator_value,
	strg_meas AS numerator_unit,
	denominator_value,
	denominator_unit,
	packsize
FROM a
JOIN internal_relationship_stage irs ON a.pfc = irs.concept_code_1
JOIN drug_concept_stage dcs ON concept_code_2 = dcs.concept_code
	AND dcs.concept_class_id = 'Ingredient';


--one ingredient and volume present (descr_pck like '%/%') volume not like '%G' review manually!!!! 
--(select * from france where  volume !='NULL' and volume  like '%G' and  strg_meas not in ( '%','NULL')  AND MOLECULE NOT LIKE '%+%' and descr_pck like '%/%')

--one ingredient dosage like %, descr_pck not like '%DOS%'
INSERT INTO ds_stage (
	drug_concept_code,
	ingredient_concept_code,
	numerator_value,
	numerator_unit,
	denominator_value,
	denominator_unit,
	box_size
	)
SELECT DISTINCT pfc,
	concept_code_2,
	CASE 
		WHEN regexp_replace(volume, '\d*(\.)?(\d)*', '', 'g') IN (
				'L',
				'ML'
				)
			THEN strg_unit::FLOAT * (substring(volume, '(\d*(\.)?(\d)*)'))::FLOAT * 10
		WHEN regexp_replace(volume, '\d*(\.)?(\d)*', '', 'g') IN (
				'KG',
				'G'
				)
			THEN strg_unit::FLOAT * (substring(volume, '(\d*(\.)?(\d)*)'))::FLOAT / 100
		ELSE NULL
		END AS numerator_value,
	CASE 
		WHEN regexp_replace(volume, '\d*(\.)?(\d)*', '', 'g') = 'ML'
			THEN 'MG'
		WHEN regexp_replace(volume, '\d*(\.)?(\d)*', '', 'g') = 'L'
			THEN 'G'
		ELSE regexp_replace(volume, '\d*(\.)?(\d)*', '', 'g')
		END AS numerator_unit,
	substring(volume, '(\d*(\.)?(\d)*)')::FLOAT AS denominator_value,
	regexp_replace(volume, '\d*(\.)?(\d)*', '', 'g') AS denominator_unit,
	packsize::INT
FROM france_1 f
JOIN internal_relationship_stage irs ON f.pfc = irs.concept_code_1
JOIN drug_concept_stage dcs ON concept_code_2 = dcs.concept_code
	AND dcs.concept_class_id = 'Ingredient'
WHERE volume != 'NULL'
	AND strg_meas = '%'
	AND molecule NOT LIKE '%+%'
	AND lower(descr_pck) NOT LIKE '/%dos%'
	AND molecule <> 'NULL';

--volume = 'NULL' AND strg_unit !='NULL' AND MOLECULE NOT LIKE '%+%' AND strg_meas = '%'
INSERT INTO ds_stage (
	drug_concept_code,
	ingredient_concept_code,
	numerator_value,
	numerator_unit,
	denominator_unit,
	box_size
	)
SELECT pfc,
	concept_code_2,
	strg_unit::FLOAT * 10 AS numerator_value,
	'MG' AS numerator_unit,
	'ML' AS denominator_unit,
	packsize::INT
FROM france_1 f
JOIN internal_relationship_stage irs ON f.pfc = irs.concept_code_1
JOIN drug_concept_stage dcs ON concept_code_2 = dcs.concept_code
	AND dcs.concept_class_id = 'Ingredient'
WHERE volume = 'NULL'
	AND strg_unit != 'NULL'
	AND molecule NOT LIKE '%+%'
	AND strg_meas = '%'
	AND molecule <> 'NULL'
	AND pfc NOT IN (
		SELECT drug_concept_code
		FROM ds_stage
		);

--volume !='NULL' and strg_unit='NULL' and MOLECULE NOT LIKE '%+%'
INSERT INTO ds_stage (
	drug_concept_code,
	ingredient_concept_code,
	amount_value,
	amount_unit,
	box_size
	)
SELECT pfc,
	concept_code_2,
	substring(volume, '(\d*(\.)?(\d)*)')::FLOAT AS amount_value,
	regexp_replace(volume, '\d*(\.)?(\d)*', '', 'g') AS amount_unit,
	packsize::INT
FROM france_1 f
JOIN internal_relationship_stage irs ON f.pfc = irs.concept_code_1
JOIN drug_concept_stage dcs ON concept_code_2 = dcs.concept_code
	AND dcs.concept_class_id = 'Ingredient'
WHERE volume != 'NULL'
	AND strg_unit = 'NULL'
	AND molecule NOT LIKE '%+%'
	AND molecule <> 'NULL'
	AND pfc NOT IN (
		SELECT drug_concept_code
		FROM ds_stage
		)
	AND regexp_replace(volume, '\d*(\.)?(\d)*', '', 'g') NOT IN (
		'L',
		'ML'
		);

-- need to extract dosages from descr_pck where  MOLECULE NOT LIKE '%+%' and volume ='NULL' and strg_unit='NULL'
--complex ingredients (excluding 'INSULIN')
DROP TABLE IF EXISTS ds_complex;
CREATE TABLE ds_complex AS
SELECT DISTINCT product_desc,
	form_desc,
	dosage,
	dosage_add,
	volume,
	packsize::int4,
	claatc,
	pfc,
	molecule,
	cd_nfc_3,
	english,
	lb_nfc_3,
	descr_pck,
	strg_unit,
	strg_meas,
	ingred,
	concentr,
	CASE 
		WHEN substring(concentr, '\d+\.\d+') IS NOT NULL
			THEN substring(concentr, '\d+\.\d+')
		WHEN substring(concentr, '\d+\.\d+') IS NULL
			THEN substring(concentr, '\d+')
		END::FLOAT AS strength,
	substring(concentr, '\d+(?:\.\d+)*([A-Z]+)') AS UNIT
FROM (
	SELECT product_desc,
		form_desc,
		dosage,
		dosage_add,
		volume,
		packsize,
		claatc,
		pfc,
		molecule,
		cd_nfc_3,
		english,
		lb_nfc_3,
		descr_pck,
		strg_unit,
		strg_meas,
		trim(UNNEST(regexp_matches(molecule, '[^\+]+', 'g'))) AS ingred,
		trim(UNNEST(regexp_matches(regexp_replace(descr_pck, '^\D*/', '', 'g'), '[^/]+', 'g'))) AS concentr
	FROM france_1
	WHERE molecule LIKE '%+%'
		AND descr_pck ~ '.*\d+.*/.*\d+.*'
		AND pfc NOT IN (
			SELECT pfc
			FROM non_drugs
			)
		AND molecule NOT LIKE '%INSULIN%'
		AND molecule <> 'NULL'
	) AS s0;

--incorrect dosages for CLAVULANIC ACID+AMOXICILLIN
UPDATE ds_complex
SET strength = substring(descr_pck, '(\d+(\.\d+)*)\w*/\d+(\.\d+)*')::FLOAT,
	unit = 'MG'
WHERE molecule = 'CLAVULANIC ACID+AMOXICILLIN'
	AND descr_pck NOT LIKE '%ML'
	AND ingred = 'AMOXICILLIN';

UPDATE ds_complex
SET strength = substring(descr_pck, '\d+(?:\.\d+)*\w*/(\d+(\.\d+)*)')::FLOAT,
	unit = 'MG'
WHERE molecule = 'CLAVULANIC ACID+AMOXICILLIN'
	AND descr_pck NOT LIKE '%ML'
	AND ingred = 'CLAVULANIC ACID';

UPDATE ds_complex
SET strength = substring(descr_pck, '(\d+(\.\d+)*)\w*/\d+(\.\d+)*')::FLOAT * substring(volume, '(\d+(\.\d+)*)')::FLOAT,
	unit = 'MG'
WHERE molecule = 'CLAVULANIC ACID+AMOXICILLIN'
	AND descr_pck LIKE '%ML'
	AND ingred = 'AMOXICILLIN';

UPDATE ds_complex
SET strength = substring(descr_pck, '\d+(?:\.\d+)*\w*/(\d+(\.\d+)*)')::FLOAT * substring(volume, '(\d+(\.\d+)*)')::FLOAT,
	unit = 'MG'
WHERE molecule = 'CLAVULANIC ACID+AMOXICILLIN'
	AND descr_pck LIKE '%ML'
	AND ingred = 'CLAVULANIC ACID';

UPDATE ds_complex
SET volume = '24H',
	unit = 'MCG'
WHERE pfc IN (
		'2521201',
		'3750501'
		);

UPDATE ds_complex
SET volume = '30DOS',
	unit = 'Y'
WHERE pfc = '5351301';

UPDATE DS_COMPLEX
SET STRENGTH = '10',
	UNIT = 'MG'
WHERE PFC = '1390401'
	AND INGRED = 'LIDOCAINE';

UPDATE DS_COMPLEX
SET STRENGTH = '20',
	UNIT = 'MG'
WHERE PFC = '1390404'
	AND INGRED = 'LIDOCAINE';

UPDATE DS_COMPLEX
SET STRENGTH = '10',
	UNIT = 'MG'
WHERE PFC = '9667649'
	AND INGRED = 'LIDOCAINE';

UPDATE DS_COMPLEX
SET UNIT = 'MG'
WHERE PFC = '9667671'
	AND INGRED = 'LIDOCAINE';

INSERT INTO ds_stage (
	drug_concept_code,
	ingredient_concept_code,
	numerator_value,
	numerator_unit,
	denominator_value,
	denominator_unit,
	box_size
	)
SELECT DISTINCT pfc,
	concept_code,
	strength AS numerator_value,
	unit AS numerator_unit,
	substring(volume, '([[:digit:]]+(\.[[:digit:]]+)?)')::FLOAT AS denominator_value,
	regexp_replace(volume, '([[:digit:]]+(\.[[:digit:]]+)?)', '', 'g') AS denominator_unit,
	packsize
FROM ds_complex f
JOIN drug_concept_stage dcs ON ingred = dcs.concept_name
	AND dcs.concept_class_id = 'Ingredient'
WHERE volume != 'NULL'
	AND molecule <> 'NULL';

INSERT INTO ds_stage (
	drug_concept_code,
	ingredient_concept_code,
	amount_value,
	amount_unit,
	box_size
	)
SELECT DISTINCT pfc,
	concept_code,
	strength AS numerator_value,
	unit AS numerator_unit,
	packsize
FROM ds_complex f
JOIN drug_concept_stage dcs ON ingred = dcs.concept_name
	AND dcs.concept_class_id = 'Ingredient'
WHERE volume = 'NULL'
	AND molecule <> 'NULL';

UPDATE ds_stage
SET amount_unit = NULL
WHERE amount_unit = 'NULL';

UPDATE ds_stage
SET numerator_unit = NULL
WHERE numerator_unit = 'NULL';

UPDATE ds_stage
SET denominator_unit = NULL
WHERE denominator_unit = 'NULL';

--need to review
UPDATE ds_stage
SET amount_unit = 'MG'
WHERE (
		drug_concept_code,
		ingredient_concept_code
		) IN (
		SELECT a.drug_concept_code,
			a.ingredient_concept_code
		FROM ds_stage a
		JOIN ds_stage b ON a.drug_concept_code = b.drug_concept_code
			AND a.ingredient_concept_code != b.ingredient_concept_code
			AND a.amount_value IS NOT NULL
			AND a.amount_unit IS NULL
			AND b.amount_unit = 'MG'
		);

UPDATE ds_stage
SET amount_unit = 'IU'
WHERE (
		drug_concept_code,
		ingredient_concept_code
		) IN (
		SELECT a.drug_concept_code,
			a.ingredient_concept_code
		FROM ds_stage a
		JOIN ds_stage b ON a.drug_concept_code = b.drug_concept_code
			AND a.ingredient_concept_code != b.ingredient_concept_code
			AND a.amount_value IS NOT NULL
			AND a.amount_unit IS NULL
			AND b.amount_unit = 'IU'
		);

UPDATE ds_stage
SET amount_unit = 'Y'
WHERE (
		drug_concept_code,
		ingredient_concept_code
		) IN (
		SELECT a.drug_concept_code,
			a.ingredient_concept_code
		FROM ds_stage a
		JOIN ds_stage b ON a.drug_concept_code = b.drug_concept_code
			AND a.ingredient_concept_code != b.ingredient_concept_code
			AND a.amount_value IS NOT NULL
			AND a.amount_unit IS NULL
			AND b.amount_unit = 'Y'
		);

UPDATE ds_stage
SET amount_unit = 'MG'
WHERE (
		drug_concept_code,
		ingredient_concept_code
		) IN (
		SELECT drug_concept_code,
			ingredient_concept_code
		FROM ds_stage A
		JOIN france_1 B ON drug_concept_code = pfc
			AND english LIKE 'Oral Solid%'
			AND amount_unit IS NULL
			AND amount_value IS NOT NULL
		);

UPDATE ds_stage
SET numerator_value = 3000,
	denominator_value = 60,
	amount_value = NULL,
	amount_unit = NULL,
	numerator_unit = 'MCG',
	denominator_unit = 'DOS'
WHERE drug_concept_code IN (
		'2393701',
		'2393702',
		'2393703',
		'2971805',
		'2971806'
		)
	AND ingredient_concept_code IN (
		SELECT concept_code
		FROM drug_concept_stage
		WHERE concept_class_id = 'Ingredient'
			AND concept_name = 'SALMETEROL'
		);

UPDATE ds_stage
SET numerator_value = 1400,
	denominator_value = 28,
	amount_value = NULL,
	amount_unit = NULL,
	numerator_unit = 'MCG',
	denominator_unit = 'DOS'
WHERE drug_concept_code IN (
		'2971801',
		'2971802',
		'2971803'
		)
	AND ingredient_concept_code IN (
		SELECT concept_code
		FROM drug_concept_stage
		WHERE concept_class_id = 'Ingredient'
			AND concept_name = 'SALMETEROL'
		);

UPDATE ds_stage
SET numerator_value = amount_value * 100,
	amount_value = NULL,
	amount_unit = NULL,
	denominator_value = amount_value,
	numerator_unit = 'MCG',
	denominator_unit = 'DOS'
WHERE ingredient_concept_code IN (
		SELECT concept_code
		FROM drug_concept_stage
		WHERE concept_class_id = 'Ingredient'
			AND concept_name = 'FLUTICASONE'
		)
	AND drug_concept_code IN (
		'2393701',
		'2971802'
		);

UPDATE ds_stage
SET numerator_value = amount_value * 250,
	amount_value = NULL,
	amount_unit = NULL,
	denominator_value = amount_value,
	numerator_unit = 'MCG',
	denominator_unit = 'DOS'
WHERE ingredient_concept_code IN (
		SELECT concept_code
		FROM drug_concept_stage
		WHERE concept_class_id = 'Ingredient'
			AND concept_name = 'FLUTICASONE'
		)
	AND drug_concept_code IN (
		'2393702',
		'2971803',
		'2971805'
		);

UPDATE ds_stage
SET numerator_value = amount_value * 500,
	amount_value = NULL,
	amount_unit = NULL,
	denominator_value = amount_value,
	numerator_unit = 'MCG',
	denominator_unit = 'DOS'
WHERE ingredient_concept_code IN (
		SELECT concept_code
		FROM drug_concept_stage
		WHERE concept_class_id = 'Ingredient'
			AND concept_name = 'FLUTICASONE'
		)
	AND drug_concept_code IN (
		'2393703',
		'2971801',
		'2971806'
		);

UPDATE ds_stage
SET numerator_value = 2760,
	denominator_value = 30,
	amount_value = NULL,
	amount_unit = NULL,
	numerator_unit = 'MCG',
	denominator_unit = 'DOS'
WHERE ingredient_concept_code IN (
		SELECT concept_code
		FROM drug_concept_stage
		WHERE concept_class_id = 'Ingredient'
			AND concept_name = 'FLUTICASONE FUROATE'
		)
	AND drug_concept_code = '5475101';

UPDATE ds_stage
SET numerator_value = 660,
	denominator_value = 30,
	amount_value = NULL,
	amount_unit = NULL,
	numerator_unit = 'MCG',
	denominator_unit = 'DOS'
WHERE ingredient_concept_code IN (
		SELECT concept_code
		FROM drug_concept_stage
		WHERE concept_class_id = 'Ingredient'
			AND concept_name = 'VILANTEROL'
		)
	AND drug_concept_code = '5475101';

UPDATE ds_stage
SET numerator_value = 24000,
	denominator_value = 60,
	amount_value = NULL,
	amount_unit = NULL,
	numerator_unit = 'MCG',
	denominator_unit = 'DOS'
WHERE ingredient_concept_code IN (
		SELECT concept_code
		FROM drug_concept_stage
		WHERE concept_class_id = 'Ingredient'
			AND concept_name = 'BUDESONIDE'
		)
	AND drug_concept_code = '4671001';

UPDATE ds_stage
SET numerator_value = 720,
	denominator_value = 60,
	amount_value = NULL,
	amount_unit = NULL,
	numerator_unit = 'MCG',
	denominator_unit = 'DOS'
WHERE ingredient_concept_code IN (
		SELECT concept_code
		FROM drug_concept_stage
		WHERE concept_class_id = 'Ingredient'
			AND concept_name = 'FORMOTEROL'
		)
	AND drug_concept_code = '4671001';

DELETE
FROM ds_stage
WHERE drug_concept_code = '2935001';

--fill RLC
--Ingredients
DROP TABLE IF EXISTS relationship_ingrdient;
CREATE TABLE relationship_ingrdient AS
SELECT DISTINCT a.concept_code AS concept_code_1,
	f.concept_id AS concept_id_2
FROM drug_concept_stage a
JOIN devv5.concept c ON upper(c.concept_name) = upper(a.concept_name)
	AND c.concept_class_id IN (
		'Ingredient',
		'VTM',
		'AU Substance'
		)
JOIN devv5.concept_relationship b ON c.concept_id = concept_id_1
JOIN devv5.concept f ON f.concept_id = concept_id_2
WHERE f.vocabulary_id LIKE 'Rx%'
	AND f.standard_concept = 'S'
	AND f.concept_class_id = 'Ingredient'
	AND a.concept_class_id = 'Ingredient';

INSERT INTO relationship_ingrdient
SELECT DISTINCT a.concept_code,
	c.concept_id
FROM drug_concept_stage a
JOIN ingredient_all_completed b ON a.concept_name = b.concept_name
JOIN devv5.concept c ON c.concept_id = concept_id_2
WHERE a.concept_class_id = 'Ingredient'
	AND (
		b.concept_name,
		concept_id_2
		) NOT IN (
		SELECT concept_name,
			concept_id_2
		FROM drug_concept_stage
		JOIN relationship_ingrdient ON concept_code = concept_code_1
			AND concept_class_id = 'Ingredient'
		);

INSERT INTO relationship_to_concept
SELECT concept_code_1,
	'DA_France',
	concept_id_2,
	rank() OVER (
		PARTITION BY concept_code_1 ORDER BY concept_id_2
		) AS precedence,
	NULL AS conversion_factor
FROM relationship_ingrdient a
JOIN devv5.concept ON concept_id_2 = concept_id
WHERE standard_concept = 'S';

--Brand Names
DROP TABLE IF EXISTS relationship_bn;
CREATE TABLE relationship_bn AS
SELECT a.concept_code AS concept_code_1,
	c.concept_id AS concept_id_2
FROM drug_concept_stage a
JOIN devv5.concept c ON upper(c.concept_name) = upper(a.concept_name)
	AND c.concept_class_id = 'Brand Name'
	AND c.vocabulary_id LIKE 'Rx%'
	AND c.invalid_reason IS NULL
WHERE a.concept_class_id = 'Brand Name';

INSERT INTO relationship_bn
SELECT b.concept_code,
	concept_id_2
FROM brand_names_manual a
JOIN drug_concept_stage b ON upper(a.concept_name) = upper(b.concept_name)
JOIN devv5.concept c ON concept_id_2 = concept_id
	AND c.invalid_reason IS NULL
	AND (
		b.concept_code,
		concept_id_2
		) NOT IN (
		SELECT concept_code_1,
			concept_id_2
		FROM relationship_bn
		);

INSERT INTO relationship_to_concept (
	concept_code_1,
	vocabulary_id_1,
	concept_id_2,
	precedence
	)
SELECT concept_code_1,
	'DA_France',
	concept_id_2,
	rank() OVER (
		PARTITION BY concept_code_1 ORDER BY concept_id_2
		)
FROM relationship_bn;

--Dose Forms
INSERT INTO relationship_to_concept (
	concept_code_1,
	vocabulary_id_1,
	concept_id_2,
	precedence,
	conversion_factor
	)
SELECT b.concept_code,
	'DA_France',
	concept_id_2,
	precedence,
	NULL
FROM new_form_name_mapping a --manually created table
JOIN drug_concept_stage b ON b.concept_name = a.dose_form_name;

--Units
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('%', 'DA_France',8554,1,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('G', 'DA_France',8576,1,1000);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('IU', 'DA_France',8510,1,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('IU', 'DA_France',8718,2,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('K', 'DA_France',8510,1,1000);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('K', 'DA_France',8718,2,1000);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('KG', 'DA_France',8576,1,1000);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('L', 'DA_France',8587,1,1000);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('M', 'DA_France',8510,1,1000000);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('MCG', 'DA_France',8576,1,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('MG', 'DA_France',8576,1,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('ML', 'DA_France',8576,2,1000);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('U', 'DA_France',8510,1,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('U', 'DA_France',8718,2,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('Y', 'DA_France',8576,1,0.001);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('UI', 'DA_France',8510,1,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('UI', 'DA_France',8718,2,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('MUI', 'DA_France',8510,1,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('MUI', 'DA_France',8718,2,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('GM', 'DA_France',8576,1,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('DOS', 'DA_France',45744809,1,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('TU', 'DA_France',9413,1,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('TU', 'DA_France',8510,2,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('TU', 'DA_France',8718,3,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('MU', 'DA_France',8510,2,0.000001);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('MU', 'DA_France',8718,3,0.000001);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('H', 'DA_France',8505,1,1);


--update ds_stage after relationship_to concept found identical ingredients
DROP TABLE IF EXISTS ds_sum;
CREATE TABLE ds_sum AS
	WITH a AS (
			SELECT DISTINCT ds.drug_concept_code,
				ds.ingredient_concept_code,
				ds.box_size,
				ds.amount_value,
				ds.amount_unit,
				ds.numerator_value,
				ds.numerator_unit,
				ds.denominator_value,
				ds.denominator_unit,
				rc.concept_id_2
			FROM ds_stage ds
			JOIN ds_stage ds2 ON ds.drug_concept_code = ds2.drug_concept_code
				AND ds.ingredient_concept_code != ds2.ingredient_concept_code
			JOIN relationship_to_concept rc ON ds.ingredient_concept_code = rc.concept_code_1
			JOIN relationship_to_concept rc2 ON ds2.ingredient_concept_code = rc2.concept_code_1
			WHERE rc.concept_id_2 = rc2.concept_id_2
			)
SELECT drug_concept_code,
	max(ingredient_concept_code) OVER (
		PARTITION BY drug_concept_code,
		concept_id_2
		) AS ingredient_concept_code,
	box_size,
	sum(amount_value) OVER (PARTITION BY drug_concept_code) AS amount_value,
	amount_unit,
	sum(numerator_value) OVER (
		PARTITION BY drug_concept_code,
		concept_id_2
		) AS numerator_value,
	numerator_unit,
	denominator_value,
	denominator_unit
FROM a
UNION
SELECT drug_concept_code,
	ingredient_concept_code,
	box_size,
	NULL as amount_value,
	NULL as amount_unit,
	NULL as numerator_value,
	NULL as numerator_unit,
	NULL as denominator_value,
	NULL as denominator_unit
FROM a
WHERE (
		drug_concept_code,
		ingredient_concept_code
		) NOT IN (
		SELECT drug_concept_code,
			max(ingredient_concept_code)
		FROM a
		GROUP BY drug_concept_code
		);

DELETE
FROM ds_stage
WHERE (
		drug_concept_code,
		ingredient_concept_code
		) IN (
		SELECT drug_concept_code,
			ingredient_concept_code
		FROM ds_sum
		);

INSERT INTO ds_stage
SELECT *
FROM DS_SUM
WHERE coalesce(amount_value, numerator_value) IS NOT NULL;

--update irs after relationship_to concept found identical ingredients
DELETE
FROM internal_relationship_stage
WHERE (
		concept_code_1,
		concept_code_2
		) IN (
		SELECT concept_code_1,
			concept_code_2
		FROM (
			SELECT DISTINCT concept_code_1,
				concept_code_2,
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
		)
	AND (
		concept_code_1,
		concept_code_2
		) NOT IN (
		SELECT drug_concept_code,
			ingredient_concept_code
		FROM ds_stage
		);

UPDATE ds_stage
SET box_size = NULL
WHERE drug_concept_code IN (
		SELECT drug_concept_code
		FROM ds_stage ds
		JOIN internal_relationship_stage i ON concept_code_1 = drug_concept_code
		LEFT JOIN drug_concept_stage ON concept_code = concept_code_2
			AND concept_class_id = 'Dose Form'
		WHERE box_size IS NOT NULL
			AND concept_name IS NULL
		);

INSERT INTO concept_synonym_stage (
	synonym_name,
	synonym_concept_code,
	synonym_vocabulary_id,
	language_concept_id
	)
SELECT dose_form,
	concept_code,
	'DA_France',
	4180190 -- French language 
FROM france_names_translation a
JOIN drug_concept_stage ON trim(upper(dose_form_name)) = upper(concept_name);

-- Create sequence for new OMOP-created standard concepts
DO $$
DECLARE
	ex INTEGER;
BEGIN
	SELECT MAX(replace(concept_code, 'OMOP','')::int4)+1 into ex FROM devv5.concept WHERE concept_code like 'OMOP%'  and concept_code not like '% %';
	DROP SEQUENCE IF EXISTS new_vocab;
	EXECUTE 'CREATE SEQUENCE new_vocab INCREMENT BY 1 START WITH ' || ex || ' NO CYCLE CACHE 20';
END$$;

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