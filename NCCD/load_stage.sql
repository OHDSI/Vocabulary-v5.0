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

/****************************
** TRUNCATE WORKING TABLES **
****************************/ 
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

/*************************
****** INPUT TABLES ******
**************************/ 
-- create backups of input tables if necessary
-- drop existing input tables
DROP TABLE IF EXISTS drug_concept_stage;
DROP TABLE IF EXISTS ds_stage;
DROP TABLE IF EXISTS internal_relationship_stage;
DROP TABLE IF EXISTS pc_stage;
DROP TABLE IF EXISTS relationship_to_concept;
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
       NULL AS source_concept_class_id
FROM nccd_full_done; 
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
SELECT*FROM t1 WHERE dose <> 0;
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
                                                               WHERE concept_class_id = 'Ingredient')) SELECT*FROM t1 WHERE dose <> 0; 
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
       NULL :: NUMERIC AS denominator_value,
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
THEN numerator_value * 0.001 ELSE numerator_value END,
numerator_unit,
denominator_value,
CASE WHEN denominator_unit = 'G' THEN 'MG' 
WHEN denominator_unit IN ('L','LITER') THEN 'ML' ELSE denominator_unit END 
FROM t1 
WHERE ingredient_concept_code IN (SELECT concept_code FROM drug_concept_stage);
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
a.dose :: NUMERIC *10 AS numerator_value,
'MG' AS numerator_unit,
NULL :: NUMERIC  AS denominator_value,
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
CASE WHEN denominator_unit IN ('G','L') THEN numerator_value * 0.001 ELSE numerator_value END,
numerator_unit,
denominator_value,
CASE WHEN denominator_unit = 'G' THEN 'MG' WHEN denominator_unit IN ('L','LITER') THEN 'ML' ELSE denominator_unit END 
FROM t1 
WHERE ingredient_concept_code IN (SELECT concept_code FROM drug_concept_stage);
-- convert MCG to MG
UPDATE ds_0
   SET amount_value = amount_value / 1000,
       amount_unit = 'MG'
WHERE amount_unit = 'MCG';
-- convert G to MG
UPDATE ds_0
   SET amount_value = amount_value*1000,
       amount_unit = 'MG'
WHERE amount_unit = 'G';
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
       a.dose :: NUMERIC AS numerator_value,
       SPLIT_PART(a.unit,'/','1') AS numerator_unit,
       NULL  :: NUMERIC AS denominator_value,
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
CASE WHEN numerator_unit = 'G' THEN numerator_value*1000 
WHEN numerator_unit = 'MCG' THEN numerator_value/ 1000  
WHEN denominator_unit = 'G' THEN numerator_value/ 1000  
ELSE numerator_value END,
CASE WHEN numerator_unit = '' THEN 'MG' 
WHEN numerator_unit = 'MCG' THEN 'MG' 
ELSE numerator_unit END,
denominator_value,
CASE WHEN denominator_unit = 'G' THEN 'MG' ELSE denominator_unit END 
FROM t1;
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
a.dose :: NUMERIC AS numerator_value,
SPLIT_PART(a.unit,'/','1') AS numerator_unit,
NULL :: NUMERIC AS denominator_value,
SPLIT_PART(a.unit,'/','2') AS denominator_unit 
FROM a 
JOIN nccd_full_done b 
ON a.ingredient_concept_code = b.nccd_code AND a.nccd_type NOT IN ('DF','IN','BN') AND b.nccd_type = 'IN' 
WHERE a.unit ~ '/' AND ingredient_concept_code IN (SELECT concept_code FROM drug_concept_stage))
SELECT DISTINCT drug_concept_code,
drug_name,
ingredient_concept_code,
CASE WHEN numerator_unit = 'G' THEN numerator_value*1000 
WHEN numerator_unit = 'MCG' THEN numerator_value/ 1000  
WHEN denominator_unit = 'G' THEN numerator_value/ 1000 
ELSE numerator_value END,
CASE WHEN numerator_unit = '' THEN 'MG' 
WHEN numerator_unit = 'MCG' THEN 'MG' 
ELSE numerator_unit END,
denominator_value,
CASE WHEN denominator_unit = 'G' THEN 'MG' ELSE denominator_unit END 
FROM t1;
--select * from ds_0;                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           
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
       amount_value,
       amount_unit,
       numerator_value,
       numerator_unit,
      denominator_value,
       denominator_unit
FROM ds_0;

UPDATE ds_stage
   SET amount_value = NULL,
       amount_unit = NULL,
       denominator_value = NULL,
       denominator_unit = NULL,
       numerator_value = NULL,
       numerator_unit = NULL
WHERE lower(numerator_unit) IN ('ml')
OR    lower(amount_unit) IN ('ml');
--delete drugs without doses from ds_stage
DELETE
FROM ds_stage
WHERE amount_value IS NULL
AND   amount_unit is   null
AND   denominator_value is  null
AND   denominator_unit is  null
AND   numerator_value IS NULL
AND   numerator_unit is  null;
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
SELECT unit AS concept_name,
       'NCCD' AS vocabulary_id,
       'Unit' AS concept_class_id,
       unit AS concept_code,
       'Drug' AS domain_id,
       CURRENT_DATE,
       TO_DATE('20991231','YYYYMMDD'),
       NULL
FROM (SELECT amount_unit AS unit
      FROM ds_0
      UNION
      SELECT numerator_unit
      FROM ds_0
      UNION
      SELECT denominator_unit
      FROM ds_0) a
WHERE unit IS NOT NULL;
/***********************************
*** INTERNAL_RELATIONSHIP_STAGE ****
************************************/ 
-- add links from Drug Products to their Attributes (Ingredients - obligatory, Dose Forms - optional, Brand Names - optional) 
-- DP - ING
INSERT INTO internal_relationship_stage
SELECT DISTINCT nccd_code,-- Drug Product 
       REGEXP_SPLIT_TO_TABLE(ing_code,'\|')-- Ingredient
       FROM nccd_full_done
WHERE ing_code <> 'X';
-- DP - DF
INSERT INTO internal_relationship_stage
SELECT DISTINCT nccd_code,-- Drug Product 
       df_code -- Dose Form 
       FROM nccd_full_done
WHERE df_code <> 'X';
-- DP - BN
INSERT INTO internal_relationship_stage
SELECT DISTINCT nccd_code,-- Drug Product 
       bn_code -- Brand Name 
       FROM nccd_full_done
WHERE bn_code <> 'X';
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
WHERE nccd_type = 'IN';
-- source BN - target BN
INSERT INTO relationship_to_concept
(
  concept_code_1,
  vocabulary_id_1,
  concept_id_2,
  precedence
)
SELECT DISTINCT nccd_code,
'NCCD',
       concept_id,
       1
FROM nccd_full_done 
WHERE nccd_type = 'BN';
-- source UNITS - target UNITS
INSERT INTO relationship_to_concept
(
  concept_code_1,
  vocabulary_id_1,
  concept_id_2,
  precedence,
  conversion_factor
)
SELECT *
FROM (
SELECT 'U','NCCD',8510,1,1
UNION ALL
SELECT 'IU','NCCD',8718,1,1
UNION ALL
SELECT 'MG','NCCD',8576,1,1
UNION ALL
SELECT 'ML','NCCD',8587,1,1) a;
-- source DF - target DF (precendence = '1' via name matching)
WITH t AS  
(
  SELECT DISTINCT a.concept_code,
         c.concept_id
  FROM drug_concept_stage a
    JOIN concept c
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
UNION ALL
SELECT concept_code,'NCCD',19001949,3 FROM drug_concept_stage  WHERE concept_name = 'Oral Tablet' 
UNION ALL
SELECT concept_code,'NCCD',44817840,4 FROM drug_concept_stage  WHERE concept_name = 'Oral Tablet'
UNION ALL
SELECT concept_code,'NCCD',19082076,5 FROM drug_concept_stage  WHERE concept_name = 'Oral Tablet'
UNION ALL
SELECT concept_code,'NCCD',37498347,6 FROM drug_concept_stage WHERE concept_name = 'Oral Tablet'
UNION ALL
SELECT concept_code,'NCCD',19082079,2 FROM drug_concept_stage WHERE concept_name = 'Oral Capsule'
UNION ALL
SELECT concept_code ,'NCCD',19082255,3 FROM drug_concept_stage WHERE concept_name = 'Oral Capsule'
UNION ALL
SELECT concept_code, 'NCCD', 19082103, 1 FROM drug_concept_stage WHERE concept_name = 'Injectable'
UNION ALL
SELECT concept_code,'NCCD',19082104,2 FROM drug_concept_stage WHERE concept_name = 'Injectable'
UNION ALL
SELECT concept_code,'NCCD',46234469,3 FROM drug_concept_stage WHERE concept_name = 'Injectable'
UNION ALL
SELECT  concept_code,'NCCD',19126920,4 FROM drug_concept_stage WHERE concept_name = 'Injectable'
UNION ALL
SELECT concept_code,'NCCD',46234467,5 FROM drug_concept_stage WHERE concept_name = 'Injectable'
UNION ALL
SELECT concept_code,'NCCD',46234466,6 FROM drug_concept_stage WHERE concept_name = 'Injectable'
UNION ALL
SELECT concept_code,'NCCD',19095973,2 FROM drug_concept_stage WHERE concept_name = 'Gel'
UNION ALL
SELECT concept_code,'NCCD',19095916,3 FROM drug_concept_stage WHERE concept_name = 'Gel'
UNION ALL
SELECT concept_code,'NCCD',19082286,2 FROM drug_concept_stage WHERE concept_name = 'Powder'
UNION ALL
SELECT concept_code,'NCCD',19082259,3 FROM drug_concept_stage WHERE concept_name = 'Powder'
UNION ALL
SELECT concept_code,'NCCD',19082227,2 FROM drug_concept_stage WHERE concept_name = 'Ointment'
UNION ALL
SELECT concept_code,'NCCD',19082224,3 FROM drug_concept_stage WHERE concept_name = 'Ointment' 
UNION ALL
SELECT concept_code,'NCCD',19093368,2 FROM drug_concept_stage WHERE concept_name = 'Vaginal Insert'
UNION ALL
SELECT concept_code,'NCCD',19082200,2 FROM drug_concept_stage WHERE concept_name = 'Suppository'
UNION ALL
SELECT concept_code,'NCCD',19093368,3 FROM drug_concept_stage WHERE concept_name = 'Suppository'
UNION ALL
SELECT concept_code,'NCCD',19127579,2 FROM drug_concept_stage WHERE concept_name = 'Inhaler' -- 19127579	744995	Dry Powder Inhaler
UNION ALL
SELECT concept_code,'NCCD',19126919,3 FROM drug_concept_stage WHERE concept_name = 'Inhaler' -- 19126919	721655	Nasal Inhaler
UNION ALL
SELECT concept_code,'NCCD',19126918,4 FROM drug_concept_stage WHERE concept_name = 'Inhaler' -- 19126918	721654	Metered Dose Inhaler
UNION ALL
SELECT concept_code,'NCCD',19082223,2 FROM drug_concept_stage WHERE concept_name = 'Oral Solution' 
UNION ALL
SELECT concept_code, 'NCCD', 19082701, 2 FROM drug_concept_stage WHERE concept_name = 'Medicated Patch' -- 19082701	318130	Patch	Dose Form	Non-standard	Valid	Drug	RxNorm
UNION ALL
SELECT concept_code, 'NCCD', 19082165, 2 FROM drug_concept_stage WHERE concept_name = 'Nasal Spray' -- -- 19082165	316962	Nasal Solution
UNION ALL
SELECT concept_code, 'NCCD',37499224 , 2 FROM drug_concept_stage WHERE concept_name = 'Oral Granules'  -- 37499224	2284290	Delayed Release Oral Granules
UNION ALL
SELECT concept_code, 'NCCD',45775489 , 3 FROM drug_concept_stage WHERE concept_name = 'Oral Granules'  -- 45775489	1540453	Granules for Oral Solution 
UNION ALL
SELECT concept_code, 'NCCD',45775490 , 4 FROM drug_concept_stage WHERE concept_name = 'Oral Granules'  -- 45775490	1540454	Granules for Oral Suspension
UNION ALL
SELECT concept_code, 'NCCD', 19082196, 2 FROM drug_concept_stage WHERE concept_name = 'Otic Solution'  -- 19082196	316974	Otic Suspension
UNION ALL
SELECT concept_code, 'NCCD',19095918 ,2 FROM drug_concept_stage WHERE concept_name = 'Paste' -- 19095918	346171	Oral Paste 
)
SELECT * FROM t; 
-- cleaning up 
-- delete "drugs" without ingredients (they shouldn't be at the drug input tables)
DELETE
FROM drug_concept_stage
WHERE concept_code NOT IN (SELECT concept_code_1
                           FROM internal_relationship_stage
                             JOIN drug_concept_stage
                               ON concept_code_2 = concept_code
                              AND concept_class_id = 'Ingredient')
AND   concept_code NOT IN (SELECT pack_concept_code FROM pc_stage)
AND   concept_class_id = 'Drug Product';
-- drop dead mappings of attributes if any
DELETE
FROM relationship_to_concept
WHERE (concept_code_1,concept_id_2) IN (SELECT concept_code_1,
                                               concept_id_2
                                        FROM relationship_to_concept r
                                          JOIN concept c ON c.concept_id = r.concept_id_2
                                        WHERE c.invalid_reason IS NOT NULL);
                                        
