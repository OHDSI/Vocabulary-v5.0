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
* Authors: Polina Talapova, Daryna Ivakhnenko, Dmitry Dymshyts
* Date: 2020
**************************************************************************/

/*************************
****** INPUT TABLES ******
**************************/ 
-- create backups of input tables if necessary
-- drop existing input tables
DROP TABLE IF EXISTS drug_concept_stage CASCADE;
DROP TABLE IF EXISTS ds_stage;
DROP TABLE IF EXISTS internal_relationship_stage;
DROP TABLE IF EXISTS pc_stage;
DROP TABLE IF EXISTS relationship_to_concept CASCADE;
DROP TABLE IF EXISTS ds_0;

CREATE TABLE drug_concept_stage 
(
  concept_name              VARCHAR(255),
  vocabulary_id             VARCHAR(20),
  concept_class_id          VARCHAR(20),
  standard_concept          VARCHAR(1),
  concept_code              VARCHAR(50),
  possible_excipient        VARCHAR(1),
  domain_id                 VARCHAR(20),
  valid_start_date          DATE,
  valid_end_date            DATE,
  invalid_reason            VARCHAR(1),
  source_concept_class_id   VARCHAR(20)
);

CREATE TABLE ds_0 
(
  drug_concept_code         VARCHAR(255),
  drug_name                 VARCHAR(255),
  ingredient_concept_code   VARCHAR(255),
  amount_value              NUMERIC,
  amount_unit               VARCHAR(255),
  numerator_value           NUMERIC,
  numerator_unit            VARCHAR(255),
  denominator_value         NUMERIC,
  denominator_unit          VARCHAR(255)
);

CREATE TABLE ds_stage 
(
  drug_concept_code         VARCHAR(50),
  ingredient_concept_code   VARCHAR(50),
  box_size                  SMALLINT,
  amount_value              NUMERIC,
  amount_unit               VARCHAR(255),
  numerator_value           NUMERIC,
  numerator_unit            VARCHAR(255),
  denominator_value         NUMERIC,
  denominator_unit          VARCHAR(255)
);

CREATE TABLE internal_relationship_stage 
(
  concept_code_1   VARCHAR(50),
  concept_code_2   VARCHAR(50)
);

CREATE TABLE pc_stage 
(
  pack_concept_code   VARCHAR(50),
  drug_concept_code   VARCHAR(50),
  amount              SMALLINT,
  box_size            SMALLINT
);

CREATE TABLE relationship_to_concept 
(
  concept_code_1      VARCHAR(50),
  vocabulary_id_1     VARCHAR(50),
  concept_id_2        INT,
  precedence          SMALLINT,
  conversion_factor   NUMERIC
);

--create indexes and constraints
DROP INDEX if exists irs_concept_code_1;
DROP INDEX if exists irs_concept_code_2;
DROP INDEX if exists dcs_concept_code;
DROP INDEX if exists ds_drug_concept_code;
DROP INDEX if exists ds_ingredient_concept_code;
DROP INDEX if exists dcs_unique_concept_code;
DROP INDEX if exists irs_unique_concept_code;

CREATE INDEX irs_concept_code_1 
  ON internal_relationship_stage (concept_code_1);
CREATE INDEX irs_concept_code_2 
  ON internal_relationship_stage (concept_code_2);
CREATE INDEX dcs_concept_code 
  ON drug_concept_stage (concept_code);
CREATE INDEX ds_drug_concept_code 
  ON ds_stage (drug_concept_code);
CREATE INDEX ds_ingredient_concept_code 
  ON ds_stage (ingredient_concept_code);
CREATE UNIQUE INDEX dcs_unique_concept_code 
  ON drug_concept_stage (concept_code);
CREATE INDEX irs_unique_concept_code 
  ON internal_relationship_stage (concept_code_1, concept_code_2);

/**************************
*** DRUG_CONCEPT_STAGE ****
***************************/ 
-- add all Drug Products and Ingredients into the DRUG_CONCEPT_STAGE (note, that Units will be added AFTER ds_stage)
INSERT INTO drug_concept_stage
(
  concept_name,
  vocabulary_id,
  concept_class_id,
  standard_concept,
  concept_code,
  domain_id,
  valid_start_date,
  valid_end_date,
  invalid_reason,
  source_concept_class_id
)
SELECT DISTINCT TRIM(REGEXP_REPLACE(INITCAP(t_nm),'^-','g')) AS concept_name,
       'NCCD' AS vocabulary_id,
       CASE
         WHEN nccd_type = 'IN' THEN 'Ingredient'
         WHEN nccd_type = 'DF' THEN 'Dose Form'
         WHEN nccd_type = 'BN' THEN 'Brand Name'
         ELSE 'Drug Product'
       END AS concept_class_id,
       CASE
         WHEN concept_id = 0 AND nccd_type != 'BN' THEN 'S'
         ELSE NULL
       END AS standard_concept,
       nccd_code AS concept_code,
       'Drug' AS domain_id,
       CURRENT_DATE AS valid_start_date,
       TO_DATE('20991231','YYYYMMDD') AS valid_end_date,
       NULL AS invalid_reason,
       nccd_type AS source_concept_class_id
FROM nccd_full_done; -- 51240
/**************************
*** DRUG_STRENGTH_STAGE ***
***************************/ 
--2. Add all Drug Products with Ingredients, Dosages and Units to DS_STAGE
-- use temporary table of ds_0 for convenient parcing of doses
-- insert unicomponent drugs excluding solutions
INSERT INTO ds_0
(
  drug_concept_code,
  drug_name,
  ingredient_concept_code,
  amount_value,
  amount_unit
)
WITH t1
AS
(SELECT DISTINCT a.nccd_code AS drug_concept_code,
       a.t_nm AS drug_name,
       a.ing_code,
       -- the source code of the Ingredient
       a.dose :: NUMERIC,
       -- numeric value for absolute content of a solid formulation
       a.unit -- unit of the absolute content of a solid formulation
       FROM nccd_full_done a
  JOIN nccd_full_done b
    ON a.ing_code = b.nccd_code
   AND a.nccd_type NOT IN ('DF', 'IN', 'BN')
   
   AND b.nccd_type = 'IN'
WHERE a.dose <> 'X'
AND   a.unit !~ '\/|%'
-- exclude solutions
AND   a.unit ~ 'MG|G|MCG|IU|U'-- pick units for solid formulations
AND   a.ing_code IN (SELECT concept_code
                     FROM drug_concept_stage
                     WHERE concept_class_id = 'Ingredient')
AND   a.ing_code !~ '\|')
SELECT*FROM t1 WHERE dose <> 0;-- 22295

--insert multicomponent drugs excluding solutions (Decimal separator for ing_code, dose, unit - | (vertical bar))
INSERT INTO ds_0
(
  drug_concept_code,
  drug_name,
  ingredient_concept_code,
  amount_value,
  amount_unit
)
WITH t1
AS
(WITH a
AS
(SELECT nccd_type,
       nccd_code,
       t_nm,
       REGEXP_SPLIT_TO_TABLE(ing_code,'\|') AS ingredient_concept_code,
       REGEXP_SPLIT_TO_TABLE(dose,'\|') AS dose,
       REGEXP_SPLIT_TO_TABLE(unit,'\|') AS unit
FROM nccd_full_done
WHERE unit ~ '\|') SELECT DISTINCT a.nccd_code AS drug_concept_code,
a.t_nm AS drug_name,
a.ingredient_concept_code,-- the source code of the Ingredient
a.dose :: NUMERIC,-- numeric value for absolute content of a solid formulation
a.unit -- unit of the absolute content of a solid formulation
FROM a 
JOIN nccd_full_done b 
ON a.ingredient_concept_code = b.nccd_code 
AND a.nccd_type NOT IN ('DF','IN','BN')
AND b.nccd_type = 'IN' 
WHERE a.dose <> 'X' AND a.unit !~ '\/|%'-- exclude solutions
AND a.unit ~ 'MG|G|MCG|IU|U' AND a.ingredient_concept_code IN (SELECT concept_code
                                                               FROM drug_concept_stage
                                                               WHERE concept_class_id = 'Ingredient')) SELECT*FROM t1 WHERE dose <> 0; --12

-- fill NUMERATOR-DENOMINATOR for percentage concentration (%) of unicomponent solutions
INSERT INTO ds_0
(
  drug_concept_code,
  drug_name,
  ingredient_concept_code,
  numerator_value,
  numerator_unit,
  denominator_value,
  denominator_unit
)
WITH t1
AS
(SELECT DISTINCT a.nccd_code AS drug_concept_code,
       a.t_nm AS drug_name,
       a.ing_code AS ingredient_concept_code,
       a.dose :: NUMERIC *10 AS numerator_value,
       'MG' AS numerator_unit,
       NULL :: FLOAT8 AS denominator_value,
       CASE
         WHEN UPPER(a.t_nm) ~* 'CREAM|OINTMENT' THEN 'G'
         ELSE 'ML'
       END AS denominator_unit
FROM nccd_full_done a
  JOIN nccd_full_done b
    ON a.ing_code = b.nccd_code
   AND a.nccd_type NOT IN ('DF', 'IN', 'BN')
   AND b.nccd_type = 'IN'
WHERE a.unit ~ '%'-- pick up percents only
AND   a.unit !~ '\/'-- exclude ready solutions
AND   a.dose <> 'X'-- exclude Drugs without dosage
)SELECT DISTINCT drug_concept_code,
drug_name,
ingredient_concept_code,
CASE WHEN denominator_unit IN ('G','L') 
THEN numerator_value*0.001 ELSE numerator_value END,
numerator_unit,denominator_value,
CASE WHEN denominator_unit = 'G' THEN 'MG' 
WHEN denominator_unit IN ('L','LITER') THEN 'ML' ELSE denominator_unit END 
FROM t1 
WHERE ingredient_concept_code IN (SELECT concept_code FROM drug_concept_stage);-- 703
-- fill NUMERATOR-DENOMINATOR for percentage concentration (%) of multicomponent solutions
INSERT INTO ds_0
(
  drug_concept_code,
  drug_name,
  ingredient_concept_code,
  numerator_value,
  numerator_unit,
  denominator_value,
  denominator_unit
)
WITH t1
AS
(WITH a
AS
(SELECT nccd_type,
       nccd_code,
       t_nm,
       REGEXP_SPLIT_TO_TABLE(ing_code,'\|') AS ingredient_concept_code,
       REGEXP_SPLIT_TO_TABLE(dose,'\|') AS dose,
       REGEXP_SPLIT_TO_TABLE(unit,'\|') AS unit
FROM nccd_full_done
WHERE unit ~ '\|') 
SELECT DISTINCT 
a.nccd_code AS drug_concept_code,
a.t_nm AS drug_name,
a.ingredient_concept_code,
a.dose::NUMERIC*10 AS numerator_value,
'MG' AS numerator_unit,
NULL::FLOAT8 AS denominator_value,
CASE WHEN UPPER(a.t_nm) ~* 'CREAM|OINTMENT' 
THEN 'G' ELSE 'ML' END AS denominator_unit 
FROM a 
JOIN nccd_full_done b 
ON a.ingredient_concept_code = b.nccd_code AND a.nccd_type NOT IN ('DF','IN','BN') AND b.nccd_type = 'IN' 
WHERE a.unit ~ '%'-- pick up percents only
AND a.unit !~ '\/'-- exclude ready solutions
AND a.dose <> 'X'-- exclude Drugs without dosage
) SELECT DISTINCT drug_concept_code,
drug_name,
ingredient_concept_code,
CASE WHEN denominator_unit IN ('G','L') THEN numerator_value*0.001 ELSE numerator_value END,
numerator_unit,
denominator_value,
CASE WHEN denominator_unit = 'G' THEN 'MG' WHEN denominator_unit IN ('L','LITER') THEN 'ML' ELSE denominator_unit END 
FROM t1 
WHERE ingredient_concept_code IN (SELECT concept_code FROM drug_concept_stage);--0
-- convert MCG to MG
UPDATE ds_0
   SET amount_value = amount_value / 1000,
       amount_unit = 'MG'
WHERE amount_unit = 'MCG';-- 131
-- convert G to MG
UPDATE ds_0
   SET amount_value = amount_value*1000,
       amount_unit = 'MG'
WHERE amount_unit = 'G';-- 4
--fill NUMERATOR-DENOMINATOR for mass concetration of unicomponent solutions
INSERT INTO ds_0
(
  drug_concept_code,
  drug_name,
  ingredient_concept_code,
  numerator_value,
  numerator_unit,
  denominator_value,
  denominator_unit
)
WITH t1
AS
(SELECT DISTINCT a.nccd_code AS drug_concept_code,
       a.t_nm AS drug_name,
       a.ing_code AS ingredient_concept_code,
       a.dose::NUMERIC AS numerator_value,
       SPLIT_PART(a.unit,'/','1') AS numerator_unit,
       1::FLOAT AS denominator_value,
       SPLIT_PART(a.unit,'/','2') AS denominator_unit
FROM nccd_full_done a
  JOIN nccd_full_done b
    ON a.ing_code = b.nccd_code
   AND a.nccd_type NOT IN ('DF', 'IN', 'BN')
   
   AND b.nccd_type = 'IN'
WHERE a.unit ~ '/'
AND   a.ing_code IN (SELECT concept_code
                                    FROM drug_concept_stage
                                    WHERE concept_class_id = 'Ingredient')) 
                                    
SELECT DISTINCT drug_concept_code,
drug_name,
ingredient_concept_code,
CASE WHEN numerator_unit = 'G' THEN numerator_value::NUMERIC*1000 
WHEN numerator_unit = 'MCG' THEN numerator_value::NUMERIC/ 1000 
WHEN denominator_unit = 'G' THEN numerator_value::NUMERIC/ 1000 
ELSE numerator_value END,
CASE WHEN numerator_unit = '' THEN 'MG' 
WHEN numerator_unit = 'MCG' THEN 'MG' 
ELSE numerator_unit END,
denominator_value,
CASE WHEN denominator_unit = 'G' THEN 'MG' ELSE denominator_unit END 
FROM t1;-- 7651
--fill NUMERATOR-DENOMINATOR for mass concetration of multicomponent solutions
INSERT INTO ds_0
(
  drug_concept_code,
  drug_name,
  ingredient_concept_code,
  numerator_value,
  numerator_unit,
  denominator_value,
  denominator_unit
)
WITH t1
AS
(WITH a
AS
(SELECT nccd_type,
       nccd_code,
       t_nm,
       REGEXP_SPLIT_TO_TABLE(ing_code,'\|') AS ingredient_concept_code,
       REGEXP_SPLIT_TO_TABLE(dose,'\|') AS dose,
       REGEXP_SPLIT_TO_TABLE(unit,'\|') AS unit
FROM nccd_full_done
WHERE unit ~ '\|') 
SELECT DISTINCT a.nccd_code AS drug_concept_code,
a.t_nm AS drug_name,
a.ingredient_concept_code,
a.dose::NUMERIC AS numerator_value,
SPLIT_PART(a.unit,'/','1') AS numerator_unit,
1::FLOAT AS denominator_value,
SPLIT_PART(a.unit,'/','2') AS denominator_unit 
FROM a 
JOIN nccd_full_done b 
ON a.ingredient_concept_code = b.nccd_code AND a.nccd_type NOT IN ('DF','IN','BN') AND b.nccd_type = 'IN' 
WHERE a.unit ~ '/' AND ingredient_concept_code IN (SELECT concept_code FROM drug_concept_stage))
SELECT DISTINCT drug_concept_code,
drug_name,
ingredient_concept_code,
CASE WHEN numerator_unit = 'G' THEN numerator_value::NUMERIC*1000 
WHEN numerator_unit = 'MCG' THEN numerator_value::NUMERIC/ 1000 
WHEN denominator_unit = 'G' THEN numerator_value::NUMERIC/ 1000 
ELSE numerator_value END,
CASE WHEN numerator_unit = '' THEN 'MG' 
WHEN numerator_unit = 'MCG' THEN 'MG' 
ELSE numerator_unit END,
denominator_value,
CASE WHEN denominator_unit = 'G' THEN 'MG' ELSE denominator_unit END 
FROM t1;--4
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    
-- remove excessive '0'
UPDATE ds_0
   SET numerator_value = TRIM(TRAILING '0' FROM CAST(numerator_value AS VARCHAR))::NUMERIC
WHERE CAST(numerator_value AS VARCHAR) ~ '\d+\.\d+.*0$';--252

UPDATE ds_0
   SET amount_value = TRIM(TRAILING '0' FROM CAST(amount_value AS VARCHAR))::NUMERIC
WHERE CAST(amount_value AS VARCHAR) ~ '\d+\.\d+.*0$';-- 131

UPDATE ds_0
   SET numerator_value = TRIM(TRAILING '.0' FROM CAST(numerator_value AS VARCHAR))::NUMERIC
WHERE CAST(numerator_value AS VARCHAR) ~ '\d+\.0$';--198

-- delete 0 as amount_value OR numerator value if any
DELETE
FROM ds_0
WHERE amount_value = 0;

DELETE
FROM ds_0
WHERE numerator_value = 0;

-- trim units
UPDATE ds_0
   SET amount_unit = TRIM(amount_unit);
UPDATE ds_0
   SET numerator_unit = TRIM(numerator_unit);
UPDATE ds_0
   SET denominator_unit = TRIM(denominator_unit);

-- fill ds_stage as is using ds_0
INSERT INTO ds_stage
(
  drug_concept_code,
  ingredient_concept_code,
  amount_value,
  amount_unit,
  numerator_value,
  numerator_unit,
  denominator_value,
  denominator_unit
)
SELECT DISTINCT drug_concept_code,
       ingredient_concept_code,
       amount_value :: NUMERIC,
       amount_unit,
       numerator_value :: NUMERIC,
       numerator_unit,
       CASE
         WHEN denominator_value IS NULL AND numerator_value IS NOT NULL THEN 1::NUMERIC
         ELSE denominator_value :: NUMERIC
       END 
,
       denominator_unit
FROM ds_0;-- 30665

UPDATE ds_stage
   SET amount_value = NULL,
       amount_unit = NULL,
       denominator_value = NULL,
       denominator_unit = NULL,
       numerator_value = NULL,
       numerator_unit = NULL
WHERE lower(numerator_unit) IN ('ml')
OR    lower(amount_unit) IN ('ml');-- 0
--delete drugs without doses from ds_stage
DELETE
FROM ds_stage
WHERE amount_value IS NULL
AND   amount_unit is   null
AND   denominator_value is  null
AND   denominator_unit is  null
AND   numerator_value IS NULL
AND   numerator_unit is  null;-- 0 
--delete duplicates if present
DELETE
FROM ds_stage
WHERE CTID NOT IN (SELECT MIN(CTID)
                   FROM ds_stage
                   GROUP BY drug_concept_code,
                            ingredient_concept_code,
                            box_size,
                            amount_value,
                            amount_unit,
                            numerator_value,
                            numerator_unit,
                            denominator_value,
                            denominator_unit);--  0
-- add drugs which have numerator_value > 1000 (for MG/ML) to the nccd_excluded 
WITH t1
AS
(SELECT *
FROM ds_stage a
  JOIN nccd_full_done b ON a.drug_concept_code = b.nccd_code
WHERE (LOWER(numerator_unit) IN ('mg') AND LOWER(denominator_unit) IN ('ml','g') OR LOWER(numerator_unit) IN ('g') AND LOWER(denominator_unit) IN ('l'))
AND   numerator_value /COALESCE(denominator_value,1) > 1000) INSERT INTO nccd_excluded SELECT DISTINCT nccd_type,nccd_code::INT,nccd_name,'>1000MG/ML, to process manually and fix units inside the names per each row (for Darina)' FROM nccd_full_done WHERE nccd_code IN (SELECT drug_concept_code FROM t1);
-- 0
-- get rif of >1000MG/ML if any. all of them should be reviewed manually 
DELETE
FROM ds_stage
WHERE (LOWER(numerator_unit) IN ('mg') AND LOWER(denominator_unit) IN ('ml','g') OR LOWER(numerator_unit) IN ('g') AND LOWER(denominator_unit) IN ('l'))
AND   numerator_value /COALESCE(denominator_value,1) > 1000;
-- 0
--select * from ds_stage;
/*************************
*** DRUG_CONCEPT_STAGE ***
**************************/ 
-- add UNITS into the drug_concept_stage
INSERT INTO drug_concept_stage
(
  concept_name,
  vocabulary_id,
  concept_class_id,
  concept_code,
  domain_id,
  valid_start_date,
  valid_end_date,
  invalid_reason
)
SELECT DISTINCT unit AS concept_name,
       'NCCD' AS vocabulary_id,
       'Unit' AS concept_class_id,
       unit AS concept_code,
       'Drug' AS domain_id,
       CURRENT_DATE,
       TO_DATE('20991231','YYYYMMDD'),
       NULL
FROM (SELECT DISTINCT amount_unit AS unit
      FROM ds_0
      UNION
      SELECT numerator_unit
      FROM ds_0
      UNION
      SELECT denominator_unit
      FROM ds_0) a
WHERE unit IS NOT NULL;-- 4
/***********************************
*** INTERNAL_RELATIONSHIP_STAGE ****
************************************/ 
-- add links from Drug Products to their Attributes (Ingredients - obligatory, Dose Forms - optional, Brand Names - optional) 
-- DP - ING
INSERT INTO internal_relationship_stage
SELECT DISTINCT nccd_code,-- Drug Product 
       REGEXP_SPLIT_TO_TABLE(ing_code,'\|')-- Ingredient
       FROM nccd_full_done
WHERE ing_code <> 'X';-- 45138
-- DP - DF
INSERT INTO internal_relationship_stage
SELECT DISTINCT nccd_code,-- Drug Product 
       df_code -- Dose Form 
       FROM nccd_full_done
WHERE df_code <> 'X';-- 28891
-- DP - BN
INSERT INTO internal_relationship_stage
SELECT DISTINCT nccd_code,-- Drug Product 
       bn_code -- Brand Name 
       FROM nccd_full_done
WHERE bn_code <> 'X';--19946
/*******************************
*** RELATIONSHIP_TO_CONCEPT ****
********************************/ 
-- add links from Drug Attribute concept_codes to their Standard equivalent concept_ids
-- source ING - target ING
INSERT INTO relationship_to_concept
(
  concept_code_1,
  vocabulary_id_1,
  concept_id_2,
  precedence
)
SELECT DISTINCT nccd_code,
'NCCD',
       c.concept_id,
       1
FROM nccd_full_done a
  JOIN concept c
    ON a.concept_id = c.concept_id
   AND c.standard_concept = 'S'
WHERE nccd_type = 'IN';--1699

-- source UNITS - target UNITS
INSERT INTO relationship_to_concept
(
  concept_code_1,
  vocabulary_id_1,
  concept_id_2,
  precedence,
  conversion_factor
)
SELECT DISTINCT *
FROM (
SELECT 'U','NCCD',8510,1,1
UNION
SELECT 'IU','NCCD',8718,1,1
UNION
SELECT 'MG','NCCD',8576,1,1
UNION
SELECT 'ML','NCCD',8587,1,1) a;--4  
-- source DF - target DF (precendence = '1' via name matching)
WITH t AS  
(
  SELECT DISTINCT a.concept_code,
         c.concept_id
  FROM drug_concept_stage a
    JOIN devv5.concept c
      ON upper(a.concept_name) = upper (c.concept_name)
     AND a.concept_class_id = 'Dose Form'
     AND c.concept_class_id = 'Dose Form'
     AND c.vocabulary_id ~ '^Rx'
     AND c.invalid_reason IS NULL)
     
INSERT INTO relationship_to_concept
(concept_code_1,vocabulary_id_1,concept_id_2,precedence)
SELECT t.concept_code as concept_code_1,
       'NCCD' as vocabulary_id_1,
       t.concept_id as concept_id_2,
       1 as precedence
FROM t; 

-- source DF - target DF (precendence > '1' via word pattern matching)
INSERT INTO relationship_to_concept  
(concept_code_1,vocabulary_id_1,concept_id_2,precedence)
with t as(
 SELECT concept_code as concept_code_1,'NCCD' as vocabulary_id_1,19082079 as concept_id_2, 2 as precedence  FROM drug_concept_stage  WHERE concept_name = 'Oral Tablet'
UNION
SELECT concept_code,'NCCD',19001949,3 FROM drug_concept_stage  WHERE concept_name = 'Oral Tablet' 
UNION
SELECT concept_code,'NCCD',44817840,4 FROM drug_concept_stage  WHERE concept_name = 'Oral Tablet'
UNION
SELECT concept_code,'NCCD',19082076,5 FROM drug_concept_stage  WHERE concept_name = 'Oral Tablet'
UNION
SELECT concept_code,'NCCD',37498347,6 FROM drug_concept_stage WHERE concept_name = 'Oral Tablet'
UNION 
SELECT concept_code,'NCCD',19082079,2 FROM drug_concept_stage WHERE concept_name = 'Oral Capsule'
UNION
SELECT concept_code ,'NCCD',19082255,3 FROM drug_concept_stage WHERE concept_name = 'Oral Capsule'
UNION
SELECT concept_code, 'NCCD', 19082103, 1 FROM drug_concept_stage WHERE concept_name = 'Injectable'
UNION
SELECT concept_code,'NCCD',19082104,2 FROM drug_concept_stage WHERE concept_name = 'Injectable'
UNION
SELECT concept_code,'NCCD',46234469,3 FROM drug_concept_stage WHERE concept_name = 'Injectable'
UNION
SELECT  concept_code,'NCCD',19126920,4 FROM drug_concept_stage WHERE concept_name = 'Injectable'
UNION
SELECT concept_code,'NCCD',46234467,5 FROM drug_concept_stage WHERE concept_name = 'Injectable'
UNION
SELECT concept_code,'NCCD',46234466,6 FROM drug_concept_stage WHERE concept_name = 'Injectable'
UNION
SELECT concept_code,'NCCD',19095973,2 FROM drug_concept_stage WHERE concept_name = 'Gel'
UNION
SELECT concept_code,'NCCD',19095916,3 FROM drug_concept_stage WHERE concept_name = 'Gel'
UNION
SELECT concept_code,'NCCD',19082286,2 FROM drug_concept_stage WHERE concept_name = 'Powder'
UNION
SELECT concept_code,'NCCD',19082259,3 FROM drug_concept_stage WHERE concept_name = 'Powder'
UNION
SELECT concept_code,'NCCD',19082227,2 FROM drug_concept_stage WHERE concept_name = 'Ointment'
UNION
SELECT concept_code,'NCCD',19082224,3 FROM drug_concept_stage WHERE concept_name = 'Ointment' 
UNION
SELECT concept_code,'NCCD',19093368,2 FROM drug_concept_stage WHERE concept_name = 'Vaginal Insert'
UNION
SELECT concept_code,'NCCD',19082200,2 FROM drug_concept_stage WHERE concept_name = 'Suppository'
UNION
SELECT concept_code,'NCCD',19093368,3 FROM drug_concept_stage WHERE concept_name = 'Suppository'
UNION
SELECT concept_code,'NCCD',19127579,2 FROM drug_concept_stage WHERE concept_name = 'Inhaler' -- 19127579	744995	Dry Powder Inhaler
UNION
SELECT concept_code,'NCCD',19126919,3 FROM drug_concept_stage WHERE concept_name = 'Inhaler' -- 19126919	721655	Nasal Inhaler
UNION
SELECT concept_code,'NCCD',19126918,4 FROM drug_concept_stage WHERE concept_name = 'Inhaler' -- 19126918	721654	Metered Dose Inhaler
UNION
SELECT concept_code,'NCCD',19082223,2 FROM drug_concept_stage WHERE concept_name = 'Oral Solution' 
UNION 
SELECT concept_code, 'NCCD', 19082701, 2 FROM drug_concept_stage WHERE concept_name = 'Medicated Patch' -- 19082701	318130	Patch	Dose Form	Non-standard	Valid	Drug	RxNorm
UNION  
SELECT concept_code, 'NCCD', 19082165, 2 FROM drug_concept_stage WHERE concept_name = 'Nasal Spray' -- -- 19082165	316962	Nasal Solution
UNION
SELECT concept_code, 'NCCD',37499224 , 2 FROM drug_concept_stage WHERE concept_name = 'Oral Granules'  -- 37499224	2284290	Delayed Release Oral Granules
UNION 
SELECT concept_code, 'NCCD',45775489 , 3 FROM drug_concept_stage WHERE concept_name = 'Oral Granules'  -- 45775489	1540453	Granules for Oral Solution 
UNION 
SELECT concept_code, 'NCCD',45775490 , 4 FROM drug_concept_stage WHERE concept_name = 'Oral Granules'  -- 45775490	1540454	Granules for Oral Suspension
UNION  
SELECT concept_code, 'NCCD', 19082196, 2 FROM drug_concept_stage WHERE concept_name = 'Otic Solution'  -- 19082196	316974	Otic Suspension
UNION 
SELECT concept_code, 'NCCD',19095918 ,2 FROM drug_concept_stage WHERE concept_name = 'Paste' -- 19095918	346171	Oral Paste 
)
SELECT distinct * FROM t; -- 31

-- cleaning up 
-- delete "drugs" without ingredients (they shouldn't be at the drug input tables)
DELETE
FROM dev_nccd.drug_concept_stage
WHERE concept_code NOT IN (SELECT concept_code_1
                           FROM dev_nccd.internal_relationship_stage
                             JOIN dev_nccd.drug_concept_stage
                               ON concept_code_2 = concept_code
                              AND concept_class_id = 'Ingredient')
AND   concept_code NOT IN (SELECT pack_concept_code FROM pc_stage)
AND   concept_class_id = 'Drug Product';-- 15
-- get rid of IRS duplicate (df)
DELETE
FROM internal_relationship_stage
WHERE concept_code_1 = '106621'
AND   concept_code_2 = 'OMOP4940688';-- 0
-- delete ingredients which were placed as Drug Products (need to be reviewed manually at the 2d phase)
DELETE
FROM internal_relationship_stage
WHERE (concept_code_1,concept_code_2) IN (SELECT concept_code_1,
                                                 concept_code_2
                                          FROM internal_relationship_stage irs
                                            JOIN drug_concept_stage dcs
                                              ON dcs.concept_code = irs.concept_code_1
                                             AND (concept_class_id,domain_id) <> ('Drug Product','Drug'));--0
-- drop dead mappings of attributes if any
DELETE
FROM relationship_to_concept
WHERE (concept_code_1,concept_id_2) IN (SELECT concept_code_1,
                                               concept_id_2
                                        FROM relationship_to_concept r
                                          JOIN devv5.concept c ON c.concept_id = r.concept_id_2
                                        WHERE c.invalid_reason IS NOT NULL);-- 0
-- normalize datatypes according to new constraints
ALTER TABLE ds_stage ALTER COLUMN amount_value TYPE NUMERIC;
ALTER TABLE ds_stage ALTER COLUMN numerator_value TYPE NUMERIC;
ALTER TABLE ds_stage ALTER COLUMN denominator_value TYPE NUMERIC;
ALTER TABLE ds_stage ALTER COLUMN box_size TYPE SMALLINT;
ALTER TABLE relationship_to_concept ALTER COLUMN conversion_factor TYPE NUMERIC;
ALTER TABLE relationship_to_concept ALTER COLUMN precedence TYPE SMALLINT;

/**********************************
******* ADD NCCD VOCABULARY *******
***********************************/ 
-- add new vocabulary to the concept table
INSERT INTO concept
(
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
SELECT 100,
       'NCCD',
       'Drug',
       'Vocabulary',
       'Vocabulary',
       NULL,
       'OMOP generated',
       TO_DATE('19700101','yyyymmdd'),
       TO_DATE('20991231','yyyymmdd'),
       NULL WHERE 'NCCD' NOT IN (SELECT concept_name FROM concept WHERE concept_name = 'NCCD');

-- add new vocabulary to the vocabulary table
INSERT INTO vocabulary
(
  vocabulary_id,
  vocabulary_name,
  vocabulary_concept_id,
  vocabulary_reference
)
SELECT 'NCCD',
       'NCCD',
       100,
       'Stub' WHERE 'NCCD' NOT IN (SELECT vocabulary_name
                                   FROM vocabulary
                                   WHERE vocabulary_name = 'NCCD');

-- update latest_update field to new date
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate( 
	pVocabularyName			=> 'NCCD',
	pVocabularyDate			=> (SELECT vocabulary_date FROM nccd_vocabulary_vesion LIMIT 1),
	pVocabularyVersion		=> (SELECT vocabulary_version FROM nccd_vocabulary_vesion LIMIT 1),
	pVocabularyDevSchema	=> 'dev_nccd'
);
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate( 
	pVocabularyName			=> 'RxNorm Extension',
	pVocabularyDate			=> CURRENT_DATE,
	pVocabularyVersion		=> 'RxNorm Extension '||CURRENT_DATE,
	pVocabularyDevSchema	=> 'dev_nccd',
	pAppendVocabulary		=> TRUE
);
END $_$;
