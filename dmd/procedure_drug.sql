/*
CREATE INDEX drug_cnc_st_l_ix ON drug_concept_stage (lower (concept_name));
CREATE INDEX drug_cnc_st_ix ON drug_concept_stage ( concept_name);
CREATE INDEX drug_cnc_st_c_ix ON drug_concept_stage ( concept_code);
exec DBMS_STATS.GATHER_TABLE_STATS (ownname => USER, tabname  => 'drug_concept_stage', cascade  => true);
*/
/*
--work with manual table 
drop table ingr_to_ingr;
create table ingr_to_ingr (concept_code_1	varchar (200),
concept_name_1 varchar (200),	insert_id_1 int,  concept_code_2 varchar (200),	concept_name_2 varchar (200),	insert_id_2 int , REL_TYPE varchar (20),	invalid_reason varchar (20))
;
WbImport -file=C:/mappings/DM+D/ingred_to_ingred_FIN_Lena.txt
         -type=text
         -table=ingr_to_ingr
         -encoding="ISO-8859-15"
         -header=true
         -decode=false
         -dateFormat="yyyy-MM-dd"
         -timestampFormat="yyyy-MM-dd HH:mm:ss"
         -delimiter='\t'
         -decimal=.
         -fileColumns=concept_code_1, concept_name_1  ,	insert_id_1  ,  concept_code_2  ,	concept_name_2 ,	insert_id_2   , REL_TYPE  ,	invalid_reason
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=false
         -continueOnError=false
         -batchSize=1000;
*/
DROP SEQUENCE IF EXISTS new_seq;
CREATE sequence new_seq increment BY 1 start
	WITH 1 cache 20;

--add OMOP codes to new ingredients
UPDATE ingr_to_ingr
SET concept_code_2 = 'OMOP' || nextval('new_seq')
WHERE concept_code_2 IS NULL
	AND concept_name_2 IS NOT NULL;

INSERT INTO ingr_to_ingr (
	concept_code_1,
	concept_name_1
	)
SELECT DISTINCT concept_code_2,
	concept_name_2
FROM ingr_to_ingr
WHERE concept_code_2 LIKE 'OMOP%';

--Non drug definition - several steps including different criteria for non-drug definition	
--BASED ON NAMES, AND absence of form info

 --all branded drugs to clical drugs, then use in ds_stage, because ds_stage...
DROP TABLE IF EXISTS branded_to_clinical;
CREATE TABLE branded_to_clinical AS
SELECT DISTINCT a.concept_code AS concept_code_1,
	a.concept_name AS concept_name_1,
	cs.concept_code AS concept_code_2,
	cs.concept_name AS concept_name_2
FROM drug_concept_stage a
JOIN concept c ON a.concept_code = c.concept_code
	AND c.vocabulary_id = 'SNOMED'
	AND a.concept_class_id LIKE 'Branded Drug%'
JOIN concept_relationship r ON r.concept_id_1 = c.concept_id
JOIN concept d ON r.concept_id_2 = d.concept_id
	AND d.vocabulary_id = 'SNOMED'
JOIN drug_concept_stage cs ON cs.concept_code = d.concept_code
	AND cs.concept_class_id LIKE 'Clinical Drug%';

--duplicates due to ONLY DEPRECATED to NON-DEPRECATED DRUGS relationship??
--let it be for now 
DELETE
FROM branded_to_clinical a
WHERE EXISTS (
		SELECT 1
		FROM (
			SELECT A.concept_code_1,
				A.concept_code_2
			FROM branded_to_clinical A
			JOIN DRUG_CONCEPT_STAGE C ON A.concept_code_1 = C.concept_code
			JOIN DRUG_CONCEPT_STAGE B ON A.concept_code_2 = B.concept_code
				AND b.concept_class_id LIKE 'Clinical Drug%'
			WHERE B.invalid_reason IS NOT NULL
				AND C.invalid_reason IS NULL
			) b
		WHERE a.concept_code_1 = b.concept_code_1
			AND a.concept_code_2 = b.concept_code_2
		);

--Packs 1 step
DROP TABLE IF EXISTS clin_dr_pack_to_clin_dr_box;
CREATE TABLE clin_dr_pack_to_clin_dr_box AS

--to determine packs we can try to find specific relationship patterns
SELECT DISTINCT a.concept_code AS concept_code_1,
	a.concept_name AS concept_name_1,
	cs.concept_code AS concept_code_2,
	cs.concept_name AS concept_name_2
FROM drug_concept_stage a
JOIN concept c ON a.concept_code = c.concept_code
	AND c.vocabulary_id = 'SNOMED'
JOIN concept_relationship r ON r.concept_id_1 = c.concept_id
JOIN concept d ON r.concept_id_2 = d.concept_id
	AND d.vocabulary_id = 'SNOMED'
JOIN drug_concept_stage cs ON cs.concept_code = d.concept_code
	AND a.insert_id IN (14)
	AND cs.insert_id IN (14)
	AND a.concept_code != cs.concept_code
	AND a.concept_class_id = cs.concept_class_id
--remove non-drugs except '9149411000001109' (is a drug)
JOIN (
	SELECT concept_code_1
	FROM (
		SELECT DISTINCT a.concept_code AS concept_code_1,
			a.concept_name AS concept_name_1,
			cs.concept_code AS concept_code_2
		FROM drug_concept_stage a
		JOIN concept c ON a.concept_code = c.concept_code
			AND c.vocabulary_id = 'SNOMED'
		JOIN concept_relationship r ON r.concept_id_1 = c.concept_id
		JOIN concept d ON r.concept_id_2 = d.concept_id
			AND d.vocabulary_id = 'SNOMED'
		JOIN drug_concept_stage cs ON cs.concept_code = d.concept_code
			AND a.insert_id = 14
			AND cs.insert_id = 14
			AND a.concept_code != cs.concept_code
		WHERE RELATIONSHIP_ID = 'Is a'
			AND NOT a.concept_name ~ 'bandage|dressing'
		) AS s0
	GROUP BY concept_code_1
	HAVING count(1) > 1
	
	UNION ALL
	
	SELECT '9149411000001109' --one who have 1 component but still is a pack
	) x ON x.concept_code_1 = a.concept_code;

--but we still have to create packs for clinical Drugs, 
--another condition for pack definition
--actually the name is wrong, it's not a boxes but packs
DROP TABLE IF EXISTS dr_to_clin_dr_box;
CREATE TABLE dr_to_clin_dr_box AS
SELECT DISTINCT a.concept_code,
	a.concept_name,
	a.concept_class_id,
	a.invalid_reason, /*cs.concept_code, cs.concept_name, cs.concept_class_id, 
bc.concept_code_2, bc.concept_name_2  ,*/
	b.concept_code_2,
	b.concept_name_2
FROM drug_concept_stage a
LEFT JOIN branded_to_clinical bc ON bc.concept_code_1 = a.concept_code
JOIN concept c ON (
		a.concept_code = c.concept_code
		OR bc.concept_code_2 = c.concept_code
		)
	AND c.vocabulary_id = 'SNOMED'
JOIN concept_relationship r ON r.concept_id_1 = c.concept_id
JOIN concept d ON r.concept_id_2 = d.concept_id
	AND d.vocabulary_id = 'SNOMED'
JOIN drug_concept_stage cs ON cs.concept_code = d.concept_code
	AND a.insert_id IN (
		11,
		12,
		13
		)
	AND cs.insert_id IN (
		14,
		15
		)
	AND a.concept_code != cs.concept_code
JOIN clin_dr_pack_to_clin_dr_box b ON b.concept_code_1 = cs.concept_code
	OR b.concept_code_1 = bc.concept_code_2
WHERE (
		SELECT count(*)
		FROM regexp_matches(a.concept_name, 'tablet|capsul', 'g')
		) > 1
	AND NOT a.concept_name ~ 'bandage|dressing';

--clinical and branded
DROP TABLE IF EXISTS dr_to_clin_dr_box_0;
CREATE TABLE dr_to_clin_dr_box_0 AS
SELECT concept_code,
	concept_name,
	concept_code_2,
	concept_name_2
FROM dr_to_clin_dr_box

UNION

SELECT concept_code_1,
	concept_name_1,
	concept_code_2,
	concept_name_2
FROM clin_dr_pack_to_clin_dr_box;

DROP TABLE IF EXISTS dr_pack_to_clin_dr_box_full;
CREATE TABLE dr_pack_to_clin_dr_box_full AS
SELECT a.concept_code_1,
	a.concept_name_1,
	b.concept_code_2,
	b.concept_name_2
FROM branded_to_clinical a
JOIN dr_to_clin_dr_box_0 b ON a.concept_code_2 = b.concept_code

UNION

SELECT concept_code,
	concept_name,
	concept_code_2,
	concept_name_2
FROM dr_to_clin_dr_box_0;--further this Packs table will be modified using non-drugs definition

--manual update of Packs tables 
DROP SEQUENCE IF EXISTS new_seq;
CREATE sequence new_seq increment BY 1 start
	WITH 200 cache 20;

DROP TABLE IF EXISTS pack_drug_to_code_2_2_seq;
CREATE TABLE pack_drug_to_code_2_2_seq AS
SELECT DISTINCT drug_new_name,
	drug_code
FROM pack_drug_to_code_2_2
WHERE drug_code IS NULL;

UPDATE pack_drug_to_code_2_2_seq
SET drug_code = 'OMOP' || nextval('new_seq');

UPDATE pack_drug_to_code_2_2 b
SET drug_code = CASE 
		WHEN b.drug_code IS NULL
			THEN (
					SELECT a.drug_code
					FROM pack_drug_to_code_2_2_seq a
					WHERE a.drug_new_name = b.drug_new_name
					)
		ELSE b.drug_code
		END;

UPDATE pack_drug_to_code_2_2
SET pack_name = replace(pack_name, '"', '');--for now remain pack_drug_to_code_2_2 as manual without rebuilding

--Box to drug - 1 step
DROP TABLE IF EXISTS box_to_drug;
CREATE TABLE box_to_drug AS
--select count (1) from (
SELECT DISTINCT a.concept_code AS concept_code_1,
	a.concept_name AS concept_name_1,
	a.concept_class_id AS concept_class_id_1,
	cs.concept_code AS concept_code_2,
	cs.concept_name AS concept_name_2,
	cs.concept_class_id AS concept_class_id_2
FROM drug_concept_stage a
JOIN concept c ON a.concept_code = c.concept_code
	AND c.vocabulary_id = 'SNOMED'
	AND a.concept_class_id LIKE '%Box%'
JOIN concept_relationship r ON r.concept_id_1 = c.concept_id
JOIN concept d ON r.concept_id_2 = d.concept_id
	AND d.vocabulary_id = 'SNOMED'
JOIN drug_concept_stage cs ON cs.concept_code = d.concept_code
	AND cs.concept_class_id LIKE '%Drug%'
	AND cs.concept_class_id NOT LIKE '%Box%'
WHERE (
		cs.invalid_reason IS NULL
		AND a.invalid_reason IS NULL
		OR cs.invalid_reason IS NOT NULL
		AND a.invalid_reason IS NOT NULL
		) -- exactly what those delete did. not sure if it works well with the deprecated to deprecated
	;

--delete invalid concepts, they give incorrect relationships
/*-- added condition to a previous query, so shouldn't needed now
DELETE from box_to_drug a 
where exists (select 1 from 
(
SELECT A.concept_code_1, A.concept_code_2 FROM box_to_drug A
JOIN DRUG_CONCEPT_STAGE C ON A.concept_code_1 = C.concept_code
JOIN DRUG_CONCEPT_STAGE B ON A.concept_code_2 = B.concept_code and b.concept_class_id like '%Drug%'
WHERE B.invalid_reason IS NOT NULL AND C.invalid_reason IS NULL
) b where a.concept_code_1 = b.concept_code_1 and a.concept_code_2 = b.concept_code_2)
;
*/
--mofify table with additional fields with box size, amount
ALTER TABLE box_to_drug ADD box_amount VARCHAR(250);

--define that by name differences
UPDATE box_to_drug
SET box_amount = replace(concept_name_1, concept_name_2 || ' ', '');

ALTER TABLE box_to_drug ADD box_size FLOAT,
	ADD amount_unit VARCHAR(20),
	ADD amount_value FLOAT;

--define that by name difference
--fill box_size, amount_unit, amount_value
UPDATE box_to_drug
SET amount_value = substring(box_amount, '[[:digit:].]+')::FLOAT
WHERE substring(box_amount, '([[:digit:].]+ (ml|gram|litre|m|dose))') = box_amount
	AND concept_code_1 NOT IN (
		SELECT concept_code_1
		FROM dr_pack_to_clin_dr_box_full
		);

UPDATE box_to_drug
SET amount_unit = regexp_replace(box_amount, '[[:digit:].]+ ', '', 'g')
WHERE substring(box_amount, '([[:digit:].]+ (ml|gram|litre|m|dose))') = box_amount
	AND concept_code_1 NOT IN (
		SELECT concept_code_1
		FROM dr_pack_to_clin_dr_box_full
		);

UPDATE box_to_drug
SET box_size = substring(box_amount, '^[[:digit:].]+')::FLOAT
WHERE substring(box_amount, '[[:digit:].]+ .*') = box_amount
	AND NOT box_amount ~ '(ml|gram|litre|m|dose)'
	AND amount_value IS NULL
	AND amount_unit IS NULL
	AND concept_code_1 NOT IN (
		SELECT concept_code_1
		FROM dr_pack_to_clin_dr_box_full
		);

UPDATE box_to_drug
SET box_size = substring(substring(box_amount, '[[:digit:].]+ x'), '[[:digit:]]+')::FLOAT,
	amount_value = substring(box_amount, 'x ([[:digit:].]+)')::FLOAT,
	amount_unit = substring(box_amount, 'x [[:digit:].]+ ([[:alpha:]]+)')
WHERE box_amount ~ '[[:digit:].]+ x [[:digit:].]+ [[:alpha:]]+'
	AND box_amount NOT LIKE '%unit doses%'
	AND amount_value IS NULL
	AND amount_unit IS NULL
	AND box_size IS NULL
	AND concept_code_1 NOT IN (
		SELECT concept_code_1
		FROM dr_pack_to_clin_dr_box_full
		);

--some boxe sizes weren't parsed, so make manual work
UPDATE box_to_drug
SET amount_unit = 'ml',
	amount_value = 4,
	box_size = 56
WHERE concept_code_1 = '14791211000001106'
	AND concept_code_2 = '14791111000001100';

UPDATE box_to_drug
SET box_size = 10
WHERE concept_code_1 = '31485711000001104'
	AND concept_code_2 = '31485411000001105';

UPDATE box_to_drug
SET box_size = 60
WHERE concept_code_1 = '15522511000001104'
	AND concept_code_2 = '15522411000001103';

UPDATE box_to_drug
SET amount_unit = 'ml',
	amount_value = 5,
	box_size = 56
WHERE concept_code_1 = '22768811000001109'
	AND concept_code_2 = '22768711000001101';

UPDATE box_to_drug
SET box_size = 50
WHERE concept_code_1 = '5987411000001103'
	AND concept_code_2 = '5987311000001105';

UPDATE box_to_drug
SET amount_unit = 'ml',
	amount_value = 5,
	box_size = 56
WHERE concept_code_1 = '4125211000001106'
	AND concept_code_2 = '4125111000001100';

UPDATE box_to_drug
SET box_size = 7
WHERE concept_code_1 = '3954511000001106'
	AND concept_code_2 = '3954411000001107';

UPDATE box_to_drug
SET amount_unit = 'ml',
	amount_value = 3,
	box_size = 20
WHERE concept_code_1 = '5186211000001101'
	AND concept_code_2 = '5185911000001103';

UPDATE box_to_drug
SET amount_unit = 'ml',
	amount_value = 3,
	box_size = 2
WHERE concept_code_1 = '5186011000001106'
	AND concept_code_2 = '5185911000001103';

--special pattern for Drug Pack, ( digit x digit)
UPDATE box_to_drug
SET box_size = substring(box_amount, '(\d+) x \(')::FLOAT
WHERE concept_code_1 IN (
		SELECT concept_code_1
		FROM dr_pack_to_clin_dr_box_full
		);

-- that's all for box_to_drug

-- Dose Forms
--full dose form table
DROP TABLE IF EXISTS drug_to_dose_form;
CREATE TABLE drug_to_dose_form AS
--relationship to dose form for Branded Drugs (branded_to_clinical used)
SELECT bc.concept_code_1,
	bc.concept_name_1,
	cs.concept_code,
	cs.concept_name
FROM drug_concept_stage a
JOIN concept c ON a.concept_code = c.concept_code
	AND c.vocabulary_id = 'SNOMED'
JOIN concept_relationship r ON r.concept_id_1 = c.concept_id
JOIN concept d ON r.concept_id_2 = d.concept_id
	AND d.vocabulary_id = 'SNOMED'
JOIN drug_concept_stage cs ON cs.concept_code = d.concept_code
	AND cs.concept_class_id = 'Dose Form'
JOIN branded_to_clinical bc ON concept_code_2 = a.concept_code
WHERE a.concept_class_id != 'Dose Form'

UNION

--relationship to doseform itselef
SELECT a.concept_code,
	a.concept_name,
	cs.concept_code,
	cs.concept_name
FROM drug_concept_stage a
JOIN concept c ON a.concept_code = c.concept_code
	AND c.vocabulary_id = 'SNOMED'
JOIN concept_relationship r ON r.concept_id_1 = c.concept_id
JOIN concept d ON r.concept_id_2 = d.concept_id
	AND d.vocabulary_id = 'SNOMED'
JOIN drug_concept_stage cs ON cs.concept_code = d.concept_code
	AND cs.concept_class_id = 'Dose Form'
WHERE a.concept_class_id != 'Dose Form';

--define forms only for CLinical Drugs??? so why the previous query has two parts then?
--duplicated active forms are choosen by length
DROP TABLE IF EXISTS clin_dr_to_dose_form;
CREATE TABLE clin_dr_to_dose_form AS
SELECT DISTINCT a.concept_code_1,
	a.concept_name_1,
	a.concept_code,
	a.concept_name
FROM (
	SELECT concept_code_1,
		concept_name_1,
		concept_code,
		concept_name,
		length(concept_name) AS lngth
	FROM drug_to_dose_form
	) a
JOIN (
	SELECT concept_code_1,
		concept_name_1,
		max(lngth) AS lngth
	FROM (
		SELECT concept_code_1,
			concept_name_1,
			concept_code,
			concept_name,
			length(concept_name) AS lngth
		FROM drug_to_dose_form
		) AS s0
	GROUP BY concept_code_1,
		concept_name_1
	) b ON a.concept_code_1 = b.concept_code_1
	AND a.concept_name_1 = b.concept_name_1
	AND a.lngth = b.lngth
JOIN drug_concept_stage c ON a.concept_code_1 = c.concept_code
	AND c.concept_class_id = 'Clinical Drug';

--several with the same length
DELETE
FROM clin_dr_to_dose_form
WHERE concept_code_1 = '329850008'
	AND concept_code = '385061003';

DELETE
FROM clin_dr_to_dose_form
WHERE concept_code_1 = '329587009'
	AND concept_code = '385061003';

DELETE
FROM clin_dr_to_dose_form
WHERE concept_code_1 = '329586000'
	AND concept_code = '385061003';;

--pack components with omop codes
--will work, lets remain these OMOP codes as they are
--!!! define how these drug components get there 
INSERT INTO clin_dr_to_dose_form (
	concept_code_1,
	concept_name_1,
	concept_code,
	concept_name
	)
VALUES (
	'OMOP21',
	'Paracetamol 500mg / Phenylephrine 6.1mg / Caffeine 25mg capsules',
	'385049006',
	'Capsule'
	);

INSERT INTO clin_dr_to_dose_form (
	concept_code_1,
	concept_name_1,
	concept_code,
	concept_name
	)
VALUES (
	'OMOP22',
	'Buclizine hydrochloride / Codeine / Paracetamol tablets',
	'385055001',
	'Tablet'
	);

INSERT INTO clin_dr_to_dose_form (
	concept_code_1,
	concept_name_1,
	concept_code,
	concept_name
	)
VALUES (
	'OMOP23',
	'Pholcodine 5mg / Pseudoephedrine 30mg / Paracetamol 500mg capsules',
	'385049006',
	'Capsule'
	);

INSERT INTO clin_dr_to_dose_form (
	concept_code_1,
	concept_name_1,
	concept_code,
	concept_name
	)
VALUES (
	'OMOP24',
	'Pholcodine 5mg / Pseudoephedrine 30mg / Paracetamol 500mg /  Diphenhydramine 12.5mg capsules',
	'385049006',
	'Capsule'
	);

INSERT INTO clin_dr_to_dose_form (
	concept_code_1,
	concept_name_1,
	concept_code,
	concept_name
	)
VALUES (
	'OMOP25',
	'Estriol 1mg / Norethisterone acetate 1mg tablets',
	'385055001',
	'Tablet'
	);

INSERT INTO clin_dr_to_dose_form (
	concept_code_1,
	concept_name_1,
	concept_code,
	concept_name
	)
VALUES (
	'OMOP26',
	'Calcium chloride / Thrombin solution',
	'385219001',
	'Solution for injection'
	);

INSERT INTO clin_dr_to_dose_form (
	concept_code_1,
	concept_name_1,
	concept_code,
	concept_name
	)
VALUES (
	'OMOP27',
	'Pyridoxine 50mg/5ml / Thiamine 250mg/5ml / Riboflavin 4mg/5ml oral solution',
	'385023001',
	'Oral solution'
	);

INSERT INTO clin_dr_to_dose_form (
	concept_code_1,
	concept_name_1,
	concept_code,
	concept_name
	)
VALUES (
	'OMOP28',
	'Codeine / Paracetamol tablets',
	'385055001',
	'Tablet'
	);

INSERT INTO clin_dr_to_dose_form (
	concept_code_1,
	concept_name_1,
	concept_code,
	concept_name
	)
VALUES (
	'OMOP29',
	'Aprotinin / Fibrinogen / Factor XIII solution',
	'385219001',
	'Solution for injection'
	);

INSERT INTO clin_dr_to_dose_form (
	concept_code_1,
	concept_name_1,
	concept_code,
	concept_name
	)
VALUES (
	'OMOP101',
	'Rebif 8.8micrograms/0.1ml (2.4million units) solution for injection 1.5ml cartridges (Merck Serono Ltd)',
	'385219001',
	'Solution for injection'
	);

INSERT INTO clin_dr_to_dose_form (
	concept_code_1,
	concept_name_1,
	concept_code,
	concept_name
	)
VALUES (
	'OMOP100',
	'Rebif 22micrograms/0.25ml (6million units) solution for injection 1.5ml cartridges (Merck Serono Ltd)',
	'385219001',
	'Solution for injection'
	);

--define non-drugs, clinical part of 
DROP TABLE IF EXISTS clnical_non_drug; 
CREATE TABLE clnical_non_drug AS
SELECT *
FROM drug_concept_stage
WHERE (
		concept_code NOT IN (
			SELECT concept_code_1
			FROM clin_dr_to_dose_form
			WHERE concept_code_1 IS NOT NULL
			)
		AND invalid_reason IS NULL
		OR concept_name ~* 'peritoneal dialysis|dressing|burger|needl|soap|biscuits|wipes|cake|milk|dessert|juice|bath oil|gluten|Low protein|cannula|swabs|bandage|Artificial saliva|cylinder|Bq|stockings'
		OR domain_id = 'Device'
		)
	AND concept_class_id = 'Clinical Drug';

--TISSEEL was considered as Device in the source data, while it has Fibrin as a component we define it as drug product
DELETE
FROM clnical_non_drug
WHERE concept_name LIKE '%TISSEEL%';

--ADD MANUALLY DEFINED NON DRUG CONCEPTS
INSERT INTO clnical_non_drug (
	concept_id,
	concept_name,
	domain_id,
	vocabulary_id,
	concept_class_id,
	standard_concept,
	concept_code,
	valid_start_date,
	valid_end_date,
	invalid_reason,
	insert_id,
	source_concept_class_id
	)
SELECT DISTINCT a.*
FROM drug_concept_stage a
JOIN (
	SELECT drug_code
	FROM non_drug --!!!MANUAL TABLE 
	
	UNION
	
	SELECT concept_code
	FROM non_drug_2 --!!!MANUAL TABLE
	) n ON n.drug_code = a.concept_code;

INSERT INTO clnical_non_drug (
	concept_id,
	concept_name,
	domain_id,
	vocabulary_id,
	concept_class_id,
	standard_concept,
	concept_code,
	valid_start_date,
	valid_end_date,
	invalid_reason,
	insert_id,
	source_concept_class_id
	)
SELECT *
FROM drug_concept_stage
WHERE concept_code = '5015311000001107';

DELETE
FROM clnical_non_drug
WHERE concept_code IN (
		SELECT drug_concept_code
		FROM nondrug_with_ingr --!!! MANUAL TABLE 
		);

-- add manual table "aut_form_mapped_noRx" excluding non-drugs
DROP TABLE IF EXISTS clin_dr_to_dose_form_2;
CREATE TABLE clin_dr_to_dose_form_2 AS
SELECT *
FROM (
	SELECT cast(concept_code_1 AS VARCHAR(250)) AS concept_code_1,
		concept_name_1,
		concept_code_2,
		concept_name_2
	FROM aut_form_mapped_noRx --manaul forms for existing drugs; --table with manualy found forms !!!
	
	UNION
	
	SELECT concept_code_1,
		concept_name_1,
		concept_code,
		concept_name
	FROM clin_dr_to_dose_form --automated forms for existing drugs+ manual forms for newly created drugs
	) AS s0
WHERE concept_code_1 NOT IN (
		SELECT concept_code
		FROM clnical_non_drug
		);

-- add Boxes
DROP TABLE IF EXISTS clin_dr_to_dose_form_3;
CREATE TABLE clin_dr_to_dose_form_3 AS
SELECT a.concept_code_1,
	a.concept_name_1,
	b.concept_code_2,
	b.concept_name_2
FROM box_to_drug a
JOIN clin_dr_to_dose_form_2 b ON a.concept_code_2 = b.concept_code_1

UNION

SELECT *
FROM clin_dr_to_dose_form_2;

--add Branded Drugs
DROP TABLE IF EXISTS dr_to_dose_form_full;
CREATE TABLE dr_to_dose_form_full AS
--branded drug
SELECT a.concept_code_1,
	a.concept_name_1,
	b.concept_code_2,
	b.concept_name_2
FROM branded_to_clinical a
JOIN clin_dr_to_dose_form_3 b ON a.concept_code_2 = b.concept_code_1

UNION

SELECT *
FROM clin_dr_to_dose_form_3;

--remove 'Not applicable' forms
DELETE
FROM dr_to_dose_form_full
WHERE concept_code_2 = '3097611000001100';

/* -- take a long time to create this table so for testing purposes skip it
--Supplier
--just take it from names , it's long executing part, don't rerun 
 -- run this once before going 
drop table Drug_to_manufact_2 ;
  create table Drug_to_manufact_2 as
 select distinct a.concept_code as concept_code_1, a.concept_name as concept_name_1, a.concept_class_id as concept_class_id_1, 
 b.concept_code as concept_code_2, b.concept_name as concept_name_2, b.invalid_reason 
 from drug_concept_stage a 
 join drug_concept_stage b on a.concept_name like  '%('||b.concept_name||')%'
 where b.concept_class_id ='Supplier'
 and a.concept_class_id like 'Branded Drug%' and a.concept_code not in (select concept_code from non_drug_full)
 ;
 */

--CLinical Drug to ingredients using existing relationship, later this relationship will be updated with ds_stage table
DROP TABLE IF EXISTS clinical_to_ingred;
CREATE TABLE clinical_to_ingred AS
SELECT DISTINCT a.concept_code AS concept_code_1,
	a.concept_name AS concept_name_1,
	cs.concept_code AS concept_code_2,
	cs.concept_name AS concept_name_2
FROM drug_concept_stage a
JOIN concept c ON a.concept_code = c.concept_code
	AND c.vocabulary_id = 'SNOMED'
	AND a.concept_class_id LIKE '%Clinical Drug%'
JOIN concept_relationship r ON r.concept_id_1 = c.concept_id
JOIN concept d ON r.concept_id_2 = d.concept_id
	AND d.vocabulary_id = 'SNOMED'
JOIN drug_concept_stage cs ON cs.concept_code = d.concept_code
	AND cs.concept_class_id = 'Ingredient'
WHERE r.relationship_id NOT IN (
		'Has excipient',
		'Has basis str subst'
		);

--modify relationships between drugs and ingredients using existing relationships and reviewed path from non-standard to standard ingr
DROP TABLE IF EXISTS clinical_to_ingred_tmp ; 
CREATE TABLE clinical_to_ingred_tmp AS
SELECT DISTINCT a.concept_code_1,
	a.concept_name_1,
	coalesce(b.concept_code_2, a.concept_code_2) AS concept_code_2,
	coalesce(b.concept_name_2, a.concept_name_2) AS concept_name_2
FROM clinical_to_ingred a
JOIN ingr_to_ingr --!!!
	b ON a.concept_code_2 = b.concept_code_1;

--another variant with narrower definition - use only  r.relationship_id  in ('Is a')
DROP TABLE IF EXISTS clinical_to_ingred_is_a;
CREATE TABLE clinical_to_ingred_is_a AS
SELECT DISTINCT a.concept_code AS concept_code_1,
	a.concept_name AS concept_name_1,
	r.relationship_id,
	cs.concept_code AS concept_code_2,
	cs.concept_name AS concept_name_2
FROM drug_concept_stage a
JOIN concept c ON a.concept_code = c.concept_code
	AND c.vocabulary_id = 'SNOMED'
	AND a.concept_class_id LIKE '%Clinical Drug%'
JOIN concept_relationship r ON r.concept_id_1 = c.concept_id
JOIN concept d ON r.concept_id_2 = d.concept_id
	AND d.vocabulary_id = 'SNOMED'
JOIN drug_concept_stage cs ON cs.concept_code = d.concept_code
	AND cs.concept_class_id = 'Ingredient'
WHERE r.relationship_id IN ('Is a');

DROP TABLE IF EXISTS clinical_to_ingred_is_a_tmp;
CREATE TABLE clinical_to_ingred_is_a_tmp AS
SELECT DISTINCT a.concept_code_1,
	a.concept_name_1,
	coalesce(b.concept_code_2, a.concept_code_2) AS concept_code_2,
	coalesce(b.concept_name_2, a.concept_name_2) AS concept_name_2
FROM clinical_to_ingred_is_a a
JOIN ingr_to_ingr b ON a.concept_code_2 = b.concept_code_1;

--prepare table for parsing if drug has several ingredients
DROP TABLE IF EXISTS drug_concept_stage_tmp;
CREATE TABLE drug_concept_stage_tmp AS
SELECT concept_id,
	CASE 
		WHEN concept_name ~ ' / \d'
			THEN replace(concept_name, ' / ', '/')
		ELSE replace(concept_name, ' / ', '!')
		END AS concept_name_chgd,
	concept_name,
	domain_id,
	vocabulary_id,
	concept_class_id,
	standard_concept,
	concept_code,
	valid_start_date,
	valid_end_date,
	invalid_reason
FROM drug_concept_stage;

--parsing dosage and components taking from concept_name
DROP TABLE IF EXISTS drug_concept_stage_tmp_0;
CREATE TABLE drug_concept_stage_tmp_0 AS
SELECT substring(a.drug_comp, '([[:digit:],.]+(mg|%|ml|mcg|hr|hours|unit(s?)|iu|g|microgram(s*)|u|mmol|c|gm|litre|million unit(s?)|nanogram(s)*|x|ppm|million units| Kallikrein inactivator units|kBq|microlitres|MBq|molar|micromol)/*[[:digit:]\,\.]*(g|dose|ml|mg|ampoule|litre|hour(s)*|h|square cm|microlitres|unit dose|drop)*)') AS dosage,
	drug_comp,
	a.concept_name,
	a.concept_code
FROM (
	SELECT DISTINCT trim(unnest(regexp_matches(concept_name_chgd, '[^!]+', 'g'))) AS drug_comp,
		concept_name,
		concept_code
	FROM drug_concept_stage_tmp
	WHERE concept_class_id = 'Clinical Drug'
	) a;

--select * from drug_concept_stage_tmp_0 where 
UPDATE drug_concept_stage_tmp_0
SET dosage = replace(dosage, 'molar', 'mmol/ml')
WHERE dosage LIKE '%molar%';

--update drug_concept_stage_tmp_0 set dosage = replace (dosage, '/dose', '');
UPDATE drug_concept_stage_tmp_0
SET dosage = regexp_replace(dosage, '/$', '')
WHERE dosage LIKE '%/';

--select * from drug_concept_stage_tmp_0 where concept_code = '12296111000001106'
--define number of components and ingredients
ALTER TABLE drug_concept_stage_tmp_0 ADD ingr_cnt INT;

UPDATE drug_concept_stage_tmp_0 b
SET ingr_cnt = i.cnt
FROM (
	SELECT concept_code,
		count(*) AS cnt
	FROM drug_concept_stage_tmp_0
	GROUP BY concept_code
	) i
WHERE i.concept_code = b.concept_code;

ALTER TABLE clinical_to_ingred_tmp ADD ingr_cnt INT;

UPDATE clinical_to_ingred_tmp b
SET ingr_cnt = i.cnt
FROM (
	SELECT concept_code_1,
		count(*) AS cnt
	FROM clinical_to_ingred_tmp
	GROUP BY concept_code_1
	) i
WHERE i.concept_code_1 = b.concept_code_1;

--easiest part -when drug has only one ingredient
DROP TABLE IF EXISTS clin_dr_to_ingr_one; 
CREATE TABLE clin_dr_to_ingr_one AS
SELECT DISTINCT a.*,
	concept_code_2 AS ingredient_concept_code,
	concept_name_2 AS ingredient_concept_name
FROM drug_concept_stage_tmp_0 a
JOIN clinical_to_ingred_tmp b ON a.concept_code = b.concept_code_1
WHERE b.concept_code_1 IN (
		SELECT concept_code_1
		FROM clinical_to_ingred_tmp
		GROUP BY concept_code_1
		HAVING count(*) = 1
		)
	AND a.ingr_cnt = 1;

--count is equal and drug_component contains ingredient , exclude also concepts from previous table
--recheck in future about complicated dosages
DROP TABLE IF EXISTS clin_dr_to_ingr_two;
CREATE TABLE clin_dr_to_ingr_two AS
SELECT DISTINCT a.*,
	concept_code_2 AS ingredient_concept_code,
	concept_name_2 AS ingredient_concept_name
FROM drug_concept_stage_tmp_0 a
JOIN clinical_to_ingred_tmp b ON a.concept_code = b.concept_code_1
	AND a.drug_comp ilike '%' || b.concept_name_2 || '%'
	AND a.ingr_cnt = b.ingr_cnt --this condition also could help with excessive ingredients number
JOIN (
	SELECT concept_code,
		count(*) AS cnt
	FROM (
		SELECT DISTINCT a.*,
			concept_code_2 AS ingredient_concept_code,
			concept_name_2 AS ingredient_concept_name,
			b.ingr_cnt
		FROM drug_concept_stage_tmp_0 a
		JOIN clinical_to_ingred_tmp b ON a.concept_code = b.concept_code_1
			AND a.drug_comp ilike '%' || b.concept_name_2 || '%'
			AND a.ingr_cnt = b.ingr_cnt
		) AS s0
	GROUP BY concept_code
	) x ON x.cnt = a.ingr_cnt
	AND x.concept_code = a.concept_code
WHERE b.concept_code_1 NOT IN (
		SELECT concept_code
		FROM clin_dr_to_ingr_one
		);

--clinical_to_ingred_is_a_tmp --another way by using narrower table for drug ingredients
DROP TABLE IF EXISTS clin_dr_to_ingr_one_part_2;
CREATE TABLE clin_dr_to_ingr_one_part_2 AS
SELECT DISTINCT a.concept_code,
	a.concept_name,
	i.concept_code_2,
	i.concept_name_2,
	a.dosage
FROM drug_concept_stage_tmp_0 a
JOIN drug_concept_stage z ON a.concept_code = z.concept_code
JOIN clinical_to_ingred_tmp b ON a.concept_code = b.concept_code_1
JOIN clinical_to_ingred_is_a_tmp i ON a.concept_code = i.concept_code_1
JOIN (
	SELECT concept_code
	FROM (
		SELECT DISTINCT a.concept_code,
			a.concept_name,
			i.concept_code_2,
			i.concept_name_2,
			a.dosage
		FROM drug_concept_stage_tmp_0 a
		JOIN drug_concept_stage z ON a.concept_code = z.concept_code
		JOIN clinical_to_ingred_tmp b ON a.concept_code = b.concept_code_1
		JOIN clinical_to_ingred_is_a_tmp i ON a.concept_code = i.concept_code_1
		WHERE a.concept_code NOT IN (
				SELECT concept_code
				FROM clin_dr_to_ingr_two
				
				UNION
				
				SELECT concept_code
				FROM clin_dr_to_ingr_one
				
				UNION
				
				SELECT concept_code
				FROM clnical_non_drug
				)
			AND z.concept_class_id = 'Clinical Drug'
			AND z.invalid_reason IS NULL
			AND a.INGR_CNT = 1
		) AS s0
	GROUP BY concept_code
	HAVING COUNT(*) = 1
	) X ON X.concept_code = A.concept_code
WHERE a.concept_code NOT IN (
		SELECT concept_code
		FROM clin_dr_to_ingr_two
		
		UNION
		
		SELECT concept_code
		FROM clin_dr_to_ingr_one
		
		UNION
		
		SELECT concept_code
		FROM clnical_non_drug
		)
	AND z.concept_class_id = 'Clinical Drug'
	AND z.invalid_reason IS NULL
	AND a.ingr_cnt = 1;

--manual update
UPDATE clin_dr_to_ingr_3
SET dosage = '10,000unit/g'
WHERE dosage = '"10,000unit"';

UPDATE clin_dr_to_ingr_3
SET dosage = '500unit/g'
WHERE dosage = '500unit';

DROP TABLE IF EXISTS ds_all_tmp;
CREATE TABLE ds_all_tmp AS
SELECT dosage,
	drug_comp,
	concept_name,
	concept_code,
	ingredient_concept_code,
	ingredient_concept_name,
	NULL::VARCHAR(200) AS volume
FROM clin_dr_to_ingr_one
WHERE concept_code NOT IN (
		SELECT concept_code
		FROM ds_by_lena_1
		)

UNION

SELECT dosage,
	drug_comp,
	concept_name,
	concept_code,
	ingredient_concept_code,
	ingredient_concept_name,
	NULL::VARCHAR(200)
FROM clin_dr_to_ingr_two
WHERE concept_code NOT IN (
		SELECT concept_code
		FROM ds_by_lena_1
		)

UNION

SELECT dosage,
	NULL,
	concept_name,
	concept_code,
	concept_code_2,
	concept_name_2,
	NULL::VARCHAR(200)
FROM clin_dr_to_ingr_one_part_2
WHERE concept_code NOT IN (
		SELECT concept_code
		FROM ds_by_lena_1
		)

UNION

--ds_by_lena_1 table is defined analysing the things left from the above
SELECT dosage,
	NULL,
	concept_name,
	concept_code,
	concept_code_2,
	concept_name_2,
	volume::VARCHAR(200)
FROM ds_by_lena_1 --!!! manual table

UNION

--ds_by_lena_1 table is defined analysing the things left from the above
SELECT dosage,
	NULL,
	concept_name,
	concept_code,
	concept_code_2,
	concept_name_2,
	NULL::VARCHAR(200)
FROM clin_dr_to_ingr_3 --consider as manualy created table - we lost update query -- !!!

UNION

-- a lot of manual work, need to write definition and delta later
SELECT dosage,
	'',
	concept_name,
	concept_code,
	concept_code_2,
	concept_name_2,
	NULL::VARCHAR(200)
FROM drug_to_ingr --!!! -manual table, review of part of ds_stage we can't make fully automatically
WHERE concept_code_2 IS NOT NULL

UNION

-- lost ingredients
SELECT NULL,
	NULL,
	drug_name,
	drug_code,
	INGR_CODE,
	INGR_NAME,
	NULL::VARCHAR(200)
FROM lost_ingr_to_rx_with_OMOP;--!!!

--need to redefine , why we do so
DELETE
FROM DS_ALL_TMP
WHERE dosage = '22micrograms/2.2ml'
	AND concept_code = '21142411000001108'
	AND ingredient_concept_code = '410851000';

DELETE
FROM DS_ALL_TMP
WHERE dosage = '88mg/2.2ml'
	AND concept_code = '21142411000001108'
	AND ingredient_concept_code = '387362001';;

UPDATE ds_all_tmp
SET dosage = '10mg/1ml'
WHERE concept_code = '11360011000001101'
	AND ingredient_concept_code = 'OMOP28664';

--select * from lost_ingr_to_rx_with_OMOP;
--select * from ds_all_tmp where ingredient_concept_code is null;
--select * from drug_to_ingr a  join devv5.concept c on a.concept_code_2 = cast (c.concept_id  as varchar (250)) and c.concept_class_id ='Ingredient' and vocabulary_id = 'RxNorm'
SELECT *
FROM ds_all_tmp
WHERE concept_code = '16436511000001106';

UPDATE ds_all_tmp
SET dosage = replace(dosage, '"', '')
WHERE dosage LIKE '%"%';

UPDATE ds_all_tmp
SET dosage = trim(dosage)
WHERE dosage <> trim(dosage);

--add volume 
UPDATE ds_all_tmp
SET volume = substring(concept_name, '([[:digit:].]+\s*(ml|g|litre|mg)) (pre-filled syringes|bags|bottles|vials|applicators|sachets|ampoules)')
WHERE substring(concept_name, '([[:digit:].]+\s*(ml|g|litre|mg)) (pre-filled syringes|bags|bottles|vials|applicators|sachets|ampoules)') IS NOT NULL
	AND (
		substring(concept_name, '([[:digit:].]+\s*(ml|g|litre|mg)) (pre-filled syringes|bags|bottles|vials|applicators|sachets|ampoules)') != dosage
		OR dosage IS NULL
		);

DROP TABLE IF EXISTS ds_all;
CREATE TABLE ds_all AS
SELECT CASE 
		WHEN substring(dosage, '([[:digit:],.]+(mg|%|ml|mcg|hr|hours|unit(s)*|iu|g|microgram(s*)|u|mmol|c|gm|litre|million unit|nanogram(s)*|x|ppm| Kallikrein inactivator units|kBq|MBq|molar|micromol|microlitres|million units|unit dose|drop))') = dosage
			AND NOT dosage ~ '%'
			THEN replace(substring(dosage, '[[:digit:],.]+'), ',', '')
		ELSE NULL
		END AS amount_value,
	CASE 
		WHEN substring(dosage, '([[:digit:],.]+(mg|%|ml|mcg|hr|hours|unit(s)*|iu|g|microgram(s*)|u|mmol|c|gm|litre|million unit|nanogram(s)*|x|ppm| Kallikrein inactivator units|kBq|MBq|molar|micromol|microlitres|million units|unit dose|drop))') = dosage
			AND NOT dosage ~ '%'
			THEN trim(regexp_replace(dosage, '[[:digit:],.]+', '', 'g')) -- Kallikrein inactivator units - because of this
		ELSE NULL
		END AS amount_unit,
	CASE 
		WHEN substring(dosage, '([[:digit:],.]+(mg|%|ml|mcg|hr|hours|unit(s)*|iu|g|microgram(s*)|u|mmol|c|gm|litre|million unit|nanogram(s)*|x|ppm| Kallikrein inactivator units|kBq|MBq|molar|micromol|microlitres|million units)/[[:digit:],.]*(g|dose|ml|mg|ampoule|litre|hour(s)*|h|square cm|microlitres|unit dose|drop))') = dosage
			OR dosage ~ '%'
			THEN replace(substring(dosage, '^[[:digit:],.]+'), ',', '')
		ELSE NULL
		END AS numerator_value,
	CASE 
		WHEN substring(dosage, '([[:digit:],.]+(mg|%|ml|mcg|hr|hours|unit(s)*|iu|g|microgram(s*)|u|mmol|c|gm|litre|million unit|nanogram(s)*|x|ppm| Kallikrein inactivator units|kBq|MBq|molar|micromol|microlitres|million units)/[[:digit:],.]*(g|dose|ml|mg|ampoule|litre|hour(s)*|h|square cm|microlitres|unit dose|drop))') = dosage
			OR dosage ~ '%'
			THEN trim(substring(dosage, '(mg|%|mcg|hr|hours|unit(s)*|iu|g|microgram(s*)|u|mmol|c|gm|litre|million unit|nanogram(s)*|x|ppm| Kallikrein inactivator units|kBq|microlitres)'))
		ELSE NULL
		END AS numerator_unit,
	CASE 
		WHEN (
				substring(dosage, '([[:digit:],.]+(mg|%|ml|mcg|hr|hours|unit(s)*|iu|g|microgram(s*)|u|mmol|c|gm|litre|million unit|nanogram(s)*|x|ppm| Kallikrein inactivator units|kBq|MBq|molar|micromol|microlitres|million units)/[[:digit:],.]*(g|dose|ml|mg|ampoule|litre|hour(s)|h|square cm|microlitres|unit dose|drop))') = dosage
				OR dosage ~ '%'
				)
			AND volume IS NULL
			THEN replace(substring(dosage, '/([[:digit:],.]+)'), ',', '')
		WHEN volume IS NOT NULL
			THEN substring(volume, '[[:digit:],.]+')
		ELSE NULL
		END AS denominator_value,
	CASE 
		WHEN (
				substring(dosage, '([[:digit:],.]+(mg|%|ml|mcg|hr|hours|unit(s)*|iu|g|microgram(s*)|u|mmol|c|gm|litre|million unit|nanogram(s)*|x|ppm| Kallikrein inactivator units|kBq|MBq|molar|micromol|microlitres|million units)/[[:digit:],.]*(g|dose|ml|mg|ampoule|litre|microlitres|hour(s)*|h|square cm|unit dose|drop))') = dosage
				OR dosage ~ '%'
				)
			AND volume IS NULL
			THEN substring(dosage, '(g|dose|ml|mg|ampoule|litre|hour(s)*|h*|square cm|microlitres|unit dose|drop)$')
		WHEN volume IS NOT NULL
			THEN trim(regexp_replace(volume, '[[:digit:],.]+', '', 'g'))
		ELSE NULL
		END AS denominator_unit,
	concept_code,
	concept_name,
	dosage,
	drug_comp,
	ingredient_concept_code,
	ingredient_concept_name
FROM ds_all_tmp;

UPDATE DS_ALL
SET ingredient_concept_code = 'OMOP1'
WHERE concept_code = '4701111000001104'
	AND ingredient_concept_code = 'OMOP11';

-- update denominator with existing value for concepts having empty and non-emty denominator value/unit
UPDATE ds_all a
SET denominator_value = i.denominator_value,
	denominator_unit = i.denominator_unit
FROM (
	SELECT b.denominator_value,
		b.denominator_unit,
		b.concept_code
	FROM ds_all b
	WHERE b.denominator_value IS NOT NULL
	) i
WHERE a.concept_code = i.concept_code
	AND a.denominator_value IS NULL;

--select * from ds_all where coalesce (amount_value, denominator_value, numerator_value) is null

--need to comment
UPDATE ds_all
SET amount_value = NULL,
	amount_unit = NULL
WHERE concept_name ~ '[[:digit:].]+(litre|ml)'
	AND NOT concept_name ~ '/[[:digit:].]+(litre|ml)'
	AND amount_value IS NOT NULL
	AND amount_unit IN (
		'litre',
		'ml'
		);

-- need to comment
UPDATE ds_all
SET denominator_value = substring(concept_name, ' ([[:digit:].]+)(litre(s?)|ml)'),
	denominator_unit = substring(concept_name, ' [[:digit:].]+(litre(s?)|ml)')
WHERE concept_name ~ '\d+(litre(s?)|ml)'
	AND NOT concept_name ~ '/[[:digit:].]+(litre(s?)|ml)'
	AND denominator_value IS NULL;

--recalculate ds_stage accordong to fake denominators
UPDATE ds_all a
SET numerator_value = numerator_value::FLOAT / denominator_value::FLOAT,
	denominator_value = NULL
WHERE concept_code IN (
		SELECT concept_code_2
		FROM box_to_drug b
		WHERE b.amount_value IS NOT NULL
		)
	AND denominator_value IS NOT NULL
	AND numerator_unit != '%';

--!!!
--Noradrenaline (base) 320micrograms/ml solution for infusion 950ml bottles for such concepts we need to keep denominator_value as true value and 
UPDATE ds_all a
SET numerator_value = numerator_value::FLOAT * denominator_value::FLOAT
WHERE concept_code IN (
		SELECT concept_code
		FROM drug_concept_stage
		WHERE concept_name ~ '[[:digit:]\.]+.*/ml.*[[:digit:]\.]+ml'
		)
	AND numerator_value IS NOT NULL
	AND denominator_value IS NOT NULL
	AND numerator_unit != '%';

--normalize box_to_drug,  make the same units 
UPDATE box_to_drug
SET amount_unit = 'g'
WHERE amount_unit = 'gram';

-- add Drug Boxes as mix of Boxes and Quant Drugs
--select * from ds_all where not regexp_like (numerator_value, '[[:digit:]/.]') 
DROP TABLE IF EXISTS ds_all_dr_box;
CREATE TABLE ds_all_dr_box AS
SELECT a.concept_code_1,
	b.ingredient_concept_code,
	NULL AS amount_value,
	NULL AS amount_unit,
	CASE 
		WHEN b.amount_value IS NOT NULL
			THEN b.amount_value::FLOAT
		WHEN b.amount_value IS NULL
			AND numerator_unit != '%'
			AND (
				a.amount_unit = b.denominator_unit
				OR a.amount_unit IN (
					'ml',
					'g'
					)
				AND b.denominator_unit IN (
					'ml',
					'g'
					)
				OR b.denominator_unit IS NULL
				)
			THEN b.numerator_value::FLOAT * a.amount_value::FLOAT
		WHEN b.amount_value IS NULL
			AND numerator_unit = '%'
			THEN b.numerator_value::FLOAT
		ELSE b.numerator_value::FLOAT
		END AS numerator_value,
	CASE 
		WHEN b.amount_value IS NOT NULL
			THEN b.amount_unit
		ELSE b.numerator_unit
		END AS numerator_unit,
	CASE 
		WHEN b.denominator_unit = 'dose'
			AND denominator_unit != a.amount_unit
			THEN b.denominator_value::FLOAT
		ELSE a.amount_value
		END AS denominator_value,
	a.amount_unit AS denominator_unit,
	a.box_size AS box_size
FROM box_to_drug a
JOIN ds_all b ON a.concept_code_2 = b.concept_code
WHERE a.amount_value IS NOT NULL

UNION

--what's this?
SELECT a.concept_code_1,
	b.ingredient_concept_code,
	b.amount_value::FLOAT AS amount_value,
	b.amount_unit,
	b.numerator_value::FLOAT AS numerator_value,
	b.numerator_unit,
	b.denominator_value::FLOAT AS denominator_value,
	b.denominator_unit,
	a.box_size AS box_size
FROM box_to_drug a
JOIN ds_all b ON a.concept_code_2 = b.concept_code
WHERE a.amount_value IS NULL;
--and b.amount_value is not null and b.amount_unit = '%'

--for all the clinical drugs (Boxes and Quant Drugs)
DROP TABLE IF EXISTS ds_all_cl_dr;
CREATE TABLE ds_all_cl_dr AS
SELECT concept_code_1,
	ingredient_concept_code,
	amount_value,
	amount_unit,
	numerator_value,
	numerator_unit,
	denominator_value,
	denominator_unit,
	box_size::INT AS box_size
FROM ds_all_dr_box

UNION

SELECT concept_code,
	ingredient_concept_code,
	amount_value::FLOAT AS amount_value,
	amount_unit,
	numerator_value::FLOAT,
	numerator_unit,
	denominator_value::FLOAT,
	denominator_unit,
	NULL::INT AS box_size
FROM ds_all;

TRUNCATE TABLE ds_stage;
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
--Clinical Drugs
SELECT *
FROM ds_all_cl_dr

UNION

--Branded Drugs
SELECT a.concept_code_1,
	ingredient_concept_code,
	amount_value,
	amount_unit,
	numerator_value,
	numerator_unit,
	denominator_value,
	denominator_unit,
	box_size
FROM branded_to_clinical a
JOIN ds_all_cl_dr b ON a.concept_code_2 = b.concept_code_1;

--manually created table pack_drug_to_code_2_2
DROP TABLE IF EXISTS ds_omop;
CREATE TABLE ds_omop AS
SELECT DISTINCT drug_code,
	drug_new_name,
	coalesce(concept_code_2, concept_code_1) AS concept_code_2,
	coalesce(concept_name_2, concept_name_1) AS concept_name_2
FROM pack_drug_to_code_2_2 --!!! packs determined manually 
	a
JOIN ingr_to_ingr b ON a.ingredient_name = b.concept_name_1
WHERE a.drug_code LIKE '%OMOP%';

DROP TABLE IF EXISTS ds_omop_0;
CREATE TABLE ds_omop_0 AS
SELECT substring(a.drug_comp, '([[:digit:],.]+(mg|%|ml|mcg|hr|hours|unit(s?)|iu|g|microgram(s*)|u|mmol|c|gm|litre|million unit(s?)|nanogram(s)*|x|ppm| Kallikrein inactivator units|kBq|microlitres|MBq|molar|micromol|million units)/*[[:digit:]\,\.]*(g|dose|ml|mg|ampoule|litre|hour(s)*|h|square cm|microlitres)*)') AS dosage,
	drug_comp,
	a.drug_new_name,
	a.drug_code,
	a.concept_code_2,
	a.concept_name_2
FROM (
	SELECT DISTINCT l.drug_comp,
		drug_new_name,
		drug_code,
		concept_code_2,
		concept_name_2
	FROM ds_omop t,
		lateral(SELECT trim(unnest(string_to_array(drug_new_name, ' / '))) AS drug_comp) l
	) a

INSERT INTO ds_stage (
	drug_concept_code,
	ingredient_concept_code,
	amount_value,
	amount_unit,
	numerator_value,
	numerator_unit,
	denominator_value,
	denominator_unit
	)
SELECT drug_code,
	concept_code_2,
	amount_value,
	amount_unit,
	numerator_value,
	numerator_unit,
	denominator_value,
	denominator_unit
FROM (
	SELECT CASE 
			WHEN substring(dosage, '([[:digit:],.]+(mg|%|ml|mcg|hr|hours|unit(s)*|iu|g|microgram(s*)|u|mmol|c|gm|litre|million unit|nanogram(s)*|x|ppm| Kallikrein inactivator units|kBq|MBq|molar|micromol|microlitres|million units))') = dosage
				AND NOT dosage ~ '%'
				THEN regexp_replace(substring(dosage, '[[:digit:],.]+'), ',', '', 'g')
			ELSE NULL
			END::FLOAT AS amount_value,
		CASE 
			WHEN substring(dosage, '([[:digit:],.]+(mg|%|ml|mcg|hr|hours|unit(s)*|iu|g|microgram(s*)|u|mmol|c|gm|litre|million unit|nanogram(s)*|x|ppm| Kallikrein inactivator units|kBq|MBq|molar|micromol|microlitres|million units))') = dosage
				AND NOT dosage ~ '%'
				THEN regexp_replace(dosage, '[[:digit:],.]+', '', 'g')
			ELSE NULL
			END AS amount_unit,
		CASE 
			WHEN substring(dosage, '([[:digit:],.]+(mg|%|ml|mcg|hr|hours|unit(s)*|iu|g|microgram(s*)|u|mmol|c|gm|litre|million unit|nanogram(s)*|x|ppm| Kallikrein inactivator units|kBq|MBq|molar|micromol|microlitres|million units)/[[:digit:],.]*(g|dose|ml|mg|ampoule|litre|hour(s)*|h|square cm|microlitres))') = dosage
				OR dosage ~ '%'
				THEN regexp_replace(substring(dosage, '^[[:digit:],.]+'), ',', '', 'g')
			ELSE NULL
			END::FLOAT AS numerator_value,
		CASE 
			WHEN substring(dosage, '([[:digit:],.]+(mg|%|ml|mcg|hr|hours|unit(s)*|iu|g|microgram(s*)|u|mmol|c|gm|litre|million unit|nanogram(s)*|x|ppm| Kallikrein inactivator units|kBq|MBq|molar|micromol|microlitres|million units)/[[:digit:],.]*(g|dose|ml|mg|ampoule|litre|hour(s)*|h|square cm|microlitres))') = dosage
				OR dosage ~ '%'
				THEN substring(dosage, '(mg|%|mcg|hr|hours|unit(s)*|iu|g|microgram(s*)|u|mmol|c|gm|litre|million unit|nanogram(s)*|x|ppm| Kallikrein inactivator units|kBq|microlitres)')
			ELSE NULL
			END AS numerator_unit,
		CASE 
			WHEN (
					substring(dosage, '([[:digit:],.]+(mg|%|ml|mcg|hr|hours|unit(s)*|iu|g|microgram(s*)|u|mmol|c|gm|litre|million unit|nanogram(s)*|x|ppm| Kallikrein inactivator units|kBq|MBq|molar|micromol|microlitres|million units)/[[:digit:],.]*(g|dose|ml|mg|ampoule|litre|hour(s)*|h|square cm|microlitres*))') = dosage
					OR dosage ~ '%'
					)
				AND volume IS NULL
				THEN regexp_replace(substring(dosage, '/([[:digit:],.]+)'), ',', '', 'g')
			WHEN volume IS NOT NULL
				THEN substring(volume, '[[:digit:],.]+')
			ELSE NULL
			END::FLOAT AS denominator_value,
		CASE 
			WHEN (
					substring(dosage, '([[:digit:],.]+(mg|%|ml|mcg|hr|hours|unit(s)*|iu|g|microgram(s*)|u|mmol|c|gm|litre|million unit|nanogram(s)*|x|ppm| Kallikrein inactivator units|kBq|MBq|molar|micromol|microlitres|million units)/[[:digit:],.]*(g|dose|ml|mg|ampoule|litre|microlitres|hour(s)*|h*|square cm))') = dosage
					OR dosage ~ '%'
					)
				AND volume IS NULL
				THEN substring(dosage, '(g|dose|ml|mg|ampoule|litre|hour(s)*|h*|square cm|microlitres)$')
			WHEN volume IS NOT NULL
				THEN regexp_replace(volume, '[[:digit:],.]+', '', 'g')
			ELSE NULL
			END AS denominator_unit,
		drug_code,
		dosage,
		concept_code_2
	FROM (
		SELECT drug_code,
			concept_code_2,
			dosage,
			NULL::VARCHAR AS volume
		FROM ds_omop_0
		WHERE drug_comp LIKE '%' || concept_name_2 || '%'
		) AS s0
	) AS s1;

-- update denominator with existing value for concepts having empty and non-emty denominator value/unit
--seems there is already such a query
UPDATE ds_stage a
SET denominator_value = i.denominator_value,
	denominator_unit = i.denominator_unit
FROM (
	SELECT b.denominator_value,
		b.denominator_unit,
		b.drug_concept_code
	FROM ds_stage b
	WHERE b.denominator_value IS NOT NULL
	) i
WHERE a.drug_concept_code = i.drug_concept_code
	AND a.denominator_value IS NULL;

 --!!! 
 --need to comment with example
UPDATE ds_stage
SET ingredient_concept_code = 'OMOP18'
WHERE ingredient_concept_code = '798336';;

UPDATE ds_stage
SET ingredient_concept_code = 'OMOP17'
WHERE ingredient_concept_code = '902251';

DELETE
FROM ds_stage
WHERE coalesce(amount_unit, numerator_unit) IS NULL
	AND ingredient_concept_code = '3588811000001104';

--pay an attention! we put in ds_stage everything including non-drugs

--add branded Drugs to non_drug
DROP TABLE IF EXISTS branded_non_drug;
CREATE TABLE branded_non_drug AS
SELECT DISTINCT a.*
FROM drug_concept_stage a
JOIN branded_to_clinical b ON a.concept_code = b.concept_code_1
JOIN clnical_non_drug nd ON b.concept_code_2 = nd.concept_code;

--ADD another classes going throught the relationships
DROP TABLE IF EXISTS cl_br_non_drug;
CREATE TABLE cl_br_non_drug AS
SELECT *
FROM branded_non_drug

UNION

SELECT *
FROM clnical_non_drug;

DROP TABLE IF EXISTS box_non_drug;
CREATE TABLE box_non_drug AS
SELECT DISTINCT a.*
FROM drug_concept_stage a
JOIN box_to_drug b ON a.concept_code = b.concept_code_1
JOIN cl_br_non_drug nd ON b.concept_code_2 = nd.concept_code;

DROP TABLE IF EXISTS non_drug_full;
CREATE TABLE non_drug_full AS
SELECT *
FROM box_non_drug

UNION

SELECT *
FROM cl_br_non_drug;

--Box fixing including existing non-drug ???
DELETE
FROM dr_pack_to_clin_dr_box_full
WHERE concept_code_1 IN (
		SELECT concept_code_1
		FROM dr_pack_to_clin_dr_box_full
		WHERE concept_code_1 IN (
				SELECT concept_code
				FROM non_drug_full
				)
			AND concept_code_2 IN (
				SELECT concept_code
				FROM non_drug_full
				)
		);

--when drug box has one of the component as drug then it's drug
DELETE
FROM non_drug_full f
WHERE EXISTS (
		SELECT 1
		FROM dr_pack_to_clin_dr_box_full
		WHERE concept_code_1 = f.concept_code
			AND concept_code NOT IN (
				'17631511000001101',
				'7850411000001102',
				'7849511000001109'
				)
		);

DELETE
FROM non_drug_full
WHERE concept_code IN (
		SELECT drug_concept_code
		FROM nondrug_with_ingr
		);

--manual packs delete
DELETE
FROM dr_pack_to_clin_dr_box_full
WHERE concept_code_1 IN (
		'17631511000001101',
		'7850411000001102',
		'7849511000001109'
		);

--since all Packs info is OK, we need to add PACK_CONTENT table as one of it's done already
DROP TABLE IF EXISTS pack_content_1;
CREATE TABLE pack_content_1 AS
SELECT a.concept_code_1 AS pack_concept_code,
	a.concept_name_1 AS pack_name,
	coalesce(b.concept_code_2, a.concept_code_2) AS drug_concept_code,
	coalesce(b.concept_name_2, a.concept_name_2) AS drug_concept_name,
	coalesce(box_size, 1) AS amount
FROM dr_pack_to_clin_dr_box_full a
LEFT JOIN box_to_drug b ON a.concept_code_2 = b.concept_code_1
	AND box_size IS NOT NULL;

--insert manual packs
INSERT INTO pack_content_1 (
	pack_concept_code,
	pack_name,
	drug_concept_code,
	drug_concept_name,
	amount
	)
SELECT pack_code,
	pack_name,
	drug_code,
	drug_new_name,
	amount
FROM pack_drug_to_code_2_2 --!!!

UNION

SELECT pack_code,
	pack_name,
	drug_code,
	drug_name,
	NULL
FROM pack_drug_to_code_1 --!!!--table with pack components joined with dmd by pack component name;
	;

INSERT INTO pack_content_1 (
	pack_concept_code,
	pack_name,
	drug_concept_code,
	drug_concept_name,
	amount
	)
SELECT DISTINCT b.concept_code_1,
	b.concept_name_1,
	drug_concept_code,
	drug_concept_name,
	amount
FROM pack_content_1 a
JOIN branded_to_clinical b ON a.pack_concept_code = b.concept_code_2
WHERE b.concept_code_1 NOT IN (
		SELECT pack_concept_code
		FROM pack_content_1
		);

INSERT INTO pack_content_1 (
	pack_concept_code,
	pack_name,
	drug_concept_code,
	drug_concept_name,
	amount
	)
SELECT DISTINCT b.concept_code_1,
	b.concept_name_1,
	drug_concept_code,
	drug_concept_name,
	amount
FROM pack_content_1 a
JOIN box_to_drug b ON a.pack_concept_code = b.concept_code_2
WHERE b.concept_code_1 NOT IN (
		SELECT pack_concept_code
		FROM pack_content_1
		);

TRUNCATE TABLE pc_stage;
INSERT INTO pc_stage (
	pack_concept_code,
	drug_concept_code,
	amount
	)
SELECT DISTINCT pack_concept_code,
	drug_concept_code,
	amount
FROM pack_content_1;

-- packs are not allowed in ds_stage
DELETE
FROM ds_stage
WHERE drug_concept_code IN (
		SELECT pack_concept_code
		FROM pc_stage
		);

--non_drugs also are not allowed in ds_stage
DELETE
FROM ds_stage
WHERE drug_concept_code IN (
		SELECT concept_code
		FROM non_drug_full
		);

 --deprecated to active
 --use SNOMED relationship
DROP TABLE IF EXISTS deprec_to_active; -- contains Ingredient, Clinical Drug, Dose Form classes
CREATE TABLE deprec_to_active AS
SELECT DISTINCT a.concept_code AS concept_code_1,
	a.concept_name AS concept_name_1,
	a.concept_class_id,
	cs.concept_code AS concept_code_2,
	cs.concept_name AS concept_name_2
FROM drug_concept_stage a
JOIN concept c ON a.concept_code = c.concept_code
	AND c.vocabulary_id = 'SNOMED'
JOIN concept_relationship r ON r.concept_id_1 = c.concept_id
JOIN concept d ON r.concept_id_2 = d.concept_id
	AND d.vocabulary_id = 'SNOMED'
JOIN drug_concept_stage cs ON cs.concept_code = d.concept_code
	AND cs.concept_class_id = a.concept_class_id
	AND a.invalid_reason IS NOT NULL
	AND cs.invalid_reason IS NULL
	AND relationship_id IN (
		'Concept same_as to',
		'Concept poss_eq to',
		'Concept replaced by',
		'Maps to'
		);
--delete from Packs deprecated concepts

--Brand NAMES - some clinical Drugs also should considered as Branded (Generic and Co-%
--need to review
DROP TABLE IF EXISTS branded_drug_to_brand_name;
CREATE TABLE branded_drug_to_brand_name AS
SELECT concept_code,
	concept_name,
	regexp_replace(regexp_replace(regexp_replace(concept_name, '\s\d.*', '', 'g'), ' \(.*', '', 'g'), '(\s(tablet(s?)|cream|capsule(s?)|gel|powder|ointment|suppositories|emollient|liquid|sachets.*|transdermal patches|infusion|solution for.*|lotion|oral solution|chewable.*|effervescent.*irrigation.*|caplets.*|oral 
|oral powder|soluble tablets sugar free|lozenges)$)', '') AS brand_name
FROM drug_concept_stage
WHERE (
		concept_class_id = 'Branded Drug'
		AND concept_name NOT LIKE 'Generic %'
		)

UNION

SELECT concept_code,
	concept_name,
	regexp_replace(concept_name, '\s.*', '', 'g') AS brand_name
FROM drug_concept_stage
WHERE concept_class_id = 'Clinical Drug'
	AND concept_name LIKE 'Co-%'

UNION

SELECT concept_code,
	concept_name,
	regexp_replace(regexp_replace(replace(concept_name, 'Generic ', ''), '\s\d.*', '', 'g'), '(\s(tablet(s?)|cream|capsule(s?)|gel|powder|ointment|suppositories|emollient|liquid|sachets.*|transdermal patches|infusion|solution for.*|lotion|oral solution|chewable.*|effervescent.*irrigation.*|caplets.*|oral drops|oral powder|soluble tablets sugar free|lozenges)$)', '') AS brand_name
FROM drug_concept_stage
WHERE concept_name LIKE 'Generic %';

DELETE
FROM branded_drug_to_brand_name a
WHERE EXISTS (
		SELECT 1
		FROM drug_concept_stage b
		WHERE lower(a.brand_name) = lower(b.concept_name)
			AND b.concept_class_id = 'Ingredient'
			AND concept_name NOT LIKE 'Co-%'
		);

DELETE
FROM branded_drug_to_brand_name a
WHERE EXISTS (
		SELECT 1
		FROM non_drug_full b
		WHERE b.concept_code = a.concept_code
		);

--manual brand_name work, finding proper patterns
DELETE
FROM branded_drug_to_brand_name
WHERE brand_name IN (
		'Zinc compound paste',
		'Yellow soft paraffin solid',
		'Wild cherry syrup',
		'Pneumococcal polysaccharide vaccine',
		'Hibicet hospital concentrate',
		'Crystal violet powder BP',
		'White soft paraffin solid',
		'Thuja occidentalis',
		'White liniment',
		'Vitamins A and D capsules BPC',
		'Vitamins',
		'Vitamin K2',
		'Vitamin E',
		'Vitamin D3',
		'Vitamin C',
		'Tri-iodothyronine',
		'Trichloroacetic acid and Salicylic acid paste',
		'Phosphates enema',
		'Tea Tree and Witch Hazel',
		'Surgical spirit',
		'Starch maize',
		'St. James Balm',
		'Squill opiate linctus paediatric',
		'Sodium DL-3-hydroxybutyrate',
		'Snake antivenin powder and solvent for',
		'Erythrocin IV lactobionate',
		'SGK Glucosamine',
		'Lycopodium clavatum',
		'Orange tincture BP',
		'Sepia officinalis',
		'Ringer lactate',
		'Rhus toxicodendron',
		'Recombinant human hyaluronidase',
		'Pulsatilla pratensis',
		'Podophyllum',
		'Phenylalanine',
		'Passiflora incarnata',
		'Oxygen cylinders',
		'Phytolacca decandra',
		'Oily phenol',
		'Levothyroxine sodium',
		'Ignatia amara',
		'Glucosamine Chondroitin Complex',
		'Gentamycin Augensalbe',
		'Gentamicin Intrathecal',
		'Gelsemium sempervirens',
		'Euphrasia officinalis',
		'Drosera rotundifolia',
		'Menthol and Eucalyptus inhalation',
		'Dried Factor VIII Fraction type',
		'Carbostesin-adrenaline',
		'Calcium and Ergocalciferol',
		'Black currant syrup',
		'Avoca wart and verruca treatment set',
		'Avena sativa comp drops',
		'Arsenicum album',
		'Arginine hydrochloride',
		'Argentum nitricum',
		'N-Acetylcysteine',
		'Fragaria / Vitis',
		'Coffea cruda',
		'Anise water concentrated',
		'Amyl nitrite vitrellae',
		'Cardamom compound tincture',
		'Amaranth solution',
		'Alpha-Lipoic Acid',
		'Actaea racemosa',
		'Aconitum napellus',
		'8-Methoxypsoralen',
		'4-Aminopyridine',
		'3,4-Diaminopyridine',
		'Adrenaline acid tartrate for anaphylaxis',
		'Paraffin hard solid',
		'Allium cepa',
		'Antidiphtheria serum',
		'Anticoagulant solution ACD-A',
		'Anticholium',
		'Anti-D',
		'Mercurius solubilis',
		'Coal tar paste',
		'Cysteamine hydrochloride',
		'Bismuth subnitrate and Iodoform paste',
		'Calcium Disodium Versenate',
		'Calendula officinalis',
		'Intraven mannitol',
		'Candida albicans',
		'Cantharis vesicatoria',
		'Chloral hydrate crystals',
		'Chloroquine sulphate',
		'Cocculus indicus',
		'Carbo vegetabilis',
		'Benzoin compound tincture',
		'Benzoic acid compound',
		'Iodoform compound paint BPC',
		'Lavender compound tincture',
		'Pyrogallol compound',
		'Wool fat solid',
		'Tragacanth compound',
		'Methylene blue',
		'Arnica',
		'Aspartate Glutamate'
		)
	OR brand_name ~ 'Zinc sulfate|Rabies vaccine|Zinc and|Water|Vitamin B compound|Thymol|Sodium|Simple linctus|Ringers|Podophyllin|Phenol|Oxygen|Morphine|Medical|Dextran|Magnesium|Macrogol|Lipofundin|Kaolin|Kalium|Ipecacuanha|Iodine|Hypurin|Hypericum|Helium cylinders|Glycerin|Glucose|Gentian|Ferric chloride|E-D3|E45|Carbon dioxide cylinders|treatment and extension course vials'
	OR brand_name ~ 'Bacillus Calmette-Guerin|Polyvalent snake antivenom|Rose water|Anticoagulant Citrate|Ammonia|Air cylinders|Ammonium chloride|Emulsifying|Ferrum|Carbomer|Alginate raft-forming|Ammonium acetate|Liquid paraffin|Acacia|Ethyl chloride|Aqueous|Beeswax|Potassium iodide|Potassium bromide|Covonia mentholated|Chalk with Opium|Calcarea|Calamine|Chloroform|Camphor|Nitrous oxide';

UPDATE branded_drug_to_brand_name
SET brand_name = regexp_replace(brand_name, '(\ssterile water inhalation solution|wort herb tincture|eye drops|sugar free|oral powder|in Orabase|Intravenous|ear drops|rectal|oral single dose|tablets|granules and solution|mouthwash|toothpaste|shampoo|sterile saline inhalation|follow on pack|initiation pack
|facewash|concentrate for|pastilles|glucose|No|inhalation|vapour|sterile saline|suspension for injection|phosphates|ear/eye/nose drops|Injectable|I.V.|preservative free|emulsion for injection)', '', 'g');

UPDATE branded_drug_to_brand_name
SET brand_name = regexp_replace(brand_name, '(\sIntra-articular / Intradermal|Intra-articular / Intramuscular|inhalant oil|powder and suspension for|powder and solvent for|oral suspension|with spacer|gel|teething|inhaler|solution|linctus|medicated sponge implant|water for irrigation|original|apple|lemon|tropical|orange|blackcurrant|ophthalmic)+', '', 'g');

UPDATE branded_drug_to_brand_name
SET brand_name = regexp_replace(brand_name, '(\ssoluble|powder spray|ear|throat|nasal|oromucosal|aerosol|water for|viasls|injection pack|initial set|maintenance set|starter pack|injection|gastro-resistant|nebuliser|pessaries|emulsion for|mixture|granules|elixir)+', '', 'g');

UPDATE branded_drug_to_brand_name
SET brand_name = regexp_replace(brand_name, '(\ssuspension enema|IV|jelly|/$|-$|emulsion and suspension for|eye|wash|ointment|skin salve|orodispersible|transdermal patches treatment|vials|vaginal|irrigation|foam enema|Methylthioninium chloride |powder enema|cutaneous emulsion|inhalation powder capsules with device|lancets|bath additive|catheter maintence|lozenges|modified-release|mouthwash|drops|gum|oral|paediatric|irrigation solution|balm|spray)+', '', 'g');

UPDATE branded_drug_to_brand_name
SET brand_name = regexp_replace(brand_name, '/eye(\s)?(.*)?|with (.*) mask|emulsion(\s)?(.*)?|vaccine(\s)?(.*)?|suspension(\s)?(.*)?|powder for(\s)?(.*)?|sodium(\s)?(.*)?|liquid(\s)?(.*)?|potassium(\s)?(.*)?|emollient(\s)?(.*)?|homeopathic(\s)?(.*)?|effervescent(\s)?(.*)?|syrup|for (.*) use', '', 'g');

UPDATE branded_drug_to_brand_name
SET brand_name = regexp_replace(brand_name, '(\s)+$', '');

UPDATE branded_drug_to_brand_name
SET brand_name = replace(brand_name, '  ', ' ');

DROP TABLE IF EXISTS br_name_list;
CREATE TABLE br_name_list AS
SELECT 'OMOP' || nextval('new_seq') AS concept_code,
	brand_name AS concept_name
FROM (
	SELECT DISTINCT brand_name
	FROM branded_drug_to_brand_name
	) AS s0;

DROP TABLE IF EXISTS drug_to_brand_name_full;
CREATE TABLE drug_to_brand_name_full AS
SELECT a.concept_code AS concept_code_1,
	b.concept_code AS concept_code_2
FROM branded_drug_to_brand_name a
JOIN br_name_list b ON a.brand_name = b.concept_name

UNION

SELECT x.concept_code_1,
	b.concept_code
FROM branded_drug_to_brand_name a
JOIN br_name_list b ON a.brand_name = b.concept_name
JOIN box_to_drug x ON x.concept_code_2 = a.concept_code;

--internal_relationship_stage
TRUNCATE TABLE internal_relationship_stage;
--Drug to ingredient
INSERT INTO internal_relationship_stage (
	concept_code_1,
	concept_code_2
	)
SELECT DISTINCT drug_concept_code,
	ingredient_concept_code
FROM ds_stage;

--Drug to Form
INSERT INTO internal_relationship_stage (
	concept_code_1,
	concept_code_2
	)
SELECT DISTINCT concept_code_1,
	concept_code_2
FROM dr_to_dose_form_full
WHERE concept_code_1 NOT IN (
		SELECT pack_concept_code
		FROM pc_stage
		);

--Drug to Brand Name 
INSERT INTO internal_relationship_stage (
	concept_code_1,
	concept_code_2
	)
SELECT DISTINCT a.concept_code_1,
	a.concept_code_2
FROM drug_to_brand_name_full a;

--Drug to manufacturer
INSERT INTO internal_relationship_stage (
	concept_code_1,
	concept_code_2
	)
SELECT DISTINCT concept_code_1,
	concept_code_2
FROM drug_to_manufact_2;

--Ingred to Ingred, for now Ingred to Ingred relationship is considered only as Maps to 
INSERT INTO internal_relationship_stage (
	concept_code_1,
	concept_code_2
	)
SELECT DISTINCT concept_code_1,
	concept_code_2
FROM ingr_to_ingr -- deprecated to active relationship already included here
WHERE concept_code_2 IS NOT NULL;

INSERT INTO internal_relationship_stage (
	concept_code_1,
	concept_code_2
	)
SELECT concept_code_1,
	concept_code_2
FROM deprec_to_active
WHERE concept_class_id != 'Ingredient';

--relationship_to_concept
--mappings and insertion into standard tables
TRUNCATE TABLE relationship_to_concept;

--Ingredients mapping
DROP TABLE IF EXISTS stand_ingr_map;
CREATE TABLE stand_ingr_map AS
SELECT DISTINCT b.concept_code_1,
	a.concept_id_2,
	a.precedence
FROM ingr_to_ingr b --manual table
JOIN ingr_to_rx a -- !!! semi-automatically created table 
	ON a.concept_code_1 = b.concept_code_1
WHERE b.concept_code_2 IS NULL
	AND a.concept_id_2 IS NOT NULL;

--Ingredients mapping, make mapping only for standard ingrediets
INSERT INTO relationship_to_concept (
	concept_code_1,
	vocabulary_id_1,
	concept_id_2,
	precedence
	)
SELECT DISTINCT concept_code_1,
	'dm+d',
	concept_id_2,
	precedence
FROM stand_ingr_map;

-- dose form mapping
INSERT INTO relationship_to_concept (
	concept_code_1,
	vocabulary_id_1,
	concept_id_2,
	precedence
	)
SELECT DISTINCT concept_code,
	'dm+d',
	concept_id_2,
	precedence
FROM AUT_FORM_ALL_MAPPED -- !!! fully manual 
WHERE concept_id_2 IS NOT NULL;

-- units mapping, --don't need to recreate now
/*
--!!!
 create table unit_for_ucum as  (
 select distinct amount_unit,concept_id_2,concept_name_2,conversion_factor,precedence,concept_id,concept_name as ucum_concept_name from (  select distinct amount_unit from ds_all_cl_dr
 union 
 select distinct numerator_unit from ds_all_cl_dr
 union
 select distinct denominator_unit from ds_all_cl_dr) a 
 left join dev_amis.AUT_UNIT_ALL_MAPPED b on lower(a.amount_unit)=lower(b.concept_code) 
 left join devv5.concept c on lower(c.concept_name)=lower(a.amount_unit) and vocabulary_id='UCUM' and invalid_reason is null);
 update  unit_for_ucum 
 set concept_id_2=concept_id where concept_id is not null;
DELETE FROM UNIT_FOR_UCUM  WHERE amount_unit IS NULL AND   concept_id_2 IS NULL AND   concept_name_2 IS NULL  AND   conversion_factor IS NULL  AND   precedence IS NULL  AND   concept_id IS NULL AND   UCUM_concept_name IS NULL;
DELETE FROM UNIT_FOR_UCUM  WHERE amount_unit = 'dose' AND   concept_id_2 IS NULL AND   concept_name_2 IS NULL  AND   conversion_factor IS NULL  AND   precedence IS NULL  AND   concept_id IS NULL AND   UCUM_concept_name IS NULL;
DELETE FROM UNIT_FOR_UCUM  WHERE amount_unit = 'molar' AND   concept_id_2 IS NULL AND   concept_name_2 IS NULL  AND   conversion_factor IS NULL  AND   precedence IS NULL  AND   concept_id IS NULL AND   UCUM_concept_name IS NULL;
UPDATE UNIT_FOR_UCUM   SET concept_id_2 = 8510,       concept_name_2 = 'unit',       precedence = 1 WHERE amount_unit = ' Kallikrein inactivator units' AND   concept_id_2 IS NULL AND   concept_name_2 IS NULL AND   conversion_factor IS NULL AND   precedence IS NULL AND   concept_id IS NULL AND   UCUM_concept_name IS NULL;
UPDATE UNIT_FOR_UCUM   SET concept_id_2 = 8576,       concept_name_2 = 'milligram',       conversion_factor = 1000,       precedence = 1 WHERE amount_unit = 'gram' AND   concept_id_2 = 8504 AND   concept_name_2 IS NULL AND   conversion_factor IS NULL AND   precedence IS NULL AND   concept_id = 8504 AND   UCUM_concept_name = 'gram';
UPDATE UNIT_FOR_UCUM   SET concept_id_2 = 8505,       concept_name_2 = 'hour',       conversion_factor = 1,       precedence = 1 WHERE amount_unit = 'hours' AND   concept_id_2 IS NULL AND   concept_name_2 IS NULL AND   conversion_factor IS NULL AND   precedence IS NULL AND   concept_id IS NULL AND   UCUM_concept_name IS NULL;
UPDATE UNIT_FOR_UCUM   SET concept_id_2 = 45891008,       concept_name_2 = 'kilobecquerel',       precedence = 1 WHERE amount_unit = 'kBq' AND   concept_id_2 IS NULL AND   concept_name_2 IS NULL AND   conversion_factor IS NULL AND   precedence IS NULL AND   concept_id IS NULL AND   UCUM_concept_name IS NULL;
UPDATE UNIT_FOR_UCUM   SET concept_id_2 = 8519,       concept_name_2 = 'liter',       conversion_factor = 1,       precedence = 2 WHERE amount_unit = 'litre' AND   concept_id_2 IS NULL AND   concept_name_2 IS NULL AND   conversion_factor IS NULL AND   precedence IS NULL AND   concept_id IS NULL AND   UCUM_concept_name IS NULL;
UPDATE UNIT_FOR_UCUM   SET concept_id_2 = 9655,       concept_name_2 = 'microgram',       conversion_factor = 2,       precedence = 1 WHERE amount_unit = 'mcg' AND   concept_id_2 IS NULL AND   concept_name_2 IS NULL AND   conversion_factor IS NULL AND   precedence IS NULL AND   concept_id IS NULL AND   UCUM_concept_name IS NULL;
UPDATE UNIT_FOR_UCUM   SET concept_name_2 = 'microgram',       conversion_factor = 1,       precedence = 2 WHERE amount_unit = 'microgram' AND   concept_id_2 = 9655 AND   concept_name_2 IS NULL AND   conversion_factor IS NULL AND   precedence IS NULL AND   concept_id = 9655 AND   UCUM_concept_name = 'microgram';
UPDATE UNIT_FOR_UCUM   SET concept_id_2 = 9655,       concept_name_2 = 'microgram',       conversion_factor = 1,       precedence = 2 WHERE amount_unit = 'micrograms' AND   concept_id_2 IS NULL AND   concept_name_2 IS NULL AND   conversion_factor IS NULL AND   precedence IS NULL AND   concept_id IS NULL AND   UCUM_concept_name IS NULL;
UPDATE UNIT_FOR_UCUM   SET concept_id_2 = 8587,       concept_name_2 = 'milliliter',       conversion_factor = 0.001,       precedence = 1 WHERE amount_unit = 'microlitres' AND   concept_id_2 IS NULL AND   concept_name_2 IS NULL AND   conversion_factor IS NULL AND   precedence IS NULL AND   concept_id IS NULL AND   UCUM_concept_name IS NULL;
UPDATE UNIT_FOR_UCUM   SET concept_name_2 = 'Million unit',       conversion_factor = 1,       precedence = 2 WHERE amount_unit = 'million unit' AND   concept_id_2 = 9689 AND   concept_name_2 IS NULL AND   conversion_factor IS NULL AND   precedence IS NULL AND   concept_id = 9689 AND   UCUM_concept_name = 'Million unit';
UPDATE UNIT_FOR_UCUM   SET concept_id_2 = 8587,       concept_name_2 = 'milliliter',       conversion_factor = 1,       precedence = 1 WHERE amount_unit = 'ml ' AND   concept_id_2 IS NULL AND   concept_name_2 IS NULL AND   conversion_factor IS NULL AND   precedence IS NULL AND   concept_id IS NULL AND   UCUM_concept_name IS NULL;
UPDATE UNIT_FOR_UCUM   SET concept_id_2 = 9573,       concept_name_2 = 'millimole',       conversion_factor = 1,       precedence = 1 WHERE amount_unit = 'mmol' AND   concept_id_2 IS NULL AND   concept_name_2 IS NULL AND   conversion_factor IS NULL AND   precedence IS NULL AND   concept_id IS NULL AND   UCUM_concept_name IS NULL;
UPDATE UNIT_FOR_UCUM   SET concept_name_2 = 'nanogram',       conversion_factor = 1,       precedence = 2 WHERE amount_unit = 'nanogram' AND   concept_id_2 = 9600 AND   concept_name_2 IS NULL AND   conversion_factor IS NULL AND   precedence IS NULL AND   concept_id = 9600 AND   UCUM_concept_name = 'nanogram';
UPDATE UNIT_FOR_UCUM   SET concept_id_2 = 9600,       concept_name_2 = 'nanogram',       conversion_factor = 1,       precedence = 2 WHERE amount_unit = 'nanograms' AND   concept_id_2 IS NULL AND   concept_name_2 IS NULL AND   conversion_factor IS NULL AND   precedence IS NULL AND   concept_id IS NULL AND   UCUM_concept_name IS NULL;
UPDATE UNIT_FOR_UCUM   SET concept_name_2 = 'unit',       conversion_factor = 1,       precedence = 1 WHERE amount_unit = 'unit' AND   concept_id_2 = 8510 AND   concept_name_2 IS NULL AND   conversion_factor IS NULL AND   precedence IS NULL AND   concept_id = 8510 AND   UCUM_concept_name = 'unit';
UPDATE UNIT_FOR_UCUM   SET concept_id_2 = 8510,       concept_name_2 = 'unit',       precedence = 1 WHERE amount_unit = 'units' AND   concept_id_2 IS NULL AND   concept_name_2 IS NULL AND   conversion_factor IS NULL AND   precedence IS NULL AND   concept_id IS NULL AND   UCUM_concept_name IS NULL;
INSERT INTO UNIT_FOR_UCUM(  amount_unit,  concept_id_2,  concept_name_2,  conversion_factor,  precedence,  concept_id,  UCUM_concept_name)VALUES(  'litre',  8587,  'milliliter',  0.001,  1,  NULL,  NULL);
INSERT INTO UNIT_FOR_UCUM(  amount_unit,  concept_id_2,  concept_name_2,  conversion_factor,  precedence,  concept_id,  UCUM_concept_name)VALUES(  'microgram',  8576,  'milligram',  0.001,  1,  NULL,  NULL);
INSERT INTO UNIT_FOR_UCUM(  amount_unit,  concept_id_2,  concept_name_2,  conversion_factor,  precedence,  concept_id,  UCUM_concept_name)VALUES(  'micrograms',  8576,  'milligram',  0.001,  1,  NULL,  NULL);
INSERT INTO UNIT_FOR_UCUM(  amount_unit,  concept_id_2,  concept_name_2,  conversion_factor,  precedence,  concept_id,  UCUM_concept_name)VALUES(  'microlitres',  9665,  'microliter',  1,  2,  NULL,  NULL);
INSERT INTO UNIT_FOR_UCUM(  amount_unit,  concept_id_2,  concept_name_2,  conversion_factor,  precedence,  concept_id,  UCUM_concept_name)VALUES(  'million unit',  8510,  'unit',  1000000,  1,  NULL,  NULL);
INSERT INTO UNIT_FOR_UCUM(  amount_unit,  concept_id_2,  concept_name_2,  conversion_factor,  precedence,  concept_id,  UCUM_concept_name)VALUES(  'nanogram',  8576,  'milligram',  0.000001,  1,  NULL,  NULL);
INSERT INTO UNIT_FOR_UCUM(  amount_unit,  concept_id_2,  concept_name_2,  conversion_factor,  precedence,  concept_id,  UCUM_concept_name)VALUES(  'nanograms',  8576,  'milligram',  0.000001,  1,  NULL,  NULL);
INSERT INTO UNIT_FOR_UCUM(  amount_unit,  concept_id_2,  concept_name_2,  conversion_factor,  precedence,  concept_id,  UCUM_concept_name)VALUES(  'mcg',  8576,  'milligram',  0.001,  1,  NULL,  NULL);
*/
DROP TABLE IF EXISTS unit_for_ucum_done;
CREATE TABLE unit_for_ucum_done --final table for internal relationship
	AS
SELECT amount_unit AS concept_name_1,
	amount_unit AS concept_code_1,
	concept_id_2,
	concept_name_2,
	conversion_factor,
	precedence
FROM unit_for_ucum;

--units mapping
INSERT INTO relationship_to_concept (
	concept_code_1,
	vocabulary_id_1,
	concept_id_2,
	precedence,
	conversion_factor
	)
SELECT DISTINCT concept_code_1,
	'dm+d',
	concept_id_2,
	precedence,
	conversion_factor
FROM unit_for_ucum_done; -- manual table, creation is above

--Brand names mapping
--name full equality
DROP TABLE IF EXISTS brand_name_map;
CREATE TABLE brand_name_map AS
SELECT a.*,
	c.concept_id,
	c.concept_name
FROM (
	SELECT DISTINCT brand_name
	FROM branded_drug_to_brand_name
	) a
LEFT JOIN concept c ON upper(a.brand_name) = upper(c.concept_name)
	AND c.vocabulary_id = 'RxNorm'
	AND c.concept_class_id = 'Brand Name'
	AND invalid_reason IS NULL;

/*
drop table Brands_by_Lena; --!!!
create table Brands_by_Lena 
(
brand_name	varchar (250),	concept_id int,	concept_name_2 varchar (250)
)
WbImport -file=C:/mappings/DM+D/brand_names_by_Lena.txt
         -type=text
         -table=BRANDS_BY_LENA
         -encoding="ISO-8859-15"
         -header=true
         -decode=false
         -dateFormat="yyyy-MM-dd"
         -timestampFormat="yyyy-MM-dd HH:mm:ss"
         -delimiter='\t'
         -decimal=.
         -fileColumns=brand_name,concept_id,concept_name_2
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=false
         -continueOnError=false;
         */
;
drop table brand_name_map_full;
CREATE TABLE brand_name_map_full AS
SELECT brand_name,
	concept_id,
	concept_name
FROM brand_name_map
WHERE concept_id IS NOT NULL

UNION

SELECT *
FROM brands_by_lena;

DELETE
FROM brand_name_map_full
WHERE concept_id IN (
		40062307,
		19059723
		); -- deprecated concepts

--brand names mapping
INSERT INTO relationship_to_concept (
	concept_code_1,
	vocabulary_id_1,
	concept_id_2
	)
SELECT DISTINCT b.concept_code,
	'dm+d',
	concept_id
FROM brand_name_map_full a
JOIN br_name_list b ON a.brand_name = b.concept_name;

--new ingredients mapping
INSERT INTO relationship_to_concept (
	concept_code_1,
	vocabulary_id_1,
	concept_id_2,
	precedence,
	conversion_factor
	)
SELECT DISTINCT INGR_CODE,
	'dm+d',
	rxnorm_id::INT,
	1,
	NULL::FLOAT
FROM lost_ingr_to_rx_with_omop;

INSERT INTO relationship_to_concept (
	concept_code_1,
	vocabulary_id_1,
	concept_id_2,
	precedence,
	conversion_factor
	)
VALUES (
	'OMOP18',
	'dm+d',
	798336,
	1,
	NULL
	);

INSERT INTO relationship_to_concept (
	concept_code_1,
	vocabulary_id_1,
	concept_id_2,
	precedence,
	conversion_factor
	)
VALUES (
	'OMOP17',
	'dm+d',
	902251,
	1,
	NULL
	);

--fix duplicates
DELETE
FROM relationship_to_concept i
WHERE EXISTS (
		SELECT 1
		FROM relationship_to_concept i_int
		WHERE i_int.concept_code_1 = i.concept_code_1
			AND i_int.vocabulary_id_1 = i.vocabulary_id_1
			AND i_int.concept_id_2 = i.concept_id_2
			AND coalesce(i_int.precedence, - 1) = coalesce(i.precedence, - 1)
			AND coalesce(i_int.conversion_factor, - 1) = coalesce(i.conversion_factor, - 1)
			AND i_int.ctid > i.ctid
		);

DELETE
FROM relationship_to_concept
WHERE concept_code_1 = '17644011000001108'
	AND concept_id_2 = 46234468
	AND precedence = 7;

DELETE
FROM relationship_to_concept
WHERE concept_code_1 = '385197005'
	AND concept_id_2 = 19126918
	AND precedence IS NULL;

--ATC concepts 
DROP TABLE IF EXISTS clinical_to_atc;
CREATE TABLE clinical_to_atc AS
SELECT --distinct a.concept_class_id
	a.concept_code AS concept_code_1,
	a.concept_name AS concept_name_1,
	d.concept_id AS concept_id_2,
	d.concept_name AS concept_name_2
FROM drug_concept_stage a
JOIN concept c ON a.concept_code = c.concept_code
	AND c.vocabulary_id = 'SNOMED'
JOIN concept_relationship r ON r.concept_id_1 = c.concept_id
JOIN concept d ON r.concept_id_2 = d.concept_id
	AND d.vocabulary_id = 'ATC'
WHERE a.concept_class_id LIKE '%Drug%';

DROP TABLE IF EXISTS clinical_to_atc_2;
CREATE TABLE clinical_to_atc_2 AS
SELECT DISTINCT a.concept_code_1,
	a.concept_name_1,
	b.concept_id_2,
	b.concept_name_2
FROM box_to_drug a
JOIN clinical_to_atc b ON a.concept_code_2 = b.concept_code_1

UNION

SELECT *
FROM clinical_to_atc;

DROP TABLE IF EXISTS clinical_to_atc_full ;
CREATE TABLE clinical_to_atc_full AS
--branded drug
SELECT DISTINCT a.concept_code_1,
	a.concept_name_1,
	b.concept_id_2,
	b.concept_name_2
FROM branded_to_clinical a
JOIN clinical_to_atc_2 b ON a.concept_code_2 = b.concept_code_1

UNION

SELECT *
FROM clinical_to_atc_2;

INSERT INTO relationship_to_concept (
	concept_code_1,
	vocabulary_id_1,
	concept_id_2
	)
SELECT DISTINCT concept_code_1,
	'dm+d',
	concept_id_2
FROM clinical_to_atc_full;

--drug_concept_stage, take version from back-up
UPDATE drug_concept_stage
SET domain_id = 'Device',
	concept_class_id = 'Device'
WHERE concept_code IN (
		SELECT concept_code
		FROM non_drug_full
		);

UPDATE drug_concept_stage
SET domain_id = 'Device',
	concept_class_id = 'Device'
WHERE concept_code IN (
		'3378311000001103',
		'3378411000001105'
		);

DELETE
FROM ds_stage
WHERE EXISTS (
		SELECT 1
		FROM drug_concept_stage
		WHERE drug_concept_code = concept_code
			AND domain_id = 'Device'
		);

UPDATE drug_concept_stage
SET domain_id = 'Drug'
WHERE domain_id != 'Device';

--newly generated concepts 
--Brand Names
INSERT INTO drug_concept_stage (
	concept_name,
	domain_id,
	vocabulary_id,
	concept_class_id,
	standard_concept,
	concept_code,
	valid_start_date,
	valid_end_date,
	invalid_reason,
	source_concept_class_id
	)
SELECT DISTINCT concept_name,
	'Drug',
	'dm+d',
	'Brand Name',
	NULL,
	concept_code,
	TO_DATE('19700101', 'yyyymmdd'),
	TO_DATE('20991231', 'yyyymmdd'),
	NULL,
	'Brand Name'
FROM br_name_list;

--NEW Ingredients
INSERT INTO drug_concept_stage (
	concept_name,
	domain_id,
	vocabulary_id,
	concept_class_id,
	standard_concept,
	concept_code,
	valid_start_date,
	valid_end_date,
	invalid_reason,
	source_concept_class_id
	)
SELECT DISTINCT concept_name_1,
	'Drug',
	'dm+d',
	'Ingredient',
	'S',
	concept_code_1,
	TO_DATE('19700101', 'yyyymmdd'),
	TO_DATE('20991231', 'yyyymmdd'),
	NULL,
	'Ingredient'
FROM ingr_to_ingr
WHERE concept_code_1 LIKE 'OMOP%';

--NEW Forms
INSERT INTO drug_concept_stage (
	concept_name,
	domain_id,
	vocabulary_id,
	concept_class_id,
	standard_concept,
	concept_code,
	valid_start_date,
	valid_end_date,
	invalid_reason,
	source_concept_class_id
	)
SELECT DISTINCT concept_name_2,
	'Drug',
	'dm+d',
	'Dose Form',
	NULL,
	concept_code_2,
	TO_DATE('19700101', 'yyyymmdd'),
	TO_DATE('20991231', 'yyyymmdd'),
	NULL,
	'Form'
FROM dr_to_dose_form_full
WHERE concept_code_2 LIKE 'OMOP%';

--NEW Pack components 
INSERT INTO drug_concept_stage (
	concept_name,
	domain_id,
	vocabulary_id,
	concept_class_id,
	standard_concept,
	concept_code,
	valid_start_date,
	valid_end_date,
	invalid_reason,
	source_concept_class_id
	)
SELECT DISTINCT drug_new_name,
	'Drug',
	'dm+d',
	'Drug Product',
	'S',
	drug_code,
	TO_DATE('19700101', 'yyyymmdd'),
	TO_DATE('20991231', 'yyyymmdd'),
	NULL,
	'VMP'
FROM pack_drug_to_code_2_2
WHERE drug_code LIKE 'OMOP%';

--add units 
INSERT INTO drug_concept_stage (
	concept_name,
	domain_id,
	vocabulary_id,
	concept_class_id,
	standard_concept,
	concept_code,
	valid_start_date,
	valid_end_date,
	invalid_reason,
	source_concept_class_id
	)
SELECT DISTINCT concept_name_1,
	'Unit',
	'dm+d',
	'Unit',
	NULL,
	concept_code_1,
	TO_DATE('19700101', 'yyyymmdd'),
	TO_DATE('20991231', 'yyyymmdd'),
	NULL,
	'Unit'
FROM unit_for_ucum_done;

--proper 'S'
UPDATE drug_concept_stage
SET standard_concept = 'S'
WHERE (
		concept_class_id LIKE '%Drug%'
		OR concept_class_id LIKE 'Device'
		)
	AND invalid_reason IS NULL
	OR concept_code IN (
		SELECT concept_code_1
		FROM ingr_to_ingr
		WHERE concept_code_2 IS NULL
		);--"standard ingredient"

--add newly created ingredients
INSERT INTO drug_concept_stage (
	concept_name,
	domain_id,
	vocabulary_id,
	concept_class_id,
	standard_concept,
	concept_code,
	valid_start_date,
	valid_end_date,
	invalid_reason,
	source_concept_class_id
	)
SELECT DISTINCT ingr_name,
	'Drug',
	'dm+d',
	'Ingredient',
	'S',
	ingr_code,
	TO_DATE('19700101', 'yyyymmdd'),
	TO_DATE('20991231', 'yyyymmdd'),
	NULL,
	'Ingredient'
FROM lost_ingr_to_rx_with_OMOP
WHERE ingr_code != 'OMOP18';

--make ingredients that don't have replacement "Standard"
UPDATE drug_concept_stage
SET standard_concept = 'S'
WHERE concept_code IN (
		SELECT concept_code
		FROM drug_concept_stage
		LEFT JOIN internal_relationship_stage ON concept_code_1 = concept_code
		WHERE concept_class_id = 'Ingredient'
			AND standard_concept IS NULL
			AND concept_code_2 IS NULL
		);

--it's OK, classes used in algorihms
UPDATE drug_concept_stage
SET concept_class_id = 'Drug Product'
WHERE concept_class_id LIKE '%Pack%'
	OR concept_class_id LIKE '%Drug%';

DELETE
FROM relationship_to_concept
WHERE concept_code_1 = '278910002'
	AND concept_id_2 = 1352213
	AND precedence IS NULL;

--1
UPDATE ds_stage b
SET box_size = i.box_size
FROM (
	SELECT substring(concept_name, '(\d+) ampoule')::INT AS box_size,
		a.concept_code
	FROM drug_concept_stage a
	WHERE concept_name ~ '\d+ ampoule'
	) i
WHERE b.drug_concept_code = i.concept_code
	AND b.box_size IS NULL;

--delete impossible combinations from ds_stage, treat these drugs as Clinical/Branded Drug Form
DELETE
FROM ds_stage a
WHERE numerator_unit IS NULL
	AND numerator_value IS NOT NULL;

UPDATE ds_stage a
SET amount_unit = NULL,
	amount_value = NULL,
	numerator_value = amount_value,
	numerator_unit = amount_unit
WHERE amount_value IS NOT NULL
	AND denominator_value IS NOT NULL;

UPDATE ds_stage
SET numerator_unit = 'ml'
WHERE drug_concept_code = '8055111000001105'
	AND ingredient_concept_code = '10569311000001100';

UPDATE ds_stage
SET numerator_unit = 'ml'
WHERE drug_concept_code = '14779411000001100'
	AND ingredient_concept_code = '80582002';

/* -- what the hell is this query?
select count (distinct drug_concept_code) from (
select drug_concept_code from ds_stage a
where amount_value is null and numerator_value is null and denominator_value is not null
union 
select drug_concept_code from ds_stage a
where amount_value is null and numerator_value is  null and box_size is not null
union
select drug_concept_code from ds_stage a 
join internal_relationship_stage b on a.drug_concept_code = b.concept_code_1 
join drug_concept_stage c on c.concept_code = b.concept_code_2
where amount_value is null and numerator_value is null
and c.concept_class_id = 'Supplier'
)
;
*/

--change amount to denominator_value when there is a solid form
UPDATE ds_stage ds
SET amount_value = denominator_value,
	amount_unit = denominator_unit,
	denominator_value = NULL,
	denominator_unit = NULL
WHERE EXISTS (
		SELECT 1
		FROM internal_relationship_stage ir
		JOIN drug_concept_stage c ON c.concept_code = ir.concept_code_2
		JOIN drug_concept_stage c1 ON c1.concept_code = ir.concept_code_1
		JOIN (
			SELECT drug_concept_code
			FROM ds_stage
			GROUP BY drug_concept_code
			HAVING count(*) = 1
			) z ON ir.concept_code_1 = z.drug_concept_code
			AND c.concept_class_id = 'Dose Form'
		WHERE amount_value IS NULL
			AND numerator_value IS NULL
			AND denominator_value IS NOT NULL
			AND c.concept_code IN (
				--all solid forms
				'3095811000001106',
				'385049006',
				'420358004',
				'385043007',
				'385045000',
				'85581007',
				'421079001',
				'385042002',
				'385054002',
				'385052003',
				'385087003'
				)
			AND ir.concept_code_1 = ds.drug_concept_code
		)
	AND denominator_unit != 'g';

DROP TABLE IF EXISTS ds_brand_update;
CREATE TABLE ds_brand_update AS
SELECT concept_code_1,
	concept_name_1
FROM branded_to_clinical
JOIN drug_concept_stage ON concept_code_1 = concept_code
	AND domain_id = 'Drug'
	AND invalid_reason IS NULL
JOIN (
	SELECT drug_concept_code
	FROM ds_stage
	WHERE amount_value IS NULL
		AND numerator_value IS NULL
	GROUP BY drug_concept_code
	HAVING count(*) = 1
	) ds ON ds.drug_concept_code = concept_code_1
WHERE concept_name_1 ~ '[[:digit:]\,\.]+(mg|%|ml|mcg|hr|hours|unit(s?)|iu|g|microgram(s*)|u|mmol|c|gm|litre|million unit(s?)|nanogram(s)*|x|ppm| Kallikrein inactivator units|kBq|microlitres|MBq|molar|micromol|million units)/*[[:digit:]\,\.]*(g|dose|ml|mg|ampoule|litre|hour(s)*|h|square cm|microlitres)*'
	AND NOT concept_name_2 ~ '[[:digit:]\,\.]+(mg|%|ml|mcg|hr|hours|unit(s?)|iu|g|microgram(s*)|u|mmol|c|gm|litre|million unit(s?)|nanogram(s)*|x|ppm| Kallikrein inactivator units|kBq|microlitres|MBq|molar|micromol|million units)/*[[:digit:]\,\.]*(g|dose|ml|mg|ampoule|litre|hour(s)*|h|square cm|microlitres)*';

UPDATE ds_stage
SET amount_value = (
		SELECT substring(concept_name_1, '([[:digit:],.]+)(mg|g|microgram(s)*|million unit(s*))')::FLOAT
		FROM ds_brand_update
		WHERE concept_code_1 = drug_concept_code
		),
	amount_unit = (
		SELECT substring(concept_name_1, '[[:digit:],.]+((mg|g|microgram(s)*|million unit(s*)))')
		FROM ds_brand_update
		WHERE concept_code_1 = drug_concept_code
		)
WHERE EXISTS (
		SELECT 1
		FROM ds_brand_update
		WHERE concept_code_1 = drug_concept_code
		)
	AND drug_concept_code NOT IN (
		'16636811000001107',
		'16636911000001102',
		'15650711000001103',
		'15651111000001105'
		) --Packs and vaccines
	;

--select * from ds_stage where drug_concept_code  in ('16636811000001107', '16636911000001102', '15650711000001103', '15651111000001105' );
DO $$
DECLARE
	ex INTEGER;
BEGIN
	SELECT MAX(replace(concept_code, 'OMOP','')::int4)+1 into ex FROM (
		SELECT concept_code FROM concept WHERE concept_code like 'OMOP%'  and concept_code not like '% %' -- Last valid value of the OMOP123-type codes
		UNION ALL
		SELECT concept_code FROM drug_concept_stage where concept_code like 'OMOP%' and concept_code not like '% %' -- Last valid value of the OMOP123-type codes
	) AS s0;
	DROP SEQUENCE IF EXISTS new_vocab;
	EXECUTE 'CREATE SEQUENCE new_vocab INCREMENT BY 1 START WITH ' || ex || ' NO CYCLE CACHE 20';
END$$;

DROP TABLE IF EXISTS code_replace;
CREATE TABLE code_replace AS
SELECT dcs.concept_code AS old_code,
	coalesce(c.concept_code, 'OMOP' || nextval('new_vocab')) AS new_code
FROM drug_concept_stage dcs
LEFT JOIN concept c ON c.concept_name = dcs.concept_name
	AND dcs.concept_class_id = c.concept_class_id
	AND coalesce(c.invalid_reason, '1') = coalesce(dcs.invalid_reason, '1')
	AND dcs.vocabulary_id = c.vocabulary_id
WHERE dcs.concept_code LIKE 'OMOP%';

 /*
drop table code_replace_exp;
 create table code_replace_exp as 
select dcs.concept_code as old_code, nvl (c.concept_code, 'OMOP'||new_vocab.nextval ) as new_code   from drug_concept_stage dcs
left join concept c on lower (c.concept_name)  = lower (dcs.concept_name) and dcs.concept_class_id = c.concept_class_id and nvl (c.invalid_reason, '1') = nvl (dcs.invalid_reason, '1') and dcs.vocabulary_id = c.vocabulary_id 
where dcs.concept_code like 'OMOP%' 
 ;
select count(*) from code_replace_exp -- 7033 -why?
minus 
select count(*) from code_replace --7029
;
select *  from drug_concept_stage dcs
left join concept c on c.concept_name  = dcs.concept_name and dcs.concept_class_id = c.concept_class_id and nvl (c.invalid_reason, '1') = nvl (dcs.invalid_reason, '1') and dcs.vocabulary_id = c.vocabulary_id  
join (
select old_code from code_replace group by old_code having count (1) >1
) z on old_code = dcs.concept_code
where  dcs.concept_code like 'OMOP%'
;
select concept_code from drug_concept_stage group by concept_code having count (1) >1
;
 */

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

--how the hell I got duplicates here??
DELETE
FROM relationship_to_concept i
WHERE EXISTS (
		SELECT 1
		FROM relationship_to_concept i_int
		WHERE i_int.concept_code_1 = i.concept_code_1
			AND i_int.vocabulary_id_1 = i.vocabulary_id_1
			AND i_int.concept_id_2 = i.concept_id_2
			AND coalesce(i_int.precedence, - 1) = coalesce(i.precedence, - 1)
			AND coalesce(i_int.conversion_factor, - 1) = coalesce(i.conversion_factor, - 1)
			AND i_int.ctid > i.ctid
		);

UPDATE ds_stage
SET amount_value = 12.5,
	amount_unit = 'mg'
WHERE drug_concept_code = '18988111000001104'
	AND ingredient_concept_code = '387525002';

UPDATE drug_concept_stage
SET source_concept_class_id = 'Supplier'
WHERE concept_class_id = 'Supplier';

--update ds_stage changing % to mg/ml, mg/g, etc.
--simple, when we have denominator_unit so we can define numerator based on denominator_unit
UPDATE ds_stage
SET numerator_value = denominator_value * numerator_value * 10,
	numerator_unit = 'mg'
WHERE numerator_unit = '%'
	AND denominator_unit IN (
		'ml',
		'gram',
		'g'
		);

UPDATE ds_stage
SET numerator_value = denominator_value * numerator_value * 0.01,
	numerator_unit = 'mg'
WHERE numerator_unit = '%'
	AND denominator_unit IN ('mg');

UPDATE ds_stage
SET numerator_value = denominator_value * numerator_value * 10,
	numerator_unit = 'g'
WHERE numerator_unit = '%'
	AND denominator_unit IN ('litre');

--use relationship between drug boxes ( Quant drugs) and Clinical (Branded) Drugs
UPDATE ds_stage ds
SET numerator_value = numerator_value * 10,
	numerator_unit = 'mg',
	denominator_unit = 'g'
WHERE EXISTS (
		SELECT 1
		FROM box_to_drug b
		JOIN ds_stage ds2 ON ds2.drug_concept_code = b.concept_code_1
		WHERE ds2.ingredient_concept_code = ds.ingredient_concept_code
			AND ds.drug_concept_code = b.concept_code_2
			AND ds.numerator_unit = '%'
			AND ds2.numerator_unit != '%'
			AND ds2.denominator_unit IN (
				'gram',
				'g'
				)
		);

UPDATE ds_stage ds
SET numerator_value = numerator_value * 10,
	numerator_unit = 'mg',
	denominator_unit = 'ml'
WHERE EXISTS (
		SELECT 1
		FROM box_to_drug b
		JOIN ds_stage ds2 ON ds2.drug_concept_code = b.concept_code_1
		WHERE ds2.ingredient_concept_code = ds.ingredient_concept_code
			AND ds.drug_concept_code = b.concept_code_2
			AND ds.numerator_unit = '%'
			AND ds2.numerator_unit != '%'
			AND ds2.denominator_unit IN ('ml')
		);

UPDATE ds_stage ds
SET numerator_value = numerator_value * 10,
	numerator_unit = 'mg',
	denominator_unit = 'g'
WHERE EXISTS (
		SELECT 1
		FROM box_to_drug b
		JOIN ds_stage ds2 ON ds2.drug_concept_code = b.concept_code_1
		WHERE ds2.ingredient_concept_code = ds.ingredient_concept_code
			AND ds.drug_concept_code = b.concept_code_2
			AND ds.numerator_unit = '%'
			AND ds2.numerator_unit != '%'
			AND ds2.denominator_unit IN ('litre')
		);

--some drugs don't have such a relationships or drug boxes ( Quant drugs) still don't have Quant info required
--if denominator is still null, means that drug box also doesn't contain quant factor, mg/ml is not a default , make analysis using concept_name
UPDATE ds_stage ds
SET numerator_value = numerator_value * 10,
	numerator_unit = 'mg',
	denominator_unit = 'ml'
WHERE numerator_unit = '%'
	AND denominator_unit IS NULL
	AND denominator_value IS NULL
	AND EXISTS (
		SELECT 1
		FROM drug_concept_stage dcs
		WHERE dcs.concept_code = ds.drug_concept_code
			AND concept_name ~ 'vial|drops|foam'
		);

--weigth / weight
UPDATE ds_stage ds
SET numerator_value = numerator_value * 10,
	numerator_unit = 'mg',
	denominator_unit = 'g'
WHERE numerator_unit = '%'
	AND denominator_unit IS NULL
	AND denominator_value IS NULL
	AND EXISTS (
		SELECT 1
		FROM drug_concept_stage dcs
		WHERE dcs.concept_code = ds.drug_concept_code
			AND NOT concept_name ~ 'vial|drops|foam'
		);

--manual changes ds_stage
--sum 
DELETE
FROM ds_stage
WHERE drug_concept_code = '20173311000001101'
	AND ingredient_concept_code = 'OMOP245707'
	AND numerator_value = 7;

DELETE
FROM ds_stage
WHERE drug_concept_code = '20173111000001103'
	AND ingredient_concept_code = 'OMOP245707'
	AND numerator_value = 7;

DELETE
FROM ds_stage
WHERE drug_concept_code = '20345511000001104'
	AND ingredient_concept_code = 'OMOP245707'
	AND numerator_value = 7;

UPDATE ds_stage
SET numerator_value = 22.4
WHERE drug_concept_code = '20345511000001104'
	AND ingredient_concept_code = 'OMOP245707'
	AND numerator_value = 15.4;

UPDATE ds_stage
SET numerator_value = 22.4
WHERE drug_concept_code = '20173111000001103'
	AND ingredient_concept_code = 'OMOP245707'
	AND numerator_value = 15.4;

UPDATE ds_stage
SET numerator_value = 22.4
WHERE drug_concept_code = '20173311000001101'
	AND ingredient_concept_code = 'OMOP245707'
	AND numerator_value = 15.4;

--set proper forms instead of upgrated
UPDATE internal_relationship_stage a
SET concept_code_2 = i.concept_code_2
FROM (
	SELECT concept_code_2,
		concept_code_1
	FROM internal_relationship_stage b
	) i
WHERE a.concept_code_2 = i.concept_code_1
	AND EXISTS (
		SELECT 1
		FROM drug_concept_stage z
		WHERE z.concept_code = a.concept_code_2
			AND z.invalid_reason IS NOT NULL
		)
	AND EXISTS (
		SELECT 1
		FROM drug_concept_stage x
		WHERE x.concept_code = a.concept_code_1
			AND x.invalid_reason IS NULL
		);

--set invalid_reason = 'U' when we have upgrated concept
UPDATE drug_concept_stage c
SET invalid_reason = 'U'
WHERE EXISTS (
		SELECT 1
		FROM drug_concept_stage c1
		JOIN internal_relationship_stage r ON r.concept_code_1 = c1.concept_code
		JOIN drug_concept_stage c2 ON c2.concept_code = r.concept_code_2
		WHERE c1.concept_class_id = 'Drug Product'
			AND c2.concept_class_id = 'Drug Product'
			AND c1.invalid_reason = 'D'
			AND c1.concept_code = c.concept_code
		);

DELETE
FROM relationship_to_concept
WHERE concept_id_2 = 19135832;

/*
select pc.*, pp.concept_name, pp.domain_id, dd.concept_name,dd.domain_id  from pc_stage pc  
join drug_concept_stage dd  on drug_concept_code = dd.concept_code
join drug_concept_stage pp  on pack_concept_code = pp.concept_code
where drug_concept_code in (select concept_code from drug_concept_stage where domain_id !='Drug')
;
select pc.*, pp.concept_name, pp.domain_id, dd.concept_name,dd.domain_id  from pc_stage pc  
join drug_concept_stage dd  on drug_concept_code = dd.concept_code
join drug_concept_stage pp  on pack_concept_code = pp.concept_code
;
*/
--look on the drugs with Device in PC_stage
--stop here and then look on the drugs with Device in PC_stage

--delete from pc_stage where drug_concept_code in (select concept_code from drug_concept_stage where domain_id !='Drug');

UPDATE pc_stage pc
SET drug_concept_code = i.concept_code_2
FROM (
	SELECT concept_code_2,
		concept_code_1
	FROM deprec_to_active da
	) i
WHERE pc.drug_concept_code = i.concept_code_1;

UPDATE relationship_to_concept
SET precedence = 1
WHERE concept_code_1 = '395939008'
	AND concept_id_2 = 1759842;

UPDATE relationship_to_concept
SET precedence = 5
WHERE concept_code_1 = '85581007'
	AND concept_id_2 = 19082104;

UPDATE relationship_to_concept
SET precedence = 1
WHERE concept_code_1 = '85581007'
	AND concept_id_2 = 19082170;

UPDATE relationship_to_concept
SET precedence = 4
WHERE concept_code_1 = '85581007'
	AND concept_id_2 = 19082103;

UPDATE relationship_to_concept
SET precedence = 3
WHERE concept_code_1 = '85581007'
	AND concept_id_2 = 19082286;

UPDATE relationship_to_concept
SET precedence = 2
WHERE concept_code_1 = '85581007'
	AND concept_id_2 = 19095976;

UPDATE ds_stage a
SET denominator_value = i.denominator_value,
	denominator_unit = i.denominator_unit
FROM (
	SELECT DISTINCT b.denominator_value,
		b.denominator_unit,
		drug_concept_code
	FROM ds_stage b
	WHERE b.denominator_unit IS NOT NULL
	) i
WHERE a.drug_concept_code = i.drug_concept_code
	AND a.denominator_unit IS NULL;

--somehow we get amount +denominator
UPDATE ds_stage a
SET numerator_value = a.amount_value,
	numerator_unit = a.amount_unit,
	amount_value = NULL,
	amount_unit = NULL
WHERE a.denominator_unit IS NOT NULL
	AND numerator_unit IS NULL;

--to do 
-- replace new OMOPs with existing = done

-- add mappings to new RxE = check what happens if we use old codes
-- formalize manaul table = check what's not mapped = try to use two cycles aproach!
-- change ppm to 0.001 of %
-- links to deprecated ATCs and ingredients 

DROP TABLE IF EXISTS r_to_c;

CREATE TABLE r_to_c AS
SELECT r.*
FROM relationship_to_concept r
JOIN concept ON concept_id = r.concept_id_2
	AND vocabulary_id IN (
		'RxNorm',
		'RxNorm Extension',
		'UCUM'
		)
WHERE r.concept_code_1 IS NOT NULL

UNION

SELECT c1.concept_code AS concept_code_1,
	c1.vocabulary_id AS vocabulary_id_1,
	r.concept_id_2,
	1,
	NULL
FROM concept c1
JOIN concept_relationship r ON r.concept_id_1 = c1.concept_id
	AND r.relationship_id IN (
		'Maps to',
		'Source - RxNorm eq'
		)
	AND r.invalid_reason IS NULL
JOIN concept c2 ON c2.concept_id = r.concept_id_2
	AND c2.invalid_reason IS NULL
WHERE c1.vocabulary_id = (
		SELECT vocabulary_id
		FROM drug_concept_stage limit 1
		)
	AND c2.vocabulary_id IN (
		'RxNorm',
		'RxNorm Extension'
		)
	AND c2.concept_class_id IN (
		'Ingredient',
		'Dose Form',
		'Brand Name',
		'Supplier'
		)
	AND c1.concept_code NOT IN (
		SELECT concept_code_1
		FROM relationship_to_concept
		WHERE concept_code_1 IS NOT NULL
		);

TRUNCATE TABLE relationship_to_concept;
INSERT INTO relationship_to_concept
SELECT *
FROM r_to_c;

DROP TABLE IF EXISTS to_manual;
CREATE TABLE to_manual AS
SELECT *
FROM drug_concept_stage
LEFT JOIN relationship_to_concept ON concept_code = concept_code_1
WHERE concept_class_id IN (
		'Ingredient',
		'Dose Form',
		'Brand Name',
		'Supplier'
		)
	AND concept_code_1 IS NULL;

SELECT DISTINCT *
FROM ds_stage
WHERE (
		amount_unit NOT IN (
			SELECT concept_code
			FROM drug_concept_stage
			WHERE concept_class_id = 'Unit'
			)
		OR numerator_unit NOT IN (
			SELECT concept_code
			FROM drug_concept_stage
			WHERE concept_class_id = 'Unit'
			)
		OR denominator_unit NOT IN (
			SELECT concept_code
			FROM drug_concept_stage
			WHERE concept_class_id = 'Unit'
			)
		);

SELECT m.*
FROM to_manual m
JOIN concept c ON lower(m.concept_name) = lower(c.concept_name)
	AND c.vocabulary_id LIKE 'Rx%'
	AND c.concept_class_id = m.concept_class_id;

SELECT *
FROM drug_concept_stage_14082017
WHERE concept_name = 'Olive oil';