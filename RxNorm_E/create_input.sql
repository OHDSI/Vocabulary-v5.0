-- COMMENTS!!!
-- Create Concepts
TRUNCATE TABLE DRUG_CONCEPT_STAGE;

-- Get products
INSERT INTO DRUG_CONCEPT_STAGE
(
  CONCEPT_NAME,
  VOCABULARY_ID,
  CONCEPT_CLASS_ID,
  STANDARD_CONCEPT,
  CONCEPT_CODE,
  POSSIBLE_EXCIPIENT,
  domain_id,
  VALID_START_DATE,
  VALID_END_DATE,
  INVALID_REASON,
  SOURCE_CONCEPT_CLASS_ID
)
SELECT DISTINCT CONCEPT_NAME,
       'Rxfix',
       'Drug Product',
       '',
       CONCEPT_CODE,
       '',
       domain_id,
       valid_start_date,
       valid_end_date,
       INVALID_REASON,
       CONCEPT_CLASS_ID
FROM concept
WHERE REGEXP_LIKE (concept_class_id,'Drug|Pack|Box|Marketed')
AND   vocabulary_id = 'RxNorm Extension'
AND   VALID_END_DATE > '02-Feb-2017'
-- add constriction
UNION
-- Get Dose Forms, Brand Names, Supplier, including RxNorm
SELECT DISTINCT b2.CONCEPT_NAME,
       'Rxfix',
       b2.CONCEPT_CLASS_ID,
       '',
       b2.CONCEPT_CODE,
       '',
       b2.domain_id,
       b2.valid_start_date,
       b2.valid_end_date,
       b2.INVALID_REASON,
       b2.CONCEPT_CLASS_ID
FROM concept_relationship a
  JOIN concept b
    ON concept_id_1 = b.concept_id
   AND REGEXP_LIKE (b.concept_class_id,'Drug|Pack|Box|Marketed')
   AND b.vocabulary_id = 'RxNorm Extension'
   AND a.invalid_reason IS NULL
  JOIN concept b2
    ON concept_id_2 = b2.concept_id
   AND b2.concept_class_id IN ('Dose Form', 'Brand Name', 'Supplier') 
   AND b2.vocabulary_id LIKE 'Rx%'
   AND b2.invalid_reason IS NULL
UNION
--Get RxNorm pack components from RxNorm
SELECT DISTINCT b2.CONCEPT_NAME,
       'Rxfix',
       'Drug Product',
       '',
       b2.CONCEPT_CODE,
       '',
       b2.domain_id,
       b2.valid_start_date,
       b2.valid_end_date,
       b2.INVALID_REASON,
       b2.CONCEPT_CLASS_ID
FROM concept_relationship a
  JOIN concept b
    ON concept_id_1 = b.concept_id
   AND REGEXP_LIKE (b.concept_class_id,'Pack')
   AND b.vocabulary_id = 'RxNorm Extension'
   AND a.invalid_reason IS NULL
   AND a.RELATIONSHIP_ID = 'Contains'
  JOIN concept b2
    ON concept_id_2 = b2.concept_id
   AND REGEXP_LIKE (b2.concept_class_id,'Drug|Marketed')
   AND b2.vocabulary_id = 'RxNorm'
   AND b2.invalid_reason IS NULL
UNION
-- Get upgraded Dose Forms, Brand Names, Supplier
SELECT DISTINCT b3.CONCEPT_NAME,
       'Rxfix',
       b3.CONCEPT_CLASS_ID,
       '',
       b3.CONCEPT_CODE,
       '',
       b3.domain_id,
       b3.valid_start_date,
       b3.valid_end_date,
       b3.INVALID_REASON,
       b3.CONCEPT_CLASS_ID-- add fresh attributes instead of invalid
       FROM concept_relationship a
  JOIN concept b
    ON concept_id_1 = b.concept_id
   AND REGEXP_LIKE (b.concept_class_id,'Drug|Pack|Box|Marketed')
   AND b.vocabulary_id = 'RxNorm Extension'
  JOIN concept b2
    ON concept_id_2 = b2.concept_id
   AND b2.concept_class_id IN ('Dose Form', 'Brand Name', 'Supplier') 
   AND b2.vocabulary_id LIKE 'Rx%'
   AND b2.invalid_reason IS NOT NULL
  JOIN concept_relationship a2
    ON a2.concept_id_1 = b2.concept_id
   AND a2.RELATIONSHIP_ID = 'Concept replaced by'
  JOIN concept b3
    ON a2.concept_id_2 = b3.concept_id
   AND b3.concept_class_id IN ('Dose Form', 'Brand Name', 'Supplier') 
   AND b3.vocabulary_id LIKE 'Rx%'
UNION
-- Ingredients: Need to check what happens to deprecated
-- Get ingredients from drug_strength (XXX might not be necessary) 
SELECT DISTINCT CONCEPT_NAME,
       'Rxfix',
       'Ingredient',
       'S',
       CONCEPT_CODE,
       '',
       domain_id,
       valid_start_date,
       valid_end_date,
       INVALID_REASON,
       'Ingredient'
FROM (SELECT b.concept_name,
             b.concept_code,
             b.domain_id,
             b.valid_start_date,
             b.valid_end_date,
             b.INVALID_REASON
      FROM drug_strength a
        JOIN concept b
          ON a.ingredient_concept_id = b.concept_id
         AND b.invalid_reason IS NULL
        JOIN concept c
          ON a.drug_concept_id = c.concept_id
         AND c.vocabulary_id = 'RxNorm Extension'
      WHERE b.vocabulary_id LIKE 'Rx%'
      UNION
      -- Get ingredients from hierarchy
      SELECT a.concept_name,
             a.concept_code,
             a.domain_id,
             a.valid_start_date,
             a.valid_end_date,
             a.INVALID_REASON--add ingredients from ancestor
             FROM concept a
        JOIN concept_ancestor b
          ON a.concept_id = ancestor_concept_id
         AND a.concept_class_id = 'Ingredient'
        JOIN concept a2
          ON descendant_concept_id = a2.concept_id
         AND a2.vocabulary_id = 'RxNorm Extension')
UNION
-- Units
SELECT DISTINCT CONCEPT_NAME,
       'Rxfix',
       'Unit',
       '',
       CONCEPT_CODE,
       '',
       'Drug',
       TO_DATE('2017/01/24','yyyy/mm/dd'),
       TO_DATE('2099/12/31','yyyy/mm/dd'),
       '',
       'Unit'
FROM (SELECT DISTINCT CONCEPT_NAME,
             CONCEPT_CODE
      FROM (SELECT DISTINCT c3.CONCEPT_CODE AS concept_name,
                   c3.CONCEPT_CODE AS concept_code
            FROM concept c
              JOIN drug_strength ds
                ON ds.DRUG_CONCEPT_ID = c.CONCEPT_ID
               AND c.vocabulary_id = 'RxNorm Extension'
              JOIN concept c3 ON AMOUNT_UNIT_CONCEPT_ID = c3.CONCEPT_ID
            UNION
            SELECT DISTINCT c2.CONCEPT_CODE,
                   c2.CONCEPT_CODE
            FROM concept c
              JOIN drug_strength ds
                ON ds.DRUG_CONCEPT_ID = c.CONCEPT_ID
               AND c.vocabulary_id = 'RxNorm Extension'
              JOIN concept c2 ON NUMERATOR_UNIT_CONCEPT_ID = c2.CONCEPT_ID
            UNION
            SELECT DISTINCT c1.CONCEPT_CODE,
                   c1.CONCEPT_CODE
            FROM concept c
              JOIN drug_strength ds
                ON ds.DRUG_CONCEPT_ID = c.CONCEPT_ID
               AND c.vocabulary_id = 'RxNorm Extension'
              JOIN concept c1 ON DENOMINATOR_UNIT_CONCEPT_ID = c1.CONCEPT_ID));

-- Remove all deprecated
DELETE drug_concept_stage
WHERE concept_code IN (SELECT concept_code
                       FROM concept
                       WHERE vocabulary_id LIKE 'RxNorm%'
                       AND   invalid_reason = 'D'
                       AND   VALID_END_DATE < '02-Feb-2017');

-- Remove all where there is less than total of 0.05 mL
DELETE drug_concept_stage
WHERE concept_code IN (SELECT concept_code
                       FROM concept c
                         JOIN devv5.drug_strength ds
                           ON drug_concept_id = concept_id
                          AND vocabulary_id = 'RxNorm Extension'
                          AND c.invalid_reason IS NULL
                       WHERE denominator_value < 0.05
                       AND   denominator_unit_concept_id = 8587);

--Remove wrong brand names
DELETE drug_concept_stage
WHERE concept_code IN (SELECT d1.concept_code
                       FROM drug_concept_stage d1
                         JOIN concept c
                           ON LOWER (d1.concept_name) = LOWER (c.concept_name)
                          AND d1.concept_class_id = 'Brand Name'
                          AND c.concept_class_id IN ('ATC 5th', 
                                                                            'ATC 4th', 
                                                                            'ATC 3rd', 
                                                                            'AU Substance', 
                                                                            'AU Qualifier', 
                                                                            'Chemical Structure', 
                                                                            'CPT4 Hierarchy', 
                                                                            'Gemscript', 
                                                                            'Gemscript THIN', 
                                                                            'GPI', 
                                                                            'Ingredient', 
                                                                            'Substance', 
                                                                            'LOINC Hierarchy', 
                                                                            'Main Heading', 
                                                                            'Organism', 
                                                                            'Pharma Preparation'
                                                                            )
UNION
                       SELECT concept_code
                       FROM drug_concept_stage
                       WHERE concept_class_id = 'Brand Name'
                       AND   REGEXP_LIKE (concept_name,'Comp\s|Comp$|Praeparatum')
                       AND   NOT REGEXP_LIKE (concept_name,'Ratioph|Zentiva|Actavis|Teva|Hormosan|Dura|Ass|Provas|Rami|Al |Pharma|Abz|-Q|Peritrast|Beloc|Hexal|Corax|Solgar|Winthrop'));

--insert into drug_concept_stage (CONCEPT_NAME,DOMAIN_ID,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,VALID_START_DATE,VALID_END_DATE,INVALID_REASON) 
--select CONCEPT_NAME,DOMAIN_ID,'Rxfix',CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,VALID_START_DATE,VALID_END_DATE,INVALID_REASON from concept_stage where concept_name='Fotemustine' and invalid_reason is null;
-- drug_strength
TRUNCATE TABLE ds_stage;

INSERT INTO ds_stage
(
  DRUG_CONCEPT_CODE,
  INGREDIENT_CONCEPT_CODE,
  BOX_SIZE,
  AMOUNT_VALUE,
  AMOUNT_UNIT,
  NUMERATOR_VALUE,
  NUMERATOR_UNIT,
  DENOMINATOR_VALUE,
  DENOMINATOR_UNIT
)
SELECT c.concept_code,
       c2.concept_code,
       box_size,
       AMOUNT_VALUE,
       c3.CONCEPT_CODE,
       NUMERATOR_VALUE,
       c4.CONCEPT_CODE,
       DENOMINATOR_VALUE,
       c5.CONCEPT_CODE
FROM concept c
  JOIN devv5.drug_strength ds ON ds.DRUG_CONCEPT_ID = c.CONCEPT_ID
  JOIN concept c2 ON ds.INGREDIENT_CONCEPT_ID = c2.CONCEPT_ID
  LEFT JOIN concept c3 ON AMOUNT_UNIT_CONCEPT_ID = c3.CONCEPT_ID
  LEFT JOIN concept c4 ON NUMERATOR_UNIT_CONCEPT_ID = c4.CONCEPT_ID
  LEFT JOIN concept c5 ON DENOMINATOR_UNIT_CONCEPT_ID = c5.CONCEPT_ID
WHERE c.vocabulary_id = 'RxNorm Extension';

--update ds_stage for homeopathic drugs
UPDATE ds_stage
   SET amount_value = numerator_value,
       amount_unit = numerator_unit,
       numerator_value = NULL,
       numerator_unit = NULL,
       denominator_value = NULL,
       denominator_unit = NULL
WHERE drug_Concept_Code IN (SELECT drug_concept_code
                            FROM ds_Stage
                            WHERE numerator_unit IN ('[hp_X]','[hp_C]'));

-- Manually add absent units in drug_strength
UPDATE DS_STAGE
   SET AMOUNT_UNIT = '[U]'
WHERE DRUG_CONCEPT_CODE = 'OMOP467711'
AND   INGREDIENT_CONCEPT_CODE = '560';

UPDATE DS_STAGE
   SET AMOUNT_UNIT = '[U]'
WHERE DRUG_CONCEPT_CODE = 'OMOP467709'
AND   INGREDIENT_CONCEPT_CODE = '560';

UPDATE DS_STAGE
   SET AMOUNT_VALUE = 100,
       AMOUNT_UNIT = 'mg',
       NUMERATOR_VALUE = NULL,
       NUMERATOR_UNIT = ''
WHERE DRUG_CONCEPT_CODE = 'OMOP420833'
AND   INGREDIENT_CONCEPT_CODE = '1202';

UPDATE DS_STAGE
   SET AMOUNT_UNIT = '[U]'
WHERE DRUG_CONCEPT_CODE = 'OMOP467706'
AND   INGREDIENT_CONCEPT_CODE = '560';

UPDATE DS_STAGE
   SET AMOUNT_VALUE = 25,
       AMOUNT_UNIT = 'mg',
       NUMERATOR_VALUE = NULL,
       NUMERATOR_UNIT = ''
WHERE DRUG_CONCEPT_CODE = 'OMOP420835'
AND   INGREDIENT_CONCEPT_CODE = '2409';

UPDATE DS_STAGE
   SET AMOUNT_UNIT = '[U]'
WHERE DRUG_CONCEPT_CODE = 'OMOP467710'
AND   INGREDIENT_CONCEPT_CODE = '560';

UPDATE DS_STAGE
   SET AMOUNT_UNIT = '[U]'
WHERE DRUG_CONCEPT_CODE = 'OMOP467715'
AND   INGREDIENT_CONCEPT_CODE = '560';

UPDATE DS_STAGE
   SET AMOUNT_UNIT = '[U]'
WHERE DRUG_CONCEPT_CODE = 'OMOP467705'
AND   INGREDIENT_CONCEPT_CODE = '560';

UPDATE DS_STAGE
   SET AMOUNT_UNIT = '[U]'
WHERE DRUG_CONCEPT_CODE = 'OMOP467712'
AND   INGREDIENT_CONCEPT_CODE = '560';

UPDATE DS_STAGE
   SET AMOUNT_UNIT = '[U]',
       NUMERATOR_UNIT = ''
WHERE DRUG_CONCEPT_CODE = 'OMOP467708'
AND   INGREDIENT_CONCEPT_CODE = '560';

UPDATE DS_STAGE
   SET AMOUNT_VALUE = 100,
       AMOUNT_UNIT = 'mg',
       NUMERATOR_VALUE = NULL,
       NUMERATOR_UNIT = ''
WHERE DRUG_CONCEPT_CODE = 'OMOP420834'
AND   INGREDIENT_CONCEPT_CODE = '1202';

UPDATE DS_STAGE
   SET AMOUNT_UNIT = '[U]'
WHERE DRUG_CONCEPT_CODE = 'OMOP467714'
AND   INGREDIENT_CONCEPT_CODE = '560';

UPDATE DS_STAGE
   SET AMOUNT_VALUE = 25,
       AMOUNT_UNIT = 'mg',
       NUMERATOR_VALUE = NULL,
       NUMERATOR_UNIT = ''
WHERE DRUG_CONCEPT_CODE = 'OMOP420834'
AND   INGREDIENT_CONCEPT_CODE = '2409';

UPDATE DS_STAGE
   SET AMOUNT_UNIT = '[U]'
WHERE DRUG_CONCEPT_CODE = 'OMOP467713'
AND   INGREDIENT_CONCEPT_CODE = '560';

UPDATE DS_STAGE
   SET AMOUNT_VALUE = 25,
       AMOUNT_UNIT = 'mg',
       NUMERATOR_VALUE = NULL,
       NUMERATOR_UNIT = ''
WHERE DRUG_CONCEPT_CODE = 'OMOP420731'
AND   INGREDIENT_CONCEPT_CODE = '2409';

UPDATE DS_STAGE
   SET AMOUNT_VALUE = 100,
       AMOUNT_UNIT = 'mg',
       NUMERATOR_VALUE = NULL,
       NUMERATOR_UNIT = ''
WHERE DRUG_CONCEPT_CODE = 'OMOP420832'
AND   INGREDIENT_CONCEPT_CODE = '1202';

UPDATE DS_STAGE
   SET AMOUNT_VALUE = 25,
       AMOUNT_UNIT = 'mg',
       NUMERATOR_VALUE = NULL,
       NUMERATOR_UNIT = ''
WHERE DRUG_CONCEPT_CODE = 'OMOP420833'
AND   INGREDIENT_CONCEPT_CODE = '2409';

UPDATE DS_STAGE
   SET AMOUNT_VALUE = 100,
       AMOUNT_UNIT = 'mg',
       NUMERATOR_VALUE = NULL,
       NUMERATOR_UNIT = ''
WHERE DRUG_CONCEPT_CODE = 'OMOP420835'
AND   INGREDIENT_CONCEPT_CODE = '1202';

-- Fix micrograms and iU
UPDATE ds_stage
   SET NUMERATOR_UNIT = 'mg',
       NUMERATOR_VALUE = NUMERATOR_VALUE / 1000
WHERE NUMERATOR_UNIT = 'ug';

UPDATE ds_stage
   SET AMOUNT_UNIT = 'mg',
       AMOUNT_VALUE = AMOUNT_VALUE / 1000
WHERE AMOUNT_UNIT = 'ug';

UPDATE ds_stage
   SET AMOUNT_UNIT = '[iU]',
       AMOUNT_VALUE = AMOUNT_VALUE*1000000
WHERE AMOUNT_UNIT = 'ukat';

UPDATE ds_stage
   SET NUMERATOR_UNIT = '[U]'
WHERE NUMERATOR_UNIT = '[iU]';

UPDATE ds_stage
   SET DENOMINATOR_UNIT = '[U]'
WHERE DENOMINATOR_UNIT = '[iU]';

UPDATE ds_stage
   SET AMOUNT_UNIT = '[U]'
WHERE AMOUNT_UNIT = '[iU]';

-- Do all sorts of manual fixes
-- Fentanyl buccal film
UPDATE ds_stage
   SET AMOUNT_VALUE = NUMERATOR_VALUE,
       AMOUNT_UNIT = NUMERATOR_UNIT,
       DENOMINATOR_VALUE = NULL,
       DENOMINATOR_UNIT = NULL,
       NUMERATOR_UNIT = NULL,
       NUMERATOR_VALUE = NULL
WHERE DRUG_CONCEPT_CODE IN (SELECT DRUG_CONCEPT_CODE
                            FROM ds_stage a
                              JOIN drug_concept_stage b ON a.drug_concept_code = b.concept_code
                            WHERE NVL(AMOUNT_UNIT,NUMERATOR_UNIT) IN ('cm','mm')
                            OR    DENOMINATOR_UNIT IN ('cm','mm')
                            AND   (b.concept_name LIKE '%Buccal Film%' OR b.concept_name LIKE '%Breakyl Start%'));

-- Fentanyl buccal film
UPDATE ds_stage
   SET AMOUNT_VALUE = NUMERATOR_VALUE,
       AMOUNT_UNIT = NUMERATOR_UNIT,
       DENOMINATOR_VALUE = NULL,
       DENOMINATOR_UNIT = NULL,
       NUMERATOR_UNIT = NULL,
       NUMERATOR_VALUE = NULL
WHERE DRUG_CONCEPT_CODE IN (SELECT DRUG_CONCEPT_CODE
                            FROM ds_stage a
                              JOIN drug_concept_stage b ON a.drug_concept_code = b.concept_code
                            WHERE NVL(AMOUNT_UNIT,NUMERATOR_UNIT) IN ('cm','mm')
                            OR    DENOMINATOR_UNIT IN ('cm','mm')
                            AND   (b.concept_name LIKE '%Buccal Film%' OR b.concept_name LIKE '%Breakyl Start%' OR NUMERATOR_VALUE IN ('0.808','1.21','1.62')));

-- Add denominator to trandermal patch
UPDATE ds_stage
   SET NUMERATOR_VALUE = 0.012,
       DENOMINATOR_VALUE = NULL,
       DENOMINATOR_UNIT = 'h',
       AMOUNT_UNIT = NULL,
       AMOUNT_VALUE = NULL,
       NUMERATOR_UNIT = 'mg'
WHERE DRUG_CONCEPT_CODE IN (SELECT DRUG_CONCEPT_CODE
                            FROM ds_stage a
                              JOIN drug_concept_stage b ON a.drug_concept_code = b.concept_code
                            --also found like 0.4*5.25 cm=2.1 mg=0.012/h 
                            WHERE b.concept_name LIKE '%Fentanyl%Transdermal%'
                            AND   AMOUNT_VALUE IN ('2.55','2.1','2.5','0.4','1.38'));

UPDATE ds_stage
   SET NUMERATOR_VALUE = 0.025,
       DENOMINATOR_VALUE = NULL,
       DENOMINATOR_UNIT = 'h',
       AMOUNT_UNIT = NULL,
       AMOUNT_VALUE = NULL,
       NUMERATOR_UNIT = 'mg'
WHERE DRUG_CONCEPT_CODE IN (SELECT DRUG_CONCEPT_CODE
                            FROM ds_stage a
                              JOIN drug_concept_stage b ON a.drug_concept_code = b.concept_code
                            WHERE b.concept_name LIKE '%Fentanyl%Transdermal%'
                            AND   AMOUNT_VALUE IN ('0.275','2.75','3.72','4.2','5.1','0.6','0.319','0.25','5','4.8'));

UPDATE ds_stage
   SET NUMERATOR_VALUE = 0.05,
       DENOMINATOR_VALUE = NULL,
       DENOMINATOR_UNIT = 'h',
       AMOUNT_UNIT = NULL,
       AMOUNT_VALUE = NULL,
       NUMERATOR_UNIT = 'mg'
WHERE DRUG_CONCEPT_CODE IN (SELECT DRUG_CONCEPT_CODE
                            FROM ds_stage a
                              JOIN drug_concept_stage b ON a.drug_concept_code = b.concept_code
                            WHERE b.concept_name LIKE '%Fentanyl%Transdermal%'
                            AND   AMOUNT_VALUE IN ('5.5','10.2','7.5','8.25','8.4','0.875','9.6','14.4','15.5'));

UPDATE ds_stage
   SET NUMERATOR_VALUE = 0.075,
       DENOMINATOR_VALUE = NULL,
       DENOMINATOR_UNIT = 'h',
       AMOUNT_UNIT = NULL,
       AMOUNT_VALUE = NULL,
       NUMERATOR_UNIT = 'mg'
WHERE DRUG_CONCEPT_CODE IN (SELECT DRUG_CONCEPT_CODE
                            FROM ds_stage a
                              JOIN drug_concept_stage b ON a.drug_concept_code = b.concept_code
                            --168
                            WHERE b.concept_name LIKE '%Fentanyl%Transdermal%'
                            AND   AMOUNT_VALUE IN ('12.6','15.3','12.4','19.2','23.1'));

UPDATE ds_stage
   SET NUMERATOR_VALUE = 0.1,
       DENOMINATOR_VALUE = NULL,
       DENOMINATOR_UNIT = 'h',
       AMOUNT_UNIT = NULL,
       AMOUNT_VALUE = NULL,
       NUMERATOR_UNIT = 'mg'
WHERE DRUG_CONCEPT_CODE IN (SELECT DRUG_CONCEPT_CODE
                            FROM ds_stage a
                              JOIN drug_concept_stage b ON a.drug_concept_code = b.concept_code
                            --168
                            WHERE b.concept_name LIKE '%Fentanyl%Transdermal%'
                            AND   AMOUNT_VALUE IN ('16.8','10','11','20.4','16.5'));

-- Fentanyl topical
UPDATE ds_stage
   SET NUMERATOR_VALUE = 0.012,
       DENOMINATOR_VALUE = NULL,
       DENOMINATOR_UNIT = 'h'
WHERE DRUG_CONCEPT_CODE IN (SELECT DRUG_CONCEPT_CODE
                            FROM ds_stage a
                              JOIN drug_concept_stage b ON a.drug_concept_code = b.concept_code
                            --also found like 0.4*5.25 cm=2.1 mg=0.012/h
                            WHERE NVL(AMOUNT_UNIT,NUMERATOR_UNIT) IN ('cm','mm')
                            OR    DENOMINATOR_UNIT IN ('cm','mm')
                            AND   REGEXP_LIKE (b.concept_name,'Fentanyl')
                            AND   NUMERATOR_VALUE IN ('2.55','2.1','2.5','0.4'));

UPDATE ds_stage
   SET NUMERATOR_VALUE = 0.025,
       DENOMINATOR_VALUE = NULL,
       DENOMINATOR_UNIT = 'h'
WHERE DRUG_CONCEPT_CODE IN (SELECT DRUG_CONCEPT_CODE
                            FROM ds_stage a
                              JOIN drug_concept_stage b ON a.drug_concept_code = b.concept_code
                            WHERE NVL(AMOUNT_UNIT,NUMERATOR_UNIT) IN ('cm','mm')
                            OR    DENOMINATOR_UNIT IN ('cm','mm')
                            AND   REGEXP_LIKE (b.concept_name,'Fentanyl')
                            AND   NUMERATOR_VALUE IN ('0.275','2.75','3.72','4.2','5.1','0.6','0.319','0.25','5'));

UPDATE ds_stage
   SET NUMERATOR_VALUE = 0.05,
       DENOMINATOR_VALUE = NULL,
       DENOMINATOR_UNIT = 'h'
WHERE DRUG_CONCEPT_CODE IN (SELECT DRUG_CONCEPT_CODE
                            FROM ds_stage a
                              JOIN drug_concept_stage b ON a.drug_concept_code = b.concept_code
                            WHERE NVL(AMOUNT_UNIT,NUMERATOR_UNIT) IN ('cm','mm')
                            OR    DENOMINATOR_UNIT IN ('cm','mm')
                            AND   REGEXP_LIKE (b.concept_name,'Fentanyl')
                            AND   NUMERATOR_VALUE IN ('5.5','10.2','7.5','8.25','8.4','0.875'));

UPDATE ds_stage
   SET NUMERATOR_VALUE = 0.075,
       DENOMINATOR_VALUE = NULL,
       DENOMINATOR_UNIT = 'h'
WHERE DRUG_CONCEPT_CODE IN (SELECT DRUG_CONCEPT_CODE
                            FROM ds_stage a
                              JOIN drug_concept_stage b ON a.drug_concept_code = b.concept_code
                            --168
                            WHERE NVL(AMOUNT_UNIT,NUMERATOR_UNIT) IN ('cm','mm')
                            OR    DENOMINATOR_UNIT IN ('cm','mm')
                            AND   REGEXP_LIKE (b.concept_name,'Fentanyl')
                            AND   NUMERATOR_VALUE IN ('12.6','15.3'));

UPDATE ds_stage
   SET NUMERATOR_VALUE = 0.1,
       DENOMINATOR_VALUE = NULL,
       DENOMINATOR_UNIT = 'h'
WHERE DRUG_CONCEPT_CODE IN (SELECT DRUG_CONCEPT_CODE
                            FROM ds_stage a
                              JOIN drug_concept_stage b ON a.drug_concept_code = b.concept_code
                            --168
                            WHERE NVL(AMOUNT_UNIT,NUMERATOR_UNIT) IN ('cm','mm')
                            OR    DENOMINATOR_UNIT IN ('cm','mm')
                            AND   REGEXP_LIKE (b.concept_name,'Fentanyl')
                            AND   NUMERATOR_VALUE IN ('16.8','10','11','20.4'));

--rivastigmine
UPDATE ds_stage
   SET NUMERATOR_VALUE = 13.3,
       DENOMINATOR_VALUE = 24,
       DENOMINATOR_UNIT = 'h'
WHERE DRUG_CONCEPT_CODE IN (SELECT DRUG_CONCEPT_CODE
                            FROM ds_stage a
                              JOIN drug_concept_stage b ON a.drug_concept_code = b.concept_code
                            WHERE NVL(AMOUNT_UNIT,NUMERATOR_UNIT) IN ('cm','mm')
                            OR    DENOMINATOR_UNIT IN ('cm','mm')
                            AND   b.concept_name LIKE '%rivastigmine%'
                            AND   NUMERATOR_VALUE = 27);

UPDATE ds_stage
   SET NUMERATOR_VALUE = CASE
                           WHEN DENOMINATOR_VALUE IS NULL THEN NUMERATOR_VALUE*24
                           ELSE NUMERATOR_VALUE / DENOMINATOR_VALUE*24
                         END 
,
       DENOMINATOR_VALUE = 24,
       DENOMINATOR_UNIT = 'h'
WHERE DRUG_CONCEPT_CODE IN (SELECT DRUG_CONCEPT_CODE
                            FROM ds_stage a
                              JOIN drug_concept_stage b ON a.drug_concept_code = b.concept_code
                            WHERE NVL(AMOUNT_UNIT,NUMERATOR_UNIT) IN ('cm','mm')
                            OR    DENOMINATOR_UNIT IN ('cm','mm')
                            AND   b.concept_name LIKE '%rivastigmine%');

--nicotine
UPDATE ds_stage
   SET NUMERATOR_VALUE = CASE
                           WHEN DENOMINATOR_VALUE IS NULL THEN NUMERATOR_VALUE*16
                           ELSE NUMERATOR_VALUE / DENOMINATOR_VALUE*16
                         END 
,
       DENOMINATOR_VALUE = 16,
       DENOMINATOR_UNIT = 'h'
WHERE DRUG_CONCEPT_CODE IN (SELECT DRUG_CONCEPT_CODE
                            FROM ds_stage a
                              JOIN drug_concept_stage b ON a.drug_concept_code = b.concept_code
                            WHERE NVL(AMOUNT_UNIT,NUMERATOR_UNIT) IN ('cm','mm')
                            OR    DENOMINATOR_UNIT IN ('cm','mm')
                            AND   b.concept_name LIKE '%Nicotine%'
                            AND   NUMERATOR_VALUE IN ('0.625','0.938','1.56','35.2'));

UPDATE ds_stage
   SET NUMERATOR_VALUE = 14,
       DENOMINATOR_VALUE = 24,
       DENOMINATOR_UNIT = 'h'
WHERE DRUG_CONCEPT_CODE IN (SELECT DRUG_CONCEPT_CODE
                            FROM ds_stage a
                              JOIN drug_concept_stage b ON a.drug_concept_code = b.concept_code
                            WHERE NVL(AMOUNT_UNIT,NUMERATOR_UNIT) IN ('cm','mm')
                            OR    DENOMINATOR_UNIT IN ('cm','mm')
                            AND   b.concept_name LIKE '%Nicotine%'
                            AND   NUMERATOR_VALUE IN ('5.57','5.14','36','78'));

--Povidone-Iodine
UPDATE ds_stage
   SET numerator_value = '100',
       denominator_value = NULL,
       DENOMINATOR_UNIT = 'mL'
WHERE drug_concept_code IN (SELECT drug_concept_code
                            FROM ds_stage a
                              JOIN drug_concept_stage b ON a.drug_concept_code = b.concept_code
                            WHERE NVL(AMOUNT_UNIT,NUMERATOR_UNIT) IN ('cm','mm')
                            OR    DENOMINATOR_UNIT IN ('cm','mm')
                            AND   concept_name LIKE '%Povidone-Iodine%');

-- XXX Delete cm2 if RxNorm doesn't have it +++
--the other cm
DELETE ds_stage
WHERE DRUG_CONCEPT_CODE IN (SELECT DRUG_CONCEPT_CODE
                            FROM ds_stage a
                              JOIN drug_concept_stage b ON a.drug_concept_code = b.concept_code
                            WHERE NVL(AMOUNT_UNIT,NUMERATOR_UNIT) IN ('cm','mm')
                            OR    DENOMINATOR_UNIT IN ('cm','mm'));

COMMIT;

-- XXX ??????! Check ingredients first
-- Delete 3 legged dogs
DELETE ds_stage
WHERE drug_concept_code IN (WITH a AS
                            (
                              SELECT drug_concept_id,
                                     COUNT(drug_concept_id) AS cnt1
                              FROM drug_strength
                              GROUP BY drug_concept_id
                            ),
                            b AS
                            (
                              SELECT descendant_concept_id,
                                     COUNT(descendant_concept_id) AS cnt2
                              FROM concept_ancestor a
                                JOIN concept b
                                  ON ancestor_concept_id = b.concept_id
                                 AND concept_class_id = 'Ingredient'
                                JOIN concept b2 ON descendant_concept_id = b2.concept_id
                              WHERE b2.concept_class_id NOT LIKE '%Comp%'
                              GROUP BY descendant_concept_id
                            )
                            SELECT concept_code
                            FROM a
                              JOIN b ON a.drug_concept_id = b.descendant_concept_id
                              JOIN concept c ON drug_concept_id = concept_id
                            WHERE cnt1 < cnt2
                            AND   c.vocabulary_id != 'RxNorm');

--delete drugs that have denominator_value less than 0.05
-- Remove those with less than 0.05 ml in denominator
DELETE ds_stage
WHERE drug_concept_code IN (SELECT drug_concept_code
                            FROM ds_stage
                            WHERE denominator_value < 0.05
                            AND   denominator_unit = 'mL');

-- Fixes U/mg to U/mL
UPDATE DS_STAGE
   SET NUMERATOR_VALUE = 10000,
       DENOMINATOR_UNIT = 'mL'
WHERE DRUG_CONCEPT_CODE = 'OMOP420658'
AND   INGREDIENT_CONCEPT_CODE = '8536'
AND   AMOUNT_VALUE IS NULL
AND   AMOUNT_UNIT IS NULL
AND   NUMERATOR_VALUE = 10
AND   NUMERATOR_UNIT = '[U]'
AND   DENOMINATOR_VALUE IS NULL
AND   DENOMINATOR_UNIT = 'mg';

UPDATE DS_STAGE
   SET NUMERATOR_VALUE = 10000,
       DENOMINATOR_UNIT = 'mL'
WHERE DRUG_CONCEPT_CODE = 'OMOP420659'
AND   INGREDIENT_CONCEPT_CODE = '8536'
AND   AMOUNT_VALUE IS NULL
AND   AMOUNT_UNIT IS NULL
AND   NUMERATOR_VALUE = 10
AND   NUMERATOR_UNIT = '[U]'
AND   DENOMINATOR_VALUE IS NULL
AND   DENOMINATOR_UNIT = 'mg';

UPDATE DS_STAGE
   SET NUMERATOR_VALUE = 10000,
       DENOMINATOR_UNIT = 'mL'
WHERE DRUG_CONCEPT_CODE = 'OMOP420660'
AND   INGREDIENT_CONCEPT_CODE = '8536'
AND   AMOUNT_VALUE IS NULL
AND   AMOUNT_UNIT IS NULL
AND   NUMERATOR_VALUE = 10
AND   NUMERATOR_UNIT = '[U]'
AND   DENOMINATOR_VALUE IS NULL
AND   DENOMINATOR_UNIT = 'mg';

UPDATE DS_STAGE
   SET NUMERATOR_VALUE = 10000,
       DENOMINATOR_UNIT = 'mL'
WHERE DRUG_CONCEPT_CODE = 'OMOP420661'
AND   INGREDIENT_CONCEPT_CODE = '8536'
AND   AMOUNT_VALUE IS NULL
AND   AMOUNT_UNIT IS NULL
AND   NUMERATOR_VALUE = 10
AND   NUMERATOR_UNIT = '[U]'
AND   DENOMINATOR_VALUE IS NULL
AND   DENOMINATOR_UNIT = 'mg';

-- Create consolidated denominator unit for drugs that have soluble and solid ingredients in the same drug 
UPDATE ds_stage ds
   SET numerator_value = amount_value,
       numerator_unit = amount_unit,
       amount_unit = NULL,
       amount_value = NULL,
       denominator_unit = 'mL'
WHERE drug_concept_code IN (SELECT drug_concept_code
                            FROM ds_Stage a
                              JOIN ds_stage b USING (drug_concept_code)
                            WHERE a.amount_value IS NOT NULL
                            AND   b.numerator_value IS NOT NULL
                            AND   b.DENOMINATOR_UNIT = 'mL')
AND   amount_value IS NOT NULL;

UPDATE ds_stage ds
   SET numerator_value = amount_value,
       numerator_unit = amount_unit,
       amount_unit = NULL,
       amount_value = NULL,
       denominator_unit = 'mg'
WHERE drug_concept_code IN (SELECT drug_concept_code
                            FROM ds_Stage a
                              JOIN ds_stage b USING (drug_concept_code)
                            WHERE a.amount_value IS NOT NULL
                            AND   b.numerator_value IS NOT NULL
                            AND   b.DENOMINATOR_UNIT = 'mg')
AND   amount_value IS NOT NULL;

--update different denominator units
MERGE INTO ds_stage ds
USING
(
  SELECT DISTINCT a.DRUG_CONCEPT_CODE,
         REGEXP_SUBSTR(concept_name,'^\d+(\.\d+)?') AS cx
  FROM ds_stage a
    JOIN ds_stage b ON a.drug_concept_code = b.drug_concept_code
    JOIN concept_stage c
      ON c.concept_code = a.drug_concept_code
     AND c.vocabulary_id = 'RxNorm Extension'
  WHERE a.DENOMINATOR_VALUE != b.DENOMINATOR_VALUE
) d ON (d.DRUG_CONCEPT_CODE = ds.DRUG_CONCEPT_CODE)
WHEN MATCHED THEN UPDATE
  SET DENOMINATOR_VALUE = cx WHERE d.DRUG_CONCEPT_CODE = ds.DRUG_CONCEPT_CODE;

-- XXX ?? ????
--rounding
UPDATE ds_stage
   SET AMOUNT_VALUE = ROUND(AMOUNT_VALUE,3 - FLOOR(LOG(10,AMOUNT_VALUE)) -1),
       NUMERATOR_VALUE = ROUND(NUMERATOR_VALUE,3 - FLOOR(LOG(10,NUMERATOR_VALUE)) -1),
       DENOMINATOR_VALUE = ROUND(DENOMINATOR_VALUE,3 - FLOOR(LOG(10,DENOMINATOR_VALUE)) -1);

COMMIT;

--fix solid forms with denominator
UPDATE ds_Stage
   SET amount_unit = numerator_unit,
       amount_value = numerator_value,
       numerator_value = NULL,
       numerator_unit = NULL,
       denominator_value = NULL,
       denominator_unit = NULL
WHERE drug_concept_Code IN (SELECT a.concept_Code
                            FROM concept a
                              JOIN drug_strength d
                                ON concept_id = drug_concept_id
                               AND denominator_unit_concept_id IS NOT NULL
                               AND REGEXP_LIKE (concept_name,'Tablet|Capsule')
                               AND vocabulary_id = 'RxNorm Extension');

-- Delete combination drugs where denominators don't match
DELETE ds_stage
WHERE (drug_concept_code,denominator_value) IN (SELECT DISTINCT a.drug_concept_code,
                                                       a.denominator_value
                                                FROM ds_stage a
                                                  JOIN ds_stage b
                                                    ON a.drug_concept_code = b.drug_concept_code
                                                   AND (a.DENOMINATOR_VALUE IS NULL
                                                   AND b.DENOMINATOR_VALUE IS NOT NULL
                                                    OR a.DENOMINATOR_VALUE != b.DENOMINATOR_VALUE
                                                    OR a.DENOMINATOR_unit != b.DENOMINATOR_unit)
                                                  JOIN drug_concept_stage
                                                    ON concept_code = a.drug_concept_code
                                                   AND a.denominator_value != REGEXP_SUBSTR (concept_name,'\d+(\.\d+)?'));

COMMIT;

-- Put percent into the numerator, not amount
UPDATE ds_stage
   SET numerator_unit = amount_unit,
       NUMERATOR_VALUE = AMOUNT_VALUE,
       AMOUNT_VALUE = NULL,
       amount_unit = NULL
WHERE amount_unit = '%';

-- More manual fixes
UPDATE DS_STAGE
   SET NUMERATOR_VALUE = 25
WHERE DRUG_CONCEPT_CODE = 'OMOP303266';

UPDATE DS_STAGE
   SET NUMERATOR_VALUE = 25
WHERE DRUG_CONCEPT_CODE = 'OMOP303267';

UPDATE DS_STAGE
   SET NUMERATOR_VALUE = 25
WHERE DRUG_CONCEPT_CODE = 'OMOP303268';

UPDATE DS_STAGE
   SET NUMERATOR_VALUE = 1
WHERE DRUG_CONCEPT_CODE = 'OMOP317478';

UPDATE DS_STAGE
   SET NUMERATOR_VALUE = 1
WHERE DRUG_CONCEPT_CODE = 'OMOP317479';

UPDATE DS_STAGE
   SET NUMERATOR_VALUE = 1
WHERE DRUG_CONCEPT_CODE = 'OMOP317480';

UPDATE DS_STAGE
   SET DENOMINATOR_UNIT = 'mL'
WHERE DRUG_CONCEPT_CODE IN ('OMOP420658','OMOP420659','OMOP420660','OMOP420661');

-- XXX Check this with Christian  obviosly it's just a percent so I changed it to mg/ml select * from devv5.drug_strength join devv5.concept on drug_Concept_id=concept_id where denominator_unit_concept_id=45744809 and numerator_unit_Concept_id=8554 ;
-- Change %/actuat into mg/mL
UPDATE ds_stage
   SET NUMERATOR_VALUE = NUMERATOR_VALUE*10,
       NUMERATOR_UNIT = 'mg',
       DENOMINATOR_VALUE = NULL,
       DENOMINATOR_UNIT = 'mL'
WHERE DENOMINATOR_UNIT = '{actuat}'
AND   NUMERATOR_UNIT = '%';

-- Manual fixes with strange % values
UPDATE ds_stage
   SET NUMERATOR_VALUE = 100,
       DENOMINATOR_VALUE = NULL,
       DENOMINATOR_UNIT = NULL
WHERE NUMERATOR_UNIT = '%'
AND   NUMERATOR_VALUE IN ('0.000283','0.1','35.3');

-- Remove all %/mg etc.
DELETE ds_Stage
WHERE NUMERATOR_UNIT = '%'
AND   DENOMINATOR_UNIT IS NOT NULL;

--delete huge dosages
DELETE ds_stage
WHERE drug_concept_code IN (SELECT drug_concept_code
                            FROM ds_stage
                            WHERE ((LOWER(numerator_unit) IN ('mg') AND LOWER(denominator_unit) IN ('ml','g') OR LOWER(numerator_unit) IN ('g') AND LOWER(denominator_unit) IN ('l')) AND numerator_value / denominator_value > 1000)
                            OR    (LOWER(numerator_unit) IN ('g') AND LOWER(denominator_unit) IN ('ml') AND numerator_value / denominator_value > 1));

-- Delete more than 100%
DELETE ds_stage
WHERE ((AMOUNT_UNIT = '%' AND amount_value > 100) OR (NUMERATOR_UNIT = '%' AND NUMERATOR_VALUE > 100));

-- XXX Check this
--delete deprecated ingredients  I deprecate those ingredients that had died before 2 Feb 2017 (and so they dont exist in drug_concept_stage)
DELETE ds_stage
WHERE INGREDIENT_CONCEPT_CODE IN (SELECT DISTINCT INGREDIENT_CONCEPT_CODE
                                  FROM ds_stage s
                                    LEFT JOIN drug_concept_stage b
                                           ON b.concept_code = s.INGREDIENT_CONCEPT_CODE
                                          AND b.concept_class_id = 'Ingredient'
                                    JOIN concept c
                                      ON s.INGREDIENT_CONCEPT_CODE = c.concept_code
                                     AND c.VOCABULARY_ID LIKE 'Rx%'
                                     AND c.INVALID_REASON = 'D'
                                  WHERE b.concept_code IS NULL);

--kind of strange drugs
DELETE ds_Stage
WHERE drug_concept_code IN (SELECT DRUG_CONCEPT_CODE
                            FROM ds_Stage
                            WHERE NUMERATOR_UNIT = 'mg'
                            AND   DENOMINATOR_UNIT = 'mg'
                            AND   NUMERATOR_VALUE / DENOMINATOR_VALUE > 1);

DELETE ds_stage
WHERE drug_concept_code IN (SELECT drug_Concept_code
                            FROM ds_stage s
                              LEFT JOIN drug_concept_stage a
                                     ON a.concept_code = s.drug_concept_code
                                    AND a.concept_class_id = 'Drug Product'
                              LEFT JOIN drug_concept_stage b
                                     ON b.concept_code = s.INGREDIENT_CONCEPT_CODE
                                    AND b.concept_class_id = 'Ingredient'
                            WHERE a.concept_code IS NULL);

COMMIT;

TRUNCATE TABLE internal_relationship_stage;

INSERT INTO internal_relationship_stage
(
  concept_code_1,
  concept_code_2
)
SELECT DISTINCT concept_code,
       concept_Code_2
FROM (
--Drug to form

     SELECT DISTINCT dc.concept_code,c2.concept_code AS concept_code_2 
     FROM drug_concept_stage dc
  JOIN concept c
    ON c.concept_code = dc.concept_code
   AND c.vocabulary_id = 'RxNorm Extension'
   AND dc.concept_class_id = 'Drug Product'
  JOIN concept_relationship cr ON c.concept_id = concept_id_1
  JOIN concept c2
    ON concept_id_2 = c2.concept_id
   AND c2.concept_class_id = 'Dose Form'
   AND c2.VOCABULARY_ID LIKE 'Rx%'
WHERE ((c2.invalid_reason IS NULL AND cr.invalid_reason IS NULL) OR (c.invalid_reason IS NOT NULL AND cr.invalid_reason IS NOT NULL AND cr.VALID_END_DATE > '02-Feb-2017'))
--where regexp_like (c.concept_name,c2.concept_name) --Problem with Transdermal patch/system
UNION
--Drug to BN
SELECT DISTINCT dc.concept_code,
       c2.concept_code
FROM drug_concept_stage dc
  JOIN concept c
    ON c.concept_code = dc.concept_code
   AND c.vocabulary_id = 'RxNorm Extension'
   AND dc.concept_class_id = 'Drug Product'
   AND (dc.SOURCE_CONCEPT_CLASS_ID NOT LIKE '%Pack%'
    OR (dc.SOURCE_CONCEPT_CLASS_ID = 'Marketed Product'
   AND dc.concept_name NOT LIKE '%Pack%'))
  JOIN concept_relationship cr ON c.concept_id = concept_id_1
  JOIN concept c2
    ON concept_id_2 = c2.concept_id
   AND c2.concept_class_id = 'Brand Name'
   AND c2.VOCABULARY_ID LIKE 'Rx%'
WHERE ((c2.invalid_reason IS NULL AND cr.invalid_reason IS NULL) OR (c.invalid_reason IS NOT NULL AND cr.invalid_reason IS NOT NULL AND cr.VALID_END_DATE < '02-Feb-2017'))
AND   REGEXP_LIKE (c.concept_name,c2.concept_name)
UNION
--Packs to BN
SELECT DISTINCT dc.concept_code,
       c2.concept_code
FROM drug_concept_stage dc
  JOIN concept c
    ON c.concept_code = dc.concept_code
   AND c.vocabulary_id = 'RxNorm Extension'
   AND dc.concept_class_id = 'Drug Product'
   AND dc.concept_name LIKE '%Pack%[%]%'
  JOIN concept_relationship cr ON c.concept_id = concept_id_1
  JOIN concept c2
    ON concept_id_2 = c2.concept_id
   AND c2.concept_class_id = 'Brand Name'
   AND c2.VOCABULARY_ID LIKE 'Rx%'
WHERE c2.concept_name = REPLACE(REPLACE(REGEXP_SUBSTR(REGEXP_SUBSTR(c.concept_name,'Pack\s\[.*\]'),'\[.*\]'),'['),']')
UNION
SELECT DISTINCT DRUG_CONCEPT_CODE,
       INGREDIENT_CONCEPT_CODE
FROM ds_Stage
UNION
--Drug to supplier
SELECT DISTINCT dc.concept_code,
       c2.concept_code
FROM drug_concept_stage dc
  JOIN concept c
    ON c.concept_code = dc.concept_code
   AND c.vocabulary_id = 'RxNorm Extension'
   AND dc.concept_class_id = 'Drug Product'
  JOIN concept_relationship cr ON c.concept_id = concept_id_1
  JOIN concept c2
    ON concept_id_2 = c2.concept_id
   AND c2.concept_class_id = 'Supplier'
   AND c2.VOCABULARY_ID LIKE 'Rx%'
WHERE ((c2.invalid_reason IS NULL AND cr.invalid_reason IS NULL) OR (c.invalid_reason IS NOT NULL AND cr.invalid_reason IS NOT NULL AND cr.VALID_END_DATE < '02-Feb-2017'))
UNION
--insert relationships to those packs that do not have Pack's BN
SELECT DISTINCT a.concept_code,
       c2.concept_code
FROM concept a
  JOIN concept_relationship b
    ON concept_id_1 = a.concept_id
   AND a.vocabulary_id = 'RxNorm Extension'
   AND a.concept_class_id LIKE '%Branded%Pack%'
  LEFT JOIN concept c2
         ON c2.concept_name = REPLACE (REPLACE (REGEXP_SUBSTR (REGEXP_SUBSTR (a.concept_name,'Pack\s\[.*\]'),'\[.*\]'),'['),']')
        AND c2.vocabulary_id LIKE 'RxNorm%'
        AND c2.concept_class_id = 'Brand Name'
WHERE concept_id_1 NOT IN (SELECT concept_id_1
                           FROM concept a
                             JOIN concept_relationship b
                               ON concept_id_1 = a.concept_id
                              AND a.vocabulary_id = 'RxNorm Extension'
                              AND a.concept_class_id LIKE '%Pack%'
                             JOIN concept c
                               ON concept_id_2 = c.concept_id
                              AND c.CONCEPT_CLASS_ID = 'Brand Name'
                              AND b.invalid_reason IS NULL));

--Delete baxter(where baxter and baxter ltd)
DELETE
FROM INTERNAL_RELATIONSHIP_STAGE
WHERE CONCEPT_CODE_1 = 'OMOP432125'
AND   CONCEPT_CODE_2 = 'OMOP439843';

DELETE
FROM INTERNAL_RELATIONSHIP_STAGE
WHERE CONCEPT_CODE_1 = 'OMOP431603'
AND   CONCEPT_CODE_2 = 'OMOP439843';

DELETE
FROM INTERNAL_RELATIONSHIP_STAGE
WHERE CONCEPT_CODE_1 = 'OMOP430700'
AND   CONCEPT_CODE_2 = 'OMOP439843';

DELETE
FROM INTERNAL_RELATIONSHIP_STAGE
WHERE CONCEPT_CODE_1 = 'OMOP425698'
AND   CONCEPT_CODE_2 = 'OMOP440161';

--Packs BN
DELETE
FROM INTERNAL_RELATIONSHIP_STAGE
WHERE CONCEPT_CODE_1 = 'OMOP339685'
AND   CONCEPT_CODE_2 = 'OMOP337535';

DELETE
FROM INTERNAL_RELATIONSHIP_STAGE
WHERE CONCEPT_CODE_1 = 'OMOP339638'
AND   CONCEPT_CODE_2 = 'OMOP332839';

DELETE
FROM INTERNAL_RELATIONSHIP_STAGE
WHERE CONCEPT_CODE_1 = 'OMOP339638'
AND   CONCEPT_CODE_2 = 'OMOP335369';

DELETE
FROM INTERNAL_RELATIONSHIP_STAGE
WHERE CONCEPT_CODE_1 = 'OMOP339724'
AND   CONCEPT_CODE_2 = 'OMOP332839';

DELETE
FROM INTERNAL_RELATIONSHIP_STAGE
WHERE CONCEPT_CODE_1 = 'OMOP339724'
AND   CONCEPT_CODE_2 = 'OMOP335369';

DELETE
FROM INTERNAL_RELATIONSHIP_STAGE
WHERE CONCEPT_CODE_1 = 'OMOP339816'
AND   CONCEPT_CODE_2 = 'OMOP337535';

DELETE
FROM INTERNAL_RELATIONSHIP_STAGE
WHERE CONCEPT_CODE_1 = 'OMOP340000'
AND   CONCEPT_CODE_2 = 'OMOP335369';

DELETE
FROM INTERNAL_RELATIONSHIP_STAGE
WHERE CONCEPT_CODE_1 = 'OMOP572794'
AND   CONCEPT_CODE_2 = '352943';

DELETE
FROM INTERNAL_RELATIONSHIP_STAGE
WHERE CONCEPT_CODE_1 = 'OMOP572847'
AND   CONCEPT_CODE_2 = '352943';

DELETE
FROM INTERNAL_RELATIONSHIP_STAGE
WHERE CONCEPT_CODE_1 = 'OMOP572888'
AND   CONCEPT_CODE_2 = '352943';

DELETE
FROM INTERNAL_RELATIONSHIP_STAGE
WHERE CONCEPT_CODE_1 = 'OMOP573373'
AND   CONCEPT_CODE_2 = 'OMOP334155';

DELETE
FROM INTERNAL_RELATIONSHIP_STAGE
WHERE CONCEPT_CODE_1 = 'OMOP573353'
AND   CONCEPT_CODE_2 = 'OMOP334155';

DELETE
FROM INTERNAL_RELATIONSHIP_STAGE
WHERE CONCEPT_CODE_1 = 'OMOP573297'
AND   CONCEPT_CODE_2 = 'OMOP334155';

DELETE
FROM INTERNAL_RELATIONSHIP_STAGE
WHERE CONCEPT_CODE_1 = 'OMOP573367'
AND   CONCEPT_CODE_2 = 'OMOP335602';

DELETE
FROM INTERNAL_RELATIONSHIP_STAGE
WHERE CONCEPT_CODE_1 = 'OMOP573196'
AND   CONCEPT_CODE_2 = '58328';

DELETE
FROM INTERNAL_RELATIONSHIP_STAGE
WHERE CONCEPT_CODE_1 = 'OMOP573393'
AND   CONCEPT_CODE_2 = 'OMOP333380';

DELETE
FROM INTERNAL_RELATIONSHIP_STAGE
WHERE CONCEPT_CODE_1 = 'OMOP573300'
AND   CONCEPT_CODE_2 = 'OMOP333380';

DELETE
FROM INTERNAL_RELATIONSHIP_STAGE
WHERE CONCEPT_CODE_1 = 'OMOP573267'
AND   CONCEPT_CODE_2 = 'OMOP571237';

DELETE
FROM INTERNAL_RELATIONSHIP_STAGE
WHERE CONCEPT_CODE_1 = 'OMOP573238'
AND   CONCEPT_CODE_2 = '225684';

DELETE
FROM INTERNAL_RELATIONSHIP_STAGE
WHERE CONCEPT_CODE_1 = 'OMOP573428'
AND   CONCEPT_CODE_2 = '151629';

DELETE
FROM INTERNAL_RELATIONSHIP_STAGE
WHERE CONCEPT_CODE_1 = 'OMOP573428'
AND   CONCEPT_CODE_2 = 'OMOP570803';

--delete deprecated concepts
DELETE internal_relationship_stage
WHERE concept_code_2 IN (SELECT concept_code
                         FROM concept c
                         WHERE c.VOCABULARY_ID LIKE 'Rx%'
                         AND   c.INVALID_REASON = 'D'
                         AND   concept_class_id = 'Ingredient');

COMMIT;

TRUNCATE TABLE pc_stage;

INSERT INTO pc_stage
(
  PACK_CONCEPT_CODE,
  DRUG_CONCEPT_CODE,
  AMOUNT,
  BOX_SIZE
)
SELECT DISTINCT c.CONCEPT_CODE,
       c2.CONCEPT_CODE,
       AMOUNT,
       BOX_SIZE
FROM pack_content
  JOIN concept c
    ON PACK_CONCEPT_ID = c.CONCEPT_ID
   AND c.vocabulary_id = 'RxNorm Extension'
  JOIN concept c2 ON DRUG_CONCEPT_ID = c2.CONCEPT_ID;

--need to think of amount
/*select c.concept_name,c2.concept_name, regexp_substr(regexp_substr(c.concept_name,'box\sof\s.*'),'\d+')
 from concept c 
join concept_relationship cr on concept_id=concept_id_1 and relationship_id='Contains' and c.vocabulary_id='RxNorm Extension'
join concept c2 on c2.concept_id=concept_id_2
 where c.concept_class_id like '%Pack%' and c.concept_code not in (select pack_concept_code from pc_stage)
 and c.invalid_reason is null;*/ 
--fix 2 equal components
DELETE
FROM PC_STAGE
WHERE PACK_CONCEPT_CODE = 'OMOP339574'
AND   DRUG_CONCEPT_CODE = '197659'
AND   AMOUNT = 12;

DELETE
FROM PC_STAGE
WHERE PACK_CONCEPT_CODE = 'OMOP339579'
AND   DRUG_CONCEPT_CODE = '311704'
AND   AMOUNT IS NULL;

DELETE
FROM PC_STAGE
WHERE PACK_CONCEPT_CODE = 'OMOP339579'
AND   DRUG_CONCEPT_CODE = '317128'
AND   AMOUNT IS NULL;

DELETE
FROM PC_STAGE
WHERE PACK_CONCEPT_CODE = 'OMOP339728'
AND   DRUG_CONCEPT_CODE = '1363273'
AND   AMOUNT = 7;

DELETE
FROM PC_STAGE
WHERE PACK_CONCEPT_CODE = 'OMOP339876'
AND   DRUG_CONCEPT_CODE = '864686'
AND   AMOUNT IS NULL;

DELETE
FROM PC_STAGE
WHERE PACK_CONCEPT_CODE = 'OMOP339876'
AND   DRUG_CONCEPT_CODE = '1117531'
AND   AMOUNT IS NULL;

DELETE
FROM PC_STAGE
WHERE PACK_CONCEPT_CODE = 'OMOP339900'
AND   DRUG_CONCEPT_CODE = '392651'
AND   AMOUNT IS NULL;

DELETE
FROM PC_STAGE
WHERE PACK_CONCEPT_CODE = 'OMOP339900'
AND   DRUG_CONCEPT_CODE = '197662'
AND   AMOUNT IS NULL;

DELETE
FROM PC_STAGE
WHERE PACK_CONCEPT_CODE = 'OMOP339913'
AND   DRUG_CONCEPT_CODE = '199797'
AND   AMOUNT IS NULL;

DELETE
FROM PC_STAGE
WHERE PACK_CONCEPT_CODE = 'OMOP339913'
AND   DRUG_CONCEPT_CODE = '199796'
AND   AMOUNT IS NULL;

DELETE
FROM PC_STAGE
WHERE PACK_CONCEPT_CODE = 'OMOP340051'
AND   DRUG_CONCEPT_CODE = '1363273'
AND   AMOUNT = 7;

DELETE
FROM PC_STAGE
WHERE PACK_CONCEPT_CODE = 'OMOP340128'
AND   DRUG_CONCEPT_CODE = '197659'
AND   AMOUNT = 12;

DELETE
FROM PC_STAGE
WHERE PACK_CONCEPT_CODE = 'OMOP339633'
AND   DRUG_CONCEPT_CODE = '310463'
AND   AMOUNT = 5;

DELETE
FROM PC_STAGE
WHERE PACK_CONCEPT_CODE = 'OMOP339814'
AND   DRUG_CONCEPT_CODE = '310463'
AND   AMOUNT = 5;

DELETE
FROM PC_STAGE
WHERE PACK_CONCEPT_CODE = 'OMOP339886'
AND   DRUG_CONCEPT_CODE = '312309'
AND   AMOUNT = 6;

DELETE
FROM PC_STAGE
WHERE PACK_CONCEPT_CODE = 'OMOP339886'
AND   DRUG_CONCEPT_CODE = '312308'
AND   AMOUNT = 109;

DELETE
FROM PC_STAGE
WHERE PACK_CONCEPT_CODE = 'OMOP339895'
AND   DRUG_CONCEPT_CODE = '312309'
AND   AMOUNT = 6;

DELETE
FROM PC_STAGE
WHERE PACK_CONCEPT_CODE = 'OMOP339895'
AND   DRUG_CONCEPT_CODE = '312308'
AND   AMOUNT = 109;

UPDATE PC_STAGE
   SET AMOUNT = 12
WHERE PACK_CONCEPT_CODE = 'OMOP339633'
AND   DRUG_CONCEPT_CODE = '310463'
AND   AMOUNT = 7;

UPDATE PC_STAGE
   SET AMOUNT = 12
WHERE PACK_CONCEPT_CODE = 'OMOP339814'
AND   DRUG_CONCEPT_CODE = '310463'
AND   AMOUNT = 7;

--insert missing packs
INSERT INTO pc_stage
(
  pack_concept_code,
  drug_concept_code,
  amount,
  box_size
)
SELECT DISTINCT ac.concept_code,
       ac2.concept_code,
       pcs.amount,
       pcs.box_size
FROM dev_amt.pc_stage pcs
  JOIN concept c
    ON c.concept_code = pcs.pack_Concept_code
   AND c.vocabulary_id = 'AMT'
   AND c.invalid_reason IS NULL
  JOIN concept_relationship cr
    ON cr.concept_id_1 = c.concept_id
   AND cr.relationship_id = 'Maps to'
  JOIN concept ac
    ON ac.concept_id = cr.concept_id_2
   AND ac.vocabulary_id = 'RxNorm Extension'
   AND ac.invalid_Reason IS NULL
  JOIN concept c2
    ON c2.concept_code = pcs.drug_concept_code
   AND c.vocabulary_id = 'AMT'
   AND c2.invalid_reason IS NULL
  JOIN concept_relationship cr2
    ON cr2.concept_id_1 = c2.concept_id
   AND cr2.relationship_id = 'Maps to'
  JOIN concept ac2
    ON ac2.concept_id = cr2.concept_id_2
   AND ac2.vocabulary_id LIKE 'RxNorm%'
   AND ac2.invalid_Reason IS NULL
WHERE c.concept_id NOT IN (SELECT pack_concept_id FROM pack_content)
AND   c.concept_id IN (SELECT c.concept_id
                       FROM dev_amt.pc_stage pcs
                         JOIN concept c
                           ON c.concept_code = pcs.pack_Concept_code
                          AND c.vocabulary_id = 'AMT'
                          AND c.invalid_reason IS NULL
                         JOIN concept_relationship cr
                           ON cr.concept_id_1 = c.concept_id
                          AND cr.relationship_id = 'Maps to'
                         JOIN concept ac
                           ON ac.concept_id = cr.concept_id_2
                          AND ac.vocabulary_id = 'RxNorm Extension'
                          AND ac.invalid_Reason IS NULL
                         JOIN concept c2
                           ON c2.concept_code = pcs.drug_concept_code
                          AND c.vocabulary_id = 'AMT'
                          AND c2.invalid_reason IS NULL
                         JOIN concept_relationship cr2
                           ON cr2.concept_id_1 = c2.concept_id
                          AND cr2.relationship_id = 'Maps to'
                         JOIN concept ac2
                           ON ac2.concept_id = cr2.concept_id_2
                          AND ac2.vocabulary_id LIKE 'RxNorm%'
                       WHERE c.concept_id NOT IN (SELECT pack_concept_id FROM pack_content)
                       GROUP BY c.concept_id
                       HAVING COUNT(c.concept_id) > 1)
AND   ac.concept_code NOT IN (SELECT pack_concept_code FROM pc_stage);

INSERT INTO pc_stage
(
  pack_concept_code,
  drug_concept_code,
  amount,
  box_size
)
SELECT DISTINCT ac.concept_code,
       ac2.concept_code,
       pcs.amount,
       pcs.box_size
FROM dev_amis.pc_stage pcs
  JOIN concept c
    ON c.concept_code = pcs.pack_Concept_code
   AND c.vocabulary_id = 'AMIS'
   AND c.invalid_reason IS NULL
  JOIN concept_relationship cr
    ON cr.concept_id_1 = c.concept_id
   AND cr.relationship_id = 'Maps to'
  JOIN concept ac
    ON ac.concept_id = cr.concept_id_2
   AND ac.vocabulary_id = 'RxNorm Extension'
   AND ac.invalid_Reason IS NULL
  JOIN concept c2
    ON c2.concept_code = pcs.drug_concept_code
   AND c.vocabulary_id = 'AMIS'
   AND c2.invalid_reason IS NULL
  JOIN concept_relationship cr2
    ON cr2.concept_id_1 = c2.concept_id
   AND cr2.relationship_id = 'Maps to'
  JOIN concept ac2
    ON ac2.concept_id = cr2.concept_id_2
   AND ac2.vocabulary_id LIKE 'RxNorm%'
   AND ac2.invalid_Reason IS NULL
WHERE c.concept_id NOT IN (SELECT pack_concept_id FROM pack_content)
AND   c.concept_id IN (SELECT c.concept_id
                       FROM dev_amis.pc_stage pcs
                         JOIN concept c
                           ON c.concept_code = pcs.pack_Concept_code
                          AND c.vocabulary_id = 'AMIS'
                          AND c.invalid_reason IS NULL
                         JOIN concept_relationship cr
                           ON cr.concept_id_1 = c.concept_id
                          AND cr.relationship_id = 'Maps to'
                         JOIN concept ac
                           ON ac.concept_id = cr.concept_id_2
                          AND ac.vocabulary_id = 'RxNorm Extension'
                          AND ac.invalid_Reason IS NULL
                         JOIN concept c2
                           ON c2.concept_code = pcs.drug_concept_code
                          AND c.vocabulary_id = 'AMIS'
                         JOIN concept_relationship cr2
                           ON cr2.concept_id_1 = c2.concept_id
                          AND cr2.relationship_id = 'Maps to'
                         JOIN concept ac2
                           ON ac2.concept_id = cr2.concept_id_2
                          AND ac2.vocabulary_id LIKE 'RxNorm%'
                       WHERE c.concept_id NOT IN (SELECT pack_concept_id FROM pack_content)
                       GROUP BY c.concept_id
                       HAVING COUNT(c.concept_id) > 1)
AND   ac.concept_code NOT IN (SELECT pack_concept_code FROM pc_stage);

COMMIT;

TRUNCATE TABLE relationship_to_concept;

INSERT INTO relationship_to_concept
(
  CONCEPT_CODE_1,
  VOCABULARY_ID_1,
  CONCEPT_ID_2,
  PRECEDENCE
)
SELECT a.concept_code,
       a.VOCABULARY_ID,
       b.concept_id,
       1
FROM drug_concept_stage a
  JOIN concept b
    ON a.concept_code = b.concept_code
   AND b.vocabulary_id IN ('RxNorm', 'RxNorm Extension') 
   AND a.concept_class_id IN ('Dose Form', 'Brand Name', 'Supplier', 'Ingredient');

INSERT INTO relationship_to_concept
(
  CONCEPT_CODE_1,
  VOCABULARY_ID_1,
  CONCEPT_ID_2,
  PRECEDENCE,
  CONVERSION_FACTOR
)
SELECT a.concept_code,
       a.VOCABULARY_ID,
       b.concept_id,
       1,
       1
FROM drug_concept_stage a
  JOIN concept b
    ON a.concept_code = b.concept_code
   AND a.concept_class_id = 'Unit'
   AND b.vocabulary_id = 'UCUM';

UPDATE RELATIONSHIP_TO_CONCEPT
   SET CONCEPT_ID_2 = 19011438
WHERE CONCEPT_CODE_1 = '1428040';

UPDATE RELATIONSHIP_TO_CONCEPT
   SET CONCEPT_ID_2 = 8576,
       CONVERSION_FACTOR = 0.001
WHERE CONCEPT_CODE_1 = 'ug'
AND   CONCEPT_ID_2 = 9655;

--strange staff
DELETE
FROM INTERNAL_RELATIONSHIP_STAGE
WHERE CONCEPT_CODE_1 = 'OMOP572936'
AND   CONCEPT_CODE_2 = '225684';

DELETE
FROM INTERNAL_RELATIONSHIP_STAGE
WHERE CONCEPT_CODE_1 = 'OMOP573198'
AND   CONCEPT_CODE_2 = 'OMOP571371';

DELETE
FROM INTERNAL_RELATIONSHIP_STAGE
WHERE CONCEPT_CODE_1 = 'OMOP573146'
AND   CONCEPT_CODE_2 = 'OMOP571828';

DELETE
FROM INTERNAL_RELATIONSHIP_STAGE
WHERE CONCEPT_CODE_1 = 'OMOP573039'
AND   CONCEPT_CODE_2 = '151629';

DELETE
FROM INTERNAL_RELATIONSHIP_STAGE
WHERE CONCEPT_CODE_1 = 'OMOP572936'
AND   CONCEPT_CODE_2 = 'OMOP572315';

DELETE
FROM INTERNAL_RELATIONSHIP_STAGE
WHERE CONCEPT_CODE_1 = 'OMOP572882'
AND   CONCEPT_CODE_2 = 'OMOP333380';

DELETE
FROM INTERNAL_RELATIONSHIP_STAGE
WHERE CONCEPT_CODE_1 = 'OMOP572848'
AND   CONCEPT_CODE_2 = 'OMOP571012';

DELETE
FROM INTERNAL_RELATIONSHIP_STAGE
WHERE CONCEPT_CODE_1 = 'OMOP573146'
AND   CONCEPT_CODE_2 = 'OMOP571237';

--Fotemustine

