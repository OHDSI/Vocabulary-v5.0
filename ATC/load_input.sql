/**************************************************************************
* Copyright 2016 Observational Health Data Sciences AND Informatics (OHDSI)
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may NOT use this file except IN compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to IN writing, software
* distributed under the License is distributed ON an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*
* Authors: Anna Ostropolets, Polina Talapova
* Date: Jul 2021
**************************************************************************/
-- in ATC we do not use ds_stage AND pc_stage
DROP TABLE IF EXISTS drug_concept_stage CASCADE;
DROP TABLE IF EXISTS internal_relationship_stage;
DROP TABLE IF EXISTS relationship_to_concept CASCADE;;

CREATE TABLE drug_concept_stage 
( concept_name    VARCHAR(255),
 vocabulary_id    VARCHAR(20),
 concept_class_id   VARCHAR(20),
 standard_concept   VARCHAR(1),
 concept_code    VARCHAR(50),
 possible_excipient  VARCHAR(1),
 domain_id     VARCHAR(20),
 valid_start_date   DATE,
 valid_end_date   DATE,
 invalid_reason   VARCHAR(1),
 source_concept_class_id VARCHAR(20));

CREATE TABLE internal_relationship_stage 
( concept_code_1 VARCHAR(50),
 concept_code_2 VARCHAR(50));

CREATE TABLE relationship_to_concept 
( concept_code_1  VARCHAR(50),
 vocabulary_id_1  VARCHAR(20),
 concept_id_2  INT,
 precedence   INT,
 conversion_factor FLOAT);

--create indexes AND constraints
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
CREATE UNIQUE INDEX dcs_unique_concept_code 
 ON drug_concept_stage (concept_code);
CREATE INDEX irs_unique_concept_code 
 ON internal_relationship_stage (concept_code_1, concept_code_2);
/*************************************
***** internal_relationship_stage ****
**************************************/
-- increase the LENGTH for concept_code_1 AND concept_code_2 fields to infinity
ALTER TABLE internal_relationship_stage ALTER COLUMN concept_code_1 TYPE VARCHAR;
ALTER TABLE internal_relationship_stage ALTER COLUMN concept_code_2 TYPE VARCHAR;
-----------------------
-- oral formulations --
------------------------
-- create a temporary table WITH all related RxN/RxE Dose Forms
DROP TABLE if exists dev_oral;
CREATE TABLE dev_oral 
AS
(SELECT DISTINCT d.*
FROM concept_relationship r
 JOIN concept c ON c.concept_Id = r.concept_id_1
 JOIN concept d
 ON d.concept_id = r.concept_id_2
 AND d.invalid_reason IS NULL
 AND d.concept_class_id = 'Dose Form'
WHERE concept_id_1 = 36217214 -- 	Oral Product (Dose Form Group)
AND relationship_id = 'RxNorm inverse is a'
AND d.concept_name !~* 'sublingual'); -- will be processed separately

-- add links between Oral ATC Drug Classes AND RxN/RxE Dose Forms into the internal_relationship_stage 
INSERT INTO internal_relationship_stage
(concept_code_1, concept_code_2)
SELECT DISTINCT 
a.concept_code|| ' ' ||b.concept_name AS concept_code_1, -- ATC code + Dose Form name AS a code
  b.concept_name AS concept_code_2 -- OMOP Dose Form name treated AS a code
FROM concept_manual a,
  dev_oral b 
WHERE a.concept_name ~* 'oral|systemic|chewing gum' -- respective ATC dose forms (preliminarily converted from adm_r and added to the names in concept_manual)
AND a.invalid_reason IS NULL
AND a.concept_class_id = 'ATC 5th'; -- indicates alive ATC code

-- add links between Oral ATC Drug Classes AND Standard Ingredients using the concept table
INSERT INTO internal_relationship_stage
(concept_code_1, concept_code_2)
WITH t1
AS
(SELECT DISTINCT a.concept_code|| ' ' ||b.concept_name AS concept_code_1, -- ATC code + Dose Form name AS a code
  a.concept_name -- ATC name to be used AS a key for JOIN 
FROM concept_manual a,
  dev_oral b 
WHERE a.concept_name ~* 'oral|systemic|chewing gum'
AND a.invalid_reason IS NULL
)
 SELECT DISTINCT a.concept_code_1, -- ATC code + Dose Form name AS a code
  c.concept_name AS concept_code_2 -- Standard Ingredient name treated AS a code
 FROM t1 a 
 JOIN concept c ON UPPER(c.concept_name) = UPPER(TRIM(REGEXP_REPLACE(a.concept_name,';.*$',''))) -- remove all unnecessary information after the semicolon
 AND c.standard_concept = 'S'
 AND c.concept_class_id = 'Ingredient'
 AND c.invalid_reason IS NULL
WHERE (concept_code_1, c.concept_name) not in (SELECT concept_code_1, concept_code_2 FROM internal_relationship_stage);

-- add links between Oral ATC Drug Classes AND Standard Ingredients using the concept_synonym table
INSERT INTO internal_relationship_stage
(concept_code_1, concept_code_2)
WITH t1
AS
(SELECT DISTINCT a.concept_code|| ' ' ||b.concept_name AS concept_code_1, -- ATC code + Dose Form name AS a code
  a.concept_name -- ATC name to be used AS a key for JOIN 
FROM concept_manual a,
  dev_oral b 
WHERE a.concept_name ~* 'oral|systemic|chewing gum'
AND a.invalid_reason IS NULL
) 
 SELECT DISTINCT a.concept_code_1, -- ATC code + Dose Form name AS a code
  c.concept_name AS concept_code_2 -- Standard Ingredient name AS a code
 FROM t1 a
 JOIN concept_synonym b ON UPPER(b.concept_synonym_name) = upper(TRIM(REGEXP_REPLACE(a.concept_name, ';.*$', '')))
 JOIN concept c
 ON c.concept_id = b.concept_id
 AND c.standard_concept = 'S'
 AND c.concept_class_id = 'Ingredient'
 AND c.invalid_reason IS NULL 
WHERE (concept_code_1, c.concept_name) not in (SELECT concept_code_1, concept_code_2 FROM internal_relationship_stage);
-----------------------------
-- sublingual formulations --
-----------------------------
-- create a temporary table WITH all related RxN/RxE Dose Forms
DROP TABLE if exists dev_sub;
CREATE TABLE dev_sub 
AS
(SELECT DISTINCT d.*
FROM concept_relationship r
 JOIN concept c ON c.concept_Id = r.concept_id_1
 JOIN concept d
 ON d.concept_id = r.concept_id_2
 AND d.invalid_reason IS NULL
 AND d.concept_class_id = 'Dose Form'
WHERE concept_id_1 = 36217214
AND relationship_id = 'RxNorm inverse is a'
AND d.concept_name ~* 'sublingual'); -- should be separated FROM oral forms in the ATC vocabulary.

-- add links between Sublingual ATC Drug Classes and Rx Dose Forms
INSERT INTO internal_relationship_stage
(concept_code_1, concept_code_2)
SELECT DISTINCT a.concept_code|| ' ' ||b.concept_name AS concept_code_1, -- ATC code + Dose Form name AS a code
  b.concept_name -- OMOP Dose Form name treated AS a code   
FROM concept_manual a,
  dev_sub b 
WHERE a.concept_name ~* 'sublingual'
AND a.invalid_reason IS NULL
AND a.concept_class_id = 'ATC 5th'; -- 507

-- add links between Sublingual ATC Drug Classes AND Standard Ingredients using the concept table
INSERT INTO internal_relationship_stage
(concept_code_1, concept_code_2)
WITH t1
AS
(SELECT DISTINCT a.concept_code|| ' ' ||b.concept_name AS concept_code_1, -- ATC code + Dose Form name AS a code
  a.concept_name -- ATC name to be used AS a key for JOIN 
FROM concept_manual a,
  dev_sub b 
WHERE a.concept_name ~* 'sublingual'
AND a.invalid_reason IS NULL
)
SELECT DISTINCT a.concept_code_1, -- ATC code + Dose Form name AS a code
  c.concept_name AS concept_code_2
FROM t1 a
JOIN concept c ON UPPER(c.concept_name) = UPPER(TRIM(REGEXP_REPLACE(a.concept_name,';.*$','')))
 AND c.standard_concept = 'S'
 AND c.concept_class_id = 'Ingredient'
 AND c.invalid_reason IS NULL
WHERE (concept_code_1, c.concept_name) not in (SELECT concept_code_1, concept_code_2 FROM internal_relationship_stage);

-- add links between Sublingual ATC Drug Classes AND Standard Ingredients using the concept_synonym table
INSERT INTO internal_relationship_stage
(concept_code_1, concept_code_2)
WITH t1
AS
(SELECT DISTINCT a.concept_code|| ' ' ||b.concept_name AS concept_code_1, -- ATC code + Dose Form name AS a code
  a.concept_name -- ATC name to be used AS a key for JOIN 
FROM concept_manual a,
  dev_sub b 
WHERE a.concept_name ~* 'sublingual'
AND a.invalid_reason IS NULL
)
SELECT DISTINCT a.concept_code_1, -- ATC code + Dose Form name AS a code
  c.concept_name AS concept_code_2 -- Standard Ingredient name AS a code
FROM t1 a
 JOIN concept_synonym b ON UPPER(b.concept_synonym_name) = UPPER(TRIM(REGEXP_REPLACE(a.concept_name,';.*$','')))
 JOIN concept c
 ON c.concept_id = b.concept_id
 AND c.standard_concept = 'S'
 AND c.concept_class_id = 'Ingredient'
 AND c.invalid_reason IS NULL
 WHERE (concept_code_1, c.concept_name) not in (SELECT concept_code_1, concept_code_2 FROM internal_relationship_stage);
-----------------------------
-- parenteral formulations --
-----------------------------
-- create a temporary table WITH all related RxN/RxE Dose Forms
DROP TABLE if exists dev_parenteral;
CREATE TABLE dev_parenteral 
AS
(SELECT DISTINCT d.*
FROM concept_relationship r
 JOIN concept c ON c.concept_Id = r.concept_id_1
 JOIN concept d
 ON d.concept_id = r.concept_id_2
 AND d.invalid_reason IS NULL
 AND d.concept_class_id = 'Dose Form'
WHERE concept_id_1 = 36217210 -- Injectable Product
AND relationship_id = 'RxNorm inverse is a'); -- returns all children of Injectable Product

-- add links between Injectable ATC Drug Classes AND Rx Dose Forms
INSERT INTO internal_relationship_stage
(concept_code_1, concept_code_2)
SELECT DISTINCT a.concept_code|| ' ' ||b.concept_name AS concept_code_1, -- ATC code + Dose Form name AS a code
  b.concept_name -- OMOP Dose Form name treated AS a code 
FROM concept_manual a,
  dev_parenteral b 
WHERE a.concept_name ~* 'parenteral|systemic' -- respective ATC routes
AND a.invalid_reason IS NULL
AND a.concept_class_id = 'ATC 5th';

-- add links between Parenteral ATC Drug Classes AND Standard Ingredients using the concept table
INSERT INTO internal_relationship_stage
(concept_code_1, concept_code_2)
WITH t1
AS
(SELECT DISTINCT a.concept_code|| ' ' ||b.concept_name AS concept_code_1, -- ATC code + Dose Form name AS a code
  a.concept_name -- ATC name to be used AS a key for JOIN 
FROM concept_manual a,
  dev_parenteral b 
WHERE a.concept_name ~* 'parenteral|systemic'
AND a.invalid_reason IS NULL
) 
SELECT DISTINCT a.concept_code_1, -- ATC code + Dose Form name AS a code
  c.concept_name AS concept_code_2 -- Standard Ingredient name AS a code
FROM t1 a
 JOIN concept c
 ON UPPER(c.concept_name) = UPPER(TRIM(REGEXP_REPLACE(a.concept_name,';.*$','')))
 AND c.standard_concept = 'S'
 AND c.concept_class_id = 'Ingredient'
 AND c.invalid_reason IS NULL
WHERE (concept_code_1, c.concept_name) NOT IN (SELECT concept_code_1, concept_code_2 FROM internal_relationship_stage);

-- add links between Parenteral ATC Drug Classes AND Ingredients using the concept_synonym table
INSERT INTO internal_relationship_stage
(concept_code_1, concept_code_2)
WITH t1
AS
(SELECT DISTINCT a.concept_code|| ' ' ||b.concept_name AS concept_code_1, -- ATC code + Dose Form name AS a code
  a.concept_name -- ATC name to be used AS a key for JOIN 
FROM concept_manual a,
  dev_parenteral b 
WHERE a.concept_name ~* 'parenteral|systemic'
AND a.invalid_reason IS NULL
 ) 
SELECT DISTINCT a.concept_code_1, -- ATC code + Dose Form name AS a code
  c.concept_name AS concept_code_2 -- Standard Ingredient name AS a code
FROM t1 a
 JOIN concept_synonym b ON UPPER (b.concept_synonym_name) = UPPER(TRIM(REGEXP_REPLACE(a.concept_name,';.*$','')))
 JOIN concept c
 ON c.concept_id = b.concept_id
 AND c.standard_concept = 'S'
 AND c.concept_class_id = 'Ingredient'
 AND c.invalid_reason IS NULL
 WHERE (concept_code_1, c.concept_name) not in (SELECT concept_code_1, concept_code_2 FROM internal_relationship_stage); 
------------------------
-- nasal formulations --
------------------------
-- create a temporary table WITH all related RxN/RxE Dose Forms
DROP TABLE if exists dev_nasal;
CREATE TABLE dev_nasal 
AS
(SELECT DISTINCT d.*
FROM concept_relationship r
 JOIN concept c ON c.concept_Id = r.concept_id_1
 JOIN concept d
 ON d.concept_id = r.concept_id_2
 AND d.invalid_reason IS NULL
 AND d.concept_class_id = 'Dose Form'
WHERE concept_id_1 = 36217213 -- Nasal Product
AND relationship_id = 'RxNorm inverse is a'); -- returns all children of Nasal Product

-- add those which are out of ancestry (Nasal Pin)
INSERT INTO dev_nasal
SELECT * FROM concept WHERE concept_id = 43563498;

-- add links between Nasal ATC Drug Classes AND Rx Dose Forms
INSERT INTO internal_relationship_stage
(concept_code_1, concept_code_2)
SELECT DISTINCT a.concept_code|| ' ' ||b.concept_name AS concept_code_1, -- ATC code + Dose Form name AS a code
  b.concept_name -- OMOP Dose Form name treated AS a code
FROM concept_manual a,
  dev_nasal b 
WHERE a.concept_name ~* 'nasal'
AND a.invalid_reason IS NULL
AND a.concept_class_id = 'ATC 5th';

-- add links between Nasal ATC Drug Classes AND Standars Ingredients using the concept table
INSERT INTO internal_relationship_stage
(concept_code_1, concept_code_2)
WITH t1
AS
(SELECT DISTINCT a.concept_code|| ' ' ||b.concept_name AS concept_code_1, -- ATC code + Dose Form name AS a code
  a.concept_name -- ATC name to be used AS a key for JOIN 
FROM concept_manual a,
  dev_nasal b 
WHERE a.concept_name ~* 'nasal'
AND a.invalid_reason IS NULL
) 
 SELECT DISTINCT a.concept_code_1, -- ATC code + Dose Form name AS a code
  c.concept_name AS concept_code_2 -- Standard Ingredient name AS a code
FROM t1 a
 JOIN concept c ON UPPER(c.concept_name) = UPPER(TRIM(REGEXP_REPLACE(a.concept_name,';.*$','')))
 AND c.standard_concept = 'S'
 AND c.concept_class_id = 'Ingredient'
 AND c.invalid_reason IS NULL
 WHERE (concept_code_1, c.concept_name) not in (SELECT concept_code_1, concept_code_2 FROM internal_relationship_stage);

-- add links between Nasal ATC Drug Classes AND Standars Ingredients using the concept_synonym table
INSERT INTO internal_relationship_stage
(concept_code_1, concept_code_2)
WITH t1
AS
(SELECT DISTINCT a.concept_code|| ' ' ||b.concept_name AS concept_code_1, -- ATC code + Dose Form name AS a code
  a.concept_name -- ATC name to be used AS a key for JOIN 
FROM concept_manual a,
  dev_nasal b 
WHERE a.concept_name ~* 'nasal'
AND a.invalid_reason IS NULL
) 
 SELECT DISTINCT a.concept_code_1, -- ATC code + Dose Form name AS a code
  c.concept_name AS concept_code_2 -- Standard Ingredient name AS a code
FROM t1 a
 JOIN concept_synonym b ON UPPER (b.concept_synonym_name) = UPPER(TRIM(REGEXP_REPLACE(a.concept_name,';.*$','')))
 JOIN concept c
 ON c.concept_id = b.concept_id
 AND c.standard_concept = 'S'
 AND c.concept_class_id = 'Ingredient'
 AND c.invalid_reason IS NULL
WHERE (concept_code_1, c.concept_name) not in (SELECT concept_code_1, concept_code_2 FROM internal_relationship_stage);
--------------------------
-- topical formulations --
--------------------------
-- create a temporary table WITH all related RxN/RxE Dose Forms
DROP TABLE IF EXISTS dev_topic;
CREATE TABLE dev_topic 
AS
(SELECT DISTINCT d.*
FROM concept_relationship r
 JOIN concept c ON c.concept_Id = r.concept_id_1
 JOIN concept d
 ON d.concept_id = r.concept_id_2
 AND d.invalid_reason IS NULL
 AND d.concept_class_id = 'Dose Form'
WHERE concept_id_1 IN (
  36217206,36244040,36244034,36217219,-- Topical Product|Soap Product|Shampoo Product|Drug Implant Product
  36217223,36217212,36217224) -- Paste Product|Mucosal Product|Prefilled Applicator Product
AND relationship_id = 'RxNorm inverse is a'); -- returns all children of Topical Product

-- add those which are out of Dose Form ancestry
INSERT INTO dev_topic
SELECT * FROM concept WHERE concept_id IN (43126087); -- Medicated Nail Polish

-- add links between 1) genuine Topical ATC Drug Classes AND Rx Dose Forms
INSERT INTO internal_relationship_stage
(concept_code_1, concept_code_2)
SELECT DISTINCT a.concept_code|| ' ' ||b.concept_name AS concept_code_1, -- ATC code + Dose Form name AS a code
  b.concept_name -- OMOP Dose Form name treated AS a code 
FROM concept_manual a,
  dev_topic b 
WHERE a.concept_name ~* 'topical'
AND a.invalid_reason IS NULL
AND a.concept_class_id = 'ATC 5th'; -- exclude transdermal systems

-- add links between 2) Transdermal or Implantable ATC Drug Classes AND Rx Dose Forms
INSERT INTO internal_relationship_stage
(concept_code_1, concept_code_2)
SELECT DISTINCT a.concept_code|| ' ' ||b.concept_name AS concept_code_1, -- ATC code + Dose Form name AS a code
  b.concept_name AS concept_code_2 -- OMOP Dose Form name treated AS a code  
FROM concept_manual a,
  dev_topic b 
WHERE a.concept_name ~* 'topical'
AND a.invalid_reason IS NULL;

-- add links between Topical ATC Drug Classes AND Standard Ingredients using the concept table
INSERT INTO internal_relationship_stage
(concept_code_1, concept_code_2)
WITH t1
AS
(SELECT DISTINCT a.concept_code|| ' ' ||b.concept_name AS concept_code_1, -- ATC code + Dose Form name AS a code
  a.concept_name -- ATC name to be used AS a key for JOIN 
FROM concept_manual a,
  dev_topic b 
WHERE a.concept_name ~* 'topical'
AND a.invalid_reason IS NULL
) -- respective ATC routes
SELECT DISTINCT a.concept_code_1, -- ATC code + Dose Form name AS a code
  c.concept_name AS concept_code_2 -- Ingredient name AS a code
FROM t1 a
 JOIN concept c ON UPPER(c.concept_name) = UPPER(TRIM(REGEXP_REPLACE(a.concept_name,';.*$','')))
 AND c.standard_concept = 'S'
 AND c.concept_class_id = 'Ingredient'
 AND c.invalid_reason IS NULL
 WHERE (concept_code_1, c.concept_name) not in (SELECT concept_code_1, concept_code_2 FROM internal_relationship_stage);

-- add links between Topical ATC Drug Classes AND Standard Ingredients using the concept_synonym table 
INSERT INTO internal_relationship_stage
(concept_code_1, concept_code_2)
WITH t1
AS
(SELECT DISTINCT a.concept_code|| ' ' ||b.concept_name AS concept_code_1, -- ATC code + Dose Form name AS a code
  a.concept_name -- ATC name to be used AS a key for JOIN 
FROM concept_manual a,
  dev_topic b 
WHERE a.concept_name ~* 'topical'
AND a.invalid_reason IS NULL
)
SELECT DISTINCT a.concept_code_1, -- ATC code + Dose Form name AS a code
  c.concept_name AS concept_code_2 -- Standard Ingredient name AS a code
FROM t1 a
 JOIN concept_synonym b ON UPPER (b.concept_synonym_name) = UPPER(TRIM(REGEXP_REPLACE(a.concept_name,';.*$','')))
 JOIN concept c
 ON c.concept_id = b.concept_id
 AND c.standard_concept = 'S'
 AND c.concept_class_id = 'Ingredient'
 AND c.invalid_reason IS NULL
WHERE (concept_code_1, c.concept_name) not in (SELECT concept_code_1, concept_code_2 FROM internal_relationship_stage);

-- add links between Transdermal or Implantable ATC Drug Classes AND Standard Ingredients using the concept table 
INSERT INTO internal_relationship_stage
(concept_code_1, concept_code_2)
WITH t1
AS
(SELECT DISTINCT a.concept_code|| ' ' ||b.concept_name AS concept_code_1, -- ATC code + Dose Form name AS a code
  a.concept_name -- ATC name to be used AS a key for JOIN 
FROM concept_manual a,
  dev_topic b 
WHERE a.concept_name ~* 'transdermal|implant' -- respective ATC routes
AND a.invalid_reason IS NULL
) 
SELECT DISTINCT a.concept_code_1, -- ATC code + Dose Form name AS a code
  c.concept_name AS concept_code_2-- Standard Ingredient name AS a code
FROM t1 a
 JOIN concept c ON UPPER(c.concept_name) = UPPER(TRIM(REGEXP_REPLACE(a.concept_name,';.*$','')))
 AND c.standard_concept = 'S'
 AND c.concept_class_id = 'Ingredient'
 AND c.invalid_reason IS NULL
 WHERE (concept_code_1, c.concept_name) not in (SELECT concept_code_1, concept_code_2 FROM internal_relationship_stage);
 
-- add links between Transdermal or Implantable ATC Drug Classes AND Standard Ingredients using the concept_synonym table 
INSERT INTO internal_relationship_stage
(concept_code_1, concept_code_2)
WITH t1
AS
(SELECT DISTINCT a.concept_code|| ' ' ||b.concept_name AS concept_code_1, -- ATC code + Dose Form name AS a code
  a.concept_name -- ATC name to be used AS a key for JOIN 
FROM concept_manual a,
  dev_topic b 
WHERE a.concept_name ~* 'transdermal|implant' -- respective ATC routes
AND a.invalid_reason IS NULL
)
SELECT DISTINCT a.concept_code_1, -- ATC code + Dose Form name AS a code
  c.concept_name AS concept_code_2 -- Standard Ingredient name AS a code
FROM t1 a
 JOIN concept_synonym b ON UPPER (b.concept_synonym_name) = UPPER(TRIM(REGEXP_REPLACE(a.concept_name,';.*$','')))
 JOIN concept c
 ON c.concept_id = b.concept_id
 AND c.standard_concept = 'S'
 AND c.concept_class_id = 'Ingredient'
 AND c.invalid_reason IS NULL
WHERE (concept_code_1, c.concept_name) not in (SELECT concept_code_1, concept_code_2 FROM internal_relationship_stage);
-----------------------------
-- mouthwash formulations --
-----------------------------
-- create a temporary table WITH all related RxN/RxE Dose Forms
DROP TABLE if exists dev_mouth;
CREATE TABLE dev_mouth 
AS
(SELECT DISTINCT d.*
FROM concept_relationship r
 JOIN concept c ON c.concept_Id = r.concept_id_1
 JOIN concept d
 ON d.concept_id = r.concept_id_2
 AND d.invalid_reason IS NULL
 AND d.concept_class_id = 'Dose Form'
WHERE concept_id_1 = 36244022 -- 	Mouthwash Product (Dose Form Group)
AND relationship_id = 'RxNorm inverse is a'
AND d.concept_name ~* 'mouthwash');

-- add links between Local Oral ATC Drug Classes AND Rx Mouthwash formulations
INSERT INTO internal_relationship_stage
(concept_code_1, concept_code_2)
SELECT DISTINCT a.concept_code|| ' ' ||b.concept_name AS concept_code_1, -- ATC code + Dose Form name AS a code
  b.concept_name -- OMOP Dose Form name treated AS a code
FROM concept_manual a,
  dev_mouth b 
WHERE a.concept_name ~* 'local oral' -- respective ATC route
AND a.invalid_reason IS NULL
AND a.concept_class_id = 'ATC 5th'; -- 21

-- add links between Local Oral ATC Drug Classes AND Ingredients using the concept table (up to date no need to use tne concept_synonym but you may check)
INSERT INTO internal_relationship_stage
(concept_code_1, concept_code_2)
WITH t1
AS
(SELECT DISTINCT a.concept_code|| ' ' ||b.concept_name AS concept_code_1, -- ATC code + Dose Form name AS a code
  a.concept_name -- ATC name to be used AS a key for JOIN
FROM concept_manual a,
  dev_mouth b 
WHERE a.concept_name ~* 'local oral' -- respective ATC routes
AND a.invalid_reason IS NULL
)
SELECT DISTINCT a.concept_code_1, -- ATC code + Dose Form name AS a code
  c.concept_name AS concept_code_2
FROM t1 a
JOIN concept c ON UPPER(c.concept_name) = UPPER(TRIM(REGEXP_REPLACE(a.concept_name,';.*$','')))
 AND c.standard_concept = 'S'
 AND c.concept_class_id = 'Ingredient'
 AND c.invalid_reason IS NULL
WHERE (concept_code_1, c.concept_name) not in (SELECT concept_code_1, concept_code_2 FROM internal_relationship_stage);
-------------------------
-- rectal formulations --
-------------------------
-- create a temporary table WITH all related Dose Forms
DROP TABLE IF EXISTS dev_rectal;
CREATE TABLE dev_rectal 
AS
(SELECT DISTINCT d.*
FROM concept_relationship r
 JOIN concept c ON c.concept_Id = r.concept_id_1
 JOIN concept d
 ON d.concept_id = r.concept_id_2
 AND d.invalid_reason IS NULL
 AND d.concept_class_id = 'Dose Form'
WHERE concept_id_1 = 	36217211 -- Rectal Product
AND relationship_id = 'RxNorm inverse is a');

-- add links between Rectal ATC Drug Classes AND Rx Dose Forms
INSERT INTO internal_relationship_stage
(concept_code_1, concept_code_2)
SELECT DISTINCT a.concept_code|| ' ' ||b.concept_name AS concept_code_1, -- ATC code + Dose Form name AS a code
  b.concept_name AS concept_code_2 -- OMOP Dose Form name treated AS a code
FROM concept_manual a,
  dev_rectal b 
WHERE a.concept_name ~* 'rectal' -- respective ATC route
AND a.invalid_reason IS NULL
AND a.concept_class_id = 'ATC 5th'; -- 1150

-- add links between Rectal ATC Drug Classes AND Standard Ingredients using the concept table
INSERT INTO internal_relationship_stage
(concept_code_1, concept_code_2)
WITH t1
AS
(SELECT DISTINCT a.concept_code|| ' ' ||b.concept_name AS concept_code_1, -- ATC code + Dose Form name AS a code
  a.concept_name -- ATC name to be used AS a key for JOIN 
FROM concept_manual a,
  dev_rectal b 
WHERE a.concept_name ~* 'rectal' -- respective ATC route
AND a.invalid_reason IS NULL
) 
SELECT DISTINCT a.concept_code_1, -- ATC code + Dose Form name AS a code
  c.concept_name AS concept_code_2 -- Standard Ingredient name AS a code
FROM t1 a
 JOIN concept c ON UPPER(c.concept_name) = UPPER(TRIM(REGEXP_REPLACE(a.concept_name,';.*$','')))
 AND c.standard_concept = 'S'
 AND c.concept_class_id = 'Ingredient'
 AND c.invalid_reason IS NULL
 WHERE (concept_code_1, c.concept_name) NOT IN (SELECT concept_code_1, concept_code_2 FROM internal_relationship_stage);

-- add links between Rectal ATC Drug Classes AND Standard Ingredients using the concept_synonym synonym
INSERT INTO internal_relationship_stage
( concept_code_1,
 concept_code_2)
WITH t1
AS
(SELECT DISTINCT a.concept_code|| ' ' ||b.concept_name AS concept_code_1, -- ATC code + Dose Form name AS a code
  a.concept_name -- ATC name to be used AS a key for JOIN
FROM concept_manual a,
  dev_rectal b 
WHERE a.concept_name ~* 'rectal' -- respective ATC route
AND a.invalid_reason IS NULL
) 
SELECT DISTINCT a.concept_code_1, -- ATC code + Dose Form name AS a code
  c.concept_name AS concept_code_2 -- Standard Ingredient name AS a code
FROM t1 a
 JOIN concept_synonym b ON UPPER (b.concept_synonym_name) = UPPER(TRIM(REGEXP_REPLACE(a.concept_name,';.*$','')))
 JOIN concept c
 ON c.concept_id = b.concept_id
 AND c.standard_concept = 'S'
 AND c.concept_class_id = 'Ingredient'
 AND c.invalid_reason IS NULL
 WHERE (concept_code_1, c.concept_name) NOT IN (SELECT concept_code_1, concept_code_2 FROM internal_relationship_stage);
--------------------------
-- vaginal formulations --
--------------------------
-- create a temporary table WITH all related Dose Forms
DROP TABLE IF EXISTS dev_vaginal;
CREATE TABLE dev_vaginal 
AS
(SELECT DISTINCT d.*
FROM concept_relationship r
 JOIN concept c ON c.concept_Id = r.concept_id_1
 JOIN concept d
 ON d.concept_id = r.concept_id_2
 AND d.invalid_reason IS NULL
 AND d.concept_class_id = 'Dose Form'
 AND d.invalid_reason IS NULL
WHERE concept_id_1 = 36217209
AND relationship_id = 'RxNorm inverse is a'); -- Vaginal Product

-- add links between Vaginal ATC Drug Classes and Rx Dose Forms
INSERT INTO internal_relationship_stage
(concept_code_1, concept_code_2)
SELECT DISTINCT a.concept_code|| ' ' ||b.concept_name AS concept_code_1, -- ATC code + Dose Form name AS a code
  b.concept_name -- OMOP Dose Form name treated AS a code
FROM concept_manual a,
  dev_vaginal b 
WHERE a.concept_name ~* 'vaginal' -- respective ATC routes
AND a.invalid_reason IS NULL
AND a.concept_class_id = 'ATC 5th';

-- add links between Vaginal ATC Drug Classes AND Standard Ingredients using the concept table
INSERT INTO internal_relationship_stage
(concept_code_1, concept_code_2)
WITH t1
AS
(SELECT DISTINCT a.concept_code|| ' ' ||b.concept_name AS concept_code_1, -- ATC code + Dose Form name AS a code
  a.concept_name -- ATC name to be used AS a key for JOIN
FROM concept_manual a,
  dev_vaginal b 
WHERE a.concept_name ~* 'vaginal' -- respective ATC route
AND a.invalid_reason IS NULL
) 
SELECT DISTINCT a.concept_code_1, -- ATC code + Dose Form name AS a code
  c.concept_name AS concept_code_2 -- Standard Ingredient name AS a code
FROM t1 a
 JOIN concept c ON UPPER(c.concept_name) = UPPER(TRIM(REGEXP_REPLACE(a.concept_name,';.*$','')))
 AND c.standard_concept = 'S'
 AND c.concept_class_id = 'Ingredient'
 AND c.invalid_reason IS NULL
 WHERE (concept_code_1, c.concept_name) not in (SELECT concept_code_1, concept_code_2 FROM internal_relationship_stage);

-- add links between Vaginal ATC Drug Classes AND Standard Ingredients using the concept_synonym table
INSERT INTO internal_relationship_stage
(concept_code_1, concept_code_2)
WITH t1
AS
(SELECT DISTINCT a.concept_code|| ' ' ||b.concept_name AS concept_code_1, -- ATC code + Dose Form name AS a code
  a.concept_name -- ATC name to be used AS a key for JOIN
FROM concept_manual a,
  dev_vaginal b 
WHERE a.concept_name ~* 'vaginal' -- respective ATC route
AND a.invalid_reason IS NULL
) 
SELECT DISTINCT a.concept_code_1, -- ATC code + Dose Form name AS a code
  c.concept_name AS concept_code_2 -- Standard Ingredient name AS a code
FROM t1 a
 JOIN concept_synonym b ON UPPER (b.concept_synonym_name) = UPPER(TRIM(REGEXP_REPLACE(a.concept_name,';.*$','')))
 JOIN concept c
 ON c.concept_id = b.concept_id
 AND c.standard_concept = 'S'
 AND c.concept_class_id = 'Ingredient'
 AND c.invalid_reason IS NULL
 WHERE (concept_code_1, c.concept_name) NOT IN (SELECT concept_code_1, concept_code_2 FROM internal_relationship_stage);
---------------------------
-- urethral formulations --
---------------------------
-- create a temporary table WITH all related RxN/RxE Dose Forms
DROP TABLE IF EXISTS dev_urethral;
CREATE TABLE dev_urethral 
AS
(SELECT DISTINCT d.*
FROM concept_relationship r
 JOIN concept c ON c.concept_Id = r.concept_id_1
 JOIN concept d
 ON d.concept_id = r.concept_id_2
 AND d.invalid_reason IS NULL
 AND d.concept_class_id = 'Dose Form'
WHERE concept_id_1 = 36217225 -- Urethral Product
AND relationship_id = 'RxNorm inverse is a');

-- add links between Urethral ATC Drug Classes AND Rx Dose Forms
INSERT INTO internal_relationship_stage
(concept_code_1, concept_code_2)
SELECT DISTINCT a.concept_code|| ' ' ||b.concept_name AS concept_code_1, -- ATC code + Dose Form name AS a code
  b.concept_name -- OMOP Dose Form name treated AS a code 
FROM concept_manual a,
  dev_urethral b 
WHERE a.concept_name ~* 'urethral' -- respective ATC route
AND a.invalid_reason IS NULL
AND a.concept_class_id = 'ATC 5th';

-- add links between Urethral ATC Drug Classes AND Standard Ingredients using the concept table (up to date no need to use tne concept_synonym but you may check)
INSERT INTO internal_relationship_stage
(concept_code_1, concept_code_2)
 WITH t1
AS
(SELECT DISTINCT a.concept_code|| ' ' ||b.concept_name AS concept_code_1, -- ATC code + Dose Form name AS a code
  a.concept_name -- ATC name to be used AS a key for JOIN
FROM concept_manual a,
  dev_urethral b 
WHERE a.concept_name ~* 'urethral' -- respective ATC route
AND a.invalid_reason IS NULL
) 
SELECT DISTINCT a.concept_code_1, -- ATC code + Dose Form name AS a code
c.concept_name AS concept_code_2 -- Standard Ingredient name AS a code
FROM t1 a
 JOIN concept c ON UPPER(c.concept_name) = UPPER(TRIM(REGEXP_REPLACE(a.concept_name,';.*$','')))
 AND c.standard_concept = 'S'
 AND c.concept_class_id = 'Ingredient'
 AND c.invalid_reason IS NULL
 WHERE (concept_code_1, c.concept_name) NOT IN (SELECT concept_code_1, concept_code_2 FROM internal_relationship_stage);
------------------------------
--- ophtalmic formulations ---
------------------------------
-- create a temporary table WITH all related RxN/RxE Dose Forms
DROP TABLE if exists dev_opht;
CREATE TABLE dev_opht 
AS
(SELECT DISTINCT d.*
FROM concept_relationship r
 JOIN concept c ON c.concept_Id = r.concept_id_1
 JOIN concept d
 ON d.concept_id = r.concept_id_2
 AND d.invalid_reason IS NULL
 AND d.concept_class_id = 'Dose Form'
WHERE concept_id_1 = 36217218 -- Ophthalmic Product (Dose Form Group)
AND relationship_id = 'RxNorm inverse is a'
AND d.concept_name ~* 'ophthalmic');

-- add links between Ophthalmic ATC Drug Classes AND Rx Dose Forms
INSERT INTO internal_relationship_stage
(concept_code_1, concept_code_2)
SELECT DISTINCT a.concept_code|| ' ' ||b.concept_name AS concept_code_1, -- ATC code + Dose Form name AS a code
  b.concept_name -- OMOP Dose Form name treated AS a code
FROM concept_manual a,
  dev_opht b 
WHERE a.concept_name ~* 'ophthalmic' -- respective ATC route
AND a.invalid_reason IS NULL
AND a.concept_class_id = 'ATC 5th';

-- add links between Ophthalmic ATC Drug Classes AND Standard Ingredients using the concept table 
INSERT INTO internal_relationship_stage
(concept_code_1, concept_code_2)
WITH t1
AS
(SELECT DISTINCT a.concept_code|| ' ' ||b.concept_name AS concept_code_1, -- ATC code + Dose Form name AS a code
  a.concept_name -- ATC name to be used AS a key for JOIN
FROM concept_manual a,
  dev_opht b 
WHERE a.concept_name ~* 'ophthalmic' -- respective ATC route
AND a.invalid_reason IS NULL
)
SELECT DISTINCT a.concept_code_1, -- ATC code + Dose Form name AS a code
  c.concept_name AS concept_code_2
FROM t1 a
JOIN concept c ON UPPER(c.concept_name) = UPPER(TRIM(REGEXP_REPLACE(a.concept_name,';.*$','')))
 AND c.standard_concept = 'S'
 AND c.concept_class_id = 'Ingredient'
 AND c.invalid_reason IS NULL
WHERE (concept_code_1, c.concept_name) NOT IN (SELECT concept_code_1, concept_code_2 FROM internal_relationship_stage);

-- add links between Ophthalmic ATC Drug Classes AND Standard Ingredients using the concept_synonym table 
INSERT INTO internal_relationship_stage
(concept_code_1, concept_code_2)
WITH t1
AS
(SELECT DISTINCT a.concept_code|| ' ' ||b.concept_name AS concept_code_1, -- ATC code + Dose Form name AS a code
  a.concept_name -- ATC name to be used AS a key for JOIN
FROM concept_manual a,
  dev_opht b 
WHERE a.concept_name ~* 'ophthalmic' -- respective ATC route
AND a.invalid_reason IS NULL
)
SELECT DISTINCT a.concept_code_1, -- ATC code + Dose Form name AS a code
  c.concept_name AS concept_code_2 -- Standard Ingredient name AS a code
FROM t1 a
 JOIN concept_synonym b ON UPPER(b.concept_synonym_name) = UPPER(TRIM(REGEXP_REPLACE(a.concept_name,';.*$','')))
 JOIN concept c
 ON c.concept_id = b.concept_id
 AND c.standard_concept = 'S'
 AND c.concept_class_id = 'Ingredient'
 AND c.invalid_reason IS NULL
 WHERE (concept_code_1, c.concept_name) NOT IN (SELECT concept_code_1, concept_code_2 FROM internal_relationship_stage);
 -------------------------
--- otic formulations ---
--------------------------
-- create a temporary table WITH all related RxN/RxE Dose Forms
DROP TABLE if exists dev_otic;
CREATE TABLE dev_otic
AS
(SELECT DISTINCT d.*
FROM concept_relationship r
 JOIN concept c ON c.concept_Id = r.concept_id_1
 JOIN concept d
 ON d.concept_id = r.concept_id_2
 AND d.invalid_reason IS NULL
 AND d.concept_class_id = 'Dose Form'
WHERE concept_id_1 = 36217217 -- Otic Product (Dose Form Group)
AND relationship_id = 'RxNorm inverse is a'
);

-- add links between Ophthalmic ATC Drug Classes AND Rx Dose Forms
INSERT INTO internal_relationship_stage
(concept_code_1, concept_code_2)
SELECT DISTINCT a.concept_code|| ' ' ||b.concept_name AS concept_code_1, -- ATC code + Dose Form name AS a code
  b.concept_name -- OMOP Dose Form name treated AS a code
FROM concept_manual a,
  dev_otic b 
WHERE a.concept_name ~* '\yotic' -- respective ATC route
AND a.invalid_reason IS NULL
AND a.concept_class_id = 'ATC 5th';

-- add links between Ophthalmic ATC Drug Classes AND Standard Ingredients using the concept table 
INSERT INTO internal_relationship_stage
(concept_code_1, concept_code_2)
WITH t1
AS
(SELECT DISTINCT a.concept_code|| ' ' ||b.concept_name AS concept_code_1, -- ATC code + Dose Form name AS a code
  a.concept_name -- ATC name to be used AS a key for JOIN
FROM concept_manual a,
  dev_otic b 
WHERE a.concept_name ~* '\yotic' -- respective ATC route
AND a.invalid_reason IS NULL
)
SELECT DISTINCT a.concept_code_1, -- ATC code + Dose Form name AS a code
  c.concept_name AS concept_code_2
FROM t1 a
JOIN concept c ON UPPER(c.concept_name) = UPPER(TRIM(REGEXP_REPLACE(a.concept_name,';.*$','')))
 AND c.standard_concept = 'S'
 AND c.concept_class_id = 'Ingredient'
 AND c.invalid_reason IS NULL
WHERE (concept_code_1, c.concept_name) NOT IN (SELECT concept_code_1, concept_code_2 FROM internal_relationship_stage);

-- add links between Ophthalmic ATC Drug Classes AND Standard Ingredients using the concept_synonym table 
INSERT INTO internal_relationship_stage
(concept_code_1, concept_code_2)
WITH t1
AS
(SELECT DISTINCT a.concept_code|| ' ' ||b.concept_name AS concept_code_1, -- ATC code + Dose Form name AS a code
  a.concept_name -- ATC name to be used AS a key for JOIN
FROM concept_manual a,
  dev_otic b 
WHERE a.concept_name ~* '\yotic' -- respective ATC route
AND a.invalid_reason IS NULL
)
SELECT DISTINCT a.concept_code_1, -- ATC code + Dose Form name AS a code
  c.concept_name AS concept_code_2 -- Standard Ingredient name AS a code
FROM t1 a
 JOIN concept_synonym b ON UPPER(b.concept_synonym_name) = UPPER(TRIM(REGEXP_REPLACE(a.concept_name,';.*$','')))
 JOIN concept c
 ON c.concept_id = b.concept_id
 AND c.standard_concept = 'S'
 AND c.concept_class_id = 'Ingredient'
 AND c.invalid_reason IS NULL
 WHERE (concept_code_1, c.concept_name) NOT IN (SELECT concept_code_1, concept_code_2 FROM internal_relationship_stage);
---------------------------
-- inhalant formulations --
---------------------------
-- create a temporary table WITH all related RxN/RxE Dose Forms
DROP TABLE if exists dev_inhal;
CREATE TABLE dev_inhal 
AS
(SELECT DISTINCT d.*
FROM concept_relationship r
 JOIN concept c ON c.concept_Id = r.concept_id_1
 JOIN concept d
 ON d.concept_id = r.concept_id_2
 AND d.invalid_reason IS NULL
 AND d.concept_class_id = 'Dose Form'
WHERE concept_id_1 IN (36217207, 36244037) -- 	Inhalant Product|	Oral Spray Product
AND relationship_id = 'RxNorm inverse is a');

-- add links between Inhalant ATC Drug Classes AND Rx Dose Forms
INSERT INTO internal_relationship_stage
(concept_code_1, concept_code_2)
SELECT DISTINCT a.concept_code|| ' ' ||b.concept_name AS concept_code_1, -- ATC code + Dose Form name AS a code
  b.concept_name -- OMOP Dose Form name treated AS a code
FROM concept_manual a,
  dev_inhal b 
WHERE a.concept_name ~* 'inhalant' -- respective ATC route
AND a.invalid_reason IS NULL
AND a.concept_class_id = 'ATC 5th';

-- add links between Inhalant ATC Drug Classes AND Standard Ingredients using the concept table
INSERT INTO internal_relationship_stage
(concept_code_1, concept_code_2)
WITH t1
AS
(SELECT DISTINCT a.concept_code|| ' ' ||b.concept_name AS concept_code_1, -- ATC code + Dose Form name AS a code
  a.concept_name -- ATC name to be used AS a key for JOIN 
FROM concept_manual a,
  dev_inhal b 
WHERE a.concept_name ~* 'inhalant' -- respective ATC route
AND a.invalid_reason IS NULL
) 
SELECT DISTINCT a.concept_code_1, -- ATC code + Dose Form name AS a code
  c.concept_name AS concept_code_2
FROM t1 a
 JOIN concept c ON UPPER (c.concept_name) = UPPER(TRIM(REGEXP_REPLACE(a.concept_name,';.*$','')))
 AND c.standard_concept = 'S'
 AND c.concept_class_id = 'Ingredient'
 AND c.invalid_reason IS NULL
 WHERE (concept_code_1, c.concept_name) NOT IN (SELECT concept_code_1, concept_code_2 FROM internal_relationship_stage);
 
-- add links between Inhalant ATC Drug Classes AND Standard Ingredients using the concept_synonym table
INSERT INTO internal_relationship_stage
(concept_code_1, concept_code_2)
WITH t1
AS
(SELECT DISTINCT a.concept_code|| ' ' ||b.concept_name AS concept_code_1, -- ATC code + Dose Form name AS a code
  a.concept_name -- ATC name to be used AS a key for JOIN 
FROM concept_manual a,
  dev_inhal b 
WHERE a.concept_name ~* 'inhalant' -- respective ATC route
AND a.invalid_reason IS NULL
) 
SELECT DISTINCT a.concept_code_1, -- ATC code + Dose Form name AS a code
  c.concept_name AS concept_code_2
FROM t1 a
 JOIN concept_synonym b ON UPPER (b.concept_synonym_name) = UPPER(TRIM(REGEXP_REPLACE(a.concept_name,';.*$','')))
 JOIN concept c
 ON c.concept_id = b.concept_id
 AND c.standard_concept = 'S'
 AND c.concept_class_id = 'Ingredient'
 AND c.invalid_reason IS NULL
 WHERE (concept_code_1, c.concept_name) NOT IN (SELECT concept_code_1, concept_code_2 FROM internal_relationship_stage);
--------------------------------
-- Ingredients W/O Dose Forms --
--------------------------------
-- add links between ATC Drug Classes, which do not have Dose Forms, AND Standard Ingredients using the concept table
INSERT INTO internal_relationship_stage
(concept_code_1, concept_code_2)
SELECT DISTINCT a.concept_code AS concept_code_1, -- for such Drug Classes use ATC code only 
 c.concept_name AS concept_code_2
FROM concept_manual a
 JOIN concept c ON TRIM(UPPER (REGEXP_REPLACE (c.concept_name,'\s+|\W+','','g'))) = TRIM( UPPER (REGEXP_REPLACE (a.concept_name,'\s+|\W+| \(.*\)|, combinations.*|;.*$','','g')))
 AND a.concept_class_id = 'ATC 5th'
 AND c.standard_concept = 'S'
 AND c.concept_class_id = 'Ingredient'
 AND c.invalid_reason IS NULL
 WHERE (a.concept_code, c.concept_name) not in (SELECT SPLIT_PART(concept_code_1, ' ', 1), concept_code_2 FROM internal_relationship_stage);
 
-- add links between ATC Drug Classes, which do not have Dose Forms, AND Standard Ingredients using the concept_synonym table
INSERT INTO internal_relationship_stage
(concept_code_1, concept_code_2)
SELECT DISTINCT a.concept_code AS concept_code_1, -- for such Drug Classes use ATC code only 
  c.concept_name AS concept_code_2 -- Standard Ingredient name AS a code
FROM concept_manual a
 JOIN concept_synonym b ON TRIM(UPPER (REGEXP_REPLACE (b.concept_synonym_name,'\s+|\W+','','g'))) = TRIM(UPPER (REGEXP_REPLACE (a.concept_name,'\s+|\W+|, combinations.*|;.*$','','g')))
 JOIN concept c
 ON c.concept_id = b.concept_id
  AND a.concept_class_id = 'ATC 5th'
 AND c.standard_concept = 'S'
 AND c.concept_class_id = 'Ingredient'
 AND c.invalid_reason IS NULL
  WHERE (a.concept_code, c.concept_name) not IN (SELECT SPLIT_PART(concept_code_1, ' ', 1), concept_code_2 FROM internal_relationship_stage);	
/*****************************  
**** combined ATC Classes ****
******************************/
-- separate all ATC Combo Classes
DROP TABLE if exists combo_pull;
CREATE TABLE combo_pull 
AS
(WITH t1
AS
(SELECT DISTINCT concept_code AS class_code,
       concept_name AS class_name,
       SPLIT_PART(concept_name,';','1') AS nm
FROM concept_manual
WHERE SPLIT_PART(concept_name,';','1') ~ ' and |combinat|preparations|acids|animals|antiinfectives|compounds|lytes\y|flowers|^glycerol|grass pollen|bacillus|^oil|alkaloids|\/|antiserum|organisms|antiseptics'
AND   invalid_reason IS NULL
AND   concept_class_id = 'ATC 5th'
AND   concept_name !~* 'varicella/zoster|tositumomab/iodine') SELECT*FROM t1);

-- create a table for ATC Combo Class mappings, start with the 1st ATC Combo Ingredient using the concept table and full name match
DROP TABLE if exists dev_combo;
CREATE TABLE dev_combo 
AS
(SELECT DISTINCT class_code,
       class_name,
       SPLIT_PART(nm,' and ',1) AS class,
       c.concept_id,
       c.concept_name,
       1 AS rnk -- stands for the Primary lateral relationship
       FROM combo_pull a
  JOIN concept c ON lower (c.concept_name) = TRIM (lower (SPLIT_PART (nm,' and ',1)))
WHERE c.standard_concept = 'S'
AND   c.concept_class_id = 'Ingredient'
AND   c.vocabulary_id ~ 'Rx');

-- obtain 1st ATC Combo Ingredient using the concept table and partial name match
INSERT INTO dev_combo
SELECT DISTINCT class_code,
  class_name,
  SPLIT_PART(nm,' and ',1) AS class,
  c.concept_id,
  c.concept_name,
  1 AS rnk -- stands for the Primary lateral relationship
FROM combo_pull a
 JOIN concept c ON lower (c.concept_name) = SUBSTRING (TRIM (lower (SPLIT_PART (nm,' and ', 1))),'\w*\s*-?\s*\w+')
WHERE c.standard_concept = 'S'
AND c.concept_class_id = 'Ingredient'
AND c.vocabulary_id ~ 'Rx'
AND (class_code, c.concept_id) NOT IN (select class_code, concept_id FROM dev_combo);

-- obtain 1st ATC Combo Ingredient using the concept_synonym table and name match
INSERT INTO dev_combo
SELECT DISTINCT class_code,
  class_name,
  SPLIT_PART(nm,' and ', 1) AS class,
  d.concept_id,
  d.concept_name,
  1 AS rnk -- stands for the Primary lateral relationship
FROM combo_pull a
JOIN concept_synonym cs ON lower(cs.concept_synonym_name) = COALESCE(TRIM(lower(SPLIT_PART (nm,' and ', 1))), SUBSTRING(TRIM(lower(SPLIT_PART (nm,' and ', 1))), '\w*\s*-?\s*\w+'))
JOIN concept d ON d.concept_id = cs.concept_id
WHERE d.standard_concept = 'S'
AND d.concept_class_id = 'Ingredient'
AND d.vocabulary_id ~ 'Rx'
AND (class_code, d.concept_id) NOT IN (select class_code, concept_id FROM dev_combo); -- 15 

-- obtain 1st ATC Combo Ingredient using the concept table and partial name match
INSERT INTO dev_combo
SELECT DISTINCT class_code,
  class_name,
  SPLIT_PART(nm,' and ',1) AS class,
  c.concept_id,
  c.concept_name,
  1 AS rnk -- stands for the Primary lateral relationship
FROM combo_pull a
 JOIN concept c ON lower (c.concept_name) = SUBSTRING (TRIM (lower (SPLIT_PART (nm,' and ', 1))),'^\w+')
WHERE c.standard_concept = 'S'
AND c.concept_class_id = 'Ingredient'
AND c.vocabulary_id ~ 'Rx'
AND (class_code) NOT IN (select class_code FROM dev_combo); -- 3 

-- obtain 2nd ATC Combo Ingredient using the concept table and full name match
INSERT INTO dev_combo
SELECT DISTINCT class_code,
  class_name,
  SPLIT_PART(nm,' and ', 2) AS class,
  c.concept_id,
  c.concept_name,
  2 AS rnk -- stands for the Secondary lateral relationship
FROM combo_pull a
 JOIN concept c ON lower (c.concept_name) = TRIM (lower (SPLIT_PART (a.nm,' and ', 2)))
WHERE c.standard_concept = 'S'
AND c.concept_class_id = 'Ingredient'
AND c.vocabulary_id ~ 'Rx'; -- 249

-- obtain 2nd ATC Combo Ingredient using the concept table and partial name match
INSERT INTO dev_combo
SELECT DISTINCT class_code,
  class_name,
  SPLIT_PART(nm,' and ', 2) AS class,
  c.concept_id,
  c.concept_name,
  2 AS rnk
FROM combo_pull a
 JOIN concept c ON lower (c.concept_name) = SUBSTRING (TRIM (lower (SPLIT_PART (nm,' and ', 2))),'\w*\s*-?\s*\w+')
WHERE c.standard_concept = 'S'
AND c.concept_class_id = 'Ingredient'
AND c.vocabulary_id ~ 'Rx'
AND (class_code, c.concept_id) NOT IN (select class_code, concept_id FROM dev_combo)
AND c.concept_id NOT IN (19049024, 19136048); -- 4 

-- obtain 2nd ATC Combo Ingredient using the concept_synonym table and partial name match
INSERT INTO dev_combo
SELECT DISTINCT class_code,
  class_name,
  SPLIT_PART(nm,' and ',2) AS class,
  d.concept_id,
  d.concept_name,
  2 AS rnk
FROM combo_pull a
JOIN concept_synonym cs ON lower(cs.concept_synonym_name) = COALESCE ( TRIM(lower(SPLIT_PART (nm,' and ', 2))), SUBSTRING (TRIM(lower(SPLIT_PART (nm,' and ', 2))), '\w*\s*-?\s*\w+'))
JOIN concept d ON d.concept_id = cs.concept_id
WHERE d.standard_concept = 'S'
AND d.concept_class_id = 'Ingredient'
AND d.vocabulary_id ~ '^Rx'
AND (class_code, d.concept_id) NOT IN (select class_code, concept_id FROM dev_combo); -- 1 

-- last hope for the 2nd one
INSERT INTO dev_combo
SELECT DISTINCT class_code,
  class_name,
  SPLIT_PART(nm,' and ', 2) AS class,
  c.concept_id,
  c.concept_name,
  2 AS rnk
FROM combo_pull a
 JOIN concept c ON lower (c.concept_name) = SUBSTRING (TRIM (lower (SPLIT_PART (nm,' and ', 2))),'^\w+')
WHERE c.standard_concept = 'S'
AND c.concept_class_id = 'Ingredient'
AND c.vocabulary_id ~ 'Rx'
AND (class_code, c.concept_id) NOT IN (select class_code, concept_id FROM dev_combo)
AND c.concept_id NOT IN (19049024, 19136048)
and class_code in ('R03AK10', 'R03AL01', 'R03AL03', 'R03AL04', 'R03AL05', 'R03AL06',  'R03AL07', 'R03AL10') ; -- 4

-- add manual mappings for ATC Combos using concept_relationship_manual 
INSERT INTO dev_combo
SELECT DISTINCT 
class_code,
  class_name,
  c.concept_name AS class, -- leave it empty
  c.concept_id,
  c.concept_name,
  CASE WHEN relationship_id = 'ATC - RxNorm pr lat' THEN 1 
       WHEN relationship_id = 'ATC - RxNorm sec lat' THEN 2  
       WHEN relationship_id = 'ATC - RxNorm pr up' THEN 3  
            ELSE 4 -- stands for 'ATC - RxNorm sec up' 
                END AS rnk
FROM combo_pull a
JOIN concept_relationship_manual r ON r.concept_code_1= a.class_code
JOIN concept c ON c.concept_code = r.concept_code_2 AND c.vocabulary_id ~ 'Rx'
AND c.concept_class_id = 'Ingredient' AND c.standard_concept = 'S'
WHERE (class_code, c.concept_id) NOT IN (select class_code, concept_id FROM dev_combo)
AND r.relationship_id IN ('ATC - RxNorm pr lat', 'ATC - RxNorm sec lat', 'ATC - RxNorm pr up', 'ATC - RxNorm sec up'); -- 17075

-- add Acetylsalicylic acid 
INSERT INTO dev_combo
SELECT class_code,
  class_name,
  'acetylsalicylic acid',
  1112807,
  'aspirin',
  CASE WHEN class_name ~ '^acetylsalicylic' THEN 1 ELSE 2 END
FROM dev_combo
WHERE (class_code, concept_id) NOT IN ( select class_code, 1112807 FROM dev_combo WHERE class_name ~* 'acetylsalicylic')
AND class_name ~* 'acetylsalicylic'; -- 276

-- ethinylestradiol 
INSERT INTO dev_combo
SELECT class_code,
  class_name,
  'ethinylestradiol',
  1549786,
  'ethinyl estradiol',
  CASE WHEN class_name ~* '^ethinylestradiol' THEN 1 ELSE 2 END
FROM dev_combo
WHERE (class_code, concept_id) NOT IN ( select class_code, 1549786 FROM dev_combo WHERE class_name ~* 'ethinylestradiol')
AND class_name ~* 'ethinylestradiol'; -- 44 
 
-- estrogen
INSERT INTO dev_combo
SELECT class_code,
  class_name,
  'ethinylestradiol',
  19049228,
  'estrogens',
  CASE WHEN class_name ~* '^estrogens|^conjugated estrogens' THEN 1 ELSE 2 END
FROM dev_combo
WHERE (class_code, concept_id) NOT IN ( select class_code, 19049228 FROM dev_combo WHERE class_name ~* 'estrogen')
AND class_name ~ 'estrogen'
    UNION ALL
SELECT class_code,
  class_name,
  'estrogens, conjugated (USP)',
  1549080,
  'estrogens, conjugated (USP)',
  CASE WHEN class_name ~* '^estrogens|^conjugated estrogens' THEN 1 ELSE 2 END
FROM dev_combo
WHERE (class_code, concept_id) NOT IN ( select class_code, 1549080 FROM dev_combo WHERE class_name ~* 'estrogen')
AND class_name ~ 'estrogen'
    UNION ALL
SELECT class_code,
  class_name,
  'estrogens, esterified (USP)',
  1551673,
  'estrogens, esterified (USP)',
  CASE WHEN class_name ~* '^estrogens|^conjugated estrogens' THEN 1 ELSE 2 END
FROM dev_combo
WHERE (class_code, concept_id) NOT IN ( select class_code, 1551673 FROM dev_combo WHERE class_name ~* 'estrogen') 
AND class_name ~ 'estrogen'
    UNION ALL
SELECT class_code,
  class_name,
  'synthetic conjugated estrogens, A',
  1596779,
  'synthetic conjugated estrogens, A',
  CASE WHEN class_name ~* '^estrogens|^conjugated estrogens' THEN 1 ELSE 2 END
FROM dev_combo
WHERE (class_code, concept_id) NOT IN ( select class_code, 1596779 FROM dev_combo WHERE class_name ~* 'estrogen')
AND class_name ~* 'estrogen'
    UNION ALL
SELECT class_code,
  class_name,
  'synthetic conjugated estrogens, B' AS class,
  1586808,
  'synthetic conjugated estrogens, B',
  CASE WHEN class_name ~* '^estrogens|^conjugated estrogens' THEN 1 ELSE 2 END
FROM dev_combo
WHERE (class_code, concept_id) NOT IN ( select class_code, 1586808 FROM dev_combo WHERE class_name ~* 'estrogen')
AND class_name ~* 'estrogen'; -- 1235

-- remove erroneous automap
DELETE FROM dev_combo WHERE class_code = 'M05BX53' AND concept_id = 19000815; -- strontium

-- add links between Oral ATC Drug Classes AND Standard Ingredients using the concept table
INSERT INTO internal_relationship_stage
(concept_code_1, concept_code_2)
WITH t1
AS
(SELECT DISTINCT a.class_code|| ' ' ||b.concept_name AS concept_code_1, -- ATC code + Dose Form name AS a code
a.concept_id
FROM dev_combo a,
  dev_oral b,
  concept_manual c 
WHERE c.concept_name ~* 'oral|systemic|chewing gum'
AND c.concept_code = a.class_code
)
 SELECT DISTINCT a.concept_code_1, -- ATC code + Dose Form name AS a code
  c.concept_name AS concept_code_2 -- Standard Ingredient name treated AS a code
 FROM t1 a 
 JOIN concept c ON c.concept_id = a.concept_id
 AND c.standard_concept = 'S'
 AND c.concept_class_id = 'Ingredient'
WHERE (concept_code_1, c.concept_name) NOT IN (SELECT concept_code_1, concept_code_2 FROM internal_relationship_stage);

-- add links between Oral ATC Drug Classes AND Ingredients using the concept table
INSERT INTO internal_relationship_stage
(concept_code_1, concept_code_2)
WITH t1
AS
(SELECT DISTINCT a.class_code|| ' ' ||b.concept_name AS concept_code_1, -- ATC code + Dose Form name AS a code
  a.class_name,
a.concept_id
FROM dev_combo a,
  dev_parenteral b,
  concept_manual c 
WHERE c.concept_name ~ 'parenteral|systemic'
AND c.concept_code = a.class_code
) -- Oral formulations
 SELECT DISTINCT a.concept_code_1, -- ATC code + Dose Form name AS a code
  c.concept_name AS concept_code_2 -- Standard Ingredient name treated AS a code
 FROM t1 a 
 JOIN concept c ON c.concept_id = a.concept_id
 AND c.standard_concept = 'S'
 AND c.concept_class_id = 'Ingredient'
WHERE (concept_code_1, c.concept_name) NOT IN (SELECT concept_code_1, concept_code_2 FROM internal_relationship_stage);
 
-- add links between Vaginal ATC Drug Classes AND Standard Ingredients using the concept table
INSERT INTO internal_relationship_stage
(concept_code_1, concept_code_2)
WITH t1
AS
(SELECT DISTINCT a.class_code|| ' ' ||b.concept_name AS concept_code_1, -- ATC code + Dose Form name AS a code
  a.class_name, 
a.concept_id
FROM dev_combo a,
  dev_vaginal b,
  concept_manual c 
WHERE c.concept_name ~* 'vaginal'
AND c.concept_code = a.class_code
)
 SELECT DISTINCT a.concept_code_1, -- ATC code + Dose Form name AS a code
  c.concept_name AS concept_code_2 -- Standard Ingredient name treated AS a code
 FROM t1 a 
 JOIN concept c ON c.concept_id = a.concept_id
 AND c.standard_concept = 'S'
 AND c.concept_class_id = 'Ingredient'
WHERE (concept_code_1, c.concept_name) NOT IN (SELECT concept_code_1, concept_code_2 FROM internal_relationship_stage);
 
-- add links between ATC Drug Classes W/O Dose Forms AND Standard Ingredients using the concept table
INSERT INTO internal_relationship_stage
(concept_code_1, concept_code_2)
WITH t1
AS
(SELECT DISTINCT 
class_code AS concept_code_1, -- ATC code + Dose Form name AS a code
class_name, -- ATC name to be used AS a key for JOIN 
concept_id
FROM dev_combo
WHERE class_name !~';' 
)
 SELECT DISTINCT a.concept_code_1, -- ATC code + Dose Form name AS a code
  c.concept_name AS concept_code_2 -- Standard Ingredient name treated AS a code
 FROM t1 a 
 JOIN concept c ON c.concept_id = a.concept_id
 AND c.standard_concept = 'S'
 AND c.concept_class_id = 'Ingredient'
WHERE (concept_code_1, c.concept_name) NOT IN (SELECT SPLIT_PART(concept_code_1, ' ', 1), concept_code_2 FROM internal_relationship_stage); -- 1198

/******************************
******* manual mapping ********
*******************************/
-- add manually mapped ATC Drug Classes to Standard Ingredients using concept_relationship_manual
INSERT INTO internal_relationship_stage
( concept_code_1, concept_code_2)
WITH t1 AS (select distinct a.concept_code_1, a.relationship_id, c.concept_name
 FROM concept_relationship_manual a
 JOIN concept_manual b
 ON b.concept_code = a.concept_code_1
 JOIN concept c
 ON c.concept_code = a.concept_code_2
 AND c.vocabulary_id = a.vocabulary_id_2
 AND c.standard_concept = 'S' AND c.vocabulary_id IN ('RxNorm', 'RxNorm Extension') 
 AND c.concept_class_id = 'Ingredient')
SELECT DISTINCT concept_code_1, 
  a.concept_name -- OMOP Ingredient name AS an ATC Drug Attribute code,
FROM t1 a
 JOIN concept_manual b ON b.concept_code = a.concept_code_1 AND b.invalid_reason is null and b.concept_class_id = 'ATC 5th'
 AND a.relationship_id IN ('ATC - RxNorm pr lat', 'ATC - RxNorm sec lat', 'ATC - RxNorm pr up', 'ATC - RxNorm sec up')
 AND (concept_code_1, a.concept_name) NOT IN (SELECT SPLIT_PART(concept_code_1, ' ', 1),concept_code_2
             FROM internal_relationship_stage); -- 7208
						 
/**********************************
******* drug_concept_stage ********
***********************************/
TRUNCATE drug_concept_stage;
-- change length of concept_code field
ALTER TABLE drug_concept_stage ALTER COLUMN concept_code TYPE VARCHAR;

-- add all ATC Drug Classes using the internal_relationship_stage table
INSERT INTO drug_concept_stage
(
 concept_name,
 vocabulary_id,
 concept_class_id,
 standard_concept,
 concept_code,
 possible_excipient,
 domain_id,
 valid_start_date,
 valid_end_date
)
SELECT DISTINCT concept_code_1, -- ATC code + name
  'ATC',
  'Drug Product',
  NULL,
  concept_code_1,
  NULL,
  'Drug', 
  TO_DATE ('19700101', 'YYYYMMDD') AS valid_start_date,
  TO_DATE('20991231','YYYYMMDD') AS valid_end_date
FROM internal_relationship_stage;

-- add ATC Drug Attributes in the form of Rx Dose Form names using the internal_relationship_stage table
INSERT INTO drug_concept_stage
(
 concept_name,
 vocabulary_id,
 concept_class_id,
 standard_concept,
 concept_code,
 possible_excipient,
 domain_id,
 valid_start_date,
 valid_end_date
)
SELECT DISTINCT concept_code_2 AS concept_name, -- ATC pseudo-attribute IN the form of OMOP Dose Form name
  'ATC' AS vocabulary_id,
  'Dose Form' AS concept_class_id,
  NULL AS standard_concept,
  concept_code_2 AS concept_code,
  NULL AS possible_excipient,
  'Drug' AS domain_id,
  TO_DATE ('19700101', 'YYYYMMDD') AS valid_start_date,
  TO_DATE('20991231','YYYYMMDD') AS valid_end_date
FROM internal_relationship_stage,
  concept
WHERE concept_code_2 = concept_name
AND concept_class_id = 'Dose Form'
AND vocabulary_id ~ 'RxNorm'
AND invalid_reason IS NULL;

-- add ATC Drug Attributes IN the form of Standard Ingredient names using the internal_relationship_stage table
INSERT INTO drug_concept_stage
( concept_name,
 vocabulary_id,
 concept_class_id,
 standard_concept,
 concept_code,
 possible_excipient,
 domain_id,
 valid_start_date,
 valid_end_date)
SELECT DISTINCT concept_code_2, -- ATC pseudo-attribute IN the form of OMOP Ingredient name
  'ATC',
  'Ingredient',
  NULL,
  concept_code_2,
  NULL,
  'Drug',
  TO_DATE ('19700101', 'YYYYMMDD') AS valid_start_date,
  TO_DATE('20991231','YYYYMMDD') AS valid_end_date
FROM internal_relationship_stage,
  concept
WHERE upper (concept_code_2) = upper(concept_name)
AND concept_class_id = 'Ingredient'
AND vocabulary_id ~ 'RxNorm'
AND standard_concept = 'S'
AND invalid_reason IS NULL
AND concept_code_2 NOT IN (select concept_code FROM drug_concept_stage);

-- obtain additional ingredients for those ATC codes which are still unmapped using fuzzy match
INSERT INTO internal_relationship_stage
WITH t1 AS
(
 -- define concepts to map
 SELECT DISTINCT class_code,
   class_name
 FROM class_drugs_scraper
 WHERE (
 -- totally lost
 class_code NOT IN (SELECT SPLIT_PART(concept_code,' ',1) FROM drug_concept_stage)
 AND LENGTH(class_code) = 7
 AND class_code NOT IN (SELECT concept_code_1
       FROM concept_relationship_manual
       WHERE relationship_id IN ('ATC - RxNorm pr lat', 'ATC - RxNorm sec lat', 'ATC - RxNorm pr up', 'ATC - RxNorm sec up'))
 AND class_code NOT IN ('B03AD04', 'V09GX01', 'V09XX03') -- ferric oxide polymaltose complexes | thallium (201Tl) chloride | selenium (75Se) norcholesterol
 AND class_name !~* '^indium|^iodine|^yttrium|^RIFAMPICIN|coagulation factor'
 AND change_type IN ('', 'A'))
 OR (
 -- absent IN the internal_relationship_stage
 class_code IN (SELECT SPLIT_PART(concept_code,' ',1) FROM drug_concept_stage)
AND class_code NOT IN (SELECT SPLIT_PART(concept_code_1,' ',1)
       FROM internal_relationship_stage a
       JOIN concept c
        ON c.concept_name = a.concept_code_2
       AND c.standard_concept = 'S'
       AND c.concept_class_id = 'Ingredient')
AND LENGTH(class_code) = 7)
OR
 -- with absent Ingredient IN drug_relationship_stage
(class_code IN (SELECT SPLIT_PART(concept_code_1,' ',1)
FROM internal_relationship_stage
GROUP BY concept_code_1
HAVING COUNT(1) = 1) AND class_code NOT IN (
  SELECT SPLIT_PART(concept_code_1,' ',1)
  FROM internal_relationship_stage a
   JOIN concept c
    ON LOWER (c.concept_name) = LOWER (a.concept_code_2)
   AND c.concept_class_id = 'Ingredient'
   AND c.standard_concept = 'S'))
),
-- fuzzy macth 1 using name similarity
t2 AS
(SELECT a.*,
  c.*
FROM t1 a
 JOIN concept_synonym b ON lower (b.concept_synonym_name) LIKE lower (concat ('%',class_name,'%'))
 JOIN concept c
 ON c.concept_id = b.concept_id
 AND c.concept_class_id = 'Ingredient'
 AND c.standard_concept = 'S'),
-- fuzzy match WITH levenshtein
t3 AS
(SELECT *
FROM t1 a
 JOIN concept c
 ON devv5.levenshtein (lower (class_name),lower (concept_name)) = 1
 AND c.concept_class_id = 'Ingredient'
 AND c.standard_concept = 'S'
 AND class_code NOT IN (SELECT class_code FROM t2)
),
-- match with non-standard and crosswalk to Standard 
t4 AS (SELECT a.*,d.*
FROM t1 a
 JOIN concept c ON lower(REGEXP_REPLACE (c.concept_name, '\s+|\W+', '', 'g')) = lower(TRIM(REGEXP_REPLACE(a.class_name,';.*$|, combinations?|IN combinations?', '', 'g')))
 AND c.domain_id = 'Drug'
 JOIN concept_relationship r ON r.concept_id_1 = c.concept_id
 JOIN concept d ON d.concept_id = r.concept_id_2 AND d.standard_concept = 'S' AND d.concept_class_id = 'Ingredient'),
t5 AS
(SELECT *
FROM t1 a
 JOIN concept c
 ON lower (c.concept_name) = lower (SUBSTRING (class_name,'\w+'))
 AND c.concept_class_id = 'Ingredient'
 AND c.standard_concept = 'S'
 AND a.class_code NOT IN (SELECT concept_code_1 FROM concept_relationship_manual)
 AND concept_id NOT IN (19018544, 19071128, 1195334, 19124906, 19049024, 40799093, 19136048) --calcium|copper|choline|magnesium|potassium|Serum|sodium
 AND class_code NOT IN (SELECT class_code FROM t2)
AND class_code NOT IN (SELECT class_code FROM t3)
),
t6 AS (
SELECT class_code,class_name,concept_id,concept_name FROM t2
UNION ALL
SELECT class_code,class_name,concept_id,concept_name FROM t3
UNION ALL
SELECT class_code,class_name,concept_id,concept_name FROM t4
UNION ALL
SELECT class_code,class_name,concept_id,concept_name FROM t5)
SELECT DISTINCT class_code, --class_name,
                concept_name
FROM t6
WHERE (class_code,concept_name) NOT IN (SELECT concept_code_1,
            concept_code_2
          FROM internal_relationship_stage)
  AND concept_id <> 43013482; -- butyl ester of methyl vinyl ether-maleic anhydride copolymer (125 kD)
/*****************************************
*** FUTHER WORK WITH ATC COMBO CLASSES ***
******************************************/
-- assemble mappings for ATC Classes indicating Ingredient Groups using the the concept_ancestor AND/OR concept tables along WITH word pattern matching
-- take descendants of Acid preparations
INSERT INTO dev_combo
SELECT DISTINCT a.concept_code,
  a.concept_name,
  'acid preparations' AS class,
  c.concept_id,
  c.concept_name,
  CASE WHEN a.concept_name ~* '^acid' THEN 3 ELSE 4 END ::INT AS rnk
FROM concept_manual a, -- ATC
  concept_ancestor ca
 JOIN concept c
 ON ca.descendant_concept_id = c.concept_id
 AND ca.ancestor_concept_id = 21600704-- ATC code of Acid preparations
 AND vocabulary_id LIKE 'RxNorm%'
 AND concept_class_id = 'Ingredient'
WHERE a.concept_name ~* 'acid preparations'
AND a.invalid_reason IS NULL AND a.concept_class_id = 'ATC 5th'; -- 8

-- Sulfonamides
INSERT INTO dev_combo
SELECT DISTINCT a.concept_code,
  a.concept_name,
  'sulfonamides' AS class,
  concept_id,
  c.concept_name,
  CASE WHEN a.concept_name ~* '^sulfonamides|^combinations of sulfonamides' THEN 3 ELSE 4 END ::INT AS rnk
FROM  concept_manual a, -- ATC
  concept_ancestor ca
 JOIN concept c
 ON ca.descendant_concept_id = c.concept_id
 AND ca.ancestor_concept_id = 21603038-- ATC code of sulfonamides
 AND c.vocabulary_id LIKE 'RxNorm%'
 AND c.concept_class_id = 'Ingredient'
 JOIN concept_relationship b ON b.concept_id_1 = ancestor_concept_id
 AND b.invalid_reason is null AND b.relationship_id = 'ATC - RxNorm pr lat'
WHERE a.concept_name ~* 'sulfonamides' AND  a.concept_name !~* '^short-acting sulfonamides|^intermediate-acting sulfonamides|^long-acting sulfonamides'
AND a.invalid_reason IS NULL AND a.concept_class_id = 'ATC 5th';
 
-- take descendants of Amino acids
INSERT INTO dev_combo
SELECT DISTINCT a.concept_code,
  a.concept_name,
  'amino acids',
  c.concept_id,
  c.concept_name,
  CASE WHEN a.concept_name ~* '^amino acids' THEN 3 ELSE 4 END ::INT AS rnk
FROM  concept_manual a, -- ATC
  concept_ancestor ca
 JOIN concept c
 ON ca.descendant_concept_id = c.concept_id
 AND ca.ancestor_concept_id IN (21601215, 21601034) -- 21601215	B05XB	Amino acids| 21601034	B02AA	Amino acids
 AND c.vocabulary_id LIKE 'RxNorm%'
 AND c.concept_class_id = 'Ingredient'
  WHERE a.concept_name ~* 'amino\s*acid'
  AND a.concept_code <> 'B03AD01'
  AND a.invalid_reason IS NULL AND a.concept_class_id = 'ATC 5th'; --	ferrous amino acid complex

-- take descendants of Analgesics
INSERT INTO dev_combo
SELECT DISTINCT a.concept_code,
  a.concept_name,
  'analgesics',
  c.concept_id,
  c.concept_name,
  CASE WHEN a.concept_name ~* '^analgesics' THEN 3 ELSE 4 END ::INT AS rnk
FROM concept_manual a, concept_ancestor ca
 JOIN concept c
 ON ca.descendant_concept_id = c.concept_id
 AND ca.ancestor_concept_id IN (21604253) -- 21604253	N02	ANALGESICS	ATC 2nd
 AND c.vocabulary_id LIKE 'RxNorm%'
 AND c.concept_class_id = 'Ingredient'
 AND c.concept_id NOT IN (939506, 950435, 964407) --	sodium bicarbonate|citric acid|salicylic acid
   WHERE a.concept_name ~* 'analgesics?' AND a.concept_name !~* '\yexcl'
AND a.invalid_reason IS NULL AND a.concept_class_id = 'ATC 5th';
 
-- take ingredients indicating Animals
INSERT INTO dev_combo
SELECT DISTINCT a.concept_code,
  a.concept_name,
  'animals',
  c.concept_id,
  c.concept_name,
  CASE WHEN a.concept_name ~* '^animals' THEN 3 ELSE 4 END ::INT AS rnk
FROM concept_manual a,
     concept c
WHERE a.concept_name ~* 'Animals'
AND a.invalid_reason IS NULL AND a.concept_class_id = 'ATC 5th'
AND (c.concept_id IN (19091701,19056189,40170543,40170448,40170341,40170416,40175840,40175865,40170916,40175984,40161698,40170420,
19095690,40170741,40170848,40161809,40161813,45892235,40171114,45892234,37496548,40170660,40172147,40175843,40175898,40175933,40171110,
40175911,40171275,40172704,40171317,40175983,40171135,35201802,40238446,40175899,40227400,40175938,19061053,19112547,43013524,40170475,
40170818,40161805,40167658,1340875,42903998,963757,40171594,37496553,40172160,35201545,40175931,35201783,789889,35201778,40175951,35201548,
40161124,42709317,40161676,40161750,40170521,40161754,40170973,40170979,40170876,40175917)
OR (
c.concept_name ~* 'rabbit|\ycow\y|\ydog\y|\ycat\y|goose|\yhog\y|\ygland\y|hamster|\yduck|oyster|\yhorse\y|\ylamb|pancreas|brain|kidney|\ybone\y|heart|spleen|lungs|^Pacific|\yfish|\yegg\y|\ypork|shrimp|\yveal|\ytuna|chicken' 
AND c.concept_name ~* 'extract' AND c.vocabulary_id LIKE 'RxNorm%' 
AND c.standard_concept = 'S' AND c.concept_class_id = 'Ingredient' 
AND c.concept_id NOT IN (46276144,40170814,40226703,43560374,40227355,42903998,40227484,19086386))
); -- 98

-- take descendants of Antiinfectives 
INSERT INTO dev_combo
SELECT DISTINCT a.concept_code,
  a.concept_name,
  'antiinfectives',
  c.concept_id,
  c.concept_name,
  CASE WHEN a.concept_name ~* '^antiinfectives' THEN 3 ELSE 4 END ::INT AS rnk
FROM concept_manual a,
 concept_ancestor ca
 JOIN concept c
 ON ca.descendant_concept_id = c.concept_id
 AND ca.ancestor_concept_id IN (21605189, 21603552, 21605145, 21601168, 21605188, 21605146) -- 	Antiinfectives|	ANTIINFECTIVES|	ANTIINFECTIVES | 	Antiinfectives |	Antiinfectives
 AND c.vocabulary_id LIKE 'RxNorm%'
 AND c.concept_class_id = 'Ingredient'
 AND c.concept_id NOT IN (19044522)-- 	zinc sulfate
 WHERE a.concept_name ~* 'antiinfectives?' --AND class_name ~* '\yexcl'
AND a.invalid_reason IS NULL AND a.concept_class_id = 'ATC 5th';
 
-- take ingredients indicating Cadmium compounds
INSERT INTO dev_combo
SELECT DISTINCT a.concept_code,
  a.concept_name,
  'cadmium compounds', 
  c.concept_id,
  c.concept_name,
  CASE WHEN a.concept_name ~* '^cadmium compounds' THEN 3 ELSE 4 END ::INT AS rnk -- groups don't have primary lateral ings
FROM concept_manual a, 
concept c
WHERE lower(c.concept_name) LIKE '%cadmium %'
AND c.concept_class_id = 'Ingredient'
AND c.vocabulary_id LIKE 'RxNorm%'
AND c.concept_id <> 45775350 
AND a.concept_name ~* 'cadmium compounds?' --AND class_name ~* '\yexcl'
AND a.invalid_reason IS NULL AND a.concept_class_id = 'ATC 5th'; -- 4

-- take ingredients indicating Calcium (different salts)
INSERT INTO dev_combo
SELECT DISTINCT  a.concept_code,
  a.concept_name,
  'calcium (different salts IN combination)',
  c.concept_id,
  c.concept_name,
  CASE WHEN a.concept_name ~* '^calcium \(different salts IN combination\)' THEN 3 ELSE 4 END ::INT AS rnk
FROM concept_manual a, concept c
WHERE c.concept_name ~* '\ycalcium\y'
AND c.concept_class_id = 'Ingredient'
AND c.vocabulary_id LIKE 'RxNorm%'
AND c.concept_id NOT IN (42903945,43533002,1337191,19007595,43532262,19051475) -- calcium ion|calcium hydride|calcium hydroxide|calcium oxide|calcium peroxide|anhydrous calcium iodide
AND a.concept_name ~* 'calcium' AND a.concept_name ~* '\ysalt'
AND a.invalid_reason IS NULL AND a.concept_class_id = 'ATC 5th';	

-- take ingredients indicating Calcium compounds
INSERT INTO dev_combo
SELECT DISTINCT a.concept_code,
  a.concept_name,
  'calcium compounds',
  c.concept_id,
  c.concept_name,
  CASE WHEN a.concept_name ~* '^calcium compounds' THEN 3 ELSE 4 END ::INT AS rnk
FROM concept_manual a, concept c
WHERE c.concept_name ~* '\ycalcium\y'
AND c.concept_class_id = 'Ingredient'
AND c.vocabulary_id LIKE 'RxNorm%'
AND c.concept_id NOT IN (19014944,42903945)
AND a.concept_name ~* 'calcium' AND a.concept_name ~* '\ycompound'
AND a.invalid_reason IS NULL AND a.concept_class_id = 'ATC 5th'; -- 212

-- take descendants of Laxatives
INSERT INTO dev_combo
SELECT DISTINCT a.concept_code,
  a.concept_name,
  'contact laxatives',
  c.concept_id,
  c.concept_name,
  CASE WHEN a.concept_name ~* '^contact laxatives' THEN 3 ELSE 4 END ::INT AS rnk
FROM concept_manual a, 
concept_ancestor ca
 JOIN concept c
 ON ca.descendant_concept_id = c.concept_id
 AND ca.ancestor_concept_id IN (21600537) 
 AND c.vocabulary_id LIKE 'RxNorm%'
 AND c.concept_class_id = 'Ingredient'
WHERE a.concept_name ~* 'contact' AND a.concept_name ~* 'laxatives?'
AND a.invalid_reason IS NULL AND a.concept_class_id = 'ATC 5th'; -- 22

-- take descendants of Corticosteroids
INSERT INTO dev_combo
SELECT DISTINCT  a.concept_code,
  a.concept_name,
  'corticosteroids',
  c.concept_id,
  c.concept_name,
  CASE WHEN  a.concept_name ~* '^corticosteroids?|^combinations of corticosteroids?' THEN 3 ELSE 4 END ::INT AS rnk
FROM concept_manual a, 
concept_ancestor ca
 JOIN concept c
 ON ca.descendant_concept_id = c.concept_id
 AND ca.ancestor_concept_id IN (21605042, 21605164, 21605200, 21605165, 21605199, 21601607, 975125) 
 AND c.vocabulary_id LIKE 'RxNorm%'
 AND c.concept_class_id = 'Ingredient'
WHERE a.concept_name ~* 'corticosteroids?'
AND a.invalid_reason IS NULL AND a.concept_class_id = 'ATC 5th';  -- 608

-- take descendants of Cough suppressants
INSERT INTO dev_combo
SELECT DISTINCT  a.concept_code,
  a.concept_name,
  'cough suppressants',
  c.concept_id,
  c.concept_name,
  CASE WHEN a.concept_name ~* '^cough suppressants|^other cough suppressants' THEN 3 ELSE 4 END ::INT AS rnk
FROM concept_manual a, 
concept_ancestor ca
 JOIN concept c
 ON ca.descendant_concept_id = c.concept_id
 AND ca.ancestor_concept_id IN (21603440, 21603366, 21603409, 21603395, 21603436) 
 AND c.vocabulary_id LIKE 'RxNorm%'
 AND c.concept_class_id = 'Ingredient'
 AND c.concept_id NOT IN (943191,1139042,1189220,1781321,19008366,19039512,19041843,19050346,19058933,19071861,19088167,19095266,42904041)
 WHERE a.concept_name ~* 'cough' AND a.concept_name ~* 'suppressants?'
AND a.invalid_reason IS NULL AND a.concept_class_id = 'ATC 5th';
       
-- take descendants of Diuretics
INSERT INTO dev_combo
SELECT DISTINCT  a.concept_code,
  a.concept_name,
  'diuretics',
  c.concept_id,
  c.concept_name,
  CASE WHEN a.concept_name ~* '^diuretics' THEN 3 ELSE 4 END ::INT AS rnk
FROM concept_manual a, concept_ancestor ca
 JOIN concept c
 ON ca.descendant_concept_id = c.concept_id
 AND ca.ancestor_concept_id = 21601461 
 AND c.vocabulary_id LIKE 'RxNorm%'
 AND c.concept_class_id = 'Ingredient'
 WHERE a.concept_name ~* 'diuretics?'
AND a.invalid_reason IS NULL AND a.concept_class_id = 'ATC 5th'; -- 2378

-- take descendants of Magnesium (different salts IN combination)
INSERT INTO dev_combo
SELECT DISTINCT  a.concept_code,
  a.concept_name,
  'magnesium (different salts IN combination)',
  c.concept_id,
  c.concept_name,
  CASE WHEN  a.concept_name ~* '^magnesium \(different salts IN combination\)' THEN 3 ELSE 4 END ::INT AS rnk
FROM concept_manual a, -- ATC
concept_ancestor ca
 JOIN concept c -- Rx
 ON ca.descendant_concept_id = c.concept_id
 AND ca.ancestor_concept_id IN (21600892) 
 AND c.vocabulary_id LIKE 'RxNorm%'
 AND c.concept_class_id = 'Ingredient'
  WHERE a.concept_name ~* 'magnesium' AND a.concept_name ~* 'salt'
AND a.invalid_reason IS NULL AND a.concept_class_id = 'ATC 5th';

-- take ingredients indicating Magnesium (different salts IN combination)
INSERT INTO dev_combo
SELECT DISTINCT  a.concept_code,
  a.concept_name,
  'magnesium (different salts IN combination)',
  c.concept_id,
  c.concept_name,
  CASE WHEN a.concept_name ~* '^magnesium \(different salts IN combination\)' THEN 3 ELSE 4 END ::INT AS rnk
FROM concept_manual a, concept c
  WHERE a.concept_name ~* 'magnesium' AND a.concept_name ~* 'salt'
  AND c.concept_name ~ 'magnesium' AND c.standard_concept = 'S' AND c.concept_class_id = 'Ingredient'
AND a.invalid_reason IS NULL AND a.concept_class_id = 'ATC 5th'
AND (a.concept_code, c.concept_id) NOT IN (select class_code, concept_id FROM dev_combo)
AND concept_id NOT IN (43532017, 37498676); -- magnesium cation | magnesium Mg-28

-- take ingredients indicating Multivitamins
INSERT INTO dev_combo
SELECT DISTINCT a.concept_code,
  a.concept_name,
  'multivitamins',
  c.concept_id,
  c.concept_name,
  CASE WHEN a.concept_name ~* '^multivitamins' THEN 1 ELSE 2 END ::INT AS rnk
FROM concept_manual a,
  concept c
WHERE c.concept_id = 36878782
 AND a.concept_name ~* 'multivitamins?'
AND a.invalid_reason IS NULL AND a.concept_class_id = 'ATC 5th'; -- 7
------------------------------------------------------------------

-- take descendants of Opium alkaloids WITH morphine
INSERT INTO dev_combo
SELECT DISTINCT  a.concept_code,
  a.concept_name,
  'opium alkaloids WITH morphine',
  c.concept_id,
  c.concept_name,
  CASE WHEN a.concept_name  ~* '^opium alkaloids WITH morphine' THEN 3 ELSE 4 END ::INT AS rnk
FROM concept_manual a, concept_ancestor ca
 JOIN concept c
 ON descendant_concept_id = c.concept_id
 AND ca.ancestor_concept_id IN (21604255) -- 	Natural opium alkaloids
 AND c.vocabulary_id LIKE 'RxNorm%'
 AND c.concept_class_id = 'Ingredient'
 AND c.concept_id NOT IN (19112635)
 WHERE a.concept_name  ~* 'opium alkaloids WITH morphine'
AND a.invalid_reason IS NULL AND a.concept_class_id = 'ATC 5th';

-- take descendants of Opium derivatives
INSERT INTO dev_combo
SELECT DISTINCT  a.concept_code,
  a.concept_name,
  'opium derivatives',
  c.concept_id,
  c.concept_name,
  CASE WHEN a.concept_name ~* '^opium derivatives' THEN 3 ELSE 4 END ::INT AS rnk
FROM concept_manual a, concept_ancestor ca
 JOIN concept c
 ON ca.descendant_concept_id = c.concept_id
 AND ca.ancestor_concept_id = 21603396 
 AND c.vocabulary_id LIKE 'RxNorm%'
 AND c.concept_class_id = 'Ingredient'
 AND c.concept_id NOT IN (19021930, 1201620)
 WHERE a.concept_name ~* 'opium derivatives'
AND a.invalid_reason IS NULL AND a.concept_class_id = 'ATC 5th';
 
-- take descendants of Organic nitrates
INSERT INTO dev_combo
SELECT DISTINCT  a.concept_code,
  a.concept_name,
'organic nitrates',
  c.concept_id,
  c.concept_name,
  CASE WHEN a.concept_name ~* '^organic nitrates' THEN 3 ELSE 4 END ::INT AS rnk
FROM concept_manual a, concept_ancestor ca
 JOIN concept c
 ON ca.descendant_concept_id = c.concept_id
 AND ca.ancestor_concept_id IN (21600316) 
 AND c.vocabulary_id LIKE 'RxNorm%'
 AND c.concept_class_id = 'Ingredient'
  WHERE a.concept_name ~* 'organic nitrates'
AND a.invalid_reason IS NULL AND a.concept_class_id = 'ATC 5th';
 
-- take descendants of Psycholeptics
INSERT INTO dev_combo
SELECT DISTINCT  a.concept_code,
  a.concept_name,
  'psycholeptics',
  c.concept_id,
  c.concept_name,
  CASE WHEN a.concept_name ~* '^psycholeptics' THEN 3 WHEN a.concept_name ~ 'excl\. psycholeptics' THEN 0 ELSE 4 END ::INT AS rnk -- 0 stands for excluded drugs
FROM concept_manual a, concept_ancestor ca
 JOIN concept c
 ON ca.descendant_concept_id = c.concept_id
 AND ca.ancestor_concept_id = 21604489
 AND c.vocabulary_id LIKE 'RxNorm%'
 AND c.concept_class_id = 'Ingredient'
 AND c.concept_id NOT IN (742594)
   WHERE a.concept_name ~* 'psycholeptics?' --AND class_name !~* 'excl\. psycholeptics'
AND a.invalid_reason IS NULL AND a.concept_class_id = 'ATC 5th';

-- take descendants of Selenium compounds
INSERT INTO dev_combo
SELECT DISTINCT  a.concept_code,
  a.concept_name,
'selenium compounds',
 c.concept_id,
  c.concept_name,
  CASE WHEN a.concept_name ~* '^selenium compounds' THEN 3 ELSE 4 END ::INT AS rnk
FROM concept_manual a, concept_ancestor ca
 JOIN concept c
 ON ca.descendant_concept_id = c.concept_id
 AND ca.ancestor_concept_id IN (21600908) 
 AND c.vocabulary_id LIKE 'RxNorm%'
 AND c.concept_class_id = 'Ingredient'
 WHERE a.concept_name ~* 'selenium compounds'
AND a.invalid_reason IS NULL AND a.concept_class_id = 'ATC 5th';

-- take descendants of Silver compounds
INSERT INTO dev_combo
SELECT DISTINCT  a.concept_code,
  a.concept_name,
  'silver compounds',
  c.concept_id,
  c.concept_name,
  CASE WHEN a.concept_name  ~* '^silver compounds' THEN 3 ELSE 4 END ::INT AS rnk
FROM concept_manual a, concept_ancestor ca
 JOIN concept c
 ON ca.descendant_concept_id = c.concept_id
 AND ca.ancestor_concept_id IN (21602248)
 AND c.vocabulary_id LIKE 'RxNorm%'
 AND c.concept_class_id = 'Ingredient'
  WHERE a.concept_name  ~* 'silver compounds'
AND a.invalid_reason IS NULL AND a.concept_class_id = 'ATC 5th'; 
 
-- take ingredients indicating Silver
INSERT INTO dev_combo
SELECT DISTINCT  a.concept_code,
  a.concept_name,
  'silver compounds',
  c.concept_id,
  c.concept_name,
  CASE WHEN a.concept_name  ~* '^silver compounds' THEN 3 ELSE 4 END ::INT AS rnk
FROM concept_manual a, concept c
WHERE c.vocabulary_id IN ( 'RxNorm', 'RxNorm Extension')
 AND c.concept_class_id = 'Ingredient'
 AND c.concept_name ~* 'silver\y'
 AND ('silver compounds', c.concept_id) NOT IN (select class, concept_id FROM dev_combo)
AND a.concept_name  ~* 'silver compounds'
AND a.invalid_reason IS NULL AND a.concept_class_id = 'ATC 5th';

-- take descendants of Sulfonylureas
INSERT INTO dev_combo
SELECT DISTINCT  a.concept_code,
  a.concept_name,
  'sulfonylureas',
  c.concept_id,
  c.concept_name,
  CASE WHEN a.concept_name  ~* '^sulfonylureas?' THEN 3 ELSE 4 END ::INT AS rnk
FROM concept_manual a, concept_ancestor ca
 JOIN concept c
 ON ca.descendant_concept_id = c.concept_id
 AND ca.ancestor_concept_id = 21600749 
 AND c.vocabulary_id LIKE 'RxNorm%'
 AND c.concept_class_id = 'Ingredient'
WHERE a.concept_name  ~* 'sulfonylureas?'
AND a.invalid_reason IS NULL AND a.concept_class_id = 'ATC 5th';

-- take ingredients indicating Snake venom antiserum
INSERT INTO dev_combo
SELECT DISTINCT  a.concept_code,
  a.concept_name,
  'snake venom antiserum',
  c.concept_id,
  c.concept_name,
  CASE WHEN a.concept_name  ~* '^snake venom antiserum' THEN 3 ELSE 4 END ::INT AS rnk
FROM concept_manual a,concept c
WHERE c.vocabulary_id IN ( 'RxNorm', 'RxNorm Extension')
 AND c.concept_class_id = 'Ingredient'
 AND c.standard_concept = 'S'
 AND c.concept_name ~* 'antiserum' AND c.concept_name ~* 'snake'
AND a.concept_name  ~* 'snake venom antiserum'
AND a.invalid_reason IS NULL AND a.concept_class_id = 'ATC 5th';

-- take ingredients indicating Aluminium preparations
INSERT INTO dev_combo
SELECT DISTINCT  a.concept_code,
  a.concept_name,
  'aluminium preparations',
  c.concept_id,
  c.concept_name,
  CASE WHEN a.concept_name  ~* '^aluminium preparations' THEN 3 ELSE 4 END ::INT AS rnk
FROM concept_manual a,concept c
WHERE c.vocabulary_id IN ( 'RxNorm', 'RxNorm Extension')
 AND c.concept_class_id = 'Ingredient'
 AND c.standard_concept = 'S'
 AND c.concept_name ~* 'aluminium|aluminum'
 AND a.concept_name  ~* 'aluminium preparations'
AND a.invalid_reason IS NULL AND a.concept_class_id = 'ATC 5th';
 
-- take ingredients indicating Aluminium compounds
INSERT INTO dev_combo
SELECT DISTINCT  a.concept_code,
  a.concept_name,
  'aluminium compounds',
  c.concept_id,
  c.concept_name,
  CASE WHEN a.concept_name  ~* '^aluminium compounds' THEN 3 ELSE 4 END ::INT AS rnk
FROM concept_manual a,concept c
WHERE c.vocabulary_id IN ( 'RxNorm', 'RxNorm Extension')
 AND c.concept_class_id = 'Ingredient'
 AND c.standard_concept = 'S'
  AND c.concept_name ~* 'aluminium|aluminum' 
  AND a.concept_name  ~* 'aluminium compounds'
AND a.invalid_reason IS NULL AND a.concept_class_id = 'ATC 5th';
 
-- take ingredients indicating Lactic acid producing organisms
INSERT INTO dev_combo
SELECT DISTINCT  a.concept_code,
  a.concept_name,
  'lactic acid producing organisms',
  c.concept_id,
  c.concept_name,
  CASE WHEN a.concept_name  ~* '^lactic acid producing organisms' THEN 3 ELSE 4 END ::INT AS rnk
FROM concept_manual a, concept c
WHERE c.vocabulary_id IN ( 'RxNorm', 'RxNorm Extension')
 AND c.concept_class_id = 'Ingredient'
 AND c.standard_concept = 'S'
  AND c.concept_name ~* 'lactobacil' 
   AND a.concept_name  ~* 'lactic acid producing organisms'
AND a.invalid_reason IS NULL AND a.concept_class_id = 'ATC 5th';
 
-- take ingredients indicating Lactobacillus  
INSERT INTO dev_combo
SELECT DISTINCT  a.concept_code,
  a.concept_name,
  'lactobacillus',
  c.concept_id,
  c.concept_name,
  CASE WHEN a.concept_name  ~* '^lactobacillus' THEN 3 ELSE 4 END ::INT AS rnk
FROM concept_manual a, concept c
WHERE c.vocabulary_id IN ( 'RxNorm', 'RxNorm Extension')
 AND c.concept_class_id = 'Ingredient'
 AND c.standard_concept = 'S'
  AND c.concept_name ~* 'lactobacil' 
    AND a.concept_name  ~* 'lactobacillus'
AND a.invalid_reason IS NULL AND a.concept_class_id = 'ATC 5th';
  
-- take ingredients indicating Magnesium compounds
INSERT INTO dev_combo
SELECT DISTINCT  a.concept_code,
  a.concept_name,
  'magnesium compounds',
  c.concept_id,
  c.concept_name,
  CASE WHEN a.concept_name  ~* '^magnesium compounds' THEN 3 ELSE 4 END ::INT AS rnk
FROM concept_manual a,concept c
WHERE c.vocabulary_id IN ( 'RxNorm', 'RxNorm Extension')
 AND c.concept_class_id = 'Ingredient'
 AND c.standard_concept = 'S'
  AND c.concept_name ~* 'magnesium'
     AND a.concept_name  ~* 'magnesium compounds'
AND a.invalid_reason IS NULL AND a.concept_class_id = 'ATC 5th'; 
  
-- take ingredients indicating Grass pollen
INSERT INTO dev_combo
SELECT DISTINCT  a.concept_code,
  a.concept_name,
  'grass pollen',
  c.concept_id,
  c.concept_name,
  CASE WHEN a.concept_name  ~* '^grass pollen' THEN 3 ELSE 4 END ::INT AS rnk
FROM concept_manual a,concept c
WHERE c.vocabulary_id IN ( 'RxNorm', 'RxNorm Extension')
 AND c.concept_class_id = 'Ingredient'
 AND c.standard_concept = 'S'
  AND a.concept_name  ~* 'grass' AND c.concept_name ~* 'pollen' 
 AND a.concept_name  ~* 'grass pollen'
AND a.invalid_reason IS NULL AND a.concept_class_id = 'ATC 5th';
  
-- take ingredients indicating Oil
INSERT INTO dev_combo
SELECT DISTINCT  a.concept_code,
  a.concept_name,
  'oil',
  c.concept_id,
  c.concept_name,
  3 -- hardcoded
  FROM concept_manual a,
  concept c
WHERE c.vocabulary_id IN ('RxNorm','RxNorm Extension')
AND c.concept_class_id = 'Ingredient'
AND c.standard_concept = 'S'
AND c.concept_name ~* '\yoil\y|\yoleum\y'
AND a.concept_name  ~* '^oil'
AND a.invalid_reason IS NULL AND a.concept_class_id = 'ATC 5th'; -- 475

--select * from concept_manual where concept_name  ~* 'oil';

-- take ingredients indicating Flowers
INSERT INTO dev_combo
SELECT DISTINCT  a.concept_code,
  a.concept_name,
  'flowers',
  c.concept_id,
  c.concept_name,
  CASE WHEN a.concept_name  ~* '^flowers' THEN 3 ELSE 4 END ::INT AS rnk
FROM concept_manual a, concept c
WHERE c.vocabulary_id IN ( 'RxNorm', 'RxNorm Extension')
 AND c.concept_class_id = 'Ingredient'
 AND c.standard_concept = 'S'
  AND c.concept_name ~* '\yflower\y' AND c.concept_name ~* 'extract'
   AND a.concept_name  ~* '^flowers'
AND a.invalid_reason IS NULL AND a.concept_class_id = 'ATC 5th';
  
-- take ingredients indicating Fumaric acid derivatives
INSERT INTO dev_combo
SELECT DISTINCT  a.concept_code,
  a.concept_name,
  'fumaric acid derivatives',
  c.concept_id,
  c.concept_name,
  CASE WHEN a.concept_name  ~* '^fumaric acid derivatives' THEN 3 ELSE 4 END ::INT AS rnk
FROM concept_manual a,
    concept c
WHERE c.vocabulary_id IN ( 'RxNorm', 'RxNorm Extension')
 AND c.concept_class_id = 'Ingredient'
 AND c.standard_concept = 'S'
  AND c.concept_name ~* 'fumarate\y'
 AND a.concept_name  ~* 'fumaric acid derivatives'
AND a.invalid_reason IS NULL AND a.concept_class_id = 'ATC 5th';
  
-- take ingredients indicating Glycerol	
INSERT INTO dev_combo
SELECT DISTINCT  a.concept_code,
  a.concept_name,
  'glycerol',
  c.concept_id,
  c.concept_name,
  CASE WHEN a.concept_name  ~* '^glycerol' THEN 3 ELSE 4 END ::INT AS rnk
FROM concept_manual a,concept c
WHERE c.vocabulary_id IN ( 'RxNorm', 'RxNorm Extension')
 AND c.concept_class_id = 'Ingredient'
 AND c.standard_concept = 'S'
  AND c.concept_name ~* 'glycerol\y'
  AND a.concept_name  ~* 'glycerol'
AND a.invalid_reason IS NULL AND a.concept_class_id = 'ATC 5th';
 
-- take descendants of Proton pump inhibitors
INSERT INTO dev_combo
SELECT DISTINCT  a.concept_code,
  a.concept_name,
  'proton pump inhibitors',
  c.concept_id,
  c.concept_name,
  CASE WHEN a.concept_name  ~* '^proton pump inhibitors' THEN 3 ELSE 4 END ::INT AS rnk
FROM concept_manual a, concept_ancestor s
 JOIN concept c
 ON descendant_concept_id = c.concept_id AND c.concept_class_id = 'Ingredient' AND c.standard_concept = 'S'
 AND ancestor_concept_id IN (21600095) 
 WHERE a.concept_name ~* 'proton pump inhibitors?'
AND a.invalid_reason IS NULL AND a.concept_class_id = 'ATC 5th';
 
-- take descendants of Thiazides
INSERT INTO dev_combo
SELECT DISTINCT  a.concept_code,
  a.concept_name,
  'thiazides',
  c.concept_id,
  c.concept_name,
  CASE WHEN a.concept_name ~* '^thiazides' THEN 3 ELSE 4 END ::INT AS rnk
FROM concept_manual a, concept_ancestor ca
 JOIN concept c
 ON ca.descendant_concept_id = c.concept_id AND c.concept_class_id = 'Ingredient' AND c.standard_concept = 'S'
 AND ca.ancestor_concept_id IN (21601463) 
 WHERE a.concept_name ~* 'thiazides'
AND a.invalid_reason IS NULL AND a.concept_class_id = 'ATC 5th'; -- 160

-- take ingredients indicating Electrolytes
 INSERT INTO dev_combo
SELECT DISTINCT a.concept_code,
  a.concept_name,
  'electrolytes',
  c.concept_id,
  c.concept_name,
  3 -- hardcoded rank for electrolytes (no 4)
  FROM concept_manual a,
  concept c
WHERE c.vocabulary_id IN ( 'RxNorm', 'RxNorm Extension')
 AND c.concept_class_id = 'Ingredient'
 AND c.standard_concept = 'S'
  AND c.concept_name ~* ('^magnesium sulfate|^ammonium chloride|^sodium chloride|^sodium acetate|^magnesium chloride^|potassium lactate|^sodium glycerophosphate|^magnesium phosphate|^potassium chloride|^calcium chloride'
  || '^sodium bicarbonate|^hydrochloric acid|^potassium acetate|^zinc chloride|^sodium phosphate|^potassium bicarbonate|^succinic acid|^sodium lactate|^sodium gluconate|^sodium fumarate')
  AND a.concept_name ~* 'electrolytes'
AND a.invalid_reason IS NULL AND a.concept_class_id = 'ATC 5th';
 
-- bismuth preparations
INSERT INTO dev_combo
SELECT DISTINCT  a.concept_code,
  a.concept_name,
  'bismuth preparations',
  c.concept_id,
  c.concept_name,
  3 -- hardcoded rank for bismuth preparations (no 4)
  FROM concept_manual a,concept c
WHERE c.vocabulary_id IN ( 'RxNorm', 'RxNorm Extension')
 AND c.concept_class_id = 'Ingredient'
 AND c.standard_concept = 'S'
  AND c.concept_name ~* ('\ybismuth')
  AND a.concept_name ~* 'bismuth preparations'
AND a.invalid_reason IS NULL AND a.concept_class_id = 'ATC 5th';
 
-- artificial tears 
INSERT INTO dev_combo
SELECT DISTINCT  a.concept_code,
  a.concept_name,
  'artificial tears',
  c.concept_id,
  c.concept_name,
  3 -- hardcoded rank 
  FROM concept_manual a,concept c
WHERE c.vocabulary_id IN ( 'RxNorm', 'RxNorm Extension')
 AND c.standard_concept = 'S'
  AND c.concept_name ~* 'carboxymethylcellulose$|carboxypolymethylene|polyvinyl alcohol$|hydroxypropyl methylcellulose$|^hypromellose$|hydroxypropyl cellulose|^hyaluronate'
 AND c.concept_class_id = 'Ingredient' 
  AND a.concept_name ~* 'artificial tears'
AND a.invalid_reason IS NULL AND a.concept_class_id = 'ATC 5th'; -- 23
 
-- potassium-sparing agents	
INSERT INTO dev_combo
SELECT DISTINCT  a.concept_code,
  a.concept_name,
  'potassium-sparing agents',
  c.concept_id,
  c.concept_name,
  CASE WHEN a.concept_name ~* '^potassium-sparing agents' THEN 3 ELSE 4 END ::INT AS rnk
FROM concept_manual a, concept c
WHERE c.vocabulary_id IN ( 'RxNorm', 'RxNorm Extension')
 AND c.concept_class_id = 'Ingredient'
 AND c.standard_concept = 'S'
  AND c.concept_name ~* '\yamiloride|triamterene|spironolactone|eplerenone|finerenone|canrenone|canrenoic acid'
  AND a.concept_name ~* 'potassium-sparing agents'
AND a.invalid_reason IS NULL AND a.concept_class_id = 'ATC 5th';

-- 19050016	4125	ethiodized oil
INSERT INTO dev_combo
SELECT DISTINCT  a.concept_code,
  a.concept_name,
  'ethyl esters of iodised fatty acids',
  c.concept_id,
  c.concept_name,
  1 -- hradcoded
FROM concept_manual a, concept c
WHERE c.vocabulary_id IN ( 'RxNorm', 'RxNorm Extension')
 AND c.concept_class_id = 'Ingredient'
 AND c.standard_concept = 'S'
  AND c.concept_name ~* 'ethiodized oil'
  AND a.concept_name ~* '^ethyl esters of iodised fatty acids'
AND a.invalid_reason IS NULL AND a.concept_class_id = 'ATC 5th'; -- 1 
 
-- excl\.trimethoprim
INSERT INTO dev_combo
SELECT DISTINCT  a.concept_code,
  a.concept_name,
  'excl. trimethoprim',
  c.concept_id,
  c.concept_name,
  0 -- hardcoded rank
  FROM concept_manual a, -- ATC
        concept c
WHERE c.vocabulary_id IN ( 'RxNorm', 'RxNorm Extension')
 AND c.concept_class_id = 'Ingredient'
 AND c.standard_concept = 'S'
  AND c.concept_name ~* 'trimethoprim'
  AND a.concept_name ~* 'excl. trimethoprim'
AND a.invalid_reason IS NULL AND a.concept_class_id = 'ATC 5th';
 
-- fix Vitamin D AND analogues IN combination
UPDATE dev_combo
 SET rnk = 3
WHERE rnk = 1
AND class_code = 'A11CC20';

-- fix erroneous rnk of 1 for Ingredient groups 
UPDATE dev_combo
 SET rnk = 3
WHERE class_code IN (SELECT class_code FROM dev_combo WHERE rnk = 1)
AND class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 2)
AND class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 4)
AND class_code IN (SELECT class_code FROM dev_combo WHERE rnk = 3)
AND rnk = 1;

DELETE
FROM dev_combo
WHERE class_code = 'A06AG11'
AND class_name = 'sodium lauryl sulfoacetate, incl. combinations'
AND concept_name = 'sodium'
AND rnk = 1; -- 0

DELETE
FROM dev_combo
WHERE class_code = 'A01AA51'
AND class_name = 'sodium fluoride, combinations'
AND concept_name = 'sodium'
AND rnk = 1; --0 

DELETE
FROM dev_combo
WHERE class_code = 'A06AB58'
AND class_name = 'sodium picosulfate, combinations'
AND concept_name = 'sodium'
AND rnk = 1; -- 0

DELETE
FROM dev_combo
WHERE class_code = 'B05XA06'
AND class_name = 'potassium phosphate, incl. combinations WITH other potassium salts'
AND concept_name = 'potassium'
AND rnk = 1;--0

DELETE
FROM dev_combo
WHERE class_code = 'A12BA51'
AND class_name = 'potassium chloride, combinations'
AND concept_name = 'potassium'
AND rnk = 1;--0

DELETE
FROM dev_combo
WHERE class_code = 'C01DA58'
AND class_name = 'isosorbide dinitrate, combinations'
AND concept_name = 'isosorbide'
AND rnk = 1; --0

-- fix erroneous rnk of 3 for J07AG53
UPDATE dev_combo
 SET rnk = 1
WHERE class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 1)
AND class_code IN (SELECT class_code FROM dev_combo WHERE rnk = 2)
AND class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 4)
AND class_code IN (SELECT class_code FROM dev_combo WHERE rnk = 3)
AND rnk = 3; -- 0

DELETE
FROM dev_combo
WHERE class_code = 'B03AD01'
AND rnk = 4; -- 0

INSERT INTO dev_combo
SELECT DISTINCT class_code,
  class_name,
  'codeine',
  1189596,
  'dihydrocodeine',
  1
FROM dev_combo
WHERE class_code = 'N02AA59'; 

-- erroneous map to bismuth
DELETE
FROM dev_combo
WHERE class_code = 'A02BD08'
AND   class = 'bismuth subcitrate, tetracycline'
AND   concept_id = 19025138; --0 

-- erroneous map to Pentaerythritol Distearate
DELETE
FROM dev_combo
WHERE class_code = 'C01DA55'
AND   class = ''
AND   concept_id = 42903512; -- 0

-- erroneous map to Potassium
DELETE
FROM dev_combo
WHERE class_code = 'B05XA06'
AND   class = 'potassium phosphate, incl. combinations with other potassium salts'
AND   concept_id = 19049024; -- 0

-- erroneous map to tenofovir
DELETE
FROM dev_combo
WHERE class_code = 'J05AR03'
AND   class = 'tenofovir disoproxil'
AND   concept_id = 19011093; -- 0

-- remove doubling ingredients with different rank, remaining those which are Primary lateral
DELETE
FROM dev_combo
WHERE (class_code,concept_id,rnk) IN (SELECT a.class_code,
                                       a.concept_id,
                                       a.rnk
                                FROM dev_combo a
                                  JOIN dev_combo b
                                    ON a.class_code = b.class_code
                                   AND a.concept_id = b.concept_id
                                WHERE a.rnk > 1
                                AND   b.rnk = 1); -- 20
                                
UPDATE dev_combo
   SET rnk = 3
WHERE class_code = 'A07FA51'
AND   class_name = 'lactic acid producing organisms, combinations'
AND   concept_id = 19136028
AND   concept_name = 'Saccharomyces cerevisiae'; -- 0

DELETE
FROM dev_combo
WHERE class_name ~ 'antiinfectives'
AND   rnk = 4
AND   concept_id IN (19010309,19136048,1036884,19049024,989878,961145,19018544,917006,914335); -- 13

UPDATE dev_combo
   SET rnk = 3
WHERE class_name ~ 'lactic acid producing organisms'
AND   rnk = 4
AND   concept_name ~* 'Saccharomyces|Bacillus|Bifidobacterium|Enterococcus|Escherichia|Streptococcus'; -- 9

DELETE
FROM dev_combo
WHERE class_name ~ 'lactic acid producing organisms'
AND   rnk = 4;

UPDATE dev_combo
   SET rnk = 3
WHERE class_name ~ 'opium derivatives'
AND   rnk = 1;

UPDATE dev_combo
   SET rnk = 3
WHERE (class_code,concept_id) IN (SELECT a.class_code,
                                         a.concept_id
                                  FROM dev_combo a
                                    JOIN dev_combo b
                                      ON b.class_code = a.class_code
                                     AND a.rnk <> b.rnk
                                     AND a.concept_id = b.concept_id
                                  WHERE (a.class_Code,a.concept_name) IN (SELECT class_code,
                                                                                 concept_name
                                                                          FROM dev_combo
                                                                          GROUP BY class_code,
                                                                                   concept_name
                                                                          HAVING COUNT(1) > 1)
                                  AND   (b.class_Code,b.concept_name) IN (SELECT class_code,
                                                                                 concept_name
                                                                          FROM dev_combo
                                                                          GROUP BY class_code,
                                                                                   concept_name
                                                                          HAVING COUNT(1) > 1)
                                  AND   a.class_code = 'S03AA30'
                                  AND   a.rnk = 4)
AND   rnk = 4;

DELETE
FROM dev_combo
WHERE class_code = 'R05FB01'
AND   class_name = 'cough suppressants and mucolytics'
AND   class = 'cough suppressants'
AND   concept_id = 19057932
AND   rnk = 3;

UPDATE dev_combo
   SET rnk = 4
WHERE class_code = 'R05FB01'
AND   class_name = 'cough suppressants and mucolytics'
AND   class = 'cough suppressants'
AND   concept_id = 19071999
AND   rnk = 3;

UPDATE dev_combo
   SET rnk = 3
WHERE class_code = 'S02AA30'
AND   class_name = 'antiinfectives, combinations'
AND   class = ''
AND   concept_id = 19006842
AND   rnk = 4;

UPDATE dev_combo
   SET rnk = 4
WHERE class_code = 'J01RA02'
AND   class = 'sulfonamides'
AND   concept_id = 1790868
AND   rnk = 3;

UPDATE dev_combo
   SET rnk = 4
WHERE class_code = 'J01RA02'
AND   class = 'sulfonamides'
AND   concept_id = 1734104
AND   rnk = 3;

UPDATE dev_combo
   SET rnk = 4
WHERE class_code = 'J01RA02'
AND   class = 'sulfonamides'
AND   concept_id = 1748975
AND   rnk = 3;

UPDATE dev_combo
   SET rnk = 4
WHERE class_code = 'J01RA02'
AND   class = 'sulfonamides'
AND   concept_id = 1778162
AND   rnk = 3;

UPDATE dev_combo
   SET rnk = 4
WHERE class_code = 'J01RA02'
AND   class = 'sulfonamides'
AND   concept_id = 1797513
AND   rnk = 3;

UPDATE dev_combo
   SET rnk = 4
WHERE class_code = 'J01RA02'
AND   class = 'sulfonamides'
AND   concept_id = 1754994
AND   rnk = 3;

UPDATE dev_combo
   SET rnk = 4
WHERE class_code = 'J01RA02'
AND   class = 'sulfonamides'
AND   concept_id = 1742253
AND   rnk = 3;

UPDATE dev_combo
   SET rnk = 4
WHERE class_code = 'J01RA02'
AND   class = 'sulfonamides'
AND   concept_id = 1707164
AND   rnk = 3;

UPDATE dev_combo
   SET rnk = 4
WHERE class_code = 'J01RA02'
AND   class = 'sulfonamides'
AND   concept_id = 1721543
AND   rnk = 3;

UPDATE dev_combo
   SET rnk = 4
WHERE class_code = 'J01RA02'
AND   class = 'sulfonamides'
AND   concept_id = 923081
AND   rnk = 3;

UPDATE dev_combo
   SET rnk = 4
WHERE class_code = 'J01RA02'
AND   class = 'sulfonamides'
AND   concept_id = 19023254
AND   rnk = 3;
UPDATE dev_combo
   SET rnk = 4
WHERE class_code = 'J01RA02'
AND   class = 'sulfonamides'
AND   concept_id = 19024197
AND   rnk = 3;

UPDATE dev_combo
   SET rnk = 4
WHERE class_code = 'J01RA02'
AND   class = 'sulfonamides'
AND   concept_id = 19037983
AND   rnk = 3;

UPDATE dev_combo
   SET rnk = 4
WHERE class_code = 'J01RA02'
AND   class = 'sulfonamides'
AND   concept_id = 19070251
AND   rnk = 3;

UPDATE dev_combo
   SET rnk = 4
WHERE class_code = 'J01RA02'
AND   class = 'sulfonamides'
AND   concept_id = 1836948
AND   rnk = 3;
UPDATE dev_combo
   SET rnk = 4
WHERE class_code = 'J01RA02'
AND   class = 'sulfonamides'
AND   concept_id = 1702559
AND   rnk = 3;

UPDATE dev_combo
   SET rnk = 4
WHERE class_code = 'R05FB02'
AND   class = 'cough suppressants'
AND   concept_id = 43012226
AND   rnk = 3;

UPDATE dev_combo
   SET rnk = 4
WHERE class_code = 'R05FB02'
AND   class = 'cough suppressants'
AND   concept_id = 912362
AND   rnk = 3;

UPDATE dev_combo
   SET rnk = 4
WHERE class_code = 'R05FB02'
AND   class = 'cough suppressants'
AND   concept_id = 19060831
AND   rnk = 3;

UPDATE dev_combo
   SET rnk = 3
WHERE class_code = 'R05FB02'
AND   class = ''
AND   concept_id = 1140088
AND   rnk = 4;

UPDATE dev_combo
   SET rnk = 4
WHERE class_code = 'R05FB02'
AND   class = 'cough suppressants'
AND   concept_id = 19063951
AND   rnk = 3;

UPDATE dev_combo
   SET rnk = 4
WHERE class_code = 'R05FB02'
AND   class = 'cough suppressants'
AND   concept_id = 1103137
AND   rnk = 3;
/*******************************************
**** ADD ODDMENTS TO THE INPUT TABLES *****
********************************************/
-- add links between ATC Classes indicating Ingredient Groups AND ATC Drug Attributes in the form of OMOP Ingredient names using dev_combo table
INSERT INTO internal_relationship_stage
(concept_code_1, concept_code_2)
SELECT DISTINCT class_code, -- ATC
  c.concept_name -- OMOP Ingredient name AS an ATC Drug Attribute code
FROM dev_combo a
 JOIN concept c ON c.concept_id = a.concept_id AND c.standard_concept = 'S'
AND (a.class_code, c.concept_name) NOT IN (
SELECT SPLIT_PART(concept_code_1, ' ', 1),
  concept_code_2
FROM internal_relationship_stage)
WHERE LENGTH (class_code) = 7
AND rnk <> 0;

-- add more links between ATC Classes indicating Ingredient Groups AND ATC Drug Attributes in the form of OMOP Ingredient names using dev_combo table
INSERT INTO internal_relationship_stage
(concept_code_1, concept_code_2)
SELECT DISTINCT class_code, -- ATC
  c.concept_name -- OMOP Ingredient name AS an ATC Drug Attribute code
FROM dev_combo a
 JOIN concept c ON lower(c.concept_name) = lower(a.concept_name)
 AND c.standard_concept = 'S'
AND (a.class_code, c.concept_name) NOT IN (
SELECT SPLIT_PART(concept_code_1, ' ', 1),
  concept_code_2
FROM internal_relationship_stage)
WHERE LENGTH (class_code) = 7 
AND rnk <> 0;

-- add ATC Groupers to DCS AS Drug Products
INSERT INTO drug_concept_stage
( concept_name,
 vocabulary_id,
 concept_class_id,
 standard_concept,
 concept_code,
 possible_excipient,
 domain_id,
 valid_start_date,
 valid_end_date
)
SELECT DISTINCT b.class_name, -- ATC code+name
  'ATC',
  'Drug Product',
  NULL,
  concept_code_1,
  NULL,
  'Drug', 
  TO_DATE ('19700101', 'YYYYMMDD') AS valid_start_date,
  TO_DATE('20991231','YYYYMMDD') AS valid_end_date
FROM internal_relationship_stage a
JOIN class_drugs_scraper b ON b.class_code = SPLIT_PART(a.concept_code_1, ' ', 1)
WHERE concept_code_1 NOT IN (select concept_code FROM drug_concept_stage);

-- add ATC Drug Attributes IN the form of Standard Ingredient names using internal_relationship_stage
INSERT INTO drug_concept_stage
( concept_name,
 vocabulary_id,
 concept_class_id,
 standard_concept,
 concept_code,
 possible_excipient,
 domain_id,
 valid_start_date,
 valid_end_date)
SELECT DISTINCT concept_code_2 AS concept_name, -- ATC pseudo-attribute IN the form of OMOP Dose Form name
  'ATC' AS vocabulary_id,
  c.concept_class_id AS concept_class_id,
  NULL AS standard_concept, -- check all standard_concept values
  concept_code_2 AS concept_code,
  NULL AS possible_excipient,
  'Drug' AS domain_id,
  TO_DATE ('19700101', 'YYYYMMDD') AS valid_start_date,
  TO_DATE('20991231','YYYYMMDD') AS valid_end_date
FROM internal_relationship_stage,
  concept c WHERE lower(c.concept_name) = lower(concept_code_2)
AND concept_class_id = 'Ingredient'
AND vocabulary_id IN ('RxNorm', 'RxNorm Extension')
AND invalid_reason IS NULL
AND concept_code_2 NOT IN (select concept_code FROM drug_concept_stage);
/***************************************
******* relationship_to_concept ********
****************************************/
-- add mappings of ATC Drug Attributes to OMOP Equivalents
TRUNCATE relationship_to_concept;
ALTER TABLE relationship_to_concept ALTER COLUMN concept_code_1 TYPE VARCHAR;

-- add links between ATC Drug Attributes AND their OMOP equivalents
INSERT INTO relationship_to_concept
( concept_code_1, vocabulary_id_1, concept_id_2)
SELECT DISTINCT concept_code_2 AS concept_code_1, -- ATC attribute IN the form of OMOP Dose Form OR Ingredient name
  'ATC' AS vocabulary_id_1,
  c.concept_id AS concept_id_2 -- OMOP concept_id
FROM internal_relationship_stage
 JOIN concept c
 ON lower(concept_code_2) = lower(c.concept_name)
 AND c.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
 AND c.invalid_reason IS NULL;
 
-- run load_interim.sql
