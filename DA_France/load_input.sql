/**************************************************************************
* Copyright 2016 Observational Health Data Sciences and Informatics (OHаI)
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
* Authors: Eldar Allakhverdiiev, Dmitry Dymshyts, Christian Reich,
*          Violetta Komar
* Date: 2017-2022
**************************************************************************/
-- TO DO in the next releases: 
-- normalize dosage parsing and processig
-- improve dose form mapping
-- normalize this code or rewrite it

-- set latest_update field to new date
DO $_$ BEGIN perform vocabulary_pack.setlatestupdate (pvocabularyname => 'DA_France',pvocabularydate => CURRENT_DATE,pvocabularyversion => 'DA_France' ||current_date,
pvocabularydevschema => 'dev_da_france_2');
END $_$; 

DROP TABLE IF EXISTS non_drugs;
DROP TABLE IF EXISTS junk_drugs;
DROP TABLE IF EXISTS pre_ingr;
DROP TABLE IF EXISTS france_to_map;
drop table IF EXISTS vacc_ins_to_map;
DROP TABLE IF EXISTS ingr;
DROP TABLE IF EXISTS brand;
DROP TABLE IF EXISTS supplier;
DROP TABLE IF EXISTS forms;
DROP TABLE IF EXISTS unit;
DROP TABLE IF EXISTS drug_products;
DROP TABLE IF EXISTS list_temp;
DROP TABLE IF EXISTS ds_for_prolonged;
DROP TABLE IF EXISTS ds_complex;
DROP TABLE IF EXISTS ds_start;
DROP TABLE IF EXISTS ds_start_1;
DROP TABLE IF EXISTS ds_start_2;
DROP TABLE IF EXISTS ds_stage_1;
DROP TABLE IF EXISTS relationship_ingrdient;
DROP TABLE IF EXISTS ds_sum;
DROP TABLE IF EXISTS manual_map_ingr;

DROP SEQUENCE IF EXISTS conc_stage_seq;
DROP SEQUENCE IF EXISTS new_vocab;

TRUNCATE TABLE drug_concept_stage;
TRUNCATE TABLE internal_relationship_stage;
TRUNCATE TABLE ds_stage;
TRUNCATE TABLE relationship_to_concept;
TRUNCATE TABLE pc_stage;

--delete duplicates
DELETE
FROM da_france_source f
WHERE EXISTS (
		SELECT 1
		FROM da_france_source f_int
		WHERE f_int.pfc = f.pfc
			AND f_int.ctid > f.ctid
		);
		
-- assemble a table with non_drugs with devices
CREATE TABLE non_drugs AS
	SELECT descr_prod,
		descr_forme,
		strg_unit||strg_meas as dosage,
		vl_wg_unit||vl_wg_meas as volume,
		pck_size,
		code_atc,
		pfc,
		molecule,
		nfc,
		descr_pck,
		strg_unit,
		strg_meas,
		NULL::VARCHAR(250) AS concept_type
	FROM da_france_source
	WHERE  molecule ~* 'CONDOMS|SWAB|WOUND|BRAN|PADS$|IUD|ANTI-SNORING AID|TEATS'
		OR molecule ~* 'INCONTINENCE PADS|WIRE|AC IOXITALAMIQ.DCI|TELEBRIX 30 MEGLUM|ANGIOGRAFINE|AMINOACIDS|ELECTROLYTES'
OR molecule ~* ' TEST| TESTS|IOXITALAMIC|ELECTROLYTE|DATSCAN|BANDAGES|DEVICES|CARE PRODUCTS|DRESSING|CATHETERS|EYE OCCLUSION PATCH|INCONTINENCE COLLECTION APPLIANCES|DEVICE|MEXTRA|URGOTUL BORDER'		
or molecule ~*'OLIGO ELEMENTS|UREA 13|BARIUM|GENERAL NUTRIENTS|GADODIAMIDE|GADOBENIC ACID|GADOTERIC ACID|GLUCOSE 1-PHOSPHATE|GADOBUTROL|BABY MILKS|LOW CALORIE FOOD|NUTRITION'
or code_atc ~*'V20|V06|V10|V09|V04|V08'
OR (
			molecule LIKE '% TEST%'
			AND molecule NOT LIKE 'TUBERCULIN%'
			)
  	OR descr_prod ~* 'SOLVAROME|BIOSTINAL|CERP SUP GLYC|ECZEBIO LINIMENT|ACTIVOX'
		OR descr_prod ~* 'CARTIMOTIL|TERUMO SER INS'
		OR descr_pck ~* 'DEODORANT|SPRAYS|BOITE|DDT|TETRAMETHRIN'
		OR descr_prod ~* 'ABCDERM CHANGE|CARTIMOTIL|XERIAL 50|ATODERM|MEDNUTRIF.LIP G120|SPIRIAL|FORTIFRESH|TOLERIANE ULTRA|AQUAPORIN ACTIVE|PSORIANE|TOTAMINE GLUCID|ADAPTIC'
		OR descr_prod ~* 'PRANABB|MICRORECTAL|BIATAIN SILIC LITE|POCOCREM|PHYSIOGEL A.I.|EFFACLAR|BLEPHASOL|INOV HEPACT DETOX|RESOURCE MIXES HP|BIOPTIMUM MINCEUR|BIOPTIMUM MEMOIRE|INOV SEROTONE|CAPILEOV ANTICHUTE|POLYBACTUM|FORTIPUDDING'
    OR descr_labo ~* 'AVENE|DUCRAY|LOHMANN & RAUSCHER|LA ROCHE POSAY|BIODERMA';
    
-- assemble a table with junk_drugs with food supplements, multivitamins, dissolvents
CREATE TABLE junk_drugs AS
	SELECT descr_prod,
		descr_forme,
		strg_unit||strg_meas as dosage,
		vl_wg_unit||vl_wg_meas as volume,
		pck_size,
		code_atc,
		pfc,
		molecule,
		nfc,
		descr_pck,
		strg_unit,
		strg_meas,
		NULL::VARCHAR(250) AS concept_type
	FROM da_france_source
WHERE molecule ~* 'DEODORANT|AVENA SATIVA|CREAM|HAIR|SHAMPOO|LOTION|FACIAL CLEANSER|LIP PROTECTANTS|CLEANSING AGENTS|SKIN|TONICS|TOOTHPASTES|MOUTH|SCALP LOTIONS|CRYSTAL VIOLET'
OR    molecule ~* 'ALLERGENS|LENS SOLUTIONS|INFANT |DISINFECTANT|ANTISEPTIC|LUBRICANTS|INSECT REPELLENTS|FOOD|SLIMMING PREPARATIONS|SPECIAL DIET|COTTON WOOL'
OR    molecule ~* 'ORAL HYGIENE|AFTER SUN PROTECTANTS|INSECT REPELLENTS|DECONGESTANT RUBS|EYE MAKE-UP REMOVERS|FIXATIVES|FOOT POWDERS|FIORAVANTI BALSAM|NUTRITION'
OR    molecule ~* 'CORN REMOVER|TANNING|OTHERS|NON MEDICATED|NON PHARMACEUTICAL|HOMOEOPATHIC| GLOBULUS|BATH OIL|SOAP'
OR    molecule ~* 'LACTOBACILLUS|LACTOSERUM|HARPAGOPHYTUM|PROBIOTICS|VACCINIUM|PANCREAS|BIFIDOBACTERIUM|LACTIC FERMENTS|OFFICINALIS|LIVER|ARNICA'
OR    code_atc ~* 'V07|V03|V01'
OR    descr_prod ~* ' CICABIAFINE |OLIOSEPTIL V.URINAT|LYSOFON|REPIDERMYL|SEBAKLEN|REFLEX SPRAY|ACARDUST|A PAR|ISOPHY EAU URIAGE'
OR    descr_prod ~* 'SPORT'
OR    descr_labo ~* 'BOIRON';

-- assemble a table pre_ingr with separated source Ingredients
CREATE TABLE pre_ingr AS
SELECT DISTINCT ingred AS concept_name,
	pfc,
	'Ingredient'::VARCHAR AS concept_class_id
FROM (
	SELECT UNNEST(regexp_matches(molecule, '[^\+]+', 'g')) AS ingred,
		pfc
	FROM da_france_source
	WHERE pfc NOT IN (
			SELECT pfc
			FROM non_drugs
			)
		and pfc not in (select pfc from junk_drugs)
	) AS s0
WHERE ingred is not NULL;

-- assemble a table for manual mapping containing ingredients with 'NULL' value in the 'molecule' field 
CREATE TABLE france_to_map AS
SELECT 
  descr_prod,
	descr_forme,
	strg_unit||strg_meas as dosage,
	vl_wg_unit||vl_wg_meas as volume,
	pck_size,
	code_atc,
	pfc,
	NULL as cse,
	nfc,
	descr_pck,
	descr_labo,
	strg_unit,
	strg_meas,
	molecule
FROM    da_france_source
WHERE molecule is not NULL
UNION
SELECT descr_prod,
	descr_forme,
	strg_unit||strg_meas as dosage,
	vl_wg_unit||vl_wg_meas as volume,
	pck_size,
	code_atc,
	a.pfc,
		CASE 
		WHEN concept_name IS NOT NULL
			THEN concept_name
		ELSE NULL
		END as cse,
	nfc,
	descr_pck,
	descr_labo,
	strg_unit,
	strg_meas,
	molecule
FROM da_france_source a
  LEFT JOIN pre_ingr b ON TRIM (REPLACE (descr_prod,'DCI','')) = UPPER (concept_name)
WHERE molecule IS NULL
AND   a.pfc NOT IN (SELECT pfc FROM non_drugs);

-- assemble a table for manual mapping with separated vaccines and insulins in order to reduce manual work (NB! manual mappings have to be stored in the concept_relationship_manual table) 
DROP TABLE if exists vacc_ins_to_map;
CREATE TABLE vacc_ins_to_map 
AS
(SELECT *
FROM france_to_map
WHERE molecule ~* 'vaccine|\yinsul|\yserum|immunoglob');

-- clean up working tables 
DELETE
FROM pre_ingr
WHERE pfc IN (SELECT pfc FROM vacc_ins_to_map)
OR    pfc IN (SELECT pfc FROM non_drugs)
OR    pfc IN (SELECT pfc FROM junk_drugs);

DELETE
FROM france_to_map
WHERE pfc IN (SELECT pfc FROM non_drugs);

DELETE
FROM france_to_map
WHERE pfc IN (SELECT pfc FROM junk_drugs);

DELETE
FROM france_to_map
WHERE pfc IN (SELECT pfc FROM vacc_ins_to_map);

-- assemble Ingredient table
CREATE TABLE ingr 
AS
SELECT DISTINCT ingred AS concept_name,
       pfc,
       'Ingredient'::VARCHAR AS concept_class_id
FROM (SELECT UNNEST(REGEXP_MATCHES(molecule,'[^\+]+','g')) AS ingred,
             pfc
      FROM france_to_map) AS s0
WHERE ingred IS NOT NULL
AND   pfc NOT IN (SELECT pfc FROM vacc_ins_to_map);


/* -- check for additional ingredients
SELECT MIN(jw) OVER (PARTITION BY pfc),
       FIRST_VALUE(concept_name) OVER (PARTITION BY source_name ORDER BY LENGTH(concept_name) DESC) AS ing,
       concept_name,
       pfc, concept_id
FROM (SELECT c.concept_name as concept_name, a.concept_name as source_name, pfc, concept_id,
             devv5.jaro_winkler(a.concept_name,c.concept_name) AS jw
      FROM dev_da_france_2.pre_ingr a,
           concept c
      WHERE a.concept_name ilike '%' ||c.concept_name|| '%'
      AND   vocabulary_id IN ('RxNorm')
      AND   c.concept_class_id = 'Ingredient'
      AND   invalid_reason IS NULL) as s
      WHERE  pfc NOT IN (SELECT pfc FROM ingr); */

-- list of Brand Names -- stopped to document here!  
-- https://docs.google.com/document/d/1Fp4Ru2ONqlb9x4ch_IRifXrV810BGznfpKbc_a96P2M/edit
CREATE TABLE brand AS
SELECT descr_prod AS concept_name,
	pfc,
	'Brand Name'::VARCHAR AS concept_class_id
FROM france_to_map
WHERE pfc NOT IN (
		SELECT pfc
		FROM non_drugs
		)
		or pfc NOT IN (
		SELECT pfc
		FROM junk_drugs
		)
	AND pfc NOT IN (
		SELECT pfc
		FROM france_to_map
		WHERE molecule is NULL
		)
OR pfc NOT IN (SELECT pfc
FROM vacc_ins_to_map) 
AND descr_prod NOT LIKE '%DCI%' 
AND NOT descr_prod ~ 'L\.IND|LAB IND' 
AND UPPER(descr_prod) NOT IN (SELECT UPPER(concept_name) 
     FROM devv5.concept
WHERE concept_class_id LIKE 'Ingredient'
AND   standard_concept = 'S');

UPDATE brand
SET concept_name = 'UMULINE PROFIL'
WHERE concept_name LIKE 'UMULINE PROFIL%';

UPDATE brand
SET concept_name = 'CALCIPRAT'
WHERE concept_name = 'CALCIPRAT D3';

UPDATE brand
SET concept_name = 'DOMPERIDONE ZENTIVA'
WHERE concept_name LIKE 'DOMPERIDONE ZENT%';

-- delete Brand Name after manual review
DELETE
FROM brand
WHERE concept_name IN (SELECT concept_name
                       FROM brand_name_mapping
                       WHERE to_concept IN ('device','supplier','d'));

-- list of supplier
CREATE TABLE supplier 
AS
SELECT DISTINCT descr_labo AS concept_name,
       pfc,
       'Supplier'::VARCHAR AS concept_class_id
FROM france_to_map
WHERE pfc NOT IN (SELECT pfc FROM non_drugs)
OR    pfc NOT IN (SELECT pfc FROM vacc_ins_to_map)
OR    pfc NOT IN (SELECT pfc FROM junk_drugs);
		
--delete from supplier brand_name 
DELETE
FROM supplier
WHERE concept_name IN (SELECT a.concept_name
                       FROM (SELECT a.concept_name,
                                    b.concept_id
                             FROM supplier a
                               JOIN supplier_mapp_auto b ON a.concept_name = b.source_name
                             UNION
                             SELECT a.concept_name,
                                    b.to_concept
                             FROM supplier a
                               JOIN supplier_manual b ON a.concept_name = b.concept_name) a
                         JOIN concept b ON a.concept_id = b.concept_id
                       WHERE concept_class_id = 'Brand Name');
                       
DELETE
FROM supplier
WHERE pfc = '0207850';

DELETE
FROM supplier
WHERE concept_name ~* 'DERMOPHIL|CRINEX';

--list of Dose Forms
CREATE TABLE forms 
AS
SELECT *
FROM devv5.concept a
  JOIN france_to_map b
    ON a.concept_code = b.nfc
   AND a.vocabulary_id = 'NFC'
   AND pfc NOT IN (SELECT pfc FROM non_drugs);

 DELETE
FROM forms
WHERE pfc IN (SELECT pfc FROM junk_drugs)
OR    pfc IN (SELECT pfc FROM vacc_ins_to_map);

UPDATE forms
   SET concept_class_id = 'Dose Form';

-- units, take units used for volume and strength definition
CREATE TABLE unit 
AS
SELECT strg_meas AS concept_name,
       'Unit'::VARCHAR AS concept_class_id,
       strg_meas AS concept_code
FROM (SELECT strg_meas
      FROM france_to_map
      WHERE pfc NOT IN (SELECT pfc FROM non_drugs)
      OR    pfc NOT IN (SELECT pfc FROM junk_drugs)
      UNION
      SELECT REGEXP_REPLACE(volume,'[[:digit:]\.]','','g')
      FROM france_to_map
      WHERE strg_meas IS NOT NULL
      AND   pfc NOT IN (SELECT pfc FROM non_drugs)) a
WHERE a.strg_meas NOT IN ('CH')
AND   a.strg_meas IS NOT NULL;

INSERT INTO unit VALUES ('UI', 'Unit', 'UI');
INSERT INTO unit VALUES ('MUI', 'Unit', 'MUI');
INSERT INTO unit VALUES ('DOS', 'Unit', 'DOS');
INSERT INTO unit VALUES ('GM', 'Unit', 'GM');
INSERT INTO unit VALUES ('H', 'Unit', 'H');

-- units
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) VALUES ('%', 'DA_France',8554,1,1);
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) VALUES ('G', 'DA_France',8576,1,1000);
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) VALUES ('IU', 'DA_France',8510,1,1);
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) VALUES ('IU', 'DA_France',8718,2,1);
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) VALUES ('K', 'DA_France',8510,1,1000);
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) VALUES ('K', 'DA_France',8718,2,1000);
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) VALUES ('KG', 'DA_France',8576,1,1000);
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) VALUES ('L', 'DA_France',8587,1,1000);
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) VALUES ('M', 'DA_France',8510,1,1000000);
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) VALUES ('MCG', 'DA_France',8576,1,1);
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) VALUES ('MG', 'DA_France',8576,1,1);
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) VALUES ('ML', 'DA_France',8576,2,1000);
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) VALUES ('U', 'DA_France',8510,1,1);
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) VALUES ('U', 'DA_France',8718,2,1);
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) VALUES ('Y', 'DA_France',8576,1,0.001);
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) VALUES ('UI', 'DA_France',8510,1,1);
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) VALUES ('UI', 'DA_France',8718,2,1);
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) VALUES ('MUI', 'DA_France',8510,1,1);
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) VALUES ('MUI', 'DA_France',8718,2,1);
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) VALUES ('GM', 'DA_France',8576,1,1);
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) VALUES ('DOS', 'DA_France',45744809,1,1);
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) VALUES ('TU', 'DA_France',9413,1,1);
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) VALUES ('TU', 'DA_France',8510,2,1);
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) VALUES ('TU', 'DA_France',8718,3,1);
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) VALUES ('MU', 'DA_France',8510,2,0.000001);
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) VALUES ('MU', 'DA_France',8718,3,0.000001);
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) VALUES ('H', 'DA_France',8505,1,1);

--dose form what doesen't exists in NFC in devv5.concept
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) VALUES ('IEP','DA_France',36250064,1,NULL);
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) VALUES ('IEP','DA_France',35604877,2,NULL);
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) VALUES ('IEP','DA_France',45775488,3,NULL);

--no inf. about suppliers
CREATE TABLE drug_products AS
SELECT DISTINCT CASE 
		WHEN d.pfc IS NOT NULL
			THEN trim(regexp_replace(replace(CONCAT (
								volume,
								' ',
								substr((replace(molecule, '+', ' / ')), 1, 175) --To avoid names length more than 255
								,
								'  ',
								b.concept_name,
								' [' || descr_prod || ']',
								' Box of ',
								a.pck_size
								), 'NULL', ''), '\s+', ' ', 'g'))
		ELSE trim(regexp_replace(replace(CONCAT (
							volume,
							' ',
							substr((replace(molecule, '+', ' / ')), 1, 175) --To avoid names length more than 255
							,
							' ',
							b.concept_name,
							' Box of ',
							a.pck_size
							), 'NULL', ''), '\s+', ' ', 'g'))
		END AS concept_name,
	'Drug Product'::VARCHAR AS concept_class_id,
	a.pfc AS concept_code
FROM france_to_map a
LEFT JOIN brand d ON d.concept_name = a.descr_prod
join devv5.concept b on b.concept_code = a.nfc and vocabulary_id = 'NFC' 
WHERE a.pfc NOT IN (
		SELECT pfc
		FROM non_drugs
		)
and a.pfc NOT IN (
		SELECT pfc
		FROM junk_drugs
		)
	AND molecule is not NULL;
	
	INSERT INTO drug_products
SELECT DISTINCT CASE 
		WHEN d.pfc IS NOT NULL		
							THEN trim(regexp_replace(replace(CONCAT (
								volume,
								' ',
								substr((replace(molecule, '+', ' / ')), 1, 175) -- to avoid names length more than 255
								,
								'  ',
								c.concept_name,
								' [' || descr_prod || ']',
								' Box of ',
								a.pck_size
								), 'NULL', ''), '\s+', ' ', 'g'))
		ELSE trim(regexp_replace(replace(CONCAT (
							volume,
							' ',
							substr((replace(molecule, '+', ' / ')), 1, 175) -- to avoid names length more than 255
							,
							' ',
							c.concept_name,
							' Box of ',
							a.pck_size
							), 'NULL', ''), '\s+', ' ', 'g'))
		END AS concept_name,
	'Drug Product'::VARCHAR AS concept_class_id,
	a.pfc AS concept_code
FROM france_to_map a
LEFT JOIN brand d ON d.concept_name = a.descr_prod
JOIN relationship_to_concept r ON a.nfc = r.concept_code_1 AND precedence = '1'
JOIN devv5.concept c ON r.concept_id_2 = c.concept_id
WHERE a.pfc NOT IN (SELECT pfc FROM non_drugs)
AND   a.pfc NOT IN (SELECT pfc FROM junk_drugs)
AND   molecule IS NOT NULL
AND   a.pfc NOT IN (SELECT concept_code FROM drug_products);
	
UPDATE drug_products
   SET concept_name = REGEXP_REPLACE(concept_name,'Box of \y1\y','');

-- create sequence for omop-generated codes
DROP SEQUENCE IF EXISTS conc_stage_seq;
CREATE SEQUENCE conc_stage_seq MINVALUE 100 MAXVALUE 1000000 START WITH 100 INCREMENT BY 1 CACHE 20;

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
FROM supplier) AS s0
UNION
SELECT concept_name,
       concept_class_id,
       concept_code
FROM forms;

--fill drug_concept_stage
INSERT INTO drug_concept_stage 
	(concept_name,vocabulary_id,domain_id,concept_class_id,standard_concept,concept_code,possible_excipient,valid_start_date,valid_end_date,invalid_reason)
SELECT CAST(concept_name AS VARCHAR(255)),
       'DA_France',
       'Drug',
       concept_class_id,
       'S',
       concept_code,
       NULL,
       CURRENT_DATE AS valid_start_date,  -- check start date
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
       NULL
FROM (SELECT *
      FROM list_temp
      UNION
      SELECT *
      FROM drug_products
      UNION
      SELECT *
      FROM unit) AS s0;

--DEVICES (rebuild names)
INSERT INTO drug_concept_stage 
(concept_name,vocabulary_id,domain_id,concept_class_id,standard_concept,concept_code,possible_excipient,valid_start_date,valid_end_date,invalid_reason)
SELECT TRIM(concept_name,'^ ') AS concept_name,
       vocabulary_id,
       domain_id,
       concept_class_id,
       standard_concept,
       concept_code,
       possible_excipient,
       valid_start_date,
       valid_end_date,
       invalid_reason
FROM
(SELECT DISTINCT substr(CONCAT (
			volume,
			' ',
			CASE molecule
				WHEN NULL
					THEN NULL
				ELSE CONCAT (
						molecule,
						' '
						)
				END,
			CASE dosage
				WHEN NULL
					THEN NULL
				ELSE CONCAT (
						dosage,
						' '
						)
				END,
			CASE descr_forme
				WHEN NULL
					THEN NULL
				ELSE descr_forme
				END,
			CASE descr_prod
				WHEN NULL
					THEN NULL
				ELSE CONCAT (
						' [',
						descr_prod,
						']'
						)
				END,
			' Box of ',
			pck_size
			), 1, 255) AS concept_name,
	'DA_France' AS vocabulary_id,
	'Device' AS domain_id,
	'Device' AS concept_class_id,
	'S' AS standard_concept,
	pfc AS concept_code,
	NULL AS possible_excipient,
	CURRENT_DATE AS valid_start_date, --check start date
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM non_drugs) a ;

--fill IRS
-- drug to supplier
INSERT INTO internal_relationship_stage
SELECT DISTINCT pfc,
	concept_code
FROM list_temp a
JOIN supplier USING (
		concept_name,
		concept_class_id
		);

-- drug to Ingredients
INSERT INTO internal_relationship_stage
SELECT DISTINCT pfc,
	concept_code
FROM list_temp a
JOIN ingr USING (
		concept_name,
		concept_class_id
		);

-- drug to Brand Name
INSERT INTO internal_relationship_stage
SELECT DISTINCT pfc,
	concept_code
FROM list_temp a
JOIN brand using (
		concept_name,
		concept_class_id
		);

-- drug to Dose Form
INSERT INTO internal_relationship_stage
SELECT DISTINCT pfc,
	b.concept_code
FROM france_to_map a
JOIN devv5.concept b on a.nfc = b.concept_code and b.vocabulary_id = 'NFC'
JOIN drug_concept_stage c ON b.concept_name = c.concept_name
	AND c.concept_class_id = 'Dose Form'
WHERE pfc IN (
		SELECT concept_code
		FROM drug_concept_stage
		WHERE concept_class_id = 'Drug Product'
		);
		
--ds_satge 
CREATE TABLE ds_start 
AS
SELECT pfc,
       descr_prod,
       descr_pck,
       amount_val,
       amount_un,
       (CASE WHEN amount_un = '%' AND denominator_un = 'ML'  THEN amount_val ELSE NULL END *10)*denominator_val AS numerator_val,
       CASE
         WHEN amount_un = '%' THEN 'MG'
         ELSE NULL
       END AS numerator_unit,
       denominator_val,
       denominator_un,
       pck_size
FROM (SELECT pfc,
             descr_prod,
             descr_pck,
             strg_unit AS amount_val,
             strg_meas AS amount_un,
             vl_wg_unit AS denominator_val,
             vl_wg_meas AS denominator_un,
             pck_size
      FROM da_france_source
      WHERE strg_meas = '%'
      AND   vl_wg_meas = 'ML' ) a 
UNION
SELECT pfc,
       descr_prod,
       descr_pck,
       amount_val,
       amount_un,
       (CASE WHEN amount_un = '%' AND denominator_un = 'G' THEN amount_val ELSE NULL END / 100) * denominator_val AS numerator_val,
       CASE
         WHEN amount_un = '%' THEN 'MG'
         ELSE NULL
       END AS numerator_unit,
       denominator_val,
       denominator_un,
       pck_size
FROM (SELECT pfc,
             descr_prod,
             descr_pck,
             strg_unit AS amount_val,
             strg_meas AS amount_un,
             vl_wg_unit AS denominator_val,
             vl_wg_meas AS denominator_un,
             pck_size
      FROM da_france_source
      WHERE strg_meas = '%'
      AND   vl_wg_meas = 'G') a
UNION
SELECT pfc,
       descr_prod,
       descr_pck,
       amount_val,
       amount_un,
       CASE
         WHEN amount_un = '%' THEN amount_val
         ELSE NULL
       END *10 AS numerator_val,
       CASE
         WHEN amount_un = '%' THEN 'MG'
         ELSE NULL
       END AS numerator_unit,
       denominator_val,
       denominator_un,
       pck_size
FROM (SELECT pfc,
             descr_prod,
             descr_pck,
             strg_unit AS amount_val,
             strg_meas AS amount_un,
             vl_wg_unit AS denominator_val,
             vl_wg_meas AS denominator_un,
             pck_size
      FROM da_france_source
      WHERE strg_meas = '%' 
      AND   vl_wg_meas IS NULL) a   
UNION
SELECT pfc,
       descr_prod,
       descr_pck,
       strg_unit AS amount_val,
       strg_meas AS amount_un,
       NULL::FLOAT AS numerator_val,
       NULL::VARCHAR AS numerator_unit,
       vl_wg_unit AS denominator_val,
       vl_wg_meas AS denominator_un,
       pck_size
FROM da_france_source
WHERE pfc NOT IN (SELECT pfc FROM da_france_source WHERE strg_meas = '%');
 
UPDATE ds_start
   SET amount_val = NULL,
       amount_un = NULL
WHERE numerator_unit IS NOT NULL;

UPDATE ds_start
   SET denominator_un = 'ML'
WHERE numerator_unit IS NOT NULL
AND   denominator_un IS NULL;

UPDATE ds_start
   SET amount_un = 'MCG'
WHERE amount_un = 'Y';

CREATE TABLE ds_start_1 
AS
(SELECT pfc,
       descr_prod,
       descr_pck,
       NULL::FLOAT AS amount_val,
       NULL::VARCHAR AS amount_un,
       amount_val*denominator_val AS nominator_val,
       amount_un AS numerator_unit,
       denominator_val,
       denominator_un,
       pck_size
FROM ds_start
WHERE amount_val IS NOT NULL
AND   denominator_val IS NOT NULL
AND   descr_pck ~ '((\.)?\d+(\s)?MG|MU|ME|MCG|K|G|Y|IU(\s)?)(\/)((1)?(\s)?ML|G)'
UNION
SELECT pfc,
       descr_prod,
       descr_pck,
       NULL::FLOAT AS amount_val,
       NULL::VARCHAR AS amount_un,
       amount_val*CAST(doses AS FLOAT) AS numerator_val,
       amount_un AS numerator_unit,
       denominator_val,
       denominator_un,
       pck_size
FROM
(
SELECT pfc,
       descr_prod,
       descr_pck,
       amount_val,
       amount_un,
       numerator_val,
       numerator_unit,
       denominator_val,
       denominator_un,
       SUBSTRING(SUBSTRING(descr_pck,'\d+D'),'\d+') AS doses,
       pck_size
FROM ds_start
WHERE amount_val IS NOT NULL
AND   denominator_val IS NOT NULL
AND   descr_pck ~ '((\.)?\d+(\s)?MG|MU|ME|MCG|Y|K|G|IU)((\s)?(\/)(\s)?DOS)') a
UNION
SELECT pfc,
       descr_prod,
       descr_pck,
       NULL::FLOAT AS amount_val,
       NULL::VARCHAR AS amount_un,
       amount_val*denominator_val AS nominator_val,
       amount_un AS numerator_unit,
       denominator_val,
       denominator_un,
       pck_size
FROM ds_start
WHERE amount_val IS NOT NULL
AND   denominator_val IS NOT NULL
AND   NOT descr_pck ~ '((\.)?\d+(\s)?MG|MU|ME|MCG|Y|K|G|IU)(\s)?(\/)'
AND   descr_pck ~ '(1(\s)?ML)'
);

CREATE TABLE ds_start_2 
AS
(SELECT pfc,
       descr_prod,
       descr_pck,
       NULL::FLOAT AS amount_val,
       NULL::VARCHAR AS amount_un,
       (amount_val / doses)*denominator_val AS numerator_val,
       amount_un AS numerator_unit,
       denominator_val,
       denominator_un,
       pck_size
FROM (SELECT pfc,
             descr_prod,
             descr_pck,
             amount_val,
             amount_un,
             numerator_val,
             numerator_unit,
             denominator_val,
             denominator_un,
             CAST(TRIM(SUBSTRING(descr_pck,'\/(\d+(ML|MG|G))'),'ML|MG|G') AS FLOAT) AS doses,
             pck_size
      FROM ds_start
      WHERE pfc NOT IN (SELECT pfc FROM ds_start_1)
      AND   amount_val IS NOT NULL
      AND   denominator_val IS NOT NULL
      AND   descr_pck ~ '(\/)') a
WHERE doses IS NOT NULL
UNION
SELECT pfc,
       descr_prod,
       descr_pck,
       NULL::FLOAT AS amount_val,
       NULL::VARCHAR AS amount_un,
       amount_val AS numerator_val,
       amount_un AS numerator_unit,
       denominator_val,
       denominator_un,
       pck_size
FROM ds_start
WHERE pfc NOT IN (SELECT pfc FROM ds_start_1)
AND   amount_val IS NOT NULL
AND   denominator_val IS NOT NULL
AND   NOT descr_pck ~ '(\/)');

CREATE TABLE ds_stage_1 
AS
(SELECT pfc,
       descr_prod,
       descr_pck,
       NULL::FLOAT AS amount_val,
       NULL::VARCHAR AS amount_un,
       amount_val AS numerator_val,
       amount_un AS numerator_unit,
       denominator_val,
       denominator_un,
       pck_size
FROM ds_start
WHERE pfc NOT IN (SELECT pfc FROM ds_start_1)
AND   pfc NOT IN (SELECT pfc FROM ds_start_2)
AND   amount_val IS NOT NULL
AND   denominator_val IS NOT NULL
UNION
SELECT *
FROM ds_start
WHERE pfc NOT IN (SELECT pfc FROM ds_start_1)
AND   pfc NOT IN (SELECT pfc FROM ds_start_2)
AND   NOT (amount_val IS NOT NULL AND denominator_val IS NOT NULL)
UNION
SELECT *
FROM ds_start_1
UNION
SELECT *
FROM ds_start_2
);

INSERT INTO ds_stage
WITH a AS
(
  SELECT a.pfc AS drug_concept_code,
         b.concept_code AS ingredient_concept_code,
        -- a.descr_prod,
         amount_val AS amount_value,
         amount_un AS amount_unit,
         numerator_val AS numerator_value,
         numerator_unit,
         denominator_val AS denominator_value,
         denominator_un AS denominator_unit,
         CAST(pck_size AS SMALLINT) AS box_size
  FROM internal_relationship_stage c
    JOIN ds_stage_1 a ON a.pfc = c.concept_code_1
    JOIN drug_concept_stage b
      ON b.concept_code = c.concept_code_2
     AND b.concept_class_id = 'Ingredient'
)
SELECT *
FROM a;

DELETE
FROM ds_stage
WHERE drug_concept_code IN (SELECT drug_concept_code
                            FROM ds_stage
                            WHERE amount_value IS NULL
                            AND   numerator_value IS NULL);

UPDATE ds_stage
   SET box_size = NULL
WHERE box_size = '1';;

-- populate relationship_ingrdient
-- Ingredients
CREATE TABLE relationship_ingrdient AS
SELECT DISTINCT a.concept_code AS concept_code_1,
	c.concept_id AS concept_id_2
FROM drug_concept_stage a
JOIN devv5.concept c ON upper(c.concept_name) = upper(a.concept_name)
	AND c.concept_class_id IN (
		'Ingredient',
		'VTM',
		'AU Substance'
		)
WHERE a.concept_class_id = 'Ingredient'
AND   c.standard_concept = 'S'
AND   c.vocabulary_id IN ('RxNorm','RxNorm Extension');

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
FROM relationship_bn where concept_id_2 !=0;

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
JOIN drug_concept_stage b ON b.concept_name = a.dose_form_name where a.concept_id_2 !=0;

/*--update ds_stage after relationship_to concept found identical ingredients
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
       MAX(ingredient_concept_code) OVER (PARTITION BY drug_concept_code,concept_id_2) AS ingredient_concept_code,
       box_size,
       SUM(amount_value) OVER (PARTITION BY drug_concept_code) AS amount_value,
       amount_unit,
       SUM(numerator_value) OVER (PARTITION BY drug_concept_code,concept_id_2) AS numerator_value,
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
		);*/

/*INSERT INTO ds_stage
SELECT *
FROM DS_SUM
WHERE coalesce(amount_value, numerator_value) IS NOT NULL;*/

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

 -- unit update in rtc
INSERT INTO relationship_to_concept
SELECT a.*
FROM (SELECT d.concept_code,
             d.vocabulary_id,
             o.concept_id_2,
             o.precedence,
             CAST(o.convertion_factor AS FLOAT) AS convertion_factor
      FROM drug_concept_stage d
        JOIN old_rtc o ON UPPER (d.concept_name) = UPPER (o.concept_name)
      WHERE concept_class_id IN ('Unit')
      AND   o.concept_name IS NOT NULL) a
  LEFT JOIN (SELECT a.*
             FROM drug_concept_stage d
               JOIN relationship_to_concept a ON a.concept_code_1 = d.concept_code
             WHERE concept_class_id = 'Unit') b ON a.concept_id_2 = b.concept_id_2
WHERE b.concept_code_1 IS NULL
AND   a.concept_id_2 != 0;

--fill irc dose form with grr mapping + manual insert
INSERT INTO relationship_to_concept
SELECT DISTINCT d.concept_code,
       d.vocabulary_id,
       a.concept_id,
       a.precedence,
       NULL::FLOAT AS conversion_factor
FROM drug_concept_stage d
  JOIN forms b ON UPPER (d.concept_name) = UPPER (b.concept_name)
  JOIN dev_grr.aut_form_1 a ON a.concept_code = b.concept_code
  JOIN devv5.concept c ON a.concept_id = c.concept_id
WHERE d.concept_class_id = 'Dose Form'
AND   a.concept_id != 0;

INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) VALUES ('QHA','DA_France',19011167,1,NULL);--Nasal Spray
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) VALUES ('QHA','DA_France',19082165,2,NULL);--Nasal Solution
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) VALUES ('QHA','DA_France',19095977,3,NULL);--	Nasal Suspension
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) VALUES ('ZYY','DA_France',19082573,1,NULL);--Oral Tablet
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) VALUES ('ZYY','DA_France',19082168,2,NULL);--	Oral Capsule
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) VALUES ('ZYY','DA_France',19082170,3,NULL);--Oral Solution
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) VALUES ('ZYY','DA_France',19082191,4,NULL);--Oral Suspension
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) VALUES ('ZYY','DA_France',19082103,5,NULL);--	Injectable Solution
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) VALUES ('ZYY','DA_France',19082104,6,NULL);--Injectable Suspension
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) VALUES ('ZYY','DA_France',46234469,7,NULL);--	Injection
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) VALUES ('ZYX','DA_France',19082573,1,NULL);--Oral Tablet
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) VALUES ('ZYX','DA_France',19082170,2,NULL);--Oral Solution
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) VALUES ('ZYX','DA_France',19082191,3,NULL);--Oral Suspension
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) VALUES ('ZYX','DA_France',19082103,4,NULL);--Injectable Solution
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) VALUES ('ZYX','DA_France',19082104,5,NULL);--Injectable Suspension
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) VALUES ('ZYX','DA_France',46234469,6,NULL);--Injection
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) VALUES ('ZYX','DA_France',19082228,7,NULL);--	Topical Solution
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) VALUES ('ZYX','DA_France',46234410,8,NULL);--Topical Suspension
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) VALUES ('ZYX','DA_France',19082224,9,NULL);--Topical Cream
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) VALUES ('ZYX','DA_France',19082165,10,NULL);--Nasal Solution
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) VALUES ('ZYX','DA_France',19095977,11,NULL);--Nasal Suspension
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) VALUES ('ZYX','DA_France',19011167,12,NULL);--Nasal Spray
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) VALUES ('ZYX','DA_France',19095898,13,NULL);--Inhalant Solution
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) VALUES ('ZYX','DA_France',19018195,14,NULL);--Inhalant
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) VALUES ('ZYX','DA_France',19082162,15,NULL);--Nasal Inhalant
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) VALUES ('ZYX','DA_France',45775491,16,NULL);--Powder for Oral Solution
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) VALUES ('ZYX','DA_France',45775492,17,NULL);--Powder for Oral Suspension

UPDATE relationship_to_concept
   SET concept_id_2 = 19129634,
       precedence = 1
WHERE concept_code_1 = 'NGB';

-- ingred with old_rtc eq
/*INSERT INTO relationship_to_concept 
select d.concept_code, d.vocabulary_id, o.concept_id_2, o.precedence, cast(o.convertion_factor  as float)  as convertion_factor 
from drug_concept_stage d
left join old_rtc o on upper(d.concept_name)=upper(o.concept_name)
where d.concept_class_id  in ('Ingredient')
and o.concept_name is not NULL
and o.concept_id_2 !=0;*/

-- 3 concepts as name = name
INSERT INTO relationship_to_concept
SELECT b.concept_code,
       b.vocabulary_id,
       a.concept_id AS concept_id_2,
       1::INTEGER AS precedence,
       NULL::FLOAT AS concvertion_factor
FROM devv5.concept a
  JOIN (SELECT d.concept_code,
               d.vocabulary_id,
               d.concept_name,
               d.concept_class_id,
               o.concept_id_2,
               o.precedence,
               o.convertion_factor
        FROM drug_concept_stage d
          LEFT JOIN old_rtc o ON UPPER (d.concept_name) = UPPER (o.concept_name)
        WHERE d.concept_class_id IN ('Ingredient')
        AND   o.concept_name IS NULL) b
    ON a.concept_name = b.concept_name
   AND a.concept_class_id = 'Ingredient'
   AND a.standard_concept = 'S'
WHERE a.concept_id != 0;

--manual ingredient create
CREATE TABLE manual_map_ingr 
(
  concept_name   VARCHAR(255),
  target_id      INTEGER
);
 
--filing manual_map_ingr
INSERT INTO manual_map_ingr (concept_name, target_id) VALUES ('NIT COMB',0); 
INSERT INTO manual_map_ingr (concept_name, target_id) VALUES ('VANILLA PLANIFOLIA',1594208); 
INSERT INTO manual_map_ingr (concept_name, target_id) VALUES ('PADINA PAVONICA',43526893); 
INSERT INTO manual_map_ingr (concept_name, target_id) VALUES ('ANTI-PARASITIC',0); 
INSERT INTO manual_map_ingr (concept_name, target_id) VALUES ('LISTEA CUBEBA',0); 
INSERT INTO manual_map_ingr (concept_name, target_id) VALUES ('BETOXYCAINE',0); 
INSERT INTO manual_map_ingr (concept_name, target_id) VALUES ('DYSMENORRHEA RELIEF',0); 
INSERT INTO manual_map_ingr (concept_name, target_id) VALUES ('TOPICAL ANALGESICS',0); 
INSERT INTO manual_map_ingr (concept_name, target_id) VALUES ('THROAT LOZENGES',0); 
INSERT INTO manual_map_ingr (concept_name, target_id) VALUES ('ANTACIDS',0); 
INSERT INTO manual_map_ingr (concept_name, target_id) VALUES ('OXAFLOZANE',0); 
INSERT INTO manual_map_ingr (concept_name, target_id) VALUES ('ALKYLGLYCEROLS (UNSPECIFIED)',0); 
INSERT INTO manual_map_ingr (concept_name, target_id) VALUES ('MONOPHOSPHOTHIAMINE',19137312); 
INSERT INTO manual_map_ingr (concept_name, target_id) VALUES ('ETHYL ORTHOFORMATE',0);
INSERT INTO manual_map_ingr (concept_name, target_id) VALUES ('BISCOUMACETATE',0);
INSERT INTO manual_map_ingr (concept_name, target_id) VALUES ('TAMUS COMMUNIS',0);
INSERT INTO manual_map_ingr (concept_name, target_id) VALUES ('N-ACETYLASPARTIC ACID',0);
INSERT INTO manual_map_ingr (concept_name, target_id) VALUES ('PRANOSAL',43014110);
INSERT INTO manual_map_ingr (concept_name, target_id) VALUES ('BACOPA MONIERI',40221311);
INSERT INTO manual_map_ingr (concept_name, target_id) VALUES ('BIORESMETHRIN',0);
INSERT INTO manual_map_ingr (concept_name, target_id) VALUES ('SULTAMICILLIN',0);
INSERT INTO manual_map_ingr (concept_name, target_id) VALUES ('METHOPRENE',0);
INSERT INTO manual_map_ingr (concept_name, target_id) VALUES ('LILIUM CANDIDUM',42899405);
INSERT INTO manual_map_ingr (concept_name, target_id) VALUES ('BROPARESTROL',0);
INSERT INTO manual_map_ingr (concept_name, target_id) VALUES ('ANTI-PARASITIC',0);
INSERT INTO manual_map_ingr (concept_name, target_id) VALUES ('PROPANOCAINE',0);
INSERT INTO manual_map_ingr (concept_name, target_id) VALUES ('PARACETAMOL',1125315);
INSERT INTO manual_map_ingr (concept_name, target_id) VALUES ('P-AMINOBENZOIC ACID',19018384);
INSERT INTO manual_map_ingr (concept_name, target_id) VALUES ('ENOXOLONE',42544020);
INSERT INTO manual_map_ingr (concept_name, target_id) VALUES ('LEVOTHYROXINE SODIUM',1501700);
INSERT INTO manual_map_ingr (concept_name, target_id) VALUES ('FONDAPARINUX SODIUM',1315865);
INSERT INTO manual_map_ingr (concept_name, target_id) VALUES ('ENOXAPARIN SODIUM',1301025);
INSERT INTO manual_map_ingr (concept_name, target_id) VALUES ('COLECALCIFEROL',19095164);
INSERT INTO manual_map_ingr (concept_name, target_id) VALUES ('ALENDRONIC ACID',1557272);
INSERT INTO manual_map_ingr (concept_name, target_id) VALUES ('ALUMINIUM',42898412);
INSERT INTO manual_map_ingr (concept_name, target_id) VALUES ('IPRATROPIUM BROMIDE',1112921); 
INSERT INTO manual_map_ingr (concept_name, target_id) VALUES ('BECLOMETASONE',1115572);
INSERT INTO manual_map_ingr (concept_name, target_id) VALUES ('CEFRADINE',1786842);
INSERT INTO manual_map_ingr (concept_name, target_id) VALUES ('CICLOSPORIN',19010482);
INSERT INTO manual_map_ingr (concept_name, target_id) VALUES ('ACETYLSALICYLIC ACID',1112807);
INSERT INTO manual_map_ingr (concept_name, target_id) VALUES ('CLOFIBRIC ACID',1598658);
INSERT INTO manual_map_ingr (concept_name, target_id) VALUES ('FLUOCINOLONE ACETONIDE',996541);
INSERT INTO manual_map_ingr (concept_name, target_id) VALUES ('FOLLICLE-STIMULATING HORMONE',1588712);
INSERT INTO manual_map_ingr (concept_name, target_id) VALUES ('ETHINYLESTRADIOL',1549786);
INSERT INTO manual_map_ingr (concept_name, target_id) VALUES ('NORETHISTERONE',19050090);
INSERT INTO manual_map_ingr (concept_name, target_id) VALUES ('LUTEINISING HORMONE',1589795);
INSERT INTO manual_map_ingr (concept_name, target_id) VALUES ('HYALURONIC ACID',787787);
INSERT INTO manual_map_ingr (concept_name, target_id) VALUES ('SALBUTAMOL',1154343);
INSERT INTO manual_map_ingr (concept_name, target_id) VALUES ('PYRIDOXINE CLOFIBRATE',19005046);
INSERT INTO manual_map_ingr (concept_name, target_id) VALUES ('TIOTROPIUM BROMIDE',1106776);
INSERT INTO manual_map_ingr (concept_name, target_id) VALUES ('URSODEOXYCHOLIC ACID',988095);

--insert manual ingredient to rtc
INSERT INTO relationship_to_concept 
SELECT a.concept_code,
       a.vocabulary_id,
       b.target_id,
       NULL::INTEGER,
       NULL::INTEGER
FROM drug_concept_stage a
  JOIN manual_map_ingr b ON a.concept_name = b.concept_name
WHERE b.target_id != 0; 

-- insert Brand Name to rtc 
INSERT INTO relationship_to_concept
SELECT a.concept_code,
       a.vocabulary_id,
       CAST(b.to_concept AS INTEGER) AS concept_id_2,
       NULL::INTEGER,
       NULL::INTEGER
FROM drug_concept_stage a
  JOIN brand_name_mapping b ON a.concept_name = b.concept_name
WHERE to_concept NOT IN ('d','device','supplier')
AND   to_concept != '0';

-- insert Supplier to rtc 
INSERT INTO relationship_to_concept
SELECT a.concept_code,
       a.vocabulary_id,
       b.concept_id,
       NULL::INTEGER,
       NULL::NUMERIC
FROM (SELECT a.concept_name,
             a.concept_code,
             a.vocabulary_id,
             b.concept_id
      FROM drug_concept_stage a
        JOIN supplier_mapp_auto b ON a.concept_name = b.source_name
      UNION
      SELECT a.concept_name,
             a.concept_code,
             a.vocabulary_id,
             b.to_concept
      FROM drug_concept_stage a
        JOIN supplier_manual b ON a.concept_name = b.concept_name) a
  JOIN concept b ON a.concept_id = b.concept_id
WHERE b.concept_class_id != 'Brand Name'
AND   b.concept_id != 0;

INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence)
SELECT DISTINCT concept_code AS concept_code_1,
       'DA_France',
       concept_id AS concept_id_2,
       precedence
FROM dev_grr.drug_concept_stage
  JOIN dev_grr.r_t_c_all_bckp USING (concept_name,concept_class_id)
WHERE concept_class_id = 'Dose Form'
AND   concept_code IN (SELECT DISTINCT i.concept_code_2
                       FROM dev_da_france_2.internal_relationship_stage i
                         JOIN dev_da_france_2.drug_concept_stage d
                           ON i.concept_code_2 = d.concept_code
                          AND d.concept_class_id = 'Dose Form'
                         JOIN devv5.concept c
                           ON c.concept_code = d.concept_code
                          AND c.vocabulary_id = 'NFC'
                       WHERE concept_code_2 NOT IN (SELECT concept_code_1
                                                    FROM dev_da_france_2.relationship_to_concept)
                       AND   d.concept_code NOT IN (SELECT concept_code_1 FROM relationship_to_concept));

--delete duplicates
DELETE FROM relationship_to_concept a
WHERE a.ctid <> (SELECT min(b.ctid)
                 FROM   relationship_to_concept b
                 WHERE  a.concept_code_1 = b.concept_code_1 and a.concept_id_2 = b.concept_id_2);

--delete from irs when marketed without dosage
DELETE
FROM internal_relationship_stage
WHERE concept_code_1 IN (
	SELECT concept_code
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
		WHERE concept_code_1 NOT IN 
		    (
				SELECT concept_code_1
				FROM internal_relationship_stage
				JOIN drug_concept_stage ON concept_code_2 = concept_code
					AND concept_class_id = 'Dose Form'
				)
		) s ON s.concept_code_1 = dcs.concept_code
	WHERE dcs.concept_class_id = 'Drug Product'
		AND invalid_reason IS NULL)
AND concept_code_2 IN (SELECT concept_code_2
FROM internal_relationship_stage a
  JOIN drug_concept_stage b ON a.concept_code_2 = b.concept_code
WHERE b.concept_class_id = 'Supplier'
AND   concept_code_1 IN (
	SELECT concept_code
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
		WHERE concept_code_1 NOT IN 
		    (
				SELECT concept_code_1
				FROM internal_relationship_stage
				JOIN drug_concept_stage ON concept_code_2 = concept_code
					AND concept_class_id = 'Dose Form'
				)
		) s ON s.concept_code_1 = dcs.concept_code
	WHERE dcs.concept_class_id = 'Drug Product'
		AND invalid_reason IS NULL));  

--- another bug from the script above
UPDATE ds_stage
   SET denominator_unit = NULL
WHERE denominator_unit = '';

/*
select * from ds_stage where amount_value = '';
select * from ds_stage where amount_unit = '';
select * from ds_stage where numerator_value = '';
select * from ds_stage where numerator_unit = '';
select * from ds_stage where denominator_value = '';
select * from ds_stage where denominator_unit = '';
select * from ds_stage where box_size = ''; */

--delete duplicates if present
DELETE
FROM ds_stage
WHERE CTID NOT IN (
SELECT MIN(CTID)
FROM ds_stage
GROUP BY drug_concept_code,ingredient_concept_code,box_size,amount_value,amount_unit,
        numerator_value,numerator_unit,denominator_value,denominator_unit); --  0 
        
       
UPDATE drug_concept_stage
   SET concept_class_id = 'Supplier'
WHERE concept_name = 'WELEDA'
AND   concept_class_id = 'Brand Name'
AND   concept_code = 'OMOP5562';

-- remove duplicated per name wrong Brand Names
DELETE
FROM drug_concept_stage
WHERE concept_name IN (SELECT concept_name
                            FROM drug_concept_stage
                            GROUP BY concept_name
                            HAVING COUNT(1) > 1)
                            and concept_class_id = 'Brand Name'; -- 306                           
DELETE
FROM drug_concept_stage
WHERE CTID NOT IN (
SELECT MIN(CTID)
FROM drug_concept_stage
GROUP BY concept_name);
                           
SELECT *
FROM drug_concept_stage
WHERE concept_name IN (SELECT drug_concept_code
                            FROM ds_stage
                            GROUP BY drug_concept_code
                            HAVING COUNT(1) > 1); -- 306
-- remove drugs which have numerator_value > 1000 (for MG/ML) to the LPD_Italy_excluded 
WITH t1 AS
(
  SELECT *
  FROM ds_stage
  WHERE (LOWER(numerator_unit) IN ('mg') AND LOWER(denominator_unit) IN ('ml','g') OR LOWER(numerator_unit) IN ('g') AND LOWER(denominator_unit) IN ('l'))
  AND   numerator_value /COALESCE(denominator_value,1) > 1000
) DELETE
FROM ds_stage
WHERE drug_concept_code IN (SELECT drug_concept_code FROM t1);-- 1

-- get rif of >1000MG/ML if any. all of them should be reviewed manually 
DELETE
FROM ds_stage
WHERE (LOWER(numerator_unit) IN ('mg') AND LOWER(denominator_unit) IN ('ml','g') OR LOWER(numerator_unit) IN ('g') AND LOWER(denominator_unit) IN ('l'))
AND   numerator_value /COALESCE(denominator_value,1) > 1000; -- 0

DELETE
FROM drug_concept_stage
WHERE concept_name = '';

DELETE
FROM ds_stage
WHERE drug_concept_code IN ('2558603','4627497','5058902','5095701');

-- get rid of concept_name duplicates if any 
UPDATE drug_concept_stage a
   SET concept_name = b.t_nm
FROM da_france_source b
WHERE b.pfc = a.concept_code;

-- run Build_RxE.sql
-- run MapDrug.sql
