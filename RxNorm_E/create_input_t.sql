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

--1 Rivive relationships in order to use them in list item #22
UPDATE concept_relationship
SET invalid_reason=null, valid_end_date=TO_DATE ('20991231', 'YYYYMMDD') 
WHERE relationship_id IN ('RxNorm has dose form','RxNorm dose form of')
AND invalid_reason='D';
COMMIT;

--2 Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3 Load full list of RxNorm Extension concepts
INSERT /*+ APPEND */ INTO  CONCEPT_STAGE (concept_name,
                           domain_id,
                           vocabulary_id,
                           concept_class_id,
                           standard_concept,
                           concept_code,
                           valid_start_date,
                           valid_end_date,
                           invalid_reason)
   SELECT concept_name,
          domain_id,
          vocabulary_id,
          concept_class_id,
          standard_concept,
          concept_code,
          valid_start_date,
          valid_end_date,
          invalid_reason
     FROM concept
    WHERE vocabulary_id = 'RxNorm Extension';			   
COMMIT;


--4 Load full list of RxNorm Extension relationships
INSERT /*+ APPEND */ INTO  concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT c1.concept_code,
          c2.concept_code,
          c1.vocabulary_id,
          c2.vocabulary_id,
          r.relationship_id,
          r.valid_start_date,
          r.valid_end_date,
          r.invalid_reason
     FROM concept c1, concept c2, concept_relationship r
    WHERE c1.concept_id = r.concept_id_1 AND c2.concept_id = r.concept_id_2 AND 'RxNorm Extension' IN (c1.vocabulary_id, c2.vocabulary_id);
COMMIT;


--5 Load full list of RxNorm Extension drug strength
INSERT /*+ APPEND */
      INTO  drug_strength_stage (drug_concept_code,
                                 vocabulary_id_1,
                                 ingredient_concept_code,
                                 vocabulary_id_2,
                                 amount_value,
                                 amount_unit_concept_id,
                                 numerator_value,
                                 numerator_unit_concept_id,
                                 denominator_value,
                                 denominator_unit_concept_id,
                                 valid_start_date,
                                 valid_end_date,
                                 invalid_reason)
   SELECT c.concept_code,
          c.vocabulary_id,
          c2.concept_code,
          c2.vocabulary_id,
          amount_value,
          amount_unit_concept_id,
          numerator_value,
          numerator_unit_concept_id,
          denominator_value,
          denominator_unit_concept_id,
          ds.valid_start_date,
          ds.valid_end_date,
          ds.invalid_reason
     FROM concept c
          JOIN drug_strength ds ON ds.DRUG_CONCEPT_ID = c.CONCEPT_ID
          JOIN concept c2 ON ds.INGREDIENT_CONCEPT_ID = c2.CONCEPT_ID
    WHERE c.vocabulary_id IN ('RxNorm', 'RxNorm Extension');
COMMIT;

--6 Load full list of RxNorm Extension pack content
INSERT /*+ APPEND */
      INTO  pack_content_stage (pack_concept_code,
                                pack_vocabulary_id,
                                drug_concept_code,
                                drug_vocabulary_id,
                                amount,
                                box_size)
   SELECT c.concept_code,
          c.vocabulary_id,
          c2.concept_code,
          c2.vocabulary_id,
          amount,
          box_size
     FROM pack_content pc
          JOIN concept c ON pc.PACK_CONCEPT_ID = c.CONCEPT_ID
          JOIN concept c2 ON pc.DRUG_CONCEPT_ID = c2.CONCEPT_ID;
COMMIT;
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
select
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
SELECT c.concept_name,
       'Rxfix',
       c.concept_class_id,
       null,
       c.concept_code,
       null,
       c.domain_id,
       c.valid_start_date,
       c.valid_end_date,
       c.invalid_reason,
       c.concept_class_id
  FROM concept c
 --their attributes
 WHERE     c.concept_class_id IN ('Dose Form', 'Brand Name', 'Supplier')
       AND c.vocabulary_id LIKE 'Rx%'
       AND c.invalid_reason IS NULL
       AND EXISTS
       (SELECT 1
            FROM concept_relationship cr
            JOIN concept c_int ON c_int.concept_id=cr.concept_id_1
            -- the same list of the products
            AND (c_int.concept_class_id LIKE '%Drug%' OR c_int.concept_class_id LIKE '%Pack%' OR c_int.concept_class_id LIKE '%Box%' OR c_int.concept_class_id LIKE '%Marketed%')
            AND c_int.vocabulary_id = 'RxNorm Extension'
            WHERE cr.concept_id_2 = c.concept_id AND cr.invalid_reason IS NULL
         )
UNION ALL
--Get RxNorm pack components from RxNorm
SELECT c.concept_name,
       'Rxfix',
       'Drug Product',
       NULL,
       c.concept_code,
       NULL,
       c.domain_id,
       c.valid_start_date,
       c.valid_end_date,
       c.invalid_reason,
       c.concept_class_id
  FROM concept c
 --only Drugs
 WHERE     (c.concept_class_id LIKE '%Drug%' OR c.concept_class_id LIKE '%Marketed%')
       AND c.vocabulary_id = 'RxNorm'
       AND c.invalid_reason IS NULL
       AND EXISTS
       (SELECT 1
          FROM concept_relationship cr 
          JOIN concept c_int ON c_int.concept_id = cr.concept_id_1 
          AND c_int.concept_class_id LIKE '%Pack%' 
          AND c_int.vocabulary_id = 'RxNorm Extension'
         WHERE cr.concept_id_2 = c.concept_id AND cr.invalid_reason IS NULL
       );
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
    SELECT c.concept_name,
       'Rxfix',
       c.concept_class_id,
       NULL,
       c.concept_code,
       NULL,
       c.domain_id,
       c.valid_start_date,
       c.valid_end_date,
       c.invalid_reason,
       c.concept_class_id
  FROM concept c
 -- add fresh attributes instead of invalid
 WHERE     EXISTS
               (SELECT 1
                  FROM concept_relationship cr
                       JOIN concept c_int1
                           ON     c_int1.concept_id = cr.concept_id_1
                              AND (c_int1.concept_class_id LIKE '%Drug%' OR c_int1.concept_class_id LIKE '%Pack%' OR c_int1.concept_class_id LIKE '%Box%' OR c_int1.concept_class_id LIKE '%Marketed%')
                              AND c_int1.vocabulary_id = 'RxNorm Extension'
                       JOIN concept c_int2
                           ON     c_int2.concept_id = cr.concept_id_2
                              AND c_int2.concept_class_id IN ('Dose Form', 'Brand Name', 'Supplier')
                              AND c_int2.vocabulary_id LIKE 'Rx%'
                              AND c_int2.invalid_reason IS NOT NULL
                       --get last fresh attributes
                       JOIN (    SELECT CONNECT_BY_ROOT concept_id_1 AS root_concept_id_1, u.concept_id_2
                                   FROM (SELECT r.*
                                           FROM concept_relationship r
                                                JOIN concept c1 ON c1.concept_id = r.concept_id_1 AND c1.concept_class_id IN ('Dose Form', 'Brand Name', 'Supplier') AND c1.vocabulary_id LIKE 'Rx%'
                                                JOIN concept c2 ON c2.concept_id = r.concept_id_2 AND c2.concept_class_id IN ('Dose Form', 'Brand Name', 'Supplier') AND c2.vocabulary_id LIKE 'Rx%'
                                          WHERE r.relationship_id = 'Concept replaced by' AND r.invalid_reason IS NULL) u
                                  WHERE CONNECT_BY_ISLEAF = 1
                             CONNECT BY NOCYCLE PRIOR u.concept_id_2 = u.concept_id_1) lf
                           ON lf.root_concept_id_1 = c_int2.concept_id
                 WHERE lf.concept_id_2 = c.concept_id AND cr.invalid_reason IS NULL)
       AND NOT EXISTS
               (SELECT 1
                  FROM DRUG_CONCEPT_STAGE dcs
                 WHERE dcs.concept_code = c.concept_code AND dcs.domain_id = c.domain_id AND dcs.concept_class_id = c.concept_class_id AND dcs.source_concept_class_id = c.concept_class_id);
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
	SELECT c.concept_name,
		   'Rxfix',
		   'Ingredient',
		   'S',
		   c.concept_code,
		   NULL,
		   c.domain_id,
		   c.valid_start_date,
		   c.valid_end_date,
		   c.invalid_reason,
		   'Ingredient'
	  FROM concept c
	 WHERE     c.invalid_reason IS NULL
		   AND c.vocabulary_id LIKE 'Rx%'
		   AND EXISTS
				   (SELECT 1
					  FROM drug_strength ds JOIN concept c_int ON c_int.concept_id = ds.drug_concept_id AND c_int.vocabulary_id = 'RxNorm Extension'
					 WHERE ds.ingredient_concept_id = c.concept_id)
		   AND NOT EXISTS
				   (SELECT 1
					  FROM DRUG_CONCEPT_STAGE dcs
					 WHERE dcs.concept_code = c.concept_code AND dcs.domain_id = c.domain_id AND dcs.concept_class_id = 'Ingredient' AND dcs.source_concept_class_id = 'Ingredient');
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
	SELECT c.concept_name,
		   'Rxfix',
		   'Ingredient',
		   'S',
		   c.concept_code,
		   NULL,
		   c.domain_id,
		   c.valid_start_date,
		   c.valid_end_date,
		   c.invalid_reason,
		   'Ingredient'
	  FROM concept c
	 WHERE     c.concept_class_id = 'Ingredient'
		   AND c.vocabulary_id LIKE 'Rx%'
		   --add ingredients from ancestor
		   AND EXISTS
				   (SELECT 1
					  FROM concept_ancestor ca JOIN concept c_int ON c_int.concept_id = ca.descendant_concept_id AND c_int.vocabulary_id = 'RxNorm Extension'
					 WHERE ca.ancestor_concept_id = c.concept_id)
		   AND NOT EXISTS
				   (SELECT 1
					  FROM DRUG_CONCEPT_STAGE dcs
					 WHERE dcs.concept_code = c.concept_code AND dcs.domain_id = c.domain_id AND dcs.concept_class_id = 'Ingredient' AND dcs.source_concept_class_id = 'Ingredient');
COMMIT;		

--4.5 Insert dead RxNorm's 'Yeasts' in order to revive it in RxE + add Kentucky grass
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
	SELECT c.concept_name,
		   'Rxfix',
		   'Ingredient',
		   'S',
		   c.concept_code,
		   NULL,
		   c.domain_id,
		   c.valid_start_date,
		   TO_DATE ('20991231', 'yyyymmdd') as valid_end_date,
		   c.invalid_reason,
		   'Ingredient'
	  FROM concept c
	 WHERE c.concept_name IN ('Yeasts','Kentucky bluegrass pollen extract') AND c.vocabulary_id='RxNorm';
COMMIT;		 	   

--4.6 Get all Units
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
	SELECT c.concept_name,'Rxfix','Unit',NULL,c.concept_code,NULL,'Drug',c.valid_start_date,c.valid_end_date,NULL,'Unit'
	  FROM concept c
	 WHERE c.concept_id IN (SELECT ds.units
							  FROM (SELECT units, drug_concept_id
									  FROM drug_strength UNPIVOT (units FOR units_ids IN (amount_unit_concept_id, numerator_unit_concept_id, denominator_unit_concept_id))) ds
								   JOIN concept c_int ON c_int.concept_id = ds.drug_concept_id AND c_int.vocabulary_id = 'RxNorm Extension')
	UNION
	SELECT c.concept_name,'Rxfix','Unit',NULL,c.concept_code,NULL,'Drug',c.valid_start_date,c.valid_end_date,NULL,'Unit'
	  FROM concept c
	WHERE c.concept_id = 45744815
;
COMMIT;

--4.7 Get a supplier that hadn't been connected to any drug
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
    SELECT c.concept_name,
           'Rxfix',
           c.concept_class_id,
           NULL,
           c.concept_code,
           NULL,
           c.domain_id,
           c.valid_start_date,
           c.valid_end_date,
           c.invalid_reason,
           c.concept_class_id
      FROM concept c
     WHERE     c.concept_name = 'Hawgreen Ltd'
           AND c.vocabulary_id = 'RxNorm Extension'
           AND NOT EXISTS
                   (SELECT 1
                      FROM DRUG_CONCEPT_STAGE dcs
                     WHERE dcs.concept_code = c.concept_code AND dcs.domain_id = c.domain_id AND dcs.concept_class_id = c.concept_class_id AND dcs.source_concept_class_id = c.concept_class_id);
COMMIT;

--5 Remove all where there is less than total of 0.05 mL
DELETE FROM DRUG_CONCEPT_STAGE
      WHERE concept_code IN (SELECT concept_code
                               FROM concept c JOIN drug_strength ds ON ds.drug_concept_id = c.concept_id
                              WHERE c.vocabulary_id = 'RxNorm Extension' AND c.invalid_reason IS NULL AND ds.denominator_value < 0.05 AND ds.denominator_unit_concept_id = 8587);
COMMIT;							  

--6 delete isopropyl as it is not an ingrediend + drugs containing it
DELETE drug_concept_stage where concept_code IN
(SELECT c.concept_code 
   FROM concept_ancestor a 
        JOIN concept c ON c.concept_id = descendant_concept_id AND ancestor_concept_id = 43563483);
DELETE drug_concept_stage where concept_code IN
('OMOP881482','OMOP341519','OMOP346740','OMOP714610');

/* Remove wrong brand names (need to save for the later clean up)
DELETE FROM DRUG_CONCEPT_STAGE
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
*/
--7 filling drug_strength
--just turn drug_strength into ds_stage replacing concept_ids with concept_codes
INSERT /*+ APPEND */
      INTO  ds_stage (DRUG_CONCEPT_CODE,INGREDIENT_CONCEPT_CODE,BOX_SIZE,AMOUNT_VALUE,AMOUNT_UNIT,NUMERATOR_VALUE,NUMERATOR_UNIT,DENOMINATOR_VALUE,DENOMINATOR_UNIT)
   SELECT  drug_concept_code, 
           CASE WHEN ingredient_concept_code='314375'     THEN '852834' --ALLERGENIC EXTRACT, GRASS, KENTUCKY BLUE
                WHEN ingredient_concept_code='OMOP332154' THEN '748794' --Inert Ingredients
                WHEN ingredient_concept_code='314329'     THEN '1309815' --ALLERGENIC EXTRACT, BIRCH
                WHEN ingredient_concept_code='1428040'    THEN '1406' --STYRAX BENZOIN RESIN   + leave 11384 Yeasts as it is
		WHEN ingredient_concept_code='236340'    THEN '644634'
                ELSE ingredient_concept_code END,
           box_size,amount_value,amount_unit,numerator_value,numerator_unit,denominator_value,denominator_unit 
     FROM (
            SELECT  c.concept_code as drug_concept_code, c2.concept_code as ingredient_concept_code,ds.box_size,
            CASE WHEN c3.concept_code = 'ug' THEN amount_value/1000 
                 WHEN c3.concept_code = 'ukat' THEN amount_value*1000000   
                 WHEN c3.concept_code = '[CCID_50]' THEN amount_value*0.7
                 WHEN c3.concept_code = '10*9' THEN amount_value*1000000000
                 WHEN c3.concept_code = '10*6' THEN amount_value*1000000
                 ELSE amount_value END AS amount_value,
            CASE WHEN c3.concept_code = 'ug' THEN 'mg' 
                 WHEN c3.concept_code = '[U]' THEN '[iU]'
                 WHEN c3.concept_code = 'ukat' THEN '[iU]'
                 WHEN c3.concept_code = '[CCID_50]' THEN '[PFU]' 
                 WHEN c3.concept_code in ('10*9','10*6') THEN '{bacteria}' 
                 ELSE c3.concept_code END AS amount_unit,
            CASE WHEN c4.concept_code = 'ug' THEN ds.numerator_value/1000
                 WHEN c4.concept_code = '[CCID_50]' THEN ds.numerator_value*0.7 
                 WHEN c4.concept_code = '10*9' THEN ds.numerator_value*1000000000
                 WHEN c4.concept_code = '10*6' THEN ds.numerator_value*1000000  
                 ELSE ds.numerator_value END AS numerator_value,
            CASE WHEN c4.concept_code = 'ug' THEN 'mg' 
                 WHEN c4.concept_code = '[U]' THEN '[iU]'
                 WHEN c4.concept_code = '[CCID_50]' THEN '[PFU]' 
                 WHEN c4.concept_code in ('10*9','10*6') THEN '{bacteria}' 
                 ELSE c4.concept_code END AS numerator_unit,
            ds.denominator_value,
            CASE WHEN c5.concept_code = '[U]' THEN '[iU]' 
                 ELSE c5.concept_code END AS denominator_unit 
              FROM concept c
                   JOIN drug_concept_stage dc on dc.concept_code=c.concept_code
                   JOIN drug_strength ds ON ds.drug_concept_id = c.concept_id AND c.vocabulary_id like 'RxNorm%' AND c.invalid_reason IS NULL
                   JOIN concept c2 ON c2.concept_id = ds.ingredient_concept_id AND (c2.invalid_reason='D' OR c2.invalid_reason IS NULL)
                   LEFT JOIN concept c3 ON c3.concept_id = ds.amount_unit_concept_id
                   LEFT JOIN concept c4 ON c4.concept_id = ds.numerator_unit_concept_id
                   LEFT JOIN concept c5 ON c5.concept_id = ds.denominator_unit_concept_id
            UNION ALL                 --add fresh concepts
            SELECT c1.concept_code,lf.concept_code,ds.box_size,amount_value,c3.concept_code,ds.numerator_value,c4.concept_code,ds.denominator_value,c5.concept_code 
              FROM concept c1
                   JOIN drug_strength ds ON c1.concept_id=ds.drug_concept_id AND c1.vocabulary_id = 'RxNorm Extension' AND c1.invalid_reason IS NULL
                   JOIN (    SELECT CONNECT_BY_ROOT concept_id_1 AS root_concept_id_1, u.concept_code
                                   FROM (SELECT r.*,c2.concept_code
                                           FROM concept_relationship r
                                                JOIN concept c1 ON c1.concept_id = r.concept_id_1 AND c1.concept_class_id = 'Ingredient' AND c1.vocabulary_id LIKE 'Rx%'
                                                JOIN concept c2 ON c2.concept_id = r.concept_id_2 AND c2.concept_class_id = 'Ingredient' AND c2.vocabulary_id LIKE 'Rx%'
                                          WHERE r.relationship_id = 'Concept replaced by' AND r.invalid_reason IS NULL) u
                                  WHERE CONNECT_BY_ISLEAF = 1
                             CONNECT BY NOCYCLE PRIOR u.concept_id_2 = u.concept_id_1) lf
                             ON lf.root_concept_id_1=ds.ingredient_concept_id  
                   LEFT JOIN concept c3 ON c3.concept_id = ds.amount_unit_concept_id
                   LEFT JOIN concept c4 ON c4.concept_id = ds.numerator_unit_concept_id
                   LEFT JOIN concept c5 ON c5.concept_id = ds.denominator_unit_concept_id);
COMMIT;	

--8 Manually add absent units in drug_strength (due to source table issues)
UPDATE ds_stage
   SET AMOUNT_UNIT = '[U]'
WHERE ingredient_concept_code = '560'
AND drug_concept_code IN ('OMOP467711','OMOP467709','OMOP467706','OMOP467710','OMOP467715','OMOP467705','OMOP467712','OMOP467708','OMOP467714','OMOP467713');

UPDATE ds_stage
   SET AMOUNT_VALUE = 25,
       AMOUNT_UNIT = 'mg',
       NUMERATOR_VALUE = NULL,
       NUMERATOR_UNIT = ''
WHERE drug_concept_code IN ('OMOP420731','OMOP420834','OMOP420835','OMOP420833')
AND   ingredient_concept_code = '2409';

UPDATE ds_stage
   SET AMOUNT_VALUE = 100,
       AMOUNT_UNIT = 'mg',
       NUMERATOR_VALUE = NULL,
       NUMERATOR_UNIT = NULL
WHERE drug_concept_code IN ('OMOP420832','OMOP420835','OMOP420834','OMOP420833')
AND   ingredient_concept_code = '1202';
COMMIT;

COMMIT;

--9 create consolidated denominator unit for drugs that have soluble and solid ingredients
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

--10 update different denominator units
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

--11 Fix solid forms with denominator
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
							   
							   
--12 Put percent into the numerator, not amount
UPDATE ds_stage
   SET numerator_unit = amount_unit,
       NUMERATOR_VALUE = AMOUNT_VALUE,
       AMOUNT_VALUE = NULL,
       amount_unit = NULL
WHERE amount_unit = '%';
COMMIT;

--13 Fixes of various ill-defined drugs violating with RxNorm editorial policies 
UPDATE ds_stage
   SET NUMERATOR_VALUE = 25
WHERE drug_concept_code IN ('OMOP303266','OMOP303267','OMOP303268');

UPDATE ds_stage
   SET NUMERATOR_VALUE = 1
WHERE drug_concept_code IN ( 'OMOP317478','OMOP317479','OMOP317480');

UPDATE ds_stage
   SET NUMERATOR_VALUE = 10000,
       DENOMINATOR_UNIT = 'mL'
WHERE INGREDIENT_CONCEPT_CODE = '8536'
AND drug_concept_code IN ('OMOP420658','OMOP420659','OMOP420660','OMOP420661');
COMMIT;

--14 Change %/actuat into mg/mL
UPDATE ds_stage
   SET NUMERATOR_VALUE = NUMERATOR_VALUE*10,
       NUMERATOR_UNIT = 'mg',
       DENOMINATOR_VALUE = NULL,
       DENOMINATOR_UNIT = 'mL'
WHERE denominator_unit = '{actuat}'
AND   numerator_unit = '%';

-- Manual fixes with strange % values
UPDATE ds_stage
   SET NUMERATOR_VALUE = 100,
       DENOMINATOR_VALUE = NULL,
       DENOMINATOR_UNIT = NULL
WHERE numerator_unit = '%'
AND   numerator_value IN (0.000283,0.1,35.3);
COMMIT;
							   
--15 Do all sorts of manual fixes
--15.1 Fentanyl buccal film
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

--15.2 Add denominator to trandermal patch
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

--15.3 Fentanyl topical
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

--15.4 rivastigmine
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

--15.5 nicotine
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

--15.6 Povidone-Iodine
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

--15.7 update wrong dosages in Varicella Virus Vaccine
UPDATE ds_stage
   SET numerator_unit = '[U]', numerator_value = 29800
WHERE drug_concept_code IN (SELECT drug_concept_code
                        FROM ds_stage a
                          JOIN drug_concept_stage ds ON a.drug_concept_code = ds.concept_code
                        WHERE ds.concept_name LIKE '%Varicella Virus Vaccine Live (Oka-Merck) strain 29800 /ML%');
COMMIT;		

--15.8 update wrong dosages in alpha-amylase
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

--15.9 delete drugs that are missing units. delete drugs from DCS to remove them totally
DELETE FROM drug_concept_stage
      WHERE concept_code IN
                (SELECT drug_concept_code
                   FROM ds_stage
                  WHERE (numerator_value IS NOT NULL AND numerator_unit IS NULL) 
                  OR (denominator_value IS NOT NULL AND denominator_unit IS NULL) 
                  OR (amount_value IS NOT NULL AND amount_unit IS NULL));
COMMIT;

--15.10 delete drugs that are missing units
DELETE FROM ds_stage
	WHERE (numerator_value IS NOT NULL AND numerator_unit IS NULL)
	OR    (denominator_value IS NOT NULL AND denominator_unit IS NULL)
	OR    (amount_value IS NOT NULL AND amount_unit IS NULL);
COMMIT;

--15.11 working on drugs that presented in way of mL/mL
UPDATE ds_stage
   SET numerator_unit = 'mg'
WHERE drug_concept_code IN (SELECT drug_concept_code
                            FROM ds_stage
                              JOIN drug_concept_stage
                                ON drug_concept_code = concept_code
                               AND concept_name LIKE '%Paclitaxel%'
                               AND numerator_unit = 'mL'
                               AND denominator_unit = 'mL');
                               
UPDATE ds_stage
   SET numerator_unit = 'mg',numerator_value=CASE WHEN denominator_value IS NOT NULL 
						  THEN denominator_value*1000 
						  ELSE 1 END
WHERE drug_concept_code IN (SELECT drug_concept_code
                            FROM ds_stage
                              JOIN drug_concept_stage
                                ON drug_concept_code = concept_code AND concept_name LIKE '%Water%' AND numerator_unit = 'mL' AND denominator_unit = 'mL');
			       
--15.12 cromolyn Inhalation powder change to 5mg/actuat
UPDATE ds_stage
   SET numerator_value=amount_value,numerator_unit=amount_unit,denominator_unit='{actuat}',amount_value=NULL,amount_unit=NULL
WHERE drug_concept_code IN ('OMOP391197','OMOP391198','OMOP391199');

--15.13 update all the gases
UPDATE ds_stage
   SET numerator_unit = '%',numerator_value = '95',denominator_unit = NULL,denominator_value = NULL
WHERE drug_concept_code IN (SELECT concept_code
                            FROM drug_concept_stage
                              JOIN ds_stage ON concept_code = drug_concept_code
                             WHERE REGEXP_LIKE (concept_name,'Oxygen\s((950 MG/ML)|(0.95 MG/MG)|(950 MG/MG)|(950000 MG/ML)|(950000000 MG/ML))'))
AND   ingredient_concept_code = '7806' AND   numerator_unit != '%';

UPDATE ds_stage
   SET numerator_unit = '%',numerator_value = '5',denominator_unit = NULL,denominator_value = NULL
WHERE drug_concept_code IN (SELECT concept_code
                            FROM drug_concept_stage
                              JOIN ds_stage ON concept_code = drug_concept_code
                            WHERE REGEXP_LIKE (concept_name,'Carbon Dioxide\s((50 MG/)|(0.05 MG/MG)|(50000 MG/ML)|(50000000 MG/ML))'))
AND   ingredient_concept_code = '2034' AND   numerator_unit != '%';

UPDATE ds_stage
   SET numerator_unit = '%',numerator_value = '50',denominator_unit = NULL,denominator_value = NULL
WHERE drug_concept_code IN (SELECT concept_code
                            FROM drug_concept_stage
                              JOIN ds_stage ON concept_code = drug_concept_code
                            WHERE REGEXP_LIKE (concept_name,'(Nitrous Oxide|Oxygen|Carbon Dioxide)\s((500 MG/.*ML)|(500000000 MG/.*ML)|(270 MG/.*ML)|(500000 MG/ML)|(500 MG/MG)|(0.00025 ML/ML))')
                            AND   numerator_unit != '%');
                           
UPDATE ds_stage
   SET numerator_unit = '%',numerator_value = '79',denominator_unit = NULL,denominator_value = NULL
WHERE drug_concept_code IN (SELECT concept_code
                            FROM drug_concept_stage
                              JOIN ds_stage ON concept_code = drug_concept_code
                            WHERE concept_name LIKE '%Helium%79%MG/%')
AND   ingredient_concept_code = '5140' AND   numerator_unit != '%';

UPDATE ds_stage
   SET numerator_unit = '%', numerator_value = '21', denominator_unit = NULL,denominator_value = NULL
WHERE drug_concept_code IN (SELECT concept_code
                            FROM drug_concept_stage
                              JOIN ds_stage ON concept_code = drug_concept_code
                            WHERE concept_name LIKE '%Oxygen%21%MG/%')
AND   ingredient_concept_code = '7806' AND   numerator_unit != '%';

UPDATE ds_stage
   SET numerator_unit = '%',
       numerator_value = CASE
                           WHEN numerator_unit = 'mg' AND denominator_unit = 'mL' THEN numerator_value / NVL(denominator_value,1)*0.1
                           WHEN numerator_value/nvl(denominator_value,1)<0.09 THEN numerator_value / NVL(denominator_value,1)*1000
                           ELSE numerator_value / NVL(denominator_value,1)*100 END ,
       denominator_unit = NULL, denominator_value = NULL
WHERE drug_concept_code IN (SELECT concept_code
                            FROM drug_concept_stage
                              JOIN ds_stage ON concept_code = drug_concept_code
                            WHERE REGEXP_LIKE (concept_name,'((Nitrous Oxide)|(Xenon)|(Isoflurane)|(Oxygen)) (\d+\.)?(\d+\s((MG/MG)|(ML/ML)))') AND numerator_unit != '%')
;

--16 Delete 3 legged dogs
DELETE FROM ds_stage
WHERE drug_concept_code IN (WITH a AS
                            ( SELECT drug_concept_id,
                                     COUNT(drug_concept_id) AS cnt1
                              FROM drug_strength
                              GROUP BY drug_concept_id
                            ),
                            b AS
                            ( SELECT descendant_concept_id,
                                     COUNT(descendant_concept_id) AS cnt2
                              FROM concept_ancestor a
                                JOIN concept b
                                  ON ancestor_concept_id = b.concept_id
                                 AND concept_class_id = 'Ingredient' AND b.vocabulary_id LIKE 'RxNorm%' 
                                JOIN concept b2 ON descendant_concept_id = b2.concept_id AND b2.concept_class_id NOT LIKE '%Comp%' AND b2.concept_name like '% / %'
                              GROUP BY descendant_concept_id)
                            SELECT concept_code
                            FROM a
                              JOIN b ON a.drug_concept_id = b.descendant_concept_id
                              JOIN concept c ON drug_concept_id = concept_id
                            WHERE cnt1 < cnt2
			    AND cnt1=regexp_count (c.concept_name,' / ')
                            AND   c.vocabulary_id != 'RxNorm');
COMMIT;

--17 Remove those with less than 0.05 ml in denominator. Delete those drugs from DCS to remove them totally
DELETE FROM drug_concept_stage
      WHERE concept_code IN (SELECT drug_concept_code
                               FROM ds_stage
                              WHERE denominator_value < 0.05 
                              AND denominator_unit = 'mL');
COMMIT;

--17.1 Remove those with less than 0.05 ml in denominator
DELETE FROM ds_stage
      WHERE drug_concept_code IN (SELECT drug_concept_code
                                    FROM ds_stage
                                   WHERE denominator_value < 0.05 
                                   AND denominator_unit = 'mL');


--18 Fix all the enormous dosages that we can
UPDATE ds_stage
SET numerator_value='100'
WHERE drug_concept_code IN
(SELECT concept_code FROM drug_concept_stage WHERE concept_name LIKE '%Hydrocortisone 140%');         

UPDATE ds_stage
SET numerator_value='20'
WHERE drug_concept_code IN
(SELECT concept_code FROM drug_concept_stage WHERE concept_name LIKE '%Benzocaine 120 %');  

UPDATE ds_stage
SET numerator_value=numerator_value/10
WHERE drug_concept_code IN
(SELECT concept_code FROM ds_stage a
                          JOIN drug_concept_stage ds ON a.drug_concept_code = ds.concept_code
                        WHERE concept_name LIKE '%Albumin Human, USP%'  AND numerator_value/nvl(denominator_value, 1)>1000);  
                        
UPDATE ds_stage
SET numerator_value = numerator_value/1000000
WHERE drug_concept_code IN
(SELECT concept_code FROM ds_stage a
                          JOIN drug_concept_stage ds ON a.drug_concept_code = ds.concept_code
                        WHERE  REGEXP_LIKE (concept_name, 'Glucose (100000000|200000000|40000000|50000000)|Gelatin 40000000|Bupivacaine|Fentanyl|sodium citrate|(Glucose 50000000 MG/ML  Injectable Solution)|(Glucose 50000000 MG/ML / Potassium Chloride 1500000 MG/ML)|Potassium Cloride (75000000|4500000|30000000|2000000|1500000)|Sodium|Peracetic acid') 
                          AND numerator_value/nvl(denominator_value, 1)>10000);
                          
UPDATE ds_stage
SET numerator_value = numerator_value/100000
WHERE drug_concept_code IN
(SELECT concept_code FROM ds_stage a
                          JOIN drug_concept_stage ds ON a.drug_concept_code = ds.concept_code
                        WHERE  REGEXP_LIKE (concept_name, '(Morphine (1000000|2000000))|Sorbitol|Mannitol') 
                          AND numerator_value/nvl(denominator_value, 1)>1000);                          
UPDATE ds_stage
   SET denominator_unit = 'mL'
WHERE drug_concept_code IN (SELECT drug_concept_code
                             FROM ds_stage
                               JOIN drug_concept_stage ON drug_concept_code = concept_code
                             WHERE numerator_unit = 'mg'
                             AND   denominator_unit = 'mg'
                             AND   numerator_value / nvl(denominator_value,1) > 1);
COMMIT;
                            
--19 Delete drugs with cm in denominator that we weren't able to fix
DELETE FROM ds_stage
	WHERE drug_concept_code IN (SELECT drug_concept_code
								FROM ds_stage a
								  JOIN drug_concept_stage b ON a.drug_concept_code = b.concept_code
								WHERE nvl(amount_unit,numerator_unit) IN ('cm','mm')
								OR    denominator_unit IN ('cm','mm'));
COMMIT;

--20 Delete combination drugs where denominators don't match
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

--20.1 move homeopathy to numerator
UPDATE ds_stage
SET numerator_value = amount_value, numerator_unit = amount_unit, amount_value=NULL,amount_unit=NULL
WHERE drug_concept_code IN (
SELECT drug_concept_code FROM ds_stage WHERE amount_unit IN ('[hp_C]','[hp_X]'));

COMMIT;

--21 Delete impossible dosages. Delete those drugs from DCS to remove them totally
DELETE FROM drug_concept_stage
WHERE concept_code IN (SELECT drug_concept_code
                            FROM ds_stage
							WHERE (((LOWER(numerator_unit)='mg' AND LOWER(denominator_unit) IN ('ml','g')) OR (LOWER(numerator_unit)='g' AND LOWER(denominator_unit)='l')) AND numerator_value / nvl(denominator_value,1) > 1000)
							OR    (LOWER(numerator_unit)='g' AND LOWER(denominator_unit)='ml' AND numerator_value / nvl(denominator_value,1) > 1)
							OR    (LOWER(numerator_unit)='mg' AND LOWER(denominator_unit)='mg' AND numerator_value / nvl(denominator_value,1) > 1)
							OR    ((amount_unit = '%' AND amount_value > 100) OR (numerator_unit = '%' AND numerator_value > 100))
							OR    (numerator_unit = '%' AND   denominator_unit IS NOT NULL)
                            );
							
--21.1 Delete impossible dosages
DELETE FROM ds_stage
	WHERE drug_concept_code IN (SELECT drug_concept_code
                            FROM ds_stage
							WHERE (((LOWER(numerator_unit)='mg' AND LOWER(denominator_unit) IN ('ml','g')) OR (LOWER(numerator_unit)='g' AND LOWER(denominator_unit)='l')) AND numerator_value / nvl(denominator_value,1) > 1000)
							OR    (LOWER(numerator_unit)='g' AND LOWER(denominator_unit)='ml' AND numerator_value / nvl(denominator_value,1) > 1)
							OR    (LOWER(numerator_unit)='mg' AND LOWER(denominator_unit)='mg' AND numerator_value / nvl(denominator_value,1) > 1)
							OR    ((amount_unit = '%' AND amount_value > 100) OR (numerator_unit = '%' AND numerator_value > 100))
							OR    (numerator_unit = '%' AND   denominator_unit IS NOT NULL)
                            );
COMMIT;

--22 Build internal_relationship_stage 
--Drug to form
INSERT /*+ APPEND */
      INTO  internal_relationship_stage
    SELECT dc.concept_code, CASE WHEN c2.concept_code = 'OMOP881524' THEN '316975'  --Rectal Creame and Rectal Cream
				 WHEN c2.concept_code = '1021221'    THEN '316999'  --Gas and Gas for Inhalation						
				 ELSE c2.concept_code END AS concept_code_2  
      FROM drug_concept_stage dc
           JOIN concept c ON c.concept_code = dc.concept_code AND c.vocabulary_id like 'RxNorm%' AND dc.concept_class_id = 'Drug Product'
           JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id AND cr.relationship_id = 'RxNorm has dose form' AND cr.invalid_reason IS NULL
           JOIN concept c2 ON c2.concept_id = cr.concept_id_2 AND c2.concept_class_id = 'Dose Form' AND c2.vocabulary_id LIKE 'Rx%' AND c2.invalid_reason IS NULL;

            --where regexp_like (c.concept_name,c2.concept_name) --Problem with Transdermal patch/system

COMMIT;

 --Drug to BN
INSERT /*+ APPEND */
      INTO  internal_relationship_stage
    SELECT dc.concept_code, c2.concept_code
      FROM drug_concept_stage dc
           JOIN concept c ON c.concept_code = dc.concept_code AND c.vocabulary_id like 'RxNorm%'
           JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id AND cr.relationship_id = 'Has brand name' AND cr.invalid_reason IS NULL
           JOIN concept c2
               ON     concept_id_2 = c2.concept_id
                  AND c2.concept_class_id = 'Brand Name'
                  AND c2.vocabulary_id LIKE 'Rx%'
                  AND LOWER (c.concept_name) LIKE '%' || LOWER (c2.concept_name) || '%'
                  AND c2.invalid_reason IS NULL
     WHERE     dc.concept_class_id = 'Drug Product'
           AND (dc.source_concept_class_id NOT LIKE '%Pack%' OR (dc.source_concept_class_id = 'Marketed Product' AND dc.concept_name NOT LIKE '%Pack%'))
           AND NOT EXISTS
                   (SELECT 1
                      FROM internal_relationship_stage irs_int
                     WHERE irs_int.concept_code_1 = dc.concept_code AND irs_int.concept_code_2 = c2.concept_code);

COMMIT;

 --Packs to BN
INSERT /*+ APPEND */
      INTO  internal_relationship_stage
    SELECT l.concept_code_1, l.concept_code_2
      FROM (WITH t
                 AS (SELECT /*+ materialize*/
                           dc.concept_code AS concept_code_1,
                            c2.concept_code AS concept_code_2,
                            c2.concept_name AS concept_name_2,
                            c.concept_name AS concept_name_1
                       FROM drug_concept_stage dc
                            JOIN concept c ON c.concept_code = dc.concept_code AND c.vocabulary_id = 'RxNorm Extension' AND dc.concept_class_id = 'Drug Product' AND dc.concept_name LIKE '%Pack%[%]%'
                            JOIN concept_relationship cr ON c.concept_id = concept_id_1 AND cr.relationship_id = 'Has brand name' AND cr.invalid_reason IS NULL
                            JOIN concept c2 ON concept_id_2 = c2.concept_id AND c2.concept_class_id = 'Brand Name' AND c2.VOCABULARY_ID LIKE 'Rx%' AND c2.invalid_reason IS NULL)
            SELECT concept_code_1, concept_code_2
              FROM t
             WHERE concept_name_2 = REGEXP_REPLACE (concept_name_1, '.* Pack .*\[(.*)\]', '\1')) l
     WHERE NOT EXISTS
               (SELECT 1
                  FROM internal_relationship_stage irs_int
                 WHERE irs_int.concept_code_1 = l.concept_code_1 AND irs_int.concept_code_2 = l.concept_code_2);

COMMIT;

 --drug to ingredient
INSERT /*+ APPEND */
      INTO  internal_relationship_stage
    SELECT ds.drug_concept_code, ds.ingredient_concept_code
      FROM ds_stage ds
     WHERE NOT EXISTS
               (SELECT 1
                  FROM internal_relationship_stage irs_int
                 WHERE irs_int.concept_code_1 = ds.drug_concept_code AND irs_int.concept_code_2 = ds.ingredient_concept_code);

COMMIT;

--Drug Form to ingredient
INSERT /*+ APPEND */
      INTO  internal_relationship_stage
    SELECT c.concept_code, c2.concept_code
      FROM concept c
           JOIN drug_concept_stage dc ON dc.concept_code=c.concept_code AND c.vocabulary_id LIKE 'RxNorm%' AND c.invalid_reason IS NULL
           JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id AND cr.RELATIONSHIP_ID = 'RxNorm has ing' AND cr.invalid_reason IS NULL
           JOIN concept c2 ON c2.concept_id = cr.concept_id_2 AND c2.concept_class_id = 'Ingredient' AND c2.invalid_reason IS NULL
     WHERE     c.concept_class_id IN ('Clinical Drug Form', 'Branded Drug Form')
           AND NOT EXISTS
                   (SELECT 1
                      FROM internal_relationship_stage irs_int
                      JOIN drug_concept_stage dcs ON dcs.concept_code=irs_int.concept_code_2
                    WHERE irs_int.concept_code_1 = c.concept_code AND dcs.concept_class_id='Ingredient');

COMMIT;

INSERT /*+ APPEND */ 
      INTO internal_relationship_stage (concept_Code_1,concept_code_2)
    SELECT DISTINCT dc.concept_code,ds.ingredient_concept_code
      FROM concept c
           JOIN drug_concept_stage dc ON dc.concept_code = c.concept_code AND c.vocabulary_id LIKE 'RxNorm%'  AND c.invalid_reason IS NULL AND c.concept_class_id IN ('Clinical Drug Form', 'Branded Drug Form')
           JOIN concept_relationship cr ON concept_id_1 = c.concept_id AND cr.invalid_reason IS NULL
           JOIN concept c2 ON c2.concept_id = concept_id_2 AND c.vocabulary_id LIKE 'RxNorm%'AND c2.invalid_reason IS NULL
           JOIN ds_stage ds ON c2.concept_code = drug_concept_code
      WHERE NOT EXISTS 
                (SELECT 1
                   FROM internal_relationship_stage irs_int
                   JOIN drug_concept_stage dcs ON dcs.concept_code = irs_int.concept_code_2
                 WHERE irs_int.concept_code_1 = c.concept_code
                 AND   dcs.concept_class_id = 'Ingredient');

COMMIT;

--add all kinds of missing ingredients
DROP TABLE ing_temp;
CREATE TABLE ing_temp AS
       SELECT distinct  c.concept_code as concept_Code_1,c.concept_name as concept_name_1,c.concept_class_id as cci1, cr2.relationship_id,c2.concept_code,c2.concept_name , c2.concept_class_id
         FROM concept c
              JOIN drug_concept_stage dc ON dc.concept_code=c.concept_code AND c.vocabulary_id LIKE 'RxNorm%' AND c.invalid_reason IS NULL AND  dc.concept_class_id = 'Drug Product' AND dc.source_concept_class_id NOT LIKE  '%Pack%' AND dc.concept_name NOT LIKE '%Pack%'
              JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id AND cr.invalid_reason IS NULL
              JOIN concept_relationship cr2 ON cr2.concept_id_1 = cr.concept_id_2 AND cr2.invalid_reason IS NULL AND cr2.relationship_id IN ('Brand name of','RxNorm has ing')
              JOIN concept c2 ON c2.concept_id = cr2.concept_id_2 AND c2.concept_class_id = 'Ingredient' AND c2.invalid_reason IS NULL
         WHERE NOT EXISTS
                   (SELECT 1
                      FROM internal_relationship_stage irs_int
                      JOIN drug_concept_stage dcs ON dcs.concept_code=irs_int.concept_code_2
                    WHERE irs_int.concept_code_1 = c.concept_code AND dcs.concept_class_id='Ingredient')
                    AND UPPER(c.concept_name) like '%'||UPPER(c2.concept_name)||'%'; 

COMMIT;

--ing_temp_2
INSERT /*+ APPEND */
      INTO  internal_relationship_stage (concept_Code_1,concept_code_2)
    SELECT concept_code_1, concept_code
      --Aspirin / Aspirin / Caffeine Oral Tablet [Mipyrin]
      FROM ing_temp 
    WHERE concept_code_1 IN 
              (SELECT i.concept_code_1 
                 FROM ing_temp i 
                      JOIN (SELECT count (concept_code) OVER (PARTITION BY concept_Code_1) AS cnt,concept_code_1
                              FROM (SELECT distinct concept_code_1,concept_name_1,concept_code,concept_name 
                                      FROM ing_temp)
                            ORDER BY concept_Code) a 
                      ON i.concept_Code_1 = a.concept_Code_1 AND regexp_count(concept_name_1,' / ')+1!= a.cnt
              	      AND (concept_name_1 like '%...%' or REGEXP_REPLACE (REGEXP_SUBSTR(UPPER(concept_name_1),' / \w+(\s\w+)?'),' / ') LIKE '%'||UPPER(concept_name)||'%' AND  REGEXP_SUBSTR (UPPER(concept_name_1),'\w+(\s\w+)?') LIKE '%'||UPPER(concept_name)||'%'))
       UNION
     SELECT distinct i.concept_code_1, concept_code 
       FROM ing_temp i 
            JOIN (SELECT count(concept_code) over (partition by concept_Code_1) as cnt,concept_code_1
                    FROM (SELECT distinct concept_code_1,concept_name_1,concept_code,concept_name 
                            FROM ing_temp)
                  ORDER BY concept_Code) a 
	    ON i.concept_Code_1=a.concept_Code_1 
     WHERE regexp_count(concept_name_1,' / ')+1= a.cnt
;

COMMIT;

INSERT /*+ APPEND */
      INTO  internal_relationship_stage (concept_Code_1,concept_code_2)
    SELECT dc.concept_code,c2.concept_code
      FROM drug_concept_stage dc
           JOIN concept c ON dc.concept_code=c.concept_code AND c.vocabulary_id LIKE 'RxNorm%' AND c.invalid_reason IS NULL AND  dc.concept_class_id = 'Drug Product' AND dc.source_concept_class_id not like '%Pack%' AND dc.concept_name NOT LIKE '%Pack%'
           JOIN devv5.concept_ancestor ca ON descendant_concept_id=c.concept_id
           JOIN concept c2 ON ancestor_concept_id=c2.concept_id AND c2.concept_class_id='Ingredient'
    WHERE NOT EXISTS
                   (SELECT 1
                      FROM internal_relationship_stage irs_int
                           JOIN drug_concept_stage dcs ON dcs.concept_code=irs_int.concept_code_2
                    WHERE irs_int.concept_code_1 = c.concept_code AND dcs.concept_class_id='Ingredient')
    AND UPPER(c.concept_name) LIKE '%'||UPPER(c2.concept_name)||'%';
COMMIT;
INSERT INTO internal_relationship_stage(concept_code_1,concept_code_2)
 (SELECT concept_code,  '11384'
FROM drug_concept_stage
WHERE concept_name LIKE '%Yeasts%'
AND   concept_code NOT IN (SELECT concept_code_1
                           FROM internal_relationship_stage
                           WHERE concept_code_2 = '11384')
AND   concept_class_id = 'Drug Product');

COMMIT;

--Drug to supplier
INSERT /*+ APPEND */
      INTO  internal_relationship_stage
    SELECT dc.concept_code, c2.concept_code
      FROM drug_concept_stage dc
           JOIN concept c ON c.concept_code = dc.concept_code AND c.vocabulary_id = 'RxNorm Extension'
           JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id AND cr.invalid_reason IS NULL
           JOIN concept c2 ON concept_id_2 = c2.concept_id AND c2.concept_class_id = 'Supplier' AND c2.vocabulary_id LIKE 'Rx%' AND c2.invalid_reason IS NULL
     WHERE     dc.concept_class_id = 'Drug Product'
           AND NOT EXISTS
                   (SELECT 1
                      FROM internal_relationship_stage irs_int
                     WHERE irs_int.concept_code_1 = dc.concept_code AND irs_int.concept_code_2 = c2.concept_code);

COMMIT;

--insert relationships to those packs that do not have Pack's BN
INSERT /*+ APPEND */
      INTO  internal_relationship_stage
    SELECT c.concept_code, c3.concept_code
      FROM concept c
           LEFT JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id AND cr.relationship_id = 'Has brand name' AND cr.invalid_reason IS NULL
           LEFT JOIN concept c2 ON c2.concept_id = cr.concept_id_2 AND c2.concept_class_id = 'Brand Name'
           -- take it from name
           LEFT JOIN concept c3
               ON     c3.concept_name = REGEXP_REPLACE (c.concept_name, '.* Pack .*\[(.*)\]', '\1')
                  AND c3.vocabulary_id LIKE 'RxNorm%'
                  AND c3.concept_class_id = 'Brand Name'
                  AND c3.invalid_reason IS NULL
     WHERE     c.vocabulary_id = 'RxNorm Extension'
           AND c.concept_class_id LIKE '%Branded%Pack%'
           AND c2.concept_id IS NULL
           AND NOT EXISTS
                   (SELECT 1
                      FROM internal_relationship_stage irs_int
                     WHERE irs_int.concept_code_1 = c.concept_code AND irs_int.concept_code_2 = c3.concept_code);

COMMIT;

--add fresh concepts
INSERT /*+ APPEND */
      INTO  internal_relationship_stage
	  /*
	  we need DISTINCT because some concepts theoretically  might have one replacement concept
	  e.g. 
	  A some_relatonship_1 B
	  A some_relatonship_2 C
	  but B and C have 'Concept replaced by' on D
	  result: two rows A - D
	  */
    SELECT DISTINCT c1.concept_code, lf.concept_code
      FROM concept c1
           JOIN concept_relationship cr ON c1.concept_id = cr.concept_id_1 AND c1.vocabulary_id = 'RxNorm Extension' AND c1.invalid_reason IS NULL AND cr.relationship_id NOT IN ('Concept replaced by', 'Concept replaces')
           JOIN (SELECT CONNECT_BY_ROOT concept_id_1 AS root_concept_id_1, u.concept_id_2,concept_code
                   FROM (SELECT r.*,c2.concept_code
                           FROM concept_relationship r
                                JOIN concept c1 ON c1.concept_id = r.concept_id_1 AND c1.concept_class_id IN ('Dose Form', 'Brand Name', 'Supplier','Ingredient') AND c1.vocabulary_id LIKE 'Rx%'
                                JOIN concept c2 ON c2.concept_id = r.concept_id_2 AND c2.concept_class_id IN ('Dose Form', 'Brand Name', 'Supplier','Ingredient') AND c2.vocabulary_id LIKE 'Rx%'
                          WHERE r.relationship_id = 'Concept replaced by' AND r.invalid_reason IS NULL) u
                  WHERE CONNECT_BY_ISLEAF = 1
             CONNECT BY NOCYCLE PRIOR u.concept_id_2 = u.concept_id_1) lf
               ON lf.root_concept_id_1 = cr.concept_id_2
     WHERE c1.concept_code <> lf.concept_code --we don't want duplicates like A - A (A 'Mapped from' B, but B have 'Concept replaced by' A -> so we have A - A in IRS)
     AND NOT EXISTS
               (SELECT 1
                  FROM internal_relationship_stage irs_int
                 WHERE irs_int.concept_code_1 = c1.concept_code AND irs_int.concept_code_2 = lf.concept_code);

COMMIT;

--23 Add all the attributes which relationships are missing in basic tables (separate query to speed up)
INSERT /*+ APPEND */ INTO internal_relationship_stage
	--missing bn
	WITH t
		 AS (SELECT /*+ materialize */
				   dc.concept_code, c.concept_name
			   FROM drug_concept_stage dc JOIN concept c ON c.concept_code = dc.concept_code AND c.vocabulary_id = 'RxNorm Extension'
			  WHERE dc.concept_class_id = 'Drug Product' AND dc.concept_name LIKE '%Pack%[%]%')
	SELECT t.concept_code, dc2.concept_code
	  FROM t JOIN drug_concept_stage dc2 ON dc2.concept_name = REGEXP_REPLACE (t.concept_name, '.* Pack .*\[(.*)\]', '\1') 
	  AND dc2.concept_class_id = 'Brand Name'
	  --WHERE  t.concept_code NOT IN (SELECT concept_code_1 FROM internal_relationship_stage irs_int JOIN drug_concept_stage dcs_int ON dcs_int.concept_code=irs_int.concept_code_2 AND dcs_int.concept_class_id = 'Brand Name' );
      WHERE NOT EXISTS
               (SELECT 1
                  FROM internal_relationship_stage irs_int
                 WHERE irs_int.concept_code_1 = t.concept_code AND irs_int.concept_code_2 = dc2.concept_code);	  
COMMIT;

--24.1 Add missing suppliers
INSERT /*+ APPEND */ INTO  internal_relationship_stage
   WITH dc
        AS (SELECT /*+ materialize */
                  LOWER (concept_name) concept_name, concept_code
              FROM drug_concept_stage
             WHERE source_concept_class_id = 'Marketed Product')
   SELECT dc.concept_code, dc2.concept_code
     FROM dc JOIN drug_concept_stage dc2 ON dc.concept_name LIKE '% ' || LOWER (dc2.concept_name) AND dc2.concept_class_id = 'Supplier'
     --WHERE  dc.concept_code NOT IN (SELECT concept_code_1 FROM internal_relationship_stage irs_int JOIN drug_concept_stage dcs_int ON dcs_int.concept_code=irs_int.concept_code_2 AND dcs_int.concept_class_id = 'Brand Name');
     WHERE NOT EXISTS
               (SELECT 1
                  FROM internal_relationship_stage irs_int
                 WHERE irs_int.concept_code_1 = dc.concept_code AND irs_int.concept_code_2 = dc2.concept_code);	  	 
COMMIT;

--24.2 Fix suppliers like Baxter and Baxter ltd
DELETE FROM internal_relationship_stage
 WHERE (concept_code_1, concept_code_2) IN 
    (SELECT b2.concept_code_1, b2.concept_code_2
    FROM (  SELECT concept_code_1
            FROM internal_relationship_stage a JOIN drug_concept_stage b ON concept_code = concept_code_2
           WHERE b.concept_class_id = 'Supplier'
        GROUP BY concept_code_1, b.concept_class_id
          HAVING COUNT (1) > 1) a
       JOIN internal_relationship_stage b ON b.concept_code_1 = a.concept_code_1
       JOIN internal_relationship_stage b2 ON b2.concept_code_1 = b.concept_code_1 AND b.concept_code_2 != b2.concept_code_2
       JOIN drug_concept_stage c ON c.concept_code = b.concept_code_2 AND c.concept_class_id = 'Supplier'
       JOIN drug_concept_stage c2 ON c2.concept_code = b2.concept_code_2 AND c2.concept_class_id = 'Supplier'
    WHERE LENGTH (c.concept_name) < LENGTH (c2.concept_name));

COMMIT;

--24.3 Cromolyn Inhalation powder
INSERT INTO internal_relationship_stage (concept_code_1,concept_code_2) VALUES ('OMOP391197','317000');
INSERT INTO internal_relationship_stage (concept_code_1,concept_code_2) VALUES ('OMOP391198','317000');
INSERT INTO internal_relationship_stage (concept_code_1,concept_code_2) VALUES ('OMOP391199','317000');
INSERT INTO internal_relationship_stage (concept_code_1,concept_code_2) VALUES ('OMOP391019','317000');
INSERT INTO internal_relationship_stage (concept_code_1,concept_code_2) VALUES ('OMOP391020','317000');
	
--24.4 Manually add missing ingredients

INSERT INTO  internal_relationship_stage  (concept_code_1,concept_code_2) VALUES ('OMOP418619','10582');
INSERT INTO  internal_relationship_stage  (concept_code_1,concept_code_2) VALUES ('OMOP421053','854930');
INSERT INTO  internal_relationship_stage  (concept_code_1,concept_code_2) VALUES ('OMOP420104','7994');
INSERT INTO  internal_relationship_stage  (concept_code_1,concept_code_2) VALUES ('OMOP417742','6313');
INSERT INTO  internal_relationship_stage  (concept_code_1,concept_code_2) VALUES ('OMOP417551','5666');
INSERT INTO  internal_relationship_stage  (concept_code_1,concept_code_2) VALUES ('OMOP412170','4141');
INSERT INTO  internal_relationship_stage  (concept_code_1,concept_code_2) VALUES ('OMOP421199','105695');
INSERT INTO  internal_relationship_stage  (concept_code_1,concept_code_2) VALUES ('OMOP421200','105695');
INSERT INTO  internal_relationship_stage  (concept_code_1,concept_code_2) VALUES ('OMOP421053','854930');
INSERT INTO  internal_relationship_stage  (concept_code_1,concept_code_2) VALUES ('OMOP299955','5333');
INSERT INTO  internal_relationship_stage  (concept_code_1,concept_code_2) VALUES ('OMOP419715','3616');
	
--25 delete multiple relationships to attributes
--25.1 define concept_1, concept_2 pairs need to be deleted
DELETE FROM internal_relationship_stage
      WHERE (concept_code_1, concept_code_2) IN
                (SELECT concept_code_1, concept_code_2
                   FROM internal_relationship_stage a
                        JOIN drug_concept_stage b ON a.concept_code_2 = b.concept_code AND b.concept_class_id IN ('Supplier')
                        JOIN drug_concept_stage c ON c.concept_code = a.concept_code_1
                  WHERE     a.concept_code_1 IN (  SELECT a_int.concept_code_1
                                                     FROM internal_relationship_stage a_int JOIN drug_concept_stage b ON b.concept_code = a_int.concept_code_2
                                                    WHERE b.concept_class_id IN ('Supplier')
                                                 GROUP BY a_int.concept_code_1, b.concept_class_id
                                                   HAVING COUNT (1) > 1)
                        --Attribute is not a part of a name
                        AND (LOWER (c.concept_name) NOT LIKE '%' || LOWER (b.concept_name) || '%' OR REGEXP_SUBSTR (c.concept_name, 'Pack\s.*') NOT LIKE '%' || b.concept_name || '%'));
DELETE FROM internal_relationship_stage
      WHERE (concept_code_1, concept_code_2) IN
                (SELECT concept_code_1, concept_code_2
                   FROM internal_relationship_stage a
                        JOIN drug_concept_stage b ON a.concept_code_2 = b.concept_code AND b.concept_class_id IN ('Dose Form')
                        JOIN drug_concept_stage c ON c.concept_code = a.concept_code_1
                  WHERE     a.concept_code_1 IN (  SELECT a_int.concept_code_1
                                                     FROM internal_relationship_stage a_int JOIN drug_concept_stage b ON b.concept_code = a_int.concept_code_2
                                                    WHERE b.concept_class_id IN ('Dose Form')
                                                 GROUP BY a_int.concept_code_1, b.concept_class_id
                                                   HAVING COUNT (1) > 1)
                        --Attribute is not a part of a name
                        AND (LOWER (c.concept_name) NOT LIKE '%' || LOWER (b.concept_name) || '%' OR REGEXP_SUBSTR (c.concept_name, 'Pack\s.*') NOT LIKE '%' || b.concept_name || '%'));
DELETE FROM internal_relationship_stage
      WHERE (concept_code_1, concept_code_2) IN
                (SELECT concept_code_1, concept_code_2
                   FROM internal_relationship_stage a
                        JOIN drug_concept_stage b ON a.concept_code_2 = b.concept_code AND b.concept_class_id IN ('Brand Name')
                        JOIN drug_concept_stage c ON c.concept_code = a.concept_code_1
                  WHERE     a.concept_code_1 IN (  SELECT a_int.concept_code_1
                                                     FROM internal_relationship_stage a_int JOIN drug_concept_stage b ON b.concept_code = a_int.concept_code_2
                                                    WHERE b.concept_class_id IN ('Brand Name')
                                                 GROUP BY a_int.concept_code_1, b.concept_class_id
                                                   HAVING COUNT (1) > 1)
                        --Attribute is not a part of a name
                        AND (LOWER (c.concept_name) NOT LIKE '%' || LOWER (b.concept_name) || '%' OR REGEXP_SUBSTR (c.concept_name, 'Pack\s.*') NOT LIKE '%' || b.concept_name || '%'));

COMMIT;

--25.2 delete 2 brand names that don't fit the rule as the brand name of the pack looks like the brand name of component (e.g. [Risedronate] and [Risedronate EC])
DELETE FROM internal_relationship_stage
      WHERE     concept_code_1 IN ('OMOP572812',
                                   'OMOP573077',
                                   'OMOP573035',
                                   'OMOP573066',
                                   'OMOP573376')
            AND concept_code_2 IN ('OMOP571371', 'OMOP569970');

--25.3 delete precise ingredients
DELETE internal_relationship_stage
WHERE concept_code_2 in ('236340','1371041');

COMMIT;

--26 just take it from the pack_content
INSERT /*+ APPEND */ INTO pc_stage
(
  PACK_CONCEPT_CODE, 
  DRUG_CONCEPT_CODE,
  AMOUNT,
  BOX_SIZE
)
SELECT c.concept_code,
       c2.concept_code,
       pc.amount,
       pc.box_size
  FROM pack_content pc
       JOIN concept c ON c.concept_id = pc.pack_concept_id AND c.vocabulary_id = 'RxNorm Extension'
       JOIN concept c2 ON c2.concept_id = pc.drug_concept_id;
COMMIT;

--26.1 fix 2 equal components manualy
DELETE FROM pc_stage
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

UPDATE pc_stage
   SET AMOUNT = 12
WHERE PACK_CONCEPT_CODE = 'OMOP339633'
AND   DRUG_CONCEPT_CODE = '310463'
AND   AMOUNT = 7;

UPDATE pc_stage
   SET AMOUNT = 12
WHERE PACK_CONCEPT_CODE = 'OMOP339814'
AND   DRUG_CONCEPT_CODE = '310463'
AND   AMOUNT = 7;
COMMIT;

--27 insert missing packs (only those that have => 2 components) - take them from the source tables
--27.1 AMT
INSERT /*+ APPEND */ INTO pc_stage
(pack_concept_code,drug_concept_code,amount,box_size)
SELECT DISTINCT ac.concept_code,ac2.concept_code,pcs.amount,pcs.box_size
FROM dev_amt.pc_stage pcs
  JOIN concept c ON c.concept_code = pcs.pack_Concept_code AND c.vocabulary_id = 'AMT' AND c.invalid_reason IS NULL
  JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id   AND cr.relationship_id = 'Maps to'
  JOIN concept ac ON ac.concept_id = cr.concept_id_2 AND ac.vocabulary_id = 'RxNorm Extension' AND ac.invalid_Reason IS NULL
  JOIN concept c2 ON c2.concept_code = pcs.drug_concept_code AND c.vocabulary_id = 'AMT' AND c2.invalid_reason IS NULL
  JOIN concept_relationship cr2 ON cr2.concept_id_1 = c2.concept_id AND cr2.relationship_id = 'Maps to'
  JOIN concept ac2 ON ac2.concept_id = cr2.concept_id_2 AND ac2.vocabulary_id LIKE 'RxNorm%' AND ac2.invalid_Reason IS NULL
WHERE c.concept_id NOT IN (SELECT pack_concept_id FROM pack_content)
AND   c.concept_id IN (SELECT c.concept_id
                       FROM dev_amt.pc_stage pcs
                         JOIN concept c ON c.concept_code = pcs.pack_Concept_code AND c.vocabulary_id = 'AMT' AND c.invalid_reason IS NULL
                         JOIN concept_relationship cr  ON cr.concept_id_1 = c.concept_id AND cr.relationship_id = 'Maps to'
                         JOIN concept ac ON ac.concept_id = cr.concept_id_2 AND ac.vocabulary_id = 'RxNorm Extension' AND ac.invalid_Reason IS NULL
                         JOIN concept c2 ON c2.concept_code = pcs.drug_concept_code  AND c.vocabulary_id = 'AMT' AND c2.invalid_reason IS NULL
                         JOIN concept_relationship cr2 ON cr2.concept_id_1 = c2.concept_id AND cr2.relationship_id = 'Maps to'
                         JOIN concept ac2 ON ac2.concept_id = cr2.concept_id_2 AND ac2.vocabulary_id LIKE 'RxNorm%'
                       WHERE c.concept_id NOT IN (SELECT pack_concept_id FROM pack_content)
                       GROUP BY c.concept_id
                       HAVING COUNT(c.concept_id) > 1)
AND   ac.concept_code NOT IN (SELECT pack_concept_code FROM pc_stage);
COMMIT;

--27.2 AMIS
INSERT /*+ APPEND */ INTO pc_stage
(pack_concept_code,drug_concept_code,amount,box_size)
SELECT DISTINCT ac.concept_code,ac2.concept_code,pcs.amount,pcs.box_size
FROM dev_amis.pc_stage pcs
  JOIN concept c ON c.concept_code = pcs.pack_Concept_code AND c.vocabulary_id = 'AMIS' AND c.invalid_reason IS NULL
  JOIN concept_relationship cr    ON cr.concept_id_1 = c.concept_id   AND cr.relationship_id = 'Maps to'
  JOIN concept ac ON ac.concept_id = cr.concept_id_2 AND ac.vocabulary_id = 'RxNorm Extension' AND ac.invalid_Reason IS NULL
  JOIN concept c2 ON c2.concept_code = pcs.drug_concept_code AND c.vocabulary_id = 'AMIS' AND c2.invalid_reason IS NULL
  JOIN concept_relationship cr2 ON cr2.concept_id_1 = c2.concept_id AND cr2.relationship_id = 'Maps to'
  JOIN concept ac2 ON ac2.concept_id = cr2.concept_id_2 AND ac2.vocabulary_id LIKE 'RxNorm%' AND ac2.invalid_Reason IS NULL
WHERE c.concept_id NOT IN (SELECT pack_concept_id FROM pack_content)
AND   c.concept_id IN (SELECT c.concept_id
                       FROM dev_amis.pc_stage pcs
                         JOIN concept c ON c.concept_code = pcs.pack_Concept_code AND c.vocabulary_id = 'AMIS' AND c.invalid_reason IS NULL
                         JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id AND cr.relationship_id = 'Maps to'
                         JOIN concept ac  ON ac.concept_id = cr.concept_id_2 AND ac.vocabulary_id = 'RxNorm Extension' AND ac.invalid_Reason IS NULL
                         JOIN concept c2 ON c2.concept_code = pcs.drug_concept_code AND c.vocabulary_id = 'AMIS'
                         JOIN concept_relationship cr2 ON cr2.concept_id_1 = c2.concept_id AND cr2.relationship_id = 'Maps to'
                         JOIN concept ac2 ON ac2.concept_id = cr2.concept_id_2 AND ac2.vocabulary_id LIKE 'RxNorm%'
                       WHERE c.concept_id NOT IN (SELECT pack_concept_id FROM pack_content)
                       GROUP BY c.concept_id
                       HAVING COUNT(c.concept_id) > 1)
AND   ac.concept_code NOT IN (SELECT pack_concept_code FROM pc_stage);
COMMIT;

--27.3 BDPM
INSERT /*+ APPEND */ INTO pc_stage
(pack_concept_code,drug_concept_code,amount,box_size)
SELECT DISTINCT ac.concept_code,ac2.concept_code,pcs.amount,pcs.box_size
FROM dev_bdpm.pc_stage pcs
  JOIN concept c ON c.concept_code = pcs.pack_Concept_code AND c.vocabulary_id = 'BDPM' AND c.invalid_reason IS NULL
  JOIN concept_relationship cr    ON cr.concept_id_1 = c.concept_id   AND cr.relationship_id = 'Maps to'
  JOIN concept ac ON ac.concept_id = cr.concept_id_2 AND ac.vocabulary_id = 'RxNorm Extension' AND ac.invalid_Reason IS NULL
  JOIN concept c2 ON c2.concept_code = pcs.drug_concept_code AND c.vocabulary_id = 'BDPM' AND c2.invalid_reason IS NULL
  JOIN concept_relationship cr2 ON cr2.concept_id_1 = c2.concept_id AND cr2.relationship_id = 'Maps to'
  JOIN concept ac2 ON ac2.concept_id = cr2.concept_id_2 AND ac2.vocabulary_id LIKE 'RxNorm%' AND ac2.invalid_Reason IS NULL
WHERE c.concept_id NOT IN (SELECT pack_concept_id FROM pack_content)
AND   c.concept_id IN (SELECT c.concept_id
                       FROM dev_bdpm.pc_stage pcs
                         JOIN concept c ON c.concept_code = pcs.pack_Concept_code AND c.vocabulary_id = 'BDPM' AND c.invalid_reason IS NULL
                         JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id AND cr.relationship_id = 'Maps to'
                         JOIN concept ac  ON ac.concept_id = cr.concept_id_2 AND ac.vocabulary_id = 'RxNorm Extension' AND ac.invalid_Reason IS NULL
                         JOIN concept c2 ON c2.concept_code = pcs.drug_concept_code AND c.vocabulary_id = 'BDPM'
                         JOIN concept_relationship cr2 ON cr2.concept_id_1 = c2.concept_id AND cr2.relationship_id = 'Maps to'
                         JOIN concept ac2 ON ac2.concept_id = cr2.concept_id_2 AND ac2.vocabulary_id LIKE 'RxNorm%'
                       WHERE c.concept_id NOT IN (SELECT pack_concept_id FROM pack_content)
                       GROUP BY c.concept_id
                       HAVING COUNT(c.concept_id) > 1)
AND   ac.concept_code NOT IN (SELECT pack_concept_code FROM pc_stage);
COMMIT;

--27.4 dm+d
INSERT /*+ APPEND */ INTO pc_stage
(pack_concept_code,drug_concept_code,amount,box_size)
SELECT DISTINCT ac.concept_code,ac2.concept_code,pcs.amount,pcs.box_size
FROM dev_dmd.pc_stage pcs
  JOIN concept c ON c.concept_code = pcs.pack_Concept_code AND c.vocabulary_id = 'dm+d' AND c.invalid_reason IS NULL
  JOIN concept_relationship cr    ON cr.concept_id_1 = c.concept_id   AND cr.relationship_id = 'Maps to'
  JOIN concept ac ON ac.concept_id = cr.concept_id_2 AND ac.vocabulary_id = 'RxNorm Extension' AND ac.invalid_Reason IS NULL
  JOIN concept c2 ON c2.concept_code = pcs.drug_concept_code AND c.vocabulary_id = 'dm+d' AND c2.invalid_reason IS NULL
  JOIN concept_relationship cr2 ON cr2.concept_id_1 = c2.concept_id AND cr2.relationship_id = 'Maps to'
  JOIN concept ac2 ON ac2.concept_id = cr2.concept_id_2 AND ac2.vocabulary_id LIKE 'RxNorm%' AND ac2.invalid_Reason IS NULL
WHERE c.concept_id NOT IN (SELECT pack_concept_id FROM pack_content)
AND   c.concept_id IN (SELECT c.concept_id
                       FROM dev_dmd.pc_stage pcs
                         JOIN concept c ON c.concept_code = pcs.pack_Concept_code AND c.vocabulary_id = 'dm+d' AND c.invalid_reason IS NULL
                         JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id AND cr.relationship_id = 'Maps to'
                         JOIN concept ac  ON ac.concept_id = cr.concept_id_2 AND ac.vocabulary_id = 'RxNorm Extension' AND ac.invalid_Reason IS NULL
                         JOIN concept c2 ON c2.concept_code = pcs.drug_concept_code AND c.vocabulary_id = 'dm+d'
                         JOIN concept_relationship cr2 ON cr2.concept_id_1 = c2.concept_id AND cr2.relationship_id = 'Maps to'
                         JOIN concept ac2 ON ac2.concept_id = cr2.concept_id_2 AND ac2.vocabulary_id LIKE 'RxNorm%'
                       WHERE c.concept_id NOT IN (SELECT pack_concept_id FROM pack_content)
                       GROUP BY c.concept_id
                       HAVING COUNT(c.concept_id) > 1)
AND   ac.concept_code NOT IN (SELECT pack_concept_code FROM pc_stage);
COMMIT;

--28 fix inert ingredients in contraceptive packs
UPDATE pc_stage
   SET amount = 7
 WHERE (pack_concept_code, drug_concept_code) IN (SELECT p.pack_concept_code, p.drug_concept_code
                                                    FROM pc_stage p
                                                         JOIN drug_concept_stage d ON d.concept_code = p.drug_concept_code AND concept_name LIKE '%Inert%' AND p.amount = 21
                                                         JOIN pc_stage p2 ON p.pack_concept_code = p2.pack_concept_code AND p.drug_concept_code != p2.drug_concept_code AND p.amount = 21);
COMMIT;

--29 update Inert Ingredients / Inert Ingredients 1 MG Oral Tablet to Inert Ingredient Oral Tablet
UPDATE pc_stage
   SET drug_concept_code = '748796'
 WHERE drug_concept_code = 'OMOP285209';
COMMIT;

--30 fixing existing packs in order to remove duplicates
DELETE FROM pc_stage
WHERE pack_concept_code = 'OMOP420950'
AND   drug_concept_code = '310463'
AND   amount = 5;
DELETE FROM pc_stage
WHERE pack_concept_code = 'OMOP420969'
AND   drug_concept_code = '310463'
AND   amount = 7;
DELETE FROM pc_stage
WHERE pack_concept_code = 'OMOP420978'
AND   drug_concept_code = '392651'
AND   amount IS NULL;
DELETE FROM pc_stage
WHERE pack_concept_code = 'OMOP420978'
AND   drug_concept_code = '197662'
AND   amount IS NULL;
DELETE FROM pc_stage
WHERE pack_concept_code = 'OMOP902613'
AND   drug_concept_code = 'OMOP918399'
AND   amount = 7;
COMMIT;

UPDATE pc_stage
   SET amount = 12
WHERE pack_concept_code = 'OMOP420950'
AND   drug_concept_code = '310463'
AND   amount = 7;
UPDATE pc_stage
   SET amount = 12
WHERE pack_concept_code = 'OMOP420969'
AND   drug_concept_code = '310463'
AND   amount = 5;
UPDATE pc_stage
   SET amount = 12
WHERE pack_concept_code = 'OMOP902613'
AND   drug_concept_code = 'OMOP918399'
AND   amount = 5;

COMMIT;

--31.1 Create links to self 
INSERT /*+ APPEND */ INTO relationship_to_concept
(CONCEPT_CODE_1,VOCABULARY_ID_1,CONCEPT_ID_2,PRECEDENCE)
SELECT a.concept_code,a.VOCABULARY_ID,b.concept_id, 1
  FROM drug_concept_stage a JOIN concept b ON b.concept_code = a.concept_code AND b.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
 WHERE a.concept_class_id IN ('Dose Form','Brand Name', 'Supplier', 'Ingredient')
 AND  a.concept_code!='11384' -- remove dead RxNorm's 'Yeasts' in order to revive it in RxE
 ;
COMMIT;

--31.2 insert relationship to units
INSERT /*+ APPEND */ INTO relationship_to_concept (CONCEPT_CODE_1,VOCABULARY_ID_1,CONCEPT_ID_2,PRECEDENCE,CONVERSION_FACTOR)
SELECT a.concept_code,a.vocabulary_id,b.concept_id,1,1
  FROM drug_concept_stage a 
  JOIN concept b ON b.concept_code = a.concept_code AND b.vocabulary_id = 'UCUM'
 WHERE a.concept_class_id = 'Unit';
COMMIT;

--31.3 insert additional mapping that doesn't exist in concept
INSERT INTO relationship_to_concept (CONCEPT_CODE_1,VOCABULARY_ID_1,CONCEPT_ID_2,PRECEDENCE,CONVERSION_FACTOR)
VALUES('mL','Rxfix', 8576,2,1000);

INSERT INTO relationship_to_concept (CONCEPT_CODE_1,  VOCABULARY_ID_1,  CONCEPT_ID_2,  PRECEDENCE,  CONVERSION_FACTOR)
VALUES ('mg','Rxfix',8587,2,0.001);

--31.4 transform micrograms into milligrams
UPDATE RELATIONSHIP_TO_CONCEPT
   SET CONCEPT_ID_2 = 8576,
       CONVERSION_FACTOR = 0.001
WHERE CONCEPT_CODE_1 = 'ug'
AND   CONCEPT_ID_2 = 9655;
COMMIT;

--31.5 delete precise ingredients
DELETE relationship_to_concept
WHERE concept_code_1 in ('1371041','236340');