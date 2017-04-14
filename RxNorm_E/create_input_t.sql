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
* Authors: Anna Ostropolets, Christian Reich, Timur Vakhitov
* Date: 2017
**************************************************************************/

--1 Add new temporary vocabulary named Rxfix to the vocabulary table
INSERT INTO concept (concept_id,
                     concept_name,
                     domain_id,
                     vocabulary_id,
                     concept_class_id,
                     standard_concept,
                     concept_code,
                     valid_start_date,
                     valid_end_date,
                     invalid_reason)
     VALUES (100,
             'Rxfix',
             'Metadata',
             'Vocabulary',
             'Vocabulary',
             NULL,
             'OMOP generated',
             TO_DATE ('19700101', 'yyyymmdd'),
             TO_DATE ('20991231', 'yyyymmdd'),
             NULL);

INSERT INTO vocabulary (vocabulary_id, vocabulary_name, vocabulary_concept_id)
     VALUES ('Rxfix', 'Rxfix', 100);

COMMIT;	 
	 
--2 Update latest_update field to new date 
BEGIN
   DEVV5.VOCABULARY_PACK.SetLatestUpdate (pVocabularyName        => 'Rxfix',
                                          pVocabularyDate        => TRUNC(SYSDATE),
                                          pVocabularyVersion     => 'Rxfix '||SYSDATE,
                                          pVocabularyDevSchema   => 'DEV_RXE');									  
END;
COMMIT;

--3 create input tables 
DROP TABLE DRUG_CONCEPT_STAGE PURGE; --temporary!!!!! later we should to move all drops to the end of this script (or cndv?)
DROP TABLE DS_STAGE PURGE;
DROP TABLE INTERNAL_RELATIONSHIP_STAGE PURGE;
DROP TABLE PC_STAGE PURGE;
DROP TABLE RELATIONSHIP_TO_CONCEPT PURGE;

--3.1 1st input table: DRUG_CONCEPT_STAGE
CREATE TABLE DRUG_CONCEPT_STAGE
(
   CONCEPT_NAME        VARCHAR2(255),
   VOCABULARY_ID       VARCHAR2(20),
   CONCEPT_CLASS_ID    VARCHAR2(20),
   STANDARD_CONCEPT    VARCHAR2(1),
   CONCEPT_CODE        VARCHAR2(50),
   POSSIBLE_EXCIPIENT  VARCHAR2(1),
   DOMAIN_ID           VARCHAR2(20),
   VALID_START_DATE    DATE,
   VALID_END_DATE      DATE,
   INVALID_REASON      VARCHAR2(1),
   SOURCE_CONCEPT_CLASS_ID VARCHAR2(20)
) NOLOGGING;

--3.2 2nd input table: DS_STAGE
CREATE TABLE DS_STAGE
(
   DRUG_CONCEPT_CODE        VARCHAR2(50),
   INGREDIENT_CONCEPT_CODE  VARCHAR2(50),
   BOX_SIZE                 NUMBER,
   AMOUNT_VALUE             FLOAT(126),
   AMOUNT_UNIT              VARCHAR2(50),
   NUMERATOR_VALUE          FLOAT(126),
   NUMERATOR_UNIT           VARCHAR2(50),
   DENOMINATOR_VALUE        FLOAT(126),
   DENOMINATOR_UNIT         VARCHAR2(50)
) NOLOGGING;

--3.3 3rd input table: INTERNAL_RELATIONSHIP_STAGE
CREATE TABLE INTERNAL_RELATIONSHIP_STAGE
(
   CONCEPT_CODE_1     VARCHAR2(50),
   CONCEPT_CODE_2     VARCHAR2(50)
) NOLOGGING;

--3.4 4th input table: PC_STAGE
CREATE TABLE PC_STAGE
(
   PACK_CONCEPT_CODE  VARCHAR2(50),
   DRUG_CONCEPT_CODE  VARCHAR2(50),
   AMOUNT             NUMBER,
   BOX_SIZE           NUMBER
) NOLOGGING;

--3.5 5th input table: RELATIONSHIP_TO_CONCEPT
CREATE TABLE RELATIONSHIP_TO_CONCEPT
(
   CONCEPT_CODE_1     VARCHAR2(50),
   VOCABULARY_ID_1    VARCHAR2(20),
   CONCEPT_ID_2       NUMBER,
   PRECEDENCE         NUMBER,
   CONVERSION_FACTOR  FLOAT(126)
) NOLOGGING;


--4 Create Concepts
--4.1 Get products
INSERT /*+ APPEND */ INTO DRUG_CONCEPT_STAGE
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
select distinct
	concept_name,
       'Rxfix',
       'Drug Product',
       null,
       concept_code,
       null,
       domain_id,
       valid_start_date,
       valid_end_date,
       invalid_reason,
       concept_class_id
FROM concept
WHERE 
-- all the "Drug" Classes
(concept_class_id LIKE '%Drug%' or concept_class_id LIKE '%Pack%' or concept_class_id LIKE '%Box%' or concept_class_id LIKE '%Marketed%')
AND vocabulary_id = 'RxNorm Extension' AND invalid_reason IS NULL
UNION ALL
-- Get Dose Forms, Brand Names, Supplier, including RxNorm
SELECT distinct	
	b2.concept_name,
       'Rxfix',
       b2.concept_class_id,
       null,
       b2.concept_code,
       null,
       b2.domain_id,
       b2.valid_start_date,
       b2.valid_end_date,
       b2.invalid_reason,
       b2.concept_class_id
FROM concept_relationship a
  JOIN concept b
    ON concept_id_1 = b.concept_id
	-- the same list of the products 
   AND (b.concept_class_id LIKE '%Drug%' or b.concept_class_id LIKE '%Pack%' or b.concept_class_id LIKE '%Box%' or b.concept_class_id LIKE '%Marketed%')
   AND b.vocabulary_id = 'RxNorm Extension'
  JOIN concept b2
    ON concept_id_2 = b2.concept_id
   AND b2.concept_class_id IN ('Dose Form', 'Brand Name', 'Supplier') --their attributes
   AND b2.vocabulary_id LIKE 'Rx%'
   AND b2.invalid_reason IS NULL
WHERE a.invalid_reason IS NULL
UNION ALL
--Get RxNorm pack components from RxNorm
SELECT  distinct
	b2.concept_name,
       'Rxfix',
       'Drug Product',
       null,
       b2.concept_code,
       null,
       b2.domain_id,
       b2.valid_start_date,
       b2.valid_end_date,
       b2.invalid_reason,
       b2.concept_class_id
FROM concept_relationship a
  JOIN concept b
    ON concept_id_1 = b.concept_id
   AND b.concept_class_id LIKE '%Pack%'
   AND b.vocabulary_id = 'RxNorm Extension'
  JOIN concept b2
    ON concept_id_2 = b2.concept_id
   --only Drugs
   AND (b2.concept_class_id LIKE '%Drug%' or b2.concept_class_id LIKE '%Marketed%')
   AND b2.vocabulary_id = 'RxNorm'
   AND b2.invalid_reason IS NULL
WHERE a.invalid_reason IS NULL AND a.invalid_reason IS NULL;
COMMIT;

--4.2 Get upgraded Dose Forms, Brand Names, Supplier
INSERT /*+ APPEND */
      INTO  DRUG_CONCEPT_STAGE (CONCEPT_NAME,
                                VOCABULARY_ID,
                                CONCEPT_CLASS_ID,
                                STANDARD_CONCEPT,
                                CONCEPT_CODE,
                                POSSIBLE_EXCIPIENT,
                                DOMAIN_ID,
                                VALID_START_DATE,
                                VALID_END_DATE,
                                INVALID_REASON,
                                SOURCE_CONCEPT_CLASS_ID)
   SELECT distinct
   	  b3.concept_name,
          'Rxfix',
          b3.concept_class_id,
          NULL,
          b3.concept_code,
          NULL,
          b3.domain_id,
          b3.valid_start_date,
          b3.valid_end_date,
          b3.invalid_reason,
          b3.concept_class_id
     -- add fresh attributes instead of invalid
     FROM concept_relationship a
          JOIN concept b
             ON     concept_id_1 = b.concept_id
                AND (b.concept_class_id LIKE '%Drug%' OR b.concept_class_id LIKE '%Pack%' OR b.concept_class_id LIKE '%Box%' OR b.concept_class_id LIKE '%Marketed%')
                AND b.vocabulary_id = 'RxNorm Extension'
          JOIN concept b2 ON concept_id_2 = b2.concept_id AND b2.concept_class_id IN ('Dose Form', 'Brand Name', 'Supplier') AND b2.vocabulary_id LIKE 'Rx%' AND b2.invalid_reason IS NOT NULL
          --get last fresh attributes
          JOIN (    SELECT CONNECT_BY_ROOT concept_id_1 AS root_concept_id_1, u.concept_id_2
                      FROM (SELECT r.*
                              FROM concept_relationship r
                                   JOIN concept c1 ON c1.concept_id = r.concept_id_1 AND c1.concept_class_id IN ('Dose Form', 'Brand Name', 'Supplier') AND c1.vocabulary_id LIKE 'Rx%'
                                   JOIN concept c2 ON c2.concept_id = r.concept_id_2 AND c2.concept_class_id IN ('Dose Form', 'Brand Name', 'Supplier') AND c2.vocabulary_id LIKE 'Rx%'
                             WHERE r.relationship_id = 'Concept replaced by' AND r.invalid_reason IS NULL) u
                     WHERE CONNECT_BY_ISLEAF = 1
                CONNECT BY NOCYCLE PRIOR u.concept_id_2 = u.concept_id_1) a2
             ON a2.root_concept_id_1 = b2.concept_id
          JOIN concept b3 ON a2.concept_id_2 = b3.concept_id
    WHERE     a.invalid_reason IS NULL
          AND NOT EXISTS
                 (SELECT 1
                    FROM DRUG_CONCEPT_STAGE dcs
                   WHERE dcs.concept_code = b3.concept_code AND dcs.domain_id = b3.domain_id AND dcs.concept_class_id = b3.concept_class_id AND dcs.source_concept_class_id = b3.concept_class_id);
COMMIT;

--4.3 Ingredients: Need to check what happens to deprecated
-- Get ingredients from drug_strength
INSERT /*+ APPEND */
      INTO  DRUG_CONCEPT_STAGE (CONCEPT_NAME,
                                VOCABULARY_ID,
                                CONCEPT_CLASS_ID,
                                STANDARD_CONCEPT,
                                CONCEPT_CODE,
                                POSSIBLE_EXCIPIENT,
                                domain_id,
                                VALID_START_DATE,
                                VALID_END_DATE,
                                INVALID_REASON,
                                SOURCE_CONCEPT_CLASS_ID)
   SELECT distinct
   	   b.concept_name,
          'Rxfix',
          'Ingredient',
          'S',
          b.concept_code,
          NULL,
          b.domain_id,
          b.valid_start_date,
          b.valid_end_date,
          b.invalid_reason,
          'Ingredient'
     FROM drug_strength a
          JOIN concept b ON a.ingredient_concept_id = b.concept_id AND b.invalid_reason IS NULL AND b.vocabulary_id LIKE 'Rx%'
          JOIN concept c ON a.drug_concept_id = c.concept_id AND c.vocabulary_id = 'RxNorm Extension'
    WHERE NOT EXISTS
             (SELECT 1
                FROM DRUG_CONCEPT_STAGE dcs
               WHERE dcs.concept_code = b.concept_code AND dcs.domain_id = b.domain_id AND dcs.concept_class_id = 'Ingredient' AND dcs.source_concept_class_id = 'Ingredient');
COMMIT;

--4.4 Get ingredients from hierarchy
INSERT /*+ APPEND */
      INTO  DRUG_CONCEPT_STAGE (CONCEPT_NAME,
                                VOCABULARY_ID,
                                CONCEPT_CLASS_ID,
                                STANDARD_CONCEPT,
                                CONCEPT_CODE,
                                POSSIBLE_EXCIPIENT,
                                domain_id,
                                VALID_START_DATE,
                                VALID_END_DATE,
                                INVALID_REASON,
                                SOURCE_CONCEPT_CLASS_ID)
   SELECT distinct
   	   a.concept_name,
          'Rxfix',
          'Ingredient',
          'S',
          a.concept_code,
          NULL,
          a.domain_id,
          a.valid_start_date,
          a.valid_end_date,
          a.invalid_reason,
          'Ingredient'
     --add ingredients from ancestor
     FROM concept a
          JOIN concept_ancestor b ON a.concept_id = b.ancestor_concept_id
          JOIN concept a2 ON b.descendant_concept_id = a2.concept_id AND a2.vocabulary_id = 'RxNorm Extension'
    WHERE     a.concept_class_id = 'Ingredient'
          AND a.vocabulary_id LIKE 'Rx%'
          AND NOT EXISTS
                 (SELECT 1
                    FROM DRUG_CONCEPT_STAGE dcs
                   WHERE dcs.concept_code = a.concept_code AND dcs.domain_id = a.domain_id AND dcs.concept_class_id = 'Ingredient' AND dcs.source_concept_class_id = 'Ingredient');
COMMIT;			   

--4.5 Get all Units
INSERT /*+ APPEND */
      INTO  DRUG_CONCEPT_STAGE (CONCEPT_NAME,
                                VOCABULARY_ID,
                                CONCEPT_CLASS_ID,
                                STANDARD_CONCEPT,
                                CONCEPT_CODE,
                                POSSIBLE_EXCIPIENT,
                                domain_id,
                                VALID_START_DATE,
                                VALID_END_DATE,
                                INVALID_REASON,
                                SOURCE_CONCEPT_CLASS_ID)
   SELECT distinct
   	  c.concept_name,
          'Rxfix',
          'Unit',
          NULL,
          c.concept_code,
          NULL,
          'Drug',
          c.valid_start_date,
          c.valid_end_date,
          NULL,
          'Unit'
     FROM concept c
    WHERE c.concept_id IN (SELECT ds.units
                             FROM (SELECT units, drug_concept_id
                                     FROM drug_strength UNPIVOT (units FOR units_ids IN (amount_unit_concept_id, numerator_unit_concept_id, denominator_unit_concept_id))) ds
                                  JOIN concept c_int ON c_int.concept_id = ds.drug_concept_id AND c_int.vocabulary_id = 'RxNorm Extension');
COMMIT;								  

--5 Remove all where there is less than total of 0.05 mL
DELETE FROM DRUG_CONCEPT_STAGE
      WHERE concept_code IN (SELECT concept_code
                               FROM concept c JOIN drug_strength ds ON ds.drug_concept_id = c.concept_id
                              WHERE c.vocabulary_id = 'RxNorm Extension' AND c.invalid_reason IS NULL AND ds.denominator_value < 0.05 AND ds.denominator_unit_concept_id = 8587);
COMMIT;							  

--6 Remove wrong brand names (need to save for the later clean up)
/*DELETE FROM DRUG_CONCEPT_STAGE
      WHERE concept_code IN
               (SELECT dcs.concept_code
                  FROM drug_concept_stage dcs
                       JOIN concept c
                          ON     LOWER (dcs.concept_name) = LOWER (c.concept_name)
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
                                                        'Pharma Preparation')
                 WHERE dcs.concept_class_id = 'Brand Name'
                UNION
                SELECT concept_code
                  FROM drug_concept_stage
                 WHERE     concept_class_id = 'Brand Name'
                       AND REGEXP_LIKE (concept_name, 'Comp\s|Comp$|Praeparatum')
                       AND NOT REGEXP_LIKE (concept_name, 'Ratioph|Zentiva|Actavis|Teva|Hormosan|Dura|Ass|Provas|Rami|Al |Pharma|Abz|-Q|Peritrast|Beloc|Hexal|Corax|Solgar|Winthrop'));
COMMIT;					   

--7 filling drug_strength
--just turn drug_strength into ds_stage replacing concept_ids with concept_codes
INSERT /*+ APPEND */
      INTO  ds_stage (DRUG_CONCEPT_CODE,
                      INGREDIENT_CONCEPT_CODE,
                      BOX_SIZE,
                      AMOUNT_VALUE,
                      AMOUNT_UNIT,
                      NUMERATOR_VALUE,
                      NUMERATOR_UNIT,
                      DENOMINATOR_VALUE,
                      DENOMINATOR_UNIT)
   SELECT distinct
   	  c.concept_code,
          c2.concept_code,
          ds.box_size,
          amount_value,
          c3.concept_code,
          ds.numerator_value,
          c4.concept_code,
          ds.denominator_value,
          c5.concept_code
     FROM concept c
          JOIN drug_strength ds ON ds.drug_concept_id = c.concept_id
          JOIN concept c2 ON c2.concept_id = ds.ingredient_concept_id
          LEFT JOIN concept c3 ON c3.concept_id = ds.amount_unit_concept_id
          LEFT JOIN concept c4 ON c4.concept_id = ds.numerator_unit_concept_id
          LEFT JOIN concept c5 ON c5.concept_id = ds.denominator_unit_concept_id
    WHERE c.vocabulary_id = 'RxNorm Extension';
COMMIT;	

--8 update ds_stage for homeopathic drugs
-- homeopatic unit is not a real concentration
/*UPDATE ds_stage
   SET amount_value = numerator_value,
       amount_unit = numerator_unit,
       numerator_value = NULL,
       numerator_unit = NULL,
       denominator_value = NULL,
       denominator_unit = NULL
 WHERE     drug_concept_code IN (SELECT drug_concept_code
                                   FROM ds_stage
                                  WHERE numerator_unit IN ('[hp_X]', '[hp_C]'));
COMMIT;							  
*/
						
--9 Manually add absent units in drug_strength (due to source table issues)
UPDATE DS_STAGE
   SET AMOUNT_UNIT = '[U]'
WHERE INGREDIENT_CONCEPT_CODE = '560'
AND DRUG_CONCEPT_CODE in ('OMOP467711','OMOP467709','OMOP467706','OMOP467710','OMOP467715','OMOP467705','OMOP467712','OMOP467708','OMOP467714','OMOP467713');

UPDATE DS_STAGE
   SET AMOUNT_VALUE = 25,
       AMOUNT_UNIT = 'mg',
       NUMERATOR_VALUE = NULL,
       NUMERATOR_UNIT = ''
WHERE DRUG_CONCEPT_CODE in ('OMOP420731','OMOP420834','OMOP420835','OMOP420833')
AND   INGREDIENT_CONCEPT_CODE = '2409';

UPDATE DS_STAGE
   SET AMOUNT_VALUE = 100,
       AMOUNT_UNIT = 'mg',
       NUMERATOR_VALUE = NULL,
       NUMERATOR_UNIT = NULL
WHERE DRUG_CONCEPT_CODE in ('OMOP420832','OMOP420835','OMOP420834','OMOP420833')
AND   INGREDIENT_CONCEPT_CODE = '1202';
COMMIT;

--10 Fix micrograms and iU
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
COMMIT;

--11 Create consolidated denominator unit for drugs that have soluble and solid ingredients
-- in the same drug (if some drug-ingredient row row has amount, another - nominator)
UPDATE ds_stage ds
   SET numerator_value = amount_value,
       numerator_unit = amount_unit,
       amount_unit = NULL,
       amount_value = NULL,
       denominator_unit = 'mL'
 WHERE     drug_concept_code IN (SELECT drug_concept_code
                                   FROM ds_stage a JOIN ds_stage b USING (drug_concept_code)
                                  WHERE a.amount_value IS NOT NULL AND b.numerator_value IS NOT NULL AND b.denominator_unit = 'mL')
       AND amount_value IS NOT NULL;

UPDATE ds_stage ds
   SET numerator_value = amount_value,
       numerator_unit = amount_unit,
       amount_unit = NULL,
       amount_value = NULL,
       denominator_unit = 'mg'
 WHERE     drug_concept_code IN (SELECT drug_concept_code
                                   FROM ds_stage a JOIN ds_stage b USING (drug_concept_code)
                                  WHERE a.amount_value IS NOT NULL AND b.numerator_value IS NOT NULL AND b.denominator_unit = 'mg')
       AND amount_value IS NOT NULL;
COMMIT;

--12 update different denominator units
MERGE INTO ds_stage ds
     USING (SELECT DISTINCT a.drug_concept_code, REGEXP_SUBSTR (c.concept_name, '^\d+(\.\d+)?') AS cx -- choose denominator from the Name
              FROM ds_stage a
                   JOIN ds_stage b ON b.drug_concept_code = a.drug_concept_code
                   JOIN concept_stage c ON c.concept_code = a.drug_concept_code AND c.vocabulary_id = 'RxNorm Extension'
             WHERE a.denominator_value != b.denominator_value) d
        ON (d.drug_concept_code = ds.drug_concept_code)
WHEN MATCHED
THEN
   UPDATE SET ds.denominator_value = d.cx
           WHERE ds.drug_concept_code = d.drug_concept_code;
COMMIT;

--13 Fix solid forms with denominator
UPDATE ds_stage
   SET amount_unit = numerator_unit,
       amount_value = numerator_value,
       numerator_value = NULL,
       numerator_unit = NULL,
       denominator_value = NULL,
       denominator_unit = NULL
 WHERE drug_concept_code IN
          (SELECT a.concept_code
             FROM concept a
                  JOIN drug_strength d
                     ON     concept_id = drug_concept_id
                        AND denominator_unit_concept_id IS NOT NULL
                        AND (concept_name LIKE '%Tablet%' OR concept_name LIKE '%Capsule%') -- solid forms defined by their forms
                        AND vocabulary_id = 'RxNorm Extension');
COMMIT;
							   
							   
--14 Put percent into the numerator, not amount
UPDATE ds_stage
   SET numerator_unit = amount_unit,
       NUMERATOR_VALUE = AMOUNT_VALUE,
       AMOUNT_VALUE = NULL,
       amount_unit = NULL
WHERE amount_unit = '%';
COMMIT;

--15 Fixes of various ill-defined drugs violating with RxNorm editorial policies 
UPDATE DS_STAGE
   SET NUMERATOR_VALUE = 25
WHERE DRUG_CONCEPT_CODE in ('OMOP303266','OMOP303267','OMOP303268');

UPDATE DS_STAGE
   SET NUMERATOR_VALUE = 1
WHERE DRUG_CONCEPT_CODE in ( 'OMOP317478','OMOP317479','OMOP317480');

UPDATE DS_STAGE
   SET NUMERATOR_VALUE = 10000,
       DENOMINATOR_UNIT = 'mL'
WHERE INGREDIENT_CONCEPT_CODE = '8536'
AND DRUG_CONCEPT_CODE in ('OMOP420658','OMOP420659','OMOP420660','OMOP420661');
COMMIT;

--16 
/*
	XXX Check this with Christian obviosly it's just a percent so I changed it to mg/ml 
	select * from devv5.drug_strength join devv5.concept on drug_Concept_id=concept_id where denominator_unit_concept_id=45744809 and numerator_unit_Concept_id=8554 ;
*/
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
AND   NUMERATOR_VALUE IN (0.000283,0.1,35.3);
COMMIT;
							   
--17 Do all sorts of manual fixes
--17.1 Fentanyl buccal film
-- AMOUNT_VALUE instead of NUMERATOR_VALUE
UPDATE ds_stage
   SET amount_value = numerator_value,
       amount_unit = numerator_unit,
       denominator_value = NULL,
       denominator_unit = NULL,
       numerator_unit = NULL,
       numerator_value = NULL
 WHERE drug_concept_code IN
          (SELECT drug_concept_code
             FROM ds_stage a JOIN drug_concept_stage b ON a.drug_concept_code = b.concept_code
            WHERE NVL (a.amount_unit, a.numerator_unit) IN ('cm', 'mm') 
			OR (a.denominator_unit IN ('cm', 'mm') 
				AND (b.concept_name LIKE '%Buccal Film%' 
				OR b.concept_name LIKE '%Breakyl Start%' 
				OR a.numerator_value IN (0.808,1.21,1.62)))
          );
COMMIT;

--17.2 Add denominator to trandermal patch
-- manualy defined dosages
UPDATE ds_stage
   SET NUMERATOR_VALUE = 0.012,
       DENOMINATOR_VALUE = NULL,
       DENOMINATOR_UNIT = 'h',
       AMOUNT_UNIT = NULL,
       AMOUNT_VALUE = NULL,
       NUMERATOR_UNIT = 'mg'
WHERE drug_concept_code IN (SELECT drug_concept_code
                            FROM ds_stage a
                              JOIN drug_concept_stage b ON a.drug_concept_code = b.concept_code
                            --also found like 0.4*5.25 cm=2.1 mg=0.012/h 
                            WHERE b.concept_name LIKE '%Fentanyl%Transdermal%'
                            AND   a.amount_value IN (2.55,2.1,2.5,0.4,1.38));

UPDATE ds_stage
   SET NUMERATOR_VALUE = 0.025,
       DENOMINATOR_VALUE = NULL,
       DENOMINATOR_UNIT = 'h',
       AMOUNT_UNIT = NULL,
       AMOUNT_VALUE = NULL,
       NUMERATOR_UNIT = 'mg'
WHERE drug_concept_code IN (SELECT drug_concept_code
                            FROM ds_stage a
                              JOIN drug_concept_stage b ON a.drug_concept_code = b.concept_code
                            WHERE b.concept_name LIKE '%Fentanyl%Transdermal%'
                            AND   a.amount_value IN (0.275,2.75,3.72,4.2,5.1,0.6,0.319,0.25,5,4.8));

UPDATE ds_stage
   SET NUMERATOR_VALUE = 0.05,
       DENOMINATOR_VALUE = NULL,
       DENOMINATOR_UNIT = 'h',
       AMOUNT_UNIT = NULL,
       AMOUNT_VALUE = NULL,
       NUMERATOR_UNIT = 'mg'
WHERE drug_concept_code IN (SELECT drug_concept_code
                            FROM ds_stage a
                            JOIN drug_concept_stage b ON a.drug_concept_code = b.concept_code
                            WHERE b.concept_name LIKE '%Fentanyl%Transdermal%'
                            AND   a.amount_value IN (5.5,10.2,7.5,8.25,8.4,0.875,9.6,14.4,15.5));

UPDATE ds_stage
   SET NUMERATOR_VALUE = 0.075,
       DENOMINATOR_VALUE = NULL,
       DENOMINATOR_UNIT = 'h',
       AMOUNT_UNIT = NULL,
       AMOUNT_VALUE = NULL,
       NUMERATOR_UNIT = 'mg'
WHERE drug_concept_code IN (SELECT drug_concept_code
                            FROM ds_stage a
                            JOIN drug_concept_stage b ON a.drug_concept_code = b.concept_code
                            WHERE b.concept_name LIKE '%Fentanyl%Transdermal%'
                            AND   a.amount_value IN (12.6,15.3,12.4,19.2,23.1));

UPDATE ds_stage
   SET NUMERATOR_VALUE = 0.1,
       DENOMINATOR_VALUE = NULL,
       DENOMINATOR_UNIT = 'h',
       AMOUNT_UNIT = NULL,
       AMOUNT_VALUE = NULL,
       NUMERATOR_UNIT = 'mg'
WHERE drug_concept_code IN (SELECT drug_concept_code
                            FROM ds_stage a
                            JOIN drug_concept_stage b ON a.drug_concept_code = b.concept_code
                            WHERE b.concept_name LIKE '%Fentanyl%Transdermal%'
                            AND   a.amount_value IN (16.8,10,11,20.4,16.5));
COMMIT;

--17.3 Fentanyl topical
UPDATE ds_stage
   SET NUMERATOR_VALUE = 0.012,
       DENOMINATOR_VALUE = NULL,
       DENOMINATOR_UNIT = 'h'
WHERE drug_concept_code IN (SELECT drug_concept_code
                            FROM ds_stage a
                            JOIN drug_concept_stage b ON a.drug_concept_code = b.concept_code
                            --also found like 0.4*5.25 cm=2.1 mg=0.012/h
                            WHERE NVL(a.amount_unit,a.numerator_unit) IN ('cm','mm')
                            OR    (a.denominator_unit IN ('cm','mm')
                            AND   b.concept_name LIKE '%Fentanyl%'
                            AND   a.numerator_value IN (2.55,2.1,2.5,0.4)));

UPDATE ds_stage
   SET NUMERATOR_VALUE = 0.025,
       DENOMINATOR_VALUE = NULL,
       DENOMINATOR_UNIT = 'h'
WHERE drug_concept_code IN (SELECT drug_concept_code
                            FROM ds_stage a
                            JOIN drug_concept_stage b ON a.drug_concept_code = b.concept_code
                            WHERE NVL(a.amount_unit,a.numerator_unit) IN ('cm','mm')
                            OR    (a.denominator_unit IN ('cm','mm')
                            AND   b.concept_name LIKE '%Fentanyl%'
                            AND   a.numerator_value IN (0.275,2.75,3.72,4.2,5.1,0.6,0.319,0.25,5)));

UPDATE ds_stage
   SET NUMERATOR_VALUE = 0.05,
       DENOMINATOR_VALUE = NULL,
       DENOMINATOR_UNIT = 'h'
WHERE drug_concept_code IN (SELECT drug_concept_code
                            FROM ds_stage a
                            JOIN drug_concept_stage b ON a.drug_concept_code = b.concept_code
                            WHERE NVL(a.amount_unit,a.numerator_unit) IN ('cm','mm')
                            OR    (a.denominator_unit IN ('cm','mm')
                            AND   b.concept_name LIKE '%Fentanyl%'
                            AND   a.numerator_value IN (5.5,10.2,7.5,8.25,8.4,0.875)));

UPDATE ds_stage
   SET NUMERATOR_VALUE = 0.075,
       DENOMINATOR_VALUE = NULL,
       DENOMINATOR_UNIT = 'h'
WHERE drug_concept_code IN (SELECT drug_concept_code
                            FROM ds_stage a
                            JOIN drug_concept_stage b ON a.drug_concept_code = b.concept_code
                            WHERE NVL(a.amount_unit,a.numerator_unit) IN ('cm','mm')
                            OR    (a.denominator_unit IN ('cm','mm')
                            AND   b.concept_name LIKE '%Fentanyl%'
                            AND   a.numerator_value IN (12.6,15.3)));

UPDATE ds_stage
   SET NUMERATOR_VALUE = 0.1,
       DENOMINATOR_VALUE = NULL,
       DENOMINATOR_UNIT = 'h'
WHERE drug_concept_code IN (SELECT drug_concept_code
                            FROM ds_stage a
                            JOIN drug_concept_stage b ON a.drug_concept_code = b.concept_code
                            WHERE NVL(a.amount_unit,a.numerator_unit) IN ('cm','mm')
                            OR    (a.denominator_unit IN ('cm','mm')
                            AND   b.concept_name LIKE '%Fentanyl%'
                            AND   a.numerator_value IN (16.8,10,11,20.4)));
COMMIT;

--17.4 rivastigmine
UPDATE ds_stage
   SET NUMERATOR_VALUE = 13.3,
       DENOMINATOR_VALUE = 24,
       DENOMINATOR_UNIT = 'h'
WHERE drug_concept_code IN (SELECT drug_concept_code
                            FROM ds_stage a
                            JOIN drug_concept_stage b ON a.drug_concept_code = b.concept_code
                            WHERE NVL(a.amount_unit,a.numerator_unit) IN ('cm','mm')
                            OR    (a.denominator_unit IN ('cm','mm')
                            AND   b.concept_name LIKE '%rivastigmine%'
                            AND   a.numerator_value = 27));

UPDATE ds_stage 
   SET NUMERATOR_VALUE = CASE
                           WHEN denominator_value IS NULL THEN numerator_value*24
                           ELSE numerator_value / denominator_value*24
                         END,
       DENOMINATOR_VALUE = 24,
       DENOMINATOR_UNIT = 'h'
WHERE drug_concept_code IN (SELECT drug_concept_code
                            FROM ds_stage a
                            JOIN drug_concept_stage b ON a.drug_concept_code = b.concept_code
                            WHERE NVL(amount_unit,numerator_unit) IN ('cm','mm')
                            OR    (denominator_unit IN ('cm','mm')
                            AND   b.concept_name LIKE '%rivastigmine%'));
COMMIT;

--17.5 nicotine
UPDATE ds_stage
   SET NUMERATOR_VALUE = CASE
                           WHEN denominator_value IS NULL THEN numerator_value*16
                           ELSE numerator_value / denominator_value*16
                         END,
       DENOMINATOR_VALUE = 16,
       DENOMINATOR_UNIT = 'h'
WHERE drug_concept_code IN (SELECT drug_concept_code
                            FROM ds_stage a
                            JOIN drug_concept_stage b ON a.drug_concept_code = b.concept_code
                            WHERE NVL(a.amount_unit,a.numerator_unit) IN ('cm','mm')
                            OR    (a.denominator_unit IN ('cm','mm')
                            AND   b.concept_name LIKE '%Nicotine%'
                            AND   numerator_value IN (0.625,0.938,1.56,35.2)));

UPDATE ds_stage
   SET NUMERATOR_VALUE = 14,
       DENOMINATOR_VALUE = 24,
       DENOMINATOR_UNIT = 'h'
WHERE drug_concept_code IN (SELECT drug_concept_code
                            FROM ds_stage a
                            JOIN drug_concept_stage b ON a.drug_concept_code = b.concept_code
                            WHERE NVL(a.amount_unit,a.numerator_unit) IN ('cm','mm')
                            OR    (a.denominator_unit IN ('cm','mm')
                            AND   b.concept_name LIKE '%Nicotine%'
                            AND   a.numerator_value IN (5.57,5.14,36,78)));
COMMIT;

--17.6 Povidone-Iodine
UPDATE ds_stage
   SET NUMERATOR_VALUE = 100,
       DENOMINATOR_VALUE = NULL,
       DENOMINATOR_UNIT = 'mL'
WHERE drug_concept_code IN (SELECT drug_concept_code
                            FROM ds_stage a
                              JOIN drug_concept_stage b ON a.drug_concept_code = b.concept_code
                            WHERE NVL(a.amount_unit,a.numerator_unit) IN ('cm','mm')
                            OR    (a.denominator_unit IN ('cm','mm')
                            AND   b.concept_name LIKE '%Povidone-Iodine%'));
							
UPDATE ds_stage
   SET NUMERATOR_VALUE = 1.4,
       NUMERATOR_UNIT = 'mg',
       DENOMINATOR_VALUE = NULL
WHERE drug_concept_code IN (SELECT drug_concept_code
                        FROM ds_stage a
                          JOIN drug_concept_stage b ON a.drug_concept_code = b.concept_code
                        WHERE ((a.numerator_value IS NOT NULL AND a.numerator_unit IS NULL) 
                        OR (a.denominator_value IS NOT NULL AND a.denominator_unit IS NULL) 
                        OR (a.amount_value IS NOT NULL AND a.amount_unit IS NULL))
                        AND   b.concept_name LIKE '%Aprotinin 10000 /ML%');
COMMIT;

--17.7 update wrong dosages in Varicella Virus Vaccine
UPDATE ds_stage
   SET numerator_unit = 'mg'
WHERE drug_concept_code IN (SELECT drug_concept_code
                        FROM ds_stage a
                          JOIN drug_concept_stage ds ON a.drug_concept_code = ds.concept_code
                        WHERE ((a.numerator_value IS NOT NULL AND a.numerator_unit IS NULL) 
                        OR (a.denominator_value IS NOT NULL AND a.denominator_unit IS NULL) 
                        OR (a.amount_value IS NOT NULL AND a.amount_unit IS NULL))
                        AND   ds.concept_name LIKE '%Varicella Virus Vaccine Live (Oka-Merck) strain 29800 /ML%');
COMMIT;

--17.8 update wrong dosages in alpha-amylase
UPDATE ds_stage
   SET numerator_unit = '[U]'
WHERE drug_concept_code IN (SELECT drug_concept_code
                        FROM ds_stage a
                          JOIN drug_concept_stage ds ON a.drug_concept_code = ds.concept_code
                        WHERE ((a.numerator_value IS NOT NULL AND a.numerator_unit IS NULL)
                        OR (a.denominator_value IS NOT NULL AND a.denominator_unit IS NULL) 
                        OR (a.amount_value IS NOT NULL AND a.amount_unit IS NULL))
                        AND   ds.concept_name LIKE '%alpha-amylase 200 /ML%');
COMMIT;
						--17.9 delete drugs that are missing units
DELETE FROM ds_stage
WHERE (numerator_value IS NOT NULL AND numerator_unit IS NULL)
OR    (denominator_value IS NOT NULL AND denominator_unit IS NULL)
OR    (amount_value IS NOT NULL AND amount_unit IS NULL);
COMMIT;

--18 Delete 3 legged dogs
DELETE FROM ds_stage
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
                                 AND concept_class_id = 'Ingredient' AND b.vocabulary_id LIKE 'RxNorm%'
                                JOIN concept b2 ON descendant_concept_id = b2.concept_id AND b2.concept_class_id NOT LIKE '%Comp%'
                              GROUP BY descendant_concept_id
                            )
                            SELECT concept_code
                            FROM a
                              JOIN b ON a.drug_concept_id = b.descendant_concept_id
                              JOIN concept c ON drug_concept_id = concept_id
                            WHERE cnt1 < cnt2
                            AND   c.vocabulary_id != 'RxNorm');
COMMIT;

--19 Remove those with less than 0.05 ml in denominator
DELETE FROM ds_stage
WHERE drug_concept_code IN (SELECT drug_concept_code
                            FROM ds_stage
                            WHERE denominator_value < 0.05
                            AND   denominator_unit = 'mL');
COMMIT;
                            
--20 Delete drugs with cm in denominator that we weren't able to fix
DELETE FROM ds_stage
WHERE drug_concept_code IN (SELECT drug_concept_code
                            FROM ds_stage a
                              JOIN drug_concept_stage b ON a.drug_concept_code = b.concept_code
                            WHERE nvl(amount_unit,numerator_unit) IN ('cm','mm')
                            OR    denominator_unit IN ('cm','mm'));
COMMIT;

--21 Delete combination drugs where denominators don't match
DELETE FROM ds_stage
WHERE (drug_concept_code,denominator_value) IN (SELECT a.drug_concept_code,
                                                       a.denominator_value
                                                FROM ds_stage a
                                                  JOIN ds_stage b
                                                    ON a.drug_concept_code = b.drug_concept_code
                                                   AND (a.denominator_value IS NULL
                                                   AND b.denominator_value IS NOT NULL
                                                    OR a.denominator_value != b.denominator_value
                                                    OR a.denominator_unit != b.denominator_unit)
                                                  JOIN drug_concept_stage ds
                                                    ON ds.concept_code = a.drug_concept_code
                                                   AND a.denominator_value != REGEXP_SUBSTR (ds.concept_name,'\d+(\.\d+)?'));

COMMIT;

--22 Deprecate ingredients that had died before 2 Feb 2017 (and so they dont exist in drug_concept_stage)
DELETE FROM ds_stage
WHERE ingredient_concept_code IN (SELECT ingredient_concept_code
                                  FROM ds_stage s
                                    LEFT JOIN drug_concept_stage b
                                           ON b.concept_code = s.ingredient_concept_code
                                          AND b.concept_class_id = 'Ingredient'
                                    JOIN concept c
                                      ON s.ingredient_concept_code = c.concept_code
                                     AND c.vocabulary_id LIKE 'Rx%'
                                     AND c.invalid_reason = 'D'
                                  WHERE b.concept_code IS NULL);
COMMIT;								  

--23 Delete impossible dosages
DELETE FROM ds_stage
WHERE drug_concept_code IN (SELECT drug_concept_code
                            FROM ds_stage
                            WHERE ((LOWER(numerator_unit) IN ('mg') AND LOWER(denominator_unit) IN ('ml','g') OR LOWER(numerator_unit) IN ('g') AND LOWER(denominator_unit) IN ('l')) AND numerator_value / denominator_value > 1000)
                            OR    (LOWER(numerator_unit) IN ('g') AND LOWER(denominator_unit) IN ('ml') AND numerator_value / denominator_value > 1)
                            OR    (LOWER(numerator_unit) IN ('mg') AND LOWER(denominator_unit) IN ('mg') AND numerator_value / denominator_value > 1)
                            OR    ((amount_unit = '%' AND amount_value > 100) OR (numerator_unit = '%' AND numerator_value > 100))
                            OR    (numerator_unit = '%' AND   denominator_unit IS NOT NULL)
                            );
COMMIT;
							
--!!!Anna, really, did we get such a concepts in a ds_stage?
--We obviously did
DELETE FROM ds_stage
WHERE drug_concept_code IN (SELECT drug_concept_code
                            FROM ds_stage s
                              LEFT JOIN drug_concept_stage a
                                     ON a.concept_code = s.drug_concept_code
                                    AND a.concept_class_id = 'Drug Product'
                              LEFT JOIN drug_concept_stage b
                                     ON b.concept_code = s.ingredient_concept_code
                                    AND b.concept_class_id = 'Ingredient'
                            WHERE a.concept_code IS NULL);
COMMIT;
                            
--24 Update 'U' ingredients to fresh ones (Fotemustine)                     
update ds_stage
set ingredient_concept_code='OMOP569695'
where ingredient_concept_code='OMOP432915'
and exists (select * from concept where concept_code='OMOP569695' and invalid_reason is null );

COMMIT;

--25 Build internal_relationship_stage 
INSERT /*+ APPEND */ INTO internal_relationship_stage
SELECT distinct concept_code,concept_code_2
FROM (
--Drug to form
     SELECT dc.concept_code,c2.concept_code AS concept_code_2 
     FROM drug_concept_stage dc
  JOIN concept c
    ON c.concept_code = dc.concept_code
   AND c.vocabulary_id = 'RxNorm Extension'
   AND dc.concept_class_id = 'Drug Product'
  JOIN concept_relationship cr ON c.concept_id = cr.concept_id_1
  JOIN concept c2
    ON cr.concept_id_2 = c2.concept_id
   AND c2.concept_class_id = 'Dose Form'
   AND c2.VOCABULARY_ID LIKE 'Rx%'
	--where regexp_like (c.concept_name,c2.concept_name) --Problem with Transdermal patch/system
UNION
--Drug to BN
SELECT dc.concept_code,
       c2.concept_code
FROM drug_concept_stage dc
  JOIN concept c
    ON c.concept_code = dc.concept_code
   AND c.vocabulary_id = 'RxNorm Extension'
   AND dc.concept_class_id = 'Drug Product'
   AND (dc.source_concept_class_id NOT LIKE '%Pack%'
    OR (dc.source_concept_class_id = 'Marketed Product'
   AND dc.concept_name NOT LIKE '%Pack%'))
  JOIN concept_relationship cr ON c.concept_id = concept_id_1
  JOIN concept c2
    ON concept_id_2 = c2.concept_id
   AND c2.concept_class_id = 'Brand Name'
   AND c2.vocabulary_id LIKE 'Rx%'
   AND LOWER(c.concept_name) like '%'||LOWER(c2.concept_name)||'%'
UNION
--Packs to BN
SELECT dc.concept_code,
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
WHERE c2.concept_name = regexp_replace (c.concept_name,'.* Pack .*\[(.*)\]','\1')
--REPLACE(REPLACE(REGEXP_SUBSTR(REGEXP_SUBSTR(c.concept_name,'Pack\s\[.*\]'),'\[.*\]'),'['),']')
UNION
  --drug to ingredient
SELECT drug_concept_code,
       ingredient_concept_code
FROM ds_Stage
UNION
--Drug Form to ingredient
select c.concept_code,c2.concept_code from concept c join concept_relationship cr on cr.concept_id_1=c.concept_id and c.concept_class_id in ('Clinical Drug Form', 'Branded Drug Form')
and c.vocabulary_id='RxNorm Extension' and c.invalid_reason is null
join concept c2 on c2.concept_id=cr.concept_id_2 and c2.concept_class_id='Ingredient'
UNION
--Drug to supplier
SELECT dc.concept_code,
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
   AND c2.vocabulary_id LIKE 'Rx%'
UNION
--insert relationships to those packs that do not have Pack's BN
SELECT a.concept_code,
       c2.concept_code
FROM concept a
  JOIN concept_relationship b
    ON concept_id_1 = a.concept_id
   AND a.vocabulary_id = 'RxNorm Extension'
   AND a.concept_class_id LIKE '%Branded%Pack%'
  LEFT JOIN concept c2
         ON c2.concept_name = regexp_replace (a.concept_name,'.* Pack .*\[(.*)\]','\1') -- take it from name
		 --REPLACE (REPLACE (REGEXP_SUBSTR (REGEXP_SUBSTR (a.concept_name,'Pack\s\[.*\]'),'\[.*\]'),'['),']') -- take it from name
        AND c2.vocabulary_id LIKE 'RxNorm%'
        AND c2.concept_class_id = 'Brand Name'
WHERE concept_id_1 NOT IN (SELECT concept_id_1
                           FROM concept a
                             JOIN concept_relationship b
                               ON b.concept_id_1 = a.concept_id
                              AND a.vocabulary_id = 'RxNorm Extension'
                              AND a.concept_class_id LIKE '%Pack%'
                             JOIN concept c
                               ON b.concept_id_2 = c.concept_id
                              AND c.concept_class_id = 'Brand Name'
                              AND b.invalid_reason IS NULL));
COMMIT;
			      
--26 Add all the attributes which relationships are missing in basic tables (separate query to speed up)
INSERT /*+ APPEND */ INTO internal_relationship_stage
--missing bn
     SELECT distinct dc.concept_code,dc2.concept_code AS concept_code_2 
     FROM drug_concept_stage dc
  JOIN concept c
    ON c.concept_code = dc.concept_code
   AND c.vocabulary_id = 'RxNorm Extension'
   AND dc.concept_class_id = 'Drug Product'
   AND dc.concept_name LIKE '%Pack%[%]%'
  JOIN drug_concept_stage dc2
    ON dc2.concept_name = regexp_replace (c.concept_name,'.* Pack .*\[(.*)\]','\1') 
	--REPLACE (REPLACE (REGEXP_SUBSTR (REGEXP_SUBSTR (c.concept_name,'Pack\s\[.*\]'),'\[.*\]'),'['),']')
   AND dc2.concept_class_id = 'Brand Name';
COMMIT;

--add missing suppliers
INSERT /*+ APPEND */ INTO  internal_relationship_stage
   WITH dc
        AS (SELECT /*+ materialize */
                  distinct LOWER (concept_name) concept_name, concept_code
              FROM drug_concept_stage
             WHERE source_concept_class_id = 'Marketed Product')
   SELECT dc.concept_code, dc2.concept_code
     FROM dc JOIN drug_concept_stage dc2 ON dc.concept_name LIKE '% ' || LOWER (dc2.concept_name) AND dc2.concept_class_id = 'Supplier';

delete internal_relationship_stage 
where (concept_code_1,concept_code_2) in ( 
with a as (select concept_code_1 from internal_relationship_stage a
join drug_concept_stage  b on concept_code = concept_code_2 
where b.concept_class_id in ('Supplier')
group by concept_code_1,b.concept_class_id having count (1) >1)
select b2.concept_code_1,b2.concept_code_2 from internal_relationship_stage b join a on a.concept_code_1=b.concept_code_1
join internal_relationship_stage b2 on b2.concept_code_1=b.concept_code_1 and b.concept_code_2!=b2.concept_code_2
join drug_concept_stage c on c.concept_code=b.concept_code_2 and c.concept_class_id='Supplier'
join drug_concept_stage c2 on c2.concept_code=b2.concept_code_2 and c2.concept_class_id='Supplier'
where length(c.concept_name)<length(c2.concept_name)
);

COMMIT;
*************************not completed*******************
	
--27 delete multiple relationships to attributes
--define concept_1, concept_2 pairs need to be deleted
CREATE TABLE ird
AS
SELECT concept_code_1,
       concept_code_2
FROM internal_relationship_stage a
  JOIN drug_concept_stage b
    ON a.concept_code_2 = b.concept_code
   AND b.concept_class_id IN ('Supplier', 'Dose Form', 'Brand Name')
  JOIN drug_concept_stage c ON c.concept_code = a.concept_code_1
WHERE a.concept_code_1 IN (SELECT a_int.concept_code_1
                         FROM internal_relationship_stage a_int
                           JOIN drug_concept_stage b ON b.concept_code = a_int.concept_code_2
                         WHERE b.concept_class_id IN ('Supplier','Dose Form','Brand Name')
                         GROUP BY a_int.concept_code_1, b.concept_class_id
                         HAVING COUNT(1) > 1)
AND NOT LOWER (c.concept_name) LIKE '%'||LOWER(b.concept_name)||'%' ; --Attribute is not a part of a name
--REGEXP_LIKE (c.concept_name,b.concept_name)
INSERT INTO ird
SELECT concept_code_1,
       concept_code_2
FROM internal_relationship_stage a
  JOIN drug_concept_stage b
    ON a.concept_code_2 = b.concept_code
   AND b.concept_class_id IN ('Supplier', 'Dose Form', 'Brand Name')
  JOIN drug_concept_stage c ON c.concept_code = concept_code_1
WHERE concept_code_1 IN (SELECT a_int.concept_code_1
                         FROM internal_relationship_stage a_int
                           JOIN drug_concept_stage b ON b.concept_code = a_int.concept_code_2
                         WHERE b.concept_class_id IN ('Supplier','Dose Form','Brand Name')
                         GROUP BY a_int.concept_code_1, b.concept_class_id
                         HAVING COUNT(1) > 1)
AND NOT REGEXP_LIKE (REGEXP_SUBSTR(c.concept_name,'Pack\s.*'),b.concept_name);

DELETE
FROM internal_relationship_stage
WHERE (concept_code_1,concept_code_2) IN (SELECT concept_code_1, concept_code_2 FROM ird);

DROP TABLE ird;

--delete 2 brand names that don't fit the rule as the brand name of the pack looks like the brand name of component (e.g. [Risedronate] and [Risedronate EC])
DELETE
FROM internal_relationship_stage
WHERE concept_code_1 in  ('OMOP572812','OMOP573077' ,'OMOP573035','OMOP573066','OMOP573376')
AND  concept_code_2  in  ('OMOP571371','OMOP569970');

--delete deprecated concepts
DELETE internal_relationship_stage
WHERE concept_code_2 IN (SELECT concept_code
                         FROM concept c
                         WHERE c.vocabulary_id LIKE 'Rx%'
                         AND   c.invalid_reason = 'D'
                         AND   concept_class_id = 'Ingredient');

COMMIT;

--just take it from the pack_content
INSERT INTO pc_stage
(
  PACK_CONCEPT_CODE, 
  DRUG_CONCEPT_CODE,
  AMOUNT,
  BOX_SIZE
)
SELECT DISTINCT c.concept_code,
       c2.concept_code,
       amount,
       box_size
FROM devv5.pack_content
  JOIN concept c
    ON pack_concept_id = c.CONCEPT_ID
   AND c.vocabulary_id = 'RxNorm Extension'
  JOIN concept c2 ON drug_concept_id = c2.concept_id;

--fix 2 equal components manualy
DELETE PC_STAGE
WHERE
   ( PACK_CONCEPT_CODE = 'OMOP339574' AND   DRUG_CONCEPT_CODE = '197659' AND   AMOUNT = 12)
OR ( PACK_CONCEPT_CODE = 'OMOP339579' AND   DRUG_CONCEPT_CODE = '311704' AND   AMOUNT IS NULL)
OR ( PACK_CONCEPT_CODE = 'OMOP339579' AND   DRUG_CONCEPT_CODE = '317128' AND   AMOUNT IS NULL)
OR ( PACK_CONCEPT_CODE = 'OMOP339728' AND   DRUG_CONCEPT_CODE = '1363273'AND   AMOUNT = 7)
OR ( PACK_CONCEPT_CODE = 'OMOP339876' AND   DRUG_CONCEPT_CODE = '864686' AND   AMOUNT IS NULL)
OR ( PACK_CONCEPT_CODE = 'OMOP339876' AND   DRUG_CONCEPT_CODE = '1117531' AND   AMOUNT IS NULL)
OR ( PACK_CONCEPT_CODE = 'OMOP339900' AND   DRUG_CONCEPT_CODE = '392651' AND   AMOUNT IS NULL)
OR ( PACK_CONCEPT_CODE = 'OMOP339900' AND   DRUG_CONCEPT_CODE = '197662' AND   AMOUNT IS NULL)
OR ( PACK_CONCEPT_CODE = 'OMOP339913' AND   DRUG_CONCEPT_CODE = '199797' AND   AMOUNT IS NULL)
OR ( PACK_CONCEPT_CODE = 'OMOP339913' AND   DRUG_CONCEPT_CODE = '199796' AND   AMOUNT IS NULL)
OR ( PACK_CONCEPT_CODE = 'OMOP340051' AND   DRUG_CONCEPT_CODE = '1363273' AND   AMOUNT = 7)
OR ( PACK_CONCEPT_CODE = 'OMOP340128' AND   DRUG_CONCEPT_CODE = '197659' AND   AMOUNT = 12)
OR ( PACK_CONCEPT_CODE = 'OMOP339633' AND   DRUG_CONCEPT_CODE = '310463' AND   AMOUNT = 5)
OR ( PACK_CONCEPT_CODE = 'OMOP339814' AND   DRUG_CONCEPT_CODE = '310463' AND   AMOUNT = 5)
OR ( PACK_CONCEPT_CODE = 'OMOP339886' AND   DRUG_CONCEPT_CODE = '312309' AND   AMOUNT = 6)
OR ( PACK_CONCEPT_CODE = 'OMOP339886' AND   DRUG_CONCEPT_CODE = '312308' AND   AMOUNT = 109)
OR ( PACK_CONCEPT_CODE = 'OMOP339895' AND   DRUG_CONCEPT_CODE = '312309' AND   AMOUNT = 6)
OR ( PACK_CONCEPT_CODE = 'OMOP339895' AND   DRUG_CONCEPT_CODE = '312308' AND   AMOUNT = 109);

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

--insert missing packs (only those that have => 2 components) - take them from the source tables
--!!! do we have packs with 1 component? Dima, it is a bug so we do not include them. You can actually look at existing packs with one component.

--AMT
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

--AMIS
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

--BDPM
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
FROM dev_bdpm.pc_stage pcs
  JOIN concept c
    ON c.concept_code = pcs.pack_Concept_code
   AND c.vocabulary_id = 'BDPM'
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
   AND c.vocabulary_id = 'BDPM'
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
                       FROM dev_bdpm.pc_stage pcs
                         JOIN concept c
                           ON c.concept_code = pcs.pack_Concept_code
                          AND c.vocabulary_id = 'BDPM'
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
                          AND c.vocabulary_id = 'BDPM'
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

--dm+d
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
FROM dev_dmd.pc_stage pcs
  JOIN concept c
    ON c.concept_code = pcs.pack_Concept_code
   AND c.vocabulary_id = 'dm+d'
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
   AND c.vocabulary_id = 'dm+d'
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
                       FROM dev_dmd.pc_stage pcs
                         JOIN concept c
                           ON c.concept_code = pcs.pack_Concept_code
                          AND c.vocabulary_id = 'dm+d'
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
                          AND c.vocabulary_id = 'dm+d'
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


--fix inert ingredients in contraceptive packs
update pc_stage
set amount='7'
 where (pack_concept_code,drug_concept_code) in
(select p.pack_concept_code,p.drug_concept_code
 from pc_stage p join drug_concept_stage d on d.concept_code=p.drug_concept_code and concept_name like '%Inert%' and p.amount='21'
join pc_stage p2 on p.pack_concept_code=p2.pack_concept_code and  p.drug_concept_code!=p2.drug_concept_code and p.amount='21');

--update Inert Ingredients / Inert Ingredients 1 MG Oral Tablet to Inert Ingredient Oral Tablet
update pc_stage
set drug_concept_code='748796'
where drug_concept_code='OMOP285209';

--Fixing existing packs in order to remove duplicates
DELETE
FROM PC_STAGE
WHERE PACK_CONCEPT_CODE = 'OMOP420950'
AND   DRUG_CONCEPT_CODE = '310463'
AND   AMOUNT = 5;
DELETE
FROM PC_STAGE
WHERE PACK_CONCEPT_CODE = 'OMOP420969'
AND   DRUG_CONCEPT_CODE = '310463'
AND   AMOUNT = 7;
DELETE
FROM PC_STAGE
WHERE PACK_CONCEPT_CODE = 'OMOP420978'
AND   DRUG_CONCEPT_CODE = '392651'
AND   AMOUNT IS NULL;
DELETE
FROM PC_STAGE
WHERE PACK_CONCEPT_CODE = 'OMOP420978'
AND   DRUG_CONCEPT_CODE = '197662'
AND   AMOUNT IS NULL;
DELETE
FROM PC_STAGE
WHERE PACK_CONCEPT_CODE = 'OMOP902613'
AND   DRUG_CONCEPT_CODE = 'OMOP918399'
AND   AMOUNT = 7;
UPDATE PC_STAGE
   SET AMOUNT = 12
WHERE PACK_CONCEPT_CODE = 'OMOP420950'
AND   DRUG_CONCEPT_CODE = '310463'
AND   AMOUNT = 7;
UPDATE PC_STAGE
   SET AMOUNT = 12
WHERE PACK_CONCEPT_CODE = 'OMOP420969'
AND   DRUG_CONCEPT_CODE = '310463'
AND   AMOUNT = 5;
UPDATE PC_STAGE
   SET AMOUNT = 12
WHERE PACK_CONCEPT_CODE = 'OMOP902613'
AND   DRUG_CONCEPT_CODE = 'OMOP918399'
AND   AMOUNT = 5;

COMMIT;

-- XXX all from concept 	
-- Christian, what do you mean?
-- Create links to self 
INSERT INTO relationship_to_concept
(
  CONCEPT_CODE_1,
  VOCABULARY_ID_1,
  CONCEPT_ID_2,
  PRECEDENCE
)
SELECT distinct
       a.concept_code,
       a.VOCABULARY_ID,
       b.concept_id,
       1
FROM drug_concept_stage a
  JOIN concept b
    ON a.concept_code = b.concept_code
   AND b.vocabulary_id IN ('RxNorm', 'RxNorm Extension') 
   AND a.concept_class_id IN ('Dose Form', 'Brand Name', 'Supplier', 'Ingredient');

--insert relationship to units
INSERT INTO relationship_to_concept
(
  CONCEPT_CODE_1,
  VOCABULARY_ID_1,
  CONCEPT_ID_2,
  PRECEDENCE,
  CONVERSION_FACTOR
)
SELECT distinct
       a.concept_code,
       a.vocabulary_id,
       b.concept_id,
       1,
       1
FROM drug_concept_stage a
  JOIN concept b
    ON a.concept_code = b.concept_code
   AND a.concept_class_id = 'Unit'
   AND b.vocabulary_id = 'UCUM';
   
-- transform micrograms into milligrams
UPDATE RELATIONSHIP_TO_CONCEPT
   SET CONCEPT_ID_2 = 8576,
       CONVERSION_FACTOR = 0.001
WHERE CONCEPT_CODE_1 = 'ug'
AND   CONCEPT_ID_2 = 9655;
