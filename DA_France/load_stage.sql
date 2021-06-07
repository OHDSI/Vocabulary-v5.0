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
* Authors: Eldar Allakhverdiiev, Dmitry Dymshyts, Christian Reich
* Date: 2017
**************************************************************************/



DROP TABLE IF EXISTS non_drugs;
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
FROM france_march_21_delta f
WHERE EXISTS (
		SELECT 1
		FROM france_march_21_delta f_int
		WHERE f_int.pfc = f.pfc
			AND f_int.ctid > f.ctid
		);

DROP TABLE IF EXISTS non_drugs;
CREATE TABLE non_drugs AS
	SELECT descr_prod,
		descr_forme,
		strg_unit||strg_meas as dosage,
		--dosage_add,
		vl_wg_unit||vl_wg_meas as volume,
		pck_size,
		code_atc,
		pfc,
		molecule,
		nfc,
	--	english,
	-- lb_nfc_3,
		descr_pck,
		strg_unit,
		strg_meas,
		NULL::VARCHAR(250) AS concept_type
	FROM france_march_21_delta
	WHERE  molecule ~* 'CONDOMS|SWAB|WOUND|BRAN|PADS$|IUD|ANTI-SNORING AID|TEATS'
		OR molecule ~* 'INCONTINENCE PADS|WIRE|AC IOXITALAMIQ.DCI|TELEBRIX 30 MEGLUM|ANGIOGRAFINE|AMINOACIDS|ELECTROLYTES'
OR molecule ~* ' TEST| TESTS|IOXITALAMIC|ELECTROLYTE|DATSCAN|BANDAGES|DEVICES|CARE PRODUCTS|DRESSING|CATHETERS|EYE OCCLUSION PATCH|INCONTINENCE COLLECTION APPLIANCES|DEVICE|MEXTRA|URGOTUL BORDER'		
or molecule ~*'OLIGO ELEMENTS|UREA 13|BARIUM|GENERAL NUTRIENTS|GADODIAMIDE|GADOBENIC ACID|GADOTERIC ACID|GLUCOSE 1-PHOSPHATE|GADOBUTROL|BABY MILKS|LOW CALORIE FOOD|NUTRITION'
or code_atc ~*'V20|V06|V10|V09|V04|V08'
OR (
			molecule LIKE '% TEST%'
			AND molecule NOT LIKE 'TUBERCULIN%'
			)
		--OR english ~* 'Non Human'
  		OR descr_prod ~* 'SOLVAROME|BIOSTINAL|CERP SUP GLYC|ECZEBIO LINIMENT|ACTIVOX'
		OR descr_prod ~* 'CARTIMOTIL|TERUMO SER INS'
		OR descr_pck ~* 'DEODORANT|SPRAYS|BOITE|DDT|TETRAMETHRIN'
		OR descr_prod ~* 'ABCDERM CHANGE|CARTIMOTIL|XERIAL 50|ATODERM|MEDNUTRIF.LIP G120|SPIRIAL|FORTIFRESH|TOLERIANE ULTRA|AQUAPORIN ACTIVE|PSORIANE|TOTAMINE GLUCID|ADAPTIC'
		OR descr_prod ~* 'PRANABB|MICRORECTAL|BIATAIN SILIC LITE|POCOCREM|PHYSIOGEL A.I.|EFFACLAR|BLEPHASOL|INOV HEPACT DETOX|RESOURCE MIXES HP|BIOPTIMUM MINCEUR|BIOPTIMUM MEMOIRE|INOV SEROTONE|CAPILEOV ANTICHUTE|POLYBACTUM|FORTIPUDDING'
    OR descr_labo ~* 'AVENE|DUCRAY|LOHMANN & RAUSCHER|LA ROCHE POSAY|BIODERMA'
				--OR lb_nfc_3 LIKE '%NON US.HUMAIN%'
		;
		



DROP TABLE IF EXISTS junk_drugs;
CREATE TABLE junk_drugs AS
	SELECT descr_prod,
		descr_forme,
		strg_unit||strg_meas as dosage,
		--dosage_add,
		vl_wg_unit||vl_wg_meas as volume,
		pck_size,
		code_atc,
		pfc,
		molecule,
		nfc,
	--	english,
	-- lb_nfc_3,
		descr_pck,
		strg_unit,
		strg_meas,
		NULL::VARCHAR(250) AS concept_type
	FROM france_march_21_delta
	WHERE 
	molecule ~* 'DEODORANT|AVENA SATIVA|CREAM|HAIR|SHAMPOO|LOTION|FACIAL CLEANSER|LIP PROTECTANTS|CLEANSING AGENTS|SKIN|TONICS|TOOTHPASTES|MOUTH|SCALP LOTIONS|CRYSTAL VIOLET'
or molecule ~* 'ALLERGENS|LENS SOLUTIONS|INFANT |DISINFECTANT|ANTISEPTIC|LUBRICANTS|INSECT REPELLENTS|FOOD|SLIMMING PREPARATIONS|SPECIAL DIET|COTTON WOOL'
or molecule ~* 'ORAL HYGIENE|AFTER SUN PROTECTANTS|INSECT REPELLENTS|DECONGESTANT RUBS|EYE MAKE-UP REMOVERS|FIXATIVES|FOOT POWDERS|FIORAVANTI BALSAM|NUTRITION'
or molecule ~* 'CORN REMOVER|TANNING|OTHERS|NON MEDICATED|NON PHARMACEUTICAL|HOMOEOPATHIC| GLOBULUS|BATH OIL|SOAP'
or molecule ~* 'LACTOBACILLUS|LACTOSERUM|HARPAGOPHYTUM|PROBIOTICS|VACCINIUM|PANCREAS|BIFIDOBACTERIUM|LACTIC FERMENTS|OFFICINALIS|LIVER|ARNICA'
or
 code_atc ~* 'V07|V03|V01'
OR descr_prod ~* ' CICABIAFINE |OLIOSEPTIL V.URINAT|LYSOFON|REPIDERMYL|SEBAKLEN|REFLEX SPRAY|ACARDUST|A PAR|ISOPHY EAU URIAGE'
OR descr_prod ~* 'SPORT'
or descr_labo ~* 'BOIRON';

--list of ingredients
DROP TABLE IF EXISTS pre_ingr;
CREATE TABLE pre_ingr AS
SELECT DISTINCT ingred AS concept_name,
	pfc,
	'Ingredient'::VARCHAR AS concept_class_id
FROM (
	SELECT UNNEST(regexp_matches(molecule, '[^\+]+', 'g')) AS ingred,
		pfc
	FROM france_march_21_delta
	WHERE pfc NOT IN (
			SELECT pfc
			FROM non_drugs
			)
		and pfc not in (select pfc from junk_drugs)
	) AS s0
WHERE ingred is not null;

 -- extract ingredients where it is obvious for molecule like 'NULL'
DROP TABLE IF EXISTS FRANCE_march_21_1;
CREATE TABLE FRANCE_march_21_1 AS
SELECT 
  descr_prod,
	descr_forme,
	strg_unit||strg_meas as dosage,
	--dosage_add,
	vl_wg_unit||vl_wg_meas as volume,
	pck_size,
	code_atc,
	pfc,
	null as cse,
	nfc,
	--english,
	--lb_nfc_3,
	descr_pck,
	descr_labo,
	strg_unit,
	strg_meas,
	molecule
FROM    france_march_21_delta
WHERE molecule is not null
UNION
SELECT descr_prod,
	descr_forme,
	strg_unit||strg_meas as dosage,
	--dosage_add,
	vl_wg_unit||vl_wg_meas as volume,
	pck_size,
	code_atc,
	a.pfc,
		CASE 
		WHEN concept_name IS NOT NULL
			THEN concept_name
		ELSE null
		END as cse,
	nfc,
	descr_pck,
	descr_labo,
	strg_unit,
	strg_meas,
	molecule
	
FROM france_march_21_delta a
LEFT JOIN pre_ingr b ON trim(replace(descr_prod, 'DCI', '')) = upper(concept_name)
WHERE molecule is null
and a.pfc not in (select pfc from non_drugs);


-- ATTENTION!! manual mapping for vaccines\insulins,  after manual work put mapped concepts to concept_relationship_manual 
drop table if exists vacc_ins_to_map;

create table  vacc_ins_to_map as (select * from FRANCE_march_21_1 where molecule ~*'vaccine|Insul|serum|immunoglob');


delete from pre_ingr where pfc in (select pfc from vacc_ins_to_map) or pfc in (select pfc from non_drugs) or pfc in (select pfc from junk_drugs);

delete from FRANCE_march_21_1 where pfc in (select pfc from non_drugs);

delete from FRANCE_march_21_1 where pfc in (select pfc from junk_drugs);



--list of ingredients
DROP TABLE IF EXISTS ingr;
CREATE TABLE ingr AS
SELECT DISTINCT ingred AS concept_name,
	pfc,
	'Ingredient'::VARCHAR AS concept_class_id
FROM (
	SELECT UNNEST(regexp_matches(molecule, '[^\+]+', 'g')) AS ingred,
		pfc
	FROM FRANCE_march_21_1

	) AS s0
WHERE ingred is not null and pfc not in (select pfc from vacc_ins_to_map);

/*DROP TABLE IF EXISTS ingredi;
CREATE TABLE ingredi 
AS
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
      AND   invalid_reason IS NULL) as s;
insert into ingr (select concept_name, pfc, 'Ingredient' from  ingredi where  pfc not in (select pfc from ingr) and ing = concept_name and pfc not in (select pfc from vacc_ins_to_map));
*/
--list of Brand Names
DROP TABLE IF EXISTS brand;
CREATE TABLE brand AS
SELECT descr_prod AS concept_name,
	pfc,
	'Brand Name'::VARCHAR AS concept_class_id
FROM FRANCE_march_21_1
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
		FROM FRANCE_march_21_1
		WHERE molecule is null
		)
	or pfc not in 
	(select pfc from vacc_ins_to_map)
	AND descr_prod NOT LIKE '%DCI%'
	AND NOT descr_prod ~ 'L\.IND|LAB IND'
	AND upper(descr_prod) NOT IN (
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

-- delete Brand Name after manual review
delete from brand where concept_name in  (
select concept_name from brand_name_mapping where to_concept in ('device','supplier','d'));



-- list of supplier
drop table if exists supplier;
create table supplier as 
select distinct descr_labo as concept_name,
 pfc,
'Supplier'::VARCHAR AS concept_class_id 
from FRANCE_march_21_1
where pfc NOT IN (
		SELECT pfc
		FROM non_drugs
		)
		or pfc	not in 
	(select pfc from vacc_ins_to_map)
	or pfc NOT IN (
		SELECT pfc
		FROM junk_drugs
		);
		

--delete from supplier brand_name 
delete from supplier where concept_name in (
select a.concept_name from 
(
select a.concept_name,  b.concept_id 
from supplier a 
join supplier_mapp_auto b on a.concept_name = b.source_name
union
select a.concept_name, b.to_concept 
from supplier a 
join supplier_manual b on a.concept_name = b.concept_name 
) a
join concept b on a.concept_id=b.concept_id
where concept_class_id = 'Brand Name'
);
delete from supplier where pfc = '0207850';
delete from supplier where concept_name ~*'DERMOPHIL|CRINEX'; 

--list of Dose Forms
DROP TABLE IF EXISTS forms;
CREATE TABLE forms AS
select *  from devv5.concept a
join FRANCE_march_21_1 b on a.concept_code = b.nfc and a.vocabulary_id = 'NFC'
AND pfc NOT IN (
		SELECT pfc
		FROM non_drugs
		)
;
 delete from forms where  pfc IN (
		SELECT pfc
		FROM junk_drugs
		)
		or pfc IN (
		SELECT pfc
		FROM vacc_ins_to_map
		);
update forms set concept_class_id = 'Dose Form';
 

-- units, take units used for volume and strength definition
DROP TABLE IF EXISTS unit;
CREATE TABLE unit AS
SELECT strg_meas AS concept_name,
	'Unit'::VARCHAR AS concept_class_id,
	strg_meas AS concept_code
FROM (
	SELECT strg_meas
	FROM FRANCE_march_21_1
	WHERE pfc NOT IN (
			SELECT pfc
			FROM non_drugs
			)
			or pfc NOT IN (
		SELECT pfc
		FROM junk_drugs
		)
	UNION
	SELECT regexp_replace(volume, '[[:digit:]\.]', '','g')
	FROM FRANCE_march_21_1
	WHERE strg_meas is not null
		AND pfc NOT IN (
			SELECT pfc
			FROM non_drugs
			)
	) a
WHERE a.strg_meas NOT IN (
		'CH'
		
		) and a.strg_meas is not null;


INSERT INTO unit VALUES ('UI', 'Unit', 'UI');
INSERT INTO unit VALUES ('MUI', 'Unit', 'MUI');
INSERT INTO unit VALUES ('DOS', 'Unit', 'DOS');
INSERT INTO unit VALUES ('GM', 'Unit', 'GM');
INSERT INTO unit VALUES ('H', 'Unit', 'H');

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

--dose form what doesen't exists in NFC in devv5.concept
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('IEP','DA_France',36250064,1,null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('IEP','DA_France',35604877,2,null);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('IEP','DA_France',45775488,3,null);


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
FROM FRANCE_march_21_1 a
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
	AND molecule is not null;
	insert into drug_products
SELECT DISTINCT CASE 
		WHEN d.pfc IS NOT NULL
			
							THEN trim(regexp_replace(replace(CONCAT (
								volume,
								' ',
								substr((replace(molecule, '+', ' / ')), 1, 175) --To avoid names length more than 255
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
							substr((replace(molecule, '+', ' / ')), 1, 175) --To avoid names length more than 255
							,
							' ',
							c.concept_name,
							' Box of ',
							a.pck_size
							), 'NULL', ''), '\s+', ' ', 'g'))
		END AS concept_name,
	'Drug Product'::VARCHAR AS concept_class_id,
	a.pfc AS concept_code
FROM FRANCE_march_21_1 a
LEFT JOIN brand d ON d.concept_name = a.descr_prod

join relationship_to_concept r on a.nfc = r.concept_code_1 and precedence = '1'
join devv5.concept c on r.concept_id_2 = c.concept_id
WHERE a.pfc NOT IN (
		SELECT pfc
		FROM non_drugs
		)
and a.pfc NOT IN (
		SELECT pfc
		FROM junk_drugs
		)
	AND molecule is not null
	and a.pfc not in (select concept_code from drug_products);
	
update drug_products
set concept_name =  regexp_replace(concept_name, 'Box of \y1\y', '');

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
	union 
	select concept_name,
	 concept_class_id
	from supplier	
) AS s0
		UNION
	SELECT concept_name,
		concept_class_id,
		concept_code
	FROM forms;

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
SELECT  cast (concept_name as varchar (255)),
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
select 
trim(concept_name,'^ ')  AS concept_name,
vocabulary_id,
	domain_id,
	concept_class_id,
	standard_concept,
	concept_code,
	possible_excipient,
	valid_start_date,
	valid_end_date,
	invalid_reason
from 
(SELECT DISTINCT substr(CONCAT (
			volume,
			' ',
			CASE molecule
				WHEN null
					THEN NULL
				ELSE CONCAT (
						molecule,
						' '
						)
				END,
			CASE dosage
				WHEN null
					THEN NULL
				ELSE CONCAT (
						dosage,
						' '
						)
				END,
			/*CASE dosage_add
				WHEN 'NULL'
					THEN NULL
				ELSE CONCAT (
						dosage_add,
						' '
						)
				END,*/
			CASE descr_forme
				WHEN null
					THEN NULL
				ELSE descr_forme
				END,
			CASE descr_prod
				WHEN null
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
	'DA_France' as vocabulary_id,
	'Device' as domain_id,
	'Device' as concept_class_id,
	'S' as standard_concept,
	pfc as concept_code,
	NULL as possible_excipient,
	CURRENT_DATE AS valid_start_date, --check start date
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL as invalid_reason
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
	b.concept_code
FROM FRANCE_march_21_1 a
JOIN devv5.concept b on a.nfc = b.concept_code and b.vocabulary_id = 'NFC'
JOIN drug_concept_stage c ON b.concept_name = c.concept_name
	AND c.concept_class_id = 'Dose Form'
WHERE pfc IN (
		SELECT concept_code
		FROM drug_concept_stage
		WHERE concept_class_id = 'Drug Product'
		);

--ds_satge 
--
drop table if exists ds_start;
create table ds_start as 
select pfc, descr_prod,descr_pck,amount_val, amount_un,
(case when amount_un = '%' and denominator_un = 'ML' then amount_val else null end *10)*denominator_val as numerator_val,
case when amount_un = '%'  then 'MG' else null end as numerator_unit, 
denominator_val, denominator_un, pck_size
from (
select pfc, descr_prod,descr_pck, strg_unit as amount_val, strg_meas as amount_un, vl_wg_unit as denominator_val,  vl_wg_meas as denominator_un, pck_size
from france_march_21_delta where strg_meas = '%' and vl_wg_meas = 'ML'
 ) a
Union
select pfc, descr_prod,descr_pck,amount_val, amount_un,
(case when amount_un = '%' and denominator_un = 'G' then amount_val else null end /100)*denominator_val as numerator_val,
case when amount_un = '%'  then 'MG' else null end as numerator_unit, 
denominator_val, denominator_un, pck_size
from (
select pfc, descr_prod,descr_pck, strg_unit as amount_val, strg_meas as amount_un, vl_wg_unit as denominator_val,  vl_wg_meas as denominator_un, pck_size
 from france_march_21_delta where strg_meas = '%' and vl_wg_meas = 'G'
 ) a 
union
select pfc, descr_prod,descr_pck,amount_val, amount_un,
case when amount_un = '%' then amount_val else null end *10 as numerator_val,
case when amount_un = '%'  then 'MG' else null end as numerator_unit, 
denominator_val, denominator_un, pck_size
from (
select pfc, descr_prod,descr_pck, strg_unit as amount_val, strg_meas as amount_un, vl_wg_unit as denominator_val,  vl_wg_meas as denominator_un, pck_size
 from france_march_21_delta where strg_meas = '%' and  vl_wg_meas is null
 ) a 
union
select pfc, descr_prod,descr_pck, strg_unit as amount_val, strg_meas as amount_un, null::float as numerator_val, null::varchar as numerator_unit,
vl_wg_unit as denominator_val,  vl_wg_meas as denominator_un, pck_size
 from france_march_21_delta 
 where  pfc not in ( select pfc from  france_march_21_delta where strg_meas = '%') 
;
 
update ds_start set  amount_val = null   ,  amount_un = null
where numerator_unit is not null;
update ds_start set  denominator_un = 'ML'
where numerator_unit is not null and denominator_un is null;
update ds_start set amount_un = 'MCG' where amount_un = 'Y';

drop table if exists ds_start_1;
create table ds_start_1 as (
select pfc, descr_prod,descr_pck,
null::float as amount_val, null::varchar as amount_un, 
amount_val*denominator_val as nominator_val, amount_un as numerator_unit,
denominator_val, denominator_un, pck_size
from ds_start
where amount_val is not null and denominator_val is not null
and descr_pck ~ '((\.)?\d+(\s)?MG|MU|ME|MCG|K|G|Y|IU(\s)?)(\/)((1)?(\s)?ML|G)'
union
select pfc,descr_prod,descr_pck,null::float as amount_val, null::varchar as amount_un,
amount_val*cast(doses as float) as numerator_val, amount_un as  numerator_unit,
denominator_val,denominator_un, pck_size
from 
(
select pfc,descr_prod,descr_pck,amount_val,amount_un,numerator_val,numerator_unit,denominator_val,denominator_un,
substring (substring(descr_pck, '\d+D'),'\d+') as doses, pck_size
from ds_start
where amount_val is not null and denominator_val is not null
and descr_pck ~ '((\.)?\d+(\s)?MG|MU|ME|MCG|Y|K|G|IU)((\s)?(\/)(\s)?DOS)'
) a 
union
select pfc, descr_prod,descr_pck,
null::float as amount_val, null::varchar as amount_un, 
amount_val*denominator_val as nominator_val, amount_un as numerator_unit,
denominator_val, denominator_un, pck_size
from ds_start
where amount_val is not null and denominator_val is not null
and not descr_pck ~ '((\.)?\d+(\s)?MG|MU|ME|MCG|Y|K|G|IU)(\s)?(\/)' and descr_pck ~ '(1(\s)?ML)'
);

drop table if exists ds_start_2;
create table  ds_start_2 as (
select pfc,descr_prod,descr_pck,null::float as amount_val, null::varchar as amount_un,
(amount_val/doses)*denominator_val  as numerator_val, amount_un as  numerator_unit,
denominator_val,denominator_un, pck_size
from (
select pfc,descr_prod,descr_pck,amount_val,amount_un,numerator_val,numerator_unit,denominator_val,denominator_un,
cast (trim (substring (descr_pck, '\/(\d+(ML|MG|G))'),'ML|MG|G') as float) as doses, pck_size
from ds_start 
where pfc not in ( select pfc from ds_start_1) and amount_val is not null and denominator_val is not null
and descr_pck ~ '(\/)'
) a 
 where doses is not null
union
select  pfc,descr_prod,descr_pck,null::float as amount_val, null::varchar as amount_un,
amount_val  as numerator_val, amount_un as  numerator_unit,
denominator_val,denominator_un, pck_size
from ds_start 
where pfc not in ( select pfc from ds_start_1) and amount_val is not null and denominator_val is not null and not  descr_pck ~ '(\/)'
);

drop table if exists ds_stage_1;
create table ds_stage_1 as (
select pfc,descr_prod,descr_pck,null::float as amount_val, null::varchar as amount_un,
amount_val as numerator_val, amount_un as  numerator_unit,
denominator_val,denominator_un, pck_size
 from ds_start
where pfc not in ( select pfc from ds_start_1) and pfc not in ( select pfc from ds_start_2)
and  amount_val is not null and denominator_val is not null  
union
select * 
 from ds_start
where pfc not in ( select pfc from ds_start_1) and pfc not in ( select pfc from ds_start_2) and not ( amount_val is not null and denominator_val is not null  )
union
select * from ds_start_1
union
select * from ds_start_2
);

truncate table ds_stage;
with a as (
select a.pfc as drug_concept_code, b.concept_code as ingredient_concept_code,a.descr_prod, amount_val as amount_value, amount_un as amount_unit , numerator_val as numerator_value, numerator_unit, denominator_val as denominator_value, denominator_un as denominator_unit, cast (pck_size as smallint)  as box_size
 from internal_relationship_stage c
join ds_stage_1 a on a.pfc = c.concept_code_1
join drug_concept_stage b on b.concept_code = c.concept_code_2 and b.concept_class_id = 'Ingredient'
)
insert into ds_stage select * from a;

delete from ds_stage where drug_concept_code in (select drug_concept_code from ds_stage where amount_value is  null and numerator_value is  null); 
update ds_stage set box_size = null where box_size ='1';

--fill RLC
--Ingredients
DROP TABLE IF EXISTS relationship_ingrdient;
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

WHERE 
	a.concept_class_id = 'Ingredient'
	and c.standard_concept ='S' 
	and c.vocabulary_id in ('RxNorm', 'RxNorm Extension');




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

 -- unit update in rtc
insert into relationship_to_concept
select a.* from  
(select  d.concept_code, d.vocabulary_id,  o.concept_id_2, o.precedence, cast (o.convertion_factor as float)  as convertion_factor
from drug_concept_stage d
join old_rtc o on upper(d.concept_name)=upper(o.concept_name)
where concept_class_id  in ('Unit')
and o.concept_name is  not null
)a 
left join 
(select a.* from drug_concept_stage d
join relationship_to_concept a on a.concept_code_1 = d.concept_code
where concept_class_id = 'Unit') b on a.concept_id_2 = b.concept_id_2
where b.concept_code_1 is null
and a.concept_id_2 !=0;

--fill irc dose form with grr mapping + manual insert
insert into relationship_to_concept 
select distinct d.concept_code,d.vocabulary_id, a.concept_id, a.precedence,  null::float as conversion_factor
from drug_concept_stage d
join forms b on upper(d.concept_name) = upper (b.concept_name)
join dev_grr.aut_form_1 a on a.concept_code = b.concept_code 
join devv5.concept c on a.concept_id = c.concept_id
where d.concept_class_id = 'Dose Form'
and a.concept_id !=0;

insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('QHA','DA_France',19011167,1,null);--Nasal Spray
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('QHA','DA_France',19082165,2,null);--Nasal Solution
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('QHA','DA_France',19095977,3,null);--	Nasal Suspension
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('ZYY','DA_France',19082573,1,null);--Oral Tablet
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('ZYY','DA_France',19082168,2,null);--	Oral Capsule
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('ZYY','DA_France',19082170,3,null);--Oral Solution
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('ZYY','DA_France',19082191,4,null);--Oral Suspension
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('ZYY','DA_France',19082103,5,null);--	Injectable Solution
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('ZYY','DA_France',19082104,6,null);--Injectable Suspension
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('ZYY','DA_France',46234469,7,null);--	Injection
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('ZYX','DA_France',19082573,1,null);--Oral Tablet
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('ZYX','DA_France',19082170,2,null);--Oral Solution
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('ZYX','DA_France',19082191,3,null);--Oral Suspension
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('ZYX','DA_France',19082103,4,null);--Injectable Solution
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('ZYX','DA_France',19082104,5,null);--Injectable Suspension
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('ZYX','DA_France',46234469,6,null);--Injection
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('ZYX','DA_France',19082228,7,null);--	Topical Solution
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('ZYX','DA_France',46234410,8,null);--Topical Suspension
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('ZYX','DA_France',19082224,9,null);--Topical Cream
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('ZYX','DA_France',19082165,10,null);--Nasal Solution
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('ZYX','DA_France',19095977,11,null);--Nasal Suspension
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('ZYX','DA_France',19011167,12,null);--Nasal Spray
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('ZYX','DA_France',19095898,13,null);--Inhalant Solution
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('ZYX','DA_France',19018195,14,null);--Inhalant
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('ZYX','DA_France',19082162,15,null);--Nasal Inhalant
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('ZYX','DA_France',45775491,16,null);--Powder for Oral Solution
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('ZYX','DA_France',45775492,17,null);--Powder for Oral Suspension


update relationship_to_concept set concept_id_2 =  19129634, precedence = 1  where concept_code_1 = 'NGB';

-- ingred with old_rtc eq
/*insert into relationship_to_concept 
select d.concept_code, d.vocabulary_id, o.concept_id_2, o.precedence, cast(o.convertion_factor  as float)  as convertion_factor 
from drug_concept_stage d
left join old_rtc o on upper(d.concept_name)=upper(o.concept_name)
where d.concept_class_id  in ('Ingredient')
and o.concept_name is not null
and o.concept_id_2 !=0;*/

-- 3 concepts as name = name
insert into relationship_to_concept
select b.concept_code, b.vocabulary_id, a.concept_id as concept_id_2, 1::integer as precedence, null::float as concvertion_factor
from devv5.concept a 
join (
select d.concept_code, d.vocabulary_id, d.concept_name, d.concept_class_id  , o.concept_id_2, o.precedence, o.convertion_factor 
from drug_concept_stage d
left join old_rtc o on upper(d.concept_name)=upper(o.concept_name)
where d.concept_class_id  in ('Ingredient')
and o.concept_name is null
) b on a.concept_name = b.concept_name and a.concept_class_id = 'Ingredient' and a.standard_concept = 'S'
 where a.concept_id !=0;
--manual ingredient create
drop table if exists manual_map_ingr;
create table manual_map_ingr
(
concept_name varchar (255),
target_id integer);
 
--filing manual_map_ingr
insert into manual_map_ingr (concept_name, target_id) values ('NIT COMB',0); 
insert into manual_map_ingr (concept_name, target_id) values ('VANILLA PLANIFOLIA',1594208); 
insert into manual_map_ingr (concept_name, target_id) values ('PADINA PAVONICA',43526893); 
insert into manual_map_ingr (concept_name, target_id) values ('ANTI-PARASITIC',0); 
insert into manual_map_ingr (concept_name, target_id) values ('LISTEA CUBEBA',0); 
insert into manual_map_ingr (concept_name, target_id) values ('BETOXYCAINE',0); 
insert into manual_map_ingr (concept_name, target_id) values ('DYSMENORRHEA RELIEF',0); 
insert into manual_map_ingr (concept_name, target_id) values ('TOPICAL ANALGESICS',0); 
insert into manual_map_ingr (concept_name, target_id) values ('THROAT LOZENGES',0); 
insert into manual_map_ingr (concept_name, target_id) values ('ANTACIDS',0); 
insert into manual_map_ingr (concept_name, target_id) values ('OXAFLOZANE',0); 
insert into manual_map_ingr (concept_name, target_id) values ('ALKYLGLYCEROLS (UNSPECIFIED)',0); 
insert into manual_map_ingr (concept_name, target_id) values ('MONOPHOSPHOTHIAMINE',19137312); 
insert into manual_map_ingr (concept_name, target_id) values ('ETHYL ORTHOFORMATE',0);
insert into manual_map_ingr (concept_name, target_id) values ('BISCOUMACETATE',0);
insert into manual_map_ingr (concept_name, target_id) values ('TAMUS COMMUNIS',0);
insert into manual_map_ingr (concept_name, target_id) values ('N-ACETYLASPARTIC ACID',0);
insert into manual_map_ingr (concept_name, target_id) values ('PRANOSAL',43014110);
insert into manual_map_ingr (concept_name, target_id) values ('BACOPA MONIERI',40221311);
insert into manual_map_ingr (concept_name, target_id) values ('BIORESMETHRIN',0);
insert into manual_map_ingr (concept_name, target_id) values ('SULTAMICILLIN',0);
insert into manual_map_ingr (concept_name, target_id) values ('METHOPRENE',0);
insert into manual_map_ingr (concept_name, target_id) values ('LILIUM CANDIDUM',42899405);
insert into manual_map_ingr (concept_name, target_id) values ('BROPARESTROL',0);
insert into manual_map_ingr (concept_name, target_id) values ('ANTI-PARASITIC',0);
insert into manual_map_ingr (concept_name, target_id) values ('PROPANOCAINE',0);
insert into manual_map_ingr (concept_name, target_id) values ('PARACETAMOL',1125315);
insert into manual_map_ingr (concept_name, target_id) values ('P-AMINOBENZOIC ACID',19018384);
insert into manual_map_ingr (concept_name, target_id) values ('ENOXOLONE',42544020);
insert into manual_map_ingr (concept_name, target_id) values ('LEVOTHYROXINE SODIUM',1501700);
insert into manual_map_ingr (concept_name, target_id) values ('FONDAPARINUX SODIUM',1315865);
insert into manual_map_ingr (concept_name, target_id) values ('ENOXAPARIN SODIUM',1301025);
insert into manual_map_ingr (concept_name, target_id) values ('COLECALCIFEROL',19095164);
insert into manual_map_ingr (concept_name, target_id) values ('ALENDRONIC ACID',1557272);
insert into manual_map_ingr (concept_name, target_id) values ('ALUMINIUM',42898412);
insert into manual_map_ingr (concept_name, target_id) values ('IPRATROPIUM BROMIDE',1112921); 
insert into manual_map_ingr (concept_name, target_id) values ('BECLOMETASONE',1115572);
insert into manual_map_ingr (concept_name, target_id) values ('CEFRADINE',1786842);
insert into manual_map_ingr (concept_name, target_id) values ('CICLOSPORIN',19010482);
insert into manual_map_ingr (concept_name, target_id) values ('ACETYLSALICYLIC ACID',1112807);
insert into manual_map_ingr (concept_name, target_id) values ('CLOFIBRIC ACID',1598658);
insert into manual_map_ingr (concept_name, target_id) values ('FLUOCINOLONE ACETONIDE',996541);
insert into manual_map_ingr (concept_name, target_id) values ('FOLLICLE-STIMULATING HORMONE',1588712);
insert into manual_map_ingr (concept_name, target_id) values ('ETHINYLESTRADIOL',1549786);
insert into manual_map_ingr (concept_name, target_id) values ('NORETHISTERONE',19050090);
insert into manual_map_ingr (concept_name, target_id) values ('LUTEINISING HORMONE',1589795);
insert into manual_map_ingr (concept_name, target_id) values ('HYALURONIC ACID',787787);
insert into manual_map_ingr (concept_name, target_id) values ('SALBUTAMOL',1154343);
insert into manual_map_ingr (concept_name, target_id) values ('PYRIDOXINE CLOFIBRATE',19005046);
insert into manual_map_ingr (concept_name, target_id) values ('TIOTROPIUM BROMIDE',1106776);
insert into manual_map_ingr (concept_name, target_id) values ('URSODEOXYCHOLIC ACID',988095);


--insert manual ingredient to rtc
insert into relationship_to_concept 
select a.concept_code,a.vocabulary_id,b.target_id, null::integer , null::integer
from drug_concept_stage a 
join manual_map_ingr b  on a.concept_name = b.concept_name
where b.target_id !=0; 


-- insert Brand Name to rtc 
insert into relationship_to_concept
select a.concept_code, a.vocabulary_id, cast (b.to_concept as integer) as concept_id_2, null::integer , null::integer
from drug_concept_stage a 
join brand_name_mapping b on a.concept_name = b.concept_name
where to_concept not in ('d','device','supplier')
and to_concept !='0';





-- insert Supplier to rtc 
insert into relationship_to_concept
select a.concept_code, a.vocabulary_id, b.concept_id, null::integer, null::numeric
from (
select a.concept_name, a.concept_code, a.vocabulary_id,  b.concept_id 
from drug_concept_stage a 
join supplier_mapp_auto b on a.concept_name = b.source_name
union
select a.concept_name, a.concept_code,a.vocabulary_id, b.to_concept 
from drug_concept_stage a 
join supplier_manual b on a.concept_name = b.concept_name 
) a 
join concept b on a.concept_id = b.concept_id
where b.concept_class_id != 'Brand Name'
and b.concept_id!=0;

insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence)
select distinct concept_code as concept_code_1, 'DA_France', concept_id as concept_id_2, precedence
from dev_grr.drug_concept_stage 
join dev_grr.r_t_c_all_bckp using(concept_name,concept_class_id)
where concept_class_id = 'Dose Form' 
and concept_code in (select distinct i.concept_code_2 from dev_da_france_2.internal_relationship_stage i
join dev_da_france_2.drug_concept_stage d on i.concept_code_2 = d.concept_code and d.concept_class_id = 'Dose Form'
join devv5.concept c on c.concept_code = d.concept_code and c.vocabulary_id = 'NFC'
where concept_code_2 not in (select concept_code_1 from dev_da_france_2.relationship_to_concept)
and d.concept_code not in (select concept_code_1 from  relationship_to_concept))
;










--delete duplicates
DELETE FROM relationship_to_concept a
WHERE a.ctid <> (SELECT min(b.ctid)
                 FROM   relationship_to_concept b
                 WHERE  a.concept_code_1 = b.concept_code_1 and a.concept_id_2 = b.concept_id_2);



--delete from irs when marketed without dosage
delete
from internal_relationship_stage
where concept_code_1 in
(
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
and concept_code_2 in (
select concept_code_2
from internal_relationship_stage a 
join drug_concept_stage b on a.concept_code_2 = b.concept_code
where b.concept_class_id = 'Supplier'
and concept_code_1 in (
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



---------------------------------------
--post proccesing
---------------------------------------


drop table if exists map_drug_stage_1;
create table map_drug_stage_1 as (
select  a.concept_code as from_code, b.to_id
from drug_concept_stage a 
join map_drug b on a.concept_code = b.from_code
join concept c on b.to_id = c.concept_id
where a.concept_code not in (
select concept_code from map_null
union
select concept_code from map_ingr_only
union
select concept_code from map_vacc
)
union
select concept_code,to_id from map_null
union
select concept_code,to_id from map_ingr_only
union
select concept_code,to_id from map_vacc
union 
select * from first_map_drug
union 
select pfc, drug_id from map_viol
);
/*
insert into  relationship_to_concept	(concept_code_1,
	vocabulary_id_1,
	concept_id_2)
select distinct from_code,'DA_France', to_id  from 
map_drug_stage_1
join drug_concept_stage s on from_code = s.concept_code
join devv5.concept c on c.concept_id = to_id
 where from_code not in(select concept_code_1 from relationship_to_concept);
*/










drop table if exists new_names; 
create table new_names (drug_concept_code varchar, new_name varchar);
insert into new_names select * from (
with a as
(
  select ds.drug_concept_code,  concat ( d2.concept_name,' ', ds.amount_value, ' ', ds.amount_unit) as comp_name from ds_stage ds
  join drug_concept_stage d2 on ds.ingredient_concept_code = d2.concept_code
join drug_concept_stage d1 on d1.concept_code = ds.drug_concept_code
 where numerator_value is null )
select distinct drug_concept_code, string_agg (comp_name, '/') over (partition by drug_concept_code order by comp_name asc) from a) as s;

insert into new_names select * from (
with a as
(
  select ds.drug_concept_code, case when denominator_value is not null then  concat ( d2.concept_name,' ', ds.numerator_value*ds.denominator_value, ' ', ds.numerator_unit,'/', denominator_unit)  when denominator_value is null then concat (d2.concept_name,' ', ds.numerator_value, ' ', ds.numerator_unit,'/', denominator_unit) end as comp_name from ds_stage ds
  join drug_concept_stage d2 on ds.ingredient_concept_code = d2.concept_code
join drug_concept_stage d1 on d1.concept_code = ds.drug_concept_code 

 where amount_value is null 
)
select distinct drug_concept_code, string_agg (comp_name, ' / ')  over (partition by drug_concept_code order by comp_name asc) from a) as s;
;

drop table if exists name_dup ;                
create table name_dup as (select distinct first_value (a.new_name) over (partition by a.drug_concept_code order by length (a.new_name) desc, a.new_name asc) as cor, drug_concept_code from dev_da_france_2.new_names a
);
delete from name_dup a
where a.ctid <> (SELECT min(b.ctid)
                 FROM   dev_da_france_2.name_dup b
                 WHERE  a.drug_concept_code = b.drug_concept_code
                 and a.cor = b.cor);




drop table  if exists a;
create table a as (
select distinct n.drug_concept_code as code, concat(ds.denominator_value, ' ', ds.denominator_unit, ' ', n.cor) as d from name_dup n
join ds_stage ds on n.drug_concept_code = ds.drug_concept_code and ds.denominator_value is not null
);


update name_dup x
set cor = (select distinct d from a where code = x.drug_concept_code)
where drug_concept_code in (select distinct drug_concept_code from a where code = x.drug_concept_code);
drop table  if exists d;

create table d as (
select distinct n.drug_concept_code as code, concat(n.cor, ' ', d.concept_name) as d from name_dup n
join internal_relationship_stage i on n.drug_concept_code = i.concept_code_1
join drug_concept_stage d on i.concept_code_2 = d.concept_code and d.concept_class_id = 'Dose Form');
update name_dup x
set cor = (select distinct d from d where code = x.drug_concept_code)
where drug_concept_code in (select distinct drug_concept_code from d where code = x.drug_concept_code);


drop table  if exists b;
create table b as (
select ds.drug_concept_code as code,  concat ( cor, ' ','[', d3.concept_name,']') as comp_name from name_dup ds
join internal_relationship_stage i on ds.drug_concept_code = i.concept_code_1
join drug_concept_stage d3 on i.concept_code_2 = d3.concept_code and d3.concept_class_id = 'Brand Name');

update name_dup x
set cor = (select distinct comp_name from b where code = x.drug_concept_code)
where drug_concept_code in (select distinct code from b where code = x.drug_concept_code);

drop table  if exists s;
create table s as ( 
select distinct n.drug_concept_code as code, concat(n.cor, ' ','by', ' ', d.concept_name) as d from name_dup n
join internal_relationship_stage i on n.drug_concept_code = i.concept_code_1
join drug_concept_stage d on i.concept_code_2 = d.concept_code and d.concept_class_id = 'Supplier');
update name_dup x
set cor = (select distinct d from s where code = x.drug_concept_code)
where drug_concept_code in (select distinct drug_concept_code from s where code = x.drug_concept_code);

drop table  if exists c;
create table c as (  select ds.drug_concept_code as code,  concat ( cor, '', ' Box of ', a.pck_size) as comp_name from name_dup ds
join FRANCE_march_21_1 a on a.pfc = ds.drug_concept_code and a.pck_size !='1'
where ds.drug_concept_code in (select code from a));
update name_dup x
set cor = (select distinct comp_name from c where code = x.drug_concept_code)
where drug_concept_code in (select distinct code from c where code = x.drug_concept_code);




update name_dup x
set cor = (select distinct comp_name from c where code = x.drug_concept_code)
where drug_concept_code in (select distinct code from c where code = x.drug_concept_code);
update name_dup x
set cor = (
SELECT  CASE 
		WHEN LENGTH(TRIM(cor)) > 255
			THEN TRIM(SUBSTR(TRIM(cor), 1, 252)) || '...'
		ELSE TRIM(cor) end from name_dup c where c.drug_concept_code = x.drug_concept_code)
		where drug_concept_code in (select distinct drug_concept_code from name_dup c where c.drug_concept_code = x.drug_concept_code);

update drug_concept_stage x
set concept_name = (select distinct cor from name_dup where drug_concept_code = x.concept_code)
where concept_code in (select distinct drug_concept_code from name_dup where drug_concept_code = x.concept_code);






update drug_concept_stage
set concept_name =  regexp_replace(concept_name, 'Box of \y1\y', '');


update drug_concept_stage x
set concept_name = (
SELECT  CASE 
		WHEN LENGTH(TRIM(concept_name)) > 255
			THEN TRIM(SUBSTR(TRIM(concept_name), 1, 252)) || '...'
		ELSE TRIM(concept_name) end from drug_concept_stage c where c.concept_code = x.concept_code)
		where concept_code in (select distinct concept_code from drug_concept_stage c where c.concept_code = x.concept_code);
		
--insert manual mapping
insert into relationship_to_concept_manual(source_attr_name, source_attr_concept_class,target_concept_id, target_concept_code, target_concept_name )
 select d.concept_name,'Drug Product', to_id, c.concept_code, c.concept_name from vacc_ins_mapped 
 join devv5.concept c on to_id = concept_id 
 join drug_concept_stage d on pfc =  d.concept_code
 where to_id!=0 and d.concept_name not in (select source_attr_name from  relationship_to_concept_manual);
