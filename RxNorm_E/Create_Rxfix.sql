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
--1 Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;


--2 Add new temporary vocabulary named Rxfix to the vocabulary table
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
             'Drug',
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
	 
--3 Update latest_update field to new date 
BEGIN
   DEVV5.VOCABULARY_PACK.SetLatestUpdate (pVocabularyName        => 'Rxfix',
                                          pVocabularyDate        => TRUNC(sysdate),
                                          pVocabularyVersion     => 'Rxfix '||sysdate,
                                          pVocabularyDevSchema   => 'DEV_RXE');
   DEVV5.VOCABULARY_PACK.SetLatestUpdate (pVocabularyName        => 'RxNorm Extension',
                                          pVocabularyDate        => TRUNC(sysdate),
                                          pVocabularyVersion     => 'RxNorm Extension '||sysdate,
                                          pVocabularyDevSchema   => 'DEV_RXE',
                                          pAppendVocabulary      => TRUE);            
END;
/
COMMIT;

--4 create input tables 
DROP TABLE DRUG_CONCEPT_STAGE PURGE; --temporary!!!!! later we should to move all drops to the end of this script (or cndv?)
DROP TABLE DS_STAGE PURGE;
DROP TABLE INTERNAL_RELATIONSHIP_STAGE PURGE;
DROP TABLE PC_STAGE PURGE;
DROP TABLE RELATIONSHIP_TO_CONCEPT PURGE;

--4.1 1st input table: DRUG_CONCEPT_STAGE
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

--4.2 2nd input table: DS_STAGE
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

--4.3 3rd input table: INTERNAL_RELATIONSHIP_STAGE
CREATE TABLE INTERNAL_RELATIONSHIP_STAGE
(
   CONCEPT_CODE_1     VARCHAR2(50),
   CONCEPT_CODE_2     VARCHAR2(50)
) NOLOGGING;

--4.4 4th input table: PC_STAGE
CREATE TABLE PC_STAGE
(
   PACK_CONCEPT_CODE  VARCHAR2(50),
   DRUG_CONCEPT_CODE  VARCHAR2(50),
   AMOUNT             NUMBER,
   BOX_SIZE           NUMBER
) NOLOGGING;

--4.5 5th input table: RELATIONSHIP_TO_CONCEPT
CREATE TABLE RELATIONSHIP_TO_CONCEPT
(
   CONCEPT_CODE_1     VARCHAR2(50),
   VOCABULARY_ID_1    VARCHAR2(20),
   CONCEPT_ID_2       NUMBER,
   PRECEDENCE         NUMBER,
   CONVERSION_FACTOR  FLOAT(126)
) NOLOGGING;


--5 Create Concepts
--5.1 Get products
INSERT /*+ APPEND */ INTO DRUG_CONCEPT_STAGE
(CONCEPT_NAME,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,POSSIBLE_EXCIPIENT,DOMAIN_ID,VALID_START_DATE,VALID_END_DATE,
  INVALID_REASON,SOURCE_CONCEPT_CLASS_ID)
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
         );
	 
COMMIT;

INSERT  INTO DRUG_CONCEPT_STAGE
(CONCEPT_NAME,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,POSSIBLE_EXCIPIENT,DOMAIN_ID,VALID_START_DATE,VALID_END_DATE,INVALID_REASON,SOURCE_CONCEPT_CLASS_ID)
--Get RxNorm pack components from RxNorm
SELECT c2.concept_name,'Rxfix','Drug Product',NULL,c2.concept_code,NULL, c2.domain_id, c2.valid_start_date,c2.valid_end_date,c2.invalid_reason,c2.concept_class_id
   FROM pack_content pc
       JOIN concept c ON c.concept_id = pc.pack_concept_id AND c.vocabulary_id = 'RxNorm Extension' 
       JOIN concept c2 ON c2.concept_id = pc.drug_concept_id AND c2.vocabulary_id = 'RxNorm' AND c2.invalid_reason IS NULL
UNION
SELECT c3.concept_name,'Rxfix','Drug Product',NULL,c3.concept_code,NULL, c3.domain_id, c3.valid_start_date,c3.valid_end_date,c3.invalid_reason,c3.concept_class_id
   FROM pack_content pc
       JOIN concept c ON c.concept_id = pc.pack_concept_id AND c.vocabulary_id = 'RxNorm Extension' 
       JOIN concept c2 ON c2.concept_id = pc.drug_concept_id AND c2.vocabulary_id = 'RxNorm' AND c2.invalid_reason = 'U'
       JOIN concept_relationship cr on cr.concept_id_1=c2.concept_id AND relationship_id='Concept replaced by'
       JOIN concept c3 ON c3.concept_id=concept_id_2 
UNION
SELECT c.concept_name,'Rxfix','Drug Product',NULL,c.concept_code,NULL, c.domain_id, c.valid_start_date,c.valid_end_date,c.invalid_reason,c.concept_class_id
   FROM concept c 
JOIN concept_relationship cr ON c.concept_id=cr.concept_id_1 
JOIN concept c2 ON c2.concept_id=concept_id_2
AND c2.vocabulary_id='RxNorm Extension' AND c2.concept_class_id LIKE '%Pack%'
WHERE relationship_id = 'Contained in'
and c.concept_code NOT IN (SELECT concept_code FROM drug_Concept_stage);

COMMIT;

--5.2 Get upgraded Dose Forms, Brand Names, Supplier
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

--5.3 Ingredients: Need to check what happens to deprecated
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

--5.4 Get ingredients from hierarchy
INSERT /*+ APPEND */
      INTO  DRUG_CONCEPT_STAGE (CONCEPT_NAME,VOCABULARY_ID,
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

--5.5 Get all Units
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
;
DELETE drug_concept_stage 
WHERE invalid_reason is not null;

COMMIT;

--6 filling drug_strength
--just turn drug_strength into ds_stage replacing concept_ids with concept_codes
INSERT /*+ APPEND */
      INTO  ds_stage (DRUG_CONCEPT_CODE,
            INGREDIENT_CONCEPT_CODE,BOX_SIZE,AMOUNT_VALUE,AMOUNT_UNIT,NUMERATOR_VALUE,NUMERATOR_UNIT,DENOMINATOR_VALUE,DENOMINATOR_UNIT)
   SELECT  drug_concept_code, ingredient_concept_code,box_size,amount_value,amount_unit,numerator_value,numerator_unit,denominator_value,denominator_unit 
     FROM (
            SELECT  c.concept_code as drug_concept_code, c2.concept_code as ingredient_concept_code,ds.box_size,amount_value,c3.concept_code AS amount_unit,ds.numerator_value AS numerator_value,c4.concept_code AS numerator_unit,
            ds.denominator_value,c5.concept_code AS denominator_unit 
              FROM concept c
                   JOIN drug_concept_stage dc on dc.concept_code=c.concept_code AND dc.concept_class_id='Drug Product'
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

--7 Build internal_relationship_stage 
--Drug to form
INSERT /*+ APPEND */
      INTO  internal_relationship_stage
    SELECT distinct dc.concept_code, c2.concept_code AS concept_code_2  
      FROM drug_concept_stage dc
           JOIN concept c ON c.concept_code = dc.concept_code AND c.vocabulary_id like 'RxNorm%' AND dc.concept_class_id = 'Drug Product'
           JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id AND cr.relationship_id = 'RxNorm has dose form' AND cr.invalid_reason IS NULL
           JOIN concept c2 ON c2.concept_id = cr.concept_id_2 AND c2.concept_class_id = 'Dose Form' AND c2.vocabulary_id LIKE 'Rx%' AND c2.invalid_reason IS NULL;
COMMIT;

 --Drug to BN
INSERT /*+ APPEND */
      INTO  internal_relationship_stage
    SELECT distinct dc.concept_code, c2.concept_code
      FROM drug_concept_stage dc
           JOIN concept c ON c.concept_code = dc.concept_code AND c.vocabulary_id like 'RxNorm%'
           JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id AND cr.relationship_id = 'Has brand name' AND cr.invalid_reason IS NULL
           JOIN concept c2
               ON     concept_id_2 = c2.concept_id
                  AND c2.concept_class_id = 'Brand Name'
                  AND c2.vocabulary_id LIKE 'Rx%'
                  AND c2.invalid_reason IS NULL
     WHERE     dc.concept_class_id = 'Drug Product'
           AND NOT EXISTS
                   (SELECT 1
                      FROM internal_relationship_stage irs_int
                     WHERE irs_int.concept_code_1 = dc.concept_code AND irs_int.concept_code_2 = c2.concept_code);
COMMIT;

 --drug to ingredient

INSERT /*+ APPEND */
      INTO  internal_relationship_stage (concept_Code_1,concept_code_2)
    SELECT distinct dc.concept_code,c2.concept_code
      FROM drug_concept_stage dc
           JOIN concept c ON dc.concept_code=c.concept_code AND c.vocabulary_id LIKE 'RxNorm%' AND c.invalid_reason IS NULL AND  dc.concept_class_id = 'Drug Product' AND dc.source_concept_class_id not like '%Pack%' AND dc.concept_name NOT LIKE '%} Pack%'
           JOIN drug_strength on drug_concept_id=c.concept_id
           JOIN concept c2 ON ingredient_concept_id=c2.concept_id AND c2.concept_class_id='Ingredient'
;

INSERT /*+ APPEND */
      INTO  internal_relationship_stage (concept_Code_1,concept_code_2)
    SELECT distinct dc.concept_code,c2.concept_code
      FROM drug_concept_stage dc
           JOIN concept c ON dc.concept_code=c.concept_code AND c.vocabulary_id LIKE 'RxNorm%' AND c.invalid_reason IS NULL AND  dc.concept_class_id = 'Drug Product' AND dc.source_concept_class_id not like '%Pack%' AND dc.concept_name NOT LIKE '%} Pack%'
           JOIN concept_ancestor ca ON descendant_concept_id=c.concept_id
           JOIN concept c2 ON ancestor_concept_id=c2.concept_id AND c2.concept_class_id='Ingredient'
    WHERE NOT EXISTS
                   (SELECT 1
                      FROM internal_relationship_stage irs_int
                           JOIN drug_concept_stage dcs ON dcs.concept_code=irs_int.concept_code_2
                    WHERE irs_int.concept_code_1 = dc.concept_code AND dcs.concept_class_id='Ingredient');
COMMIT;

--Drug to supplier
INSERT /*+ APPEND */
      INTO  internal_relationship_stage
    SELECT distinct dc.concept_code, c2.concept_code
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

--8 just take it from the pack_content
INSERT /*+ APPEND */ INTO pc_stage
(PACK_CONCEPT_CODE,  DRUG_CONCEPT_CODE,AMOUNT, BOX_SIZE)
SELECT c.concept_code, c2.concept_code,pc.amount, pc.box_size
  FROM pack_content pc
       JOIN concept c ON c.concept_id = pc.pack_concept_id AND c.vocabulary_id = 'RxNorm Extension'
       JOIN concept c2 ON c2.concept_id = pc.drug_concept_id;
COMMIT;


--9 Create links to self 
INSERT /*+ APPEND */ INTO relationship_to_concept
(CONCEPT_CODE_1,VOCABULARY_ID_1,CONCEPT_ID_2,PRECEDENCE)
SELECT a.concept_code,a.VOCABULARY_ID,b.concept_id, 1
  FROM drug_concept_stage a JOIN concept b ON b.concept_code = a.concept_code AND b.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
 WHERE a.concept_class_id IN ('Dose Form','Brand Name', 'Supplier', 'Ingredient') ;
COMMIT;

--9.2 insert relationship to units
INSERT /*+ APPEND */ INTO relationship_to_concept (CONCEPT_CODE_1,VOCABULARY_ID_1,CONCEPT_ID_2,PRECEDENCE,CONVERSION_FACTOR)
SELECT a.concept_code,a.vocabulary_id,b.concept_id,1,1
  FROM drug_concept_stage a 
  JOIN concept b ON b.concept_code = a.concept_code AND b.vocabulary_id = 'UCUM'
 WHERE a.concept_class_id = 'Unit';
COMMIT;

--10 Before Build_RxE
INSERT INTO vocabulary (vocabulary_id,vocabulary_name,vocabulary_concept_id)
VALUES ('RxO','RxO', 0);

UPDATE concept
   SET vocabulary_id = 'RxO'
WHERE vocabulary_id = 'RxNorm Extension';

UPDATE concept_relationship
   SET invalid_reason = 'D', valid_end_date = TRUNC(SYSDATE) -1
WHERE concept_id_1 IN (SELECT concept_id_1
                       FROM concept_relationship
                         JOIN concept ON concept_id_1 = concept_id AND vocabulary_id = 'RxO');
UPDATE concept_relationship
   SET invalid_reason = 'D', valid_end_date = TRUNC(SYSDATE) -1
WHERE concept_id_2 IN (SELECT concept_id_2
                       FROM concept_relationship
                         JOIN concept ON concept_id_2 = concept_id AND vocabulary_id = 'RxO');


--11 Creating manual table with concept_code_1 representing attribute (Brand Name,Supplier, Dose Form)
that you want to replace by another already existing one (concept_code_2)
insert into concept_relationship_stage
(CONCEPT_CODE_1,CONCEPT_CODE_2,VOCABULARY_ID_1,VOCABULARY_ID_2,RELATIONSHIP_ID,VALID_START_DATE,VALID_END_DATE)
select concept_code_1,concept_code_2,'Rxfix','Rxfix','Concept replaced by',trunc(sysdate),TO_DATE('2099/12/31', 'yyyy/mm/dd')
from suppliers_to_repl
where concept_code_1 in 
(select concept_code from drug_concept_stage)
and concept_code_2 in 
(select concept_code from drug_concept_stage);

COMMIT;
