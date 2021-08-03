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
/********************
***** RX COMBO *****
*********************/
-- create a table with aggregated RxE ingredients: rx_combo
DROP TABLE IF EXISTS rx_combo;
CREATE TABLE rx_combo AS
SELECT drug_concept_id,
       string_agg(ingredient_concept_id::VARCHAR, '-' ORDER BY ingredient_concept_id) AS i_combo
FROM devv5.drug_strength
       JOIN devv5.concept ON concept_id = drug_concept_id AND
                       concept_class_id IN ('Clinical Drug Form', 'Ingredient') -- 'Clinical Drug Comp' doesn't exist in ATCs
GROUP BY drug_concept_id ;
/*************************
***** CLASS TO DRUG ******
**************************/    
-- assemble a table containing ATC Drug Classes which are hierarchically connected to RxN/RxE Drug Products via 'ATC - RxNorm' relationships (resembles Subsumes).
-- Monocomponent ATC classes
DROP TABLE if exists class_to_drug_new;
CREATE TABLE class_to_drug_new 
AS
(WITH t1
AS
(SELECT *
FROM concept_manual
WHERE invalid_reason IS NULL
AND   concept_class_id = 'ATC 5th'
AND   concept_code NOT IN (SELECT class_code FROM dev_combo)),
-- get attributes
t2
AS
(SELECT DISTINCT a.concept_code AS class_code,
       a.concept_name AS class_name,
       d.concept_code AS ing_name,
       d2.concept_code AS df_name
FROM t1 a
  JOIN internal_relationship_stage i ON SUBSTRING (i.concept_code_1,'\w+') = a.concept_code
  JOIN drug_concept_stage d
    ON d.concept_code = i.concept_code_2
   AND d.concept_class_id = 'Ingredient'
  LEFT JOIN internal_relationship_stage i2 ON SUBSTRING (i2.concept_code_1,'\w+') = a.concept_code
  JOIN drug_concept_stage d2
    ON d2.concept_code = i2.concept_code_2
   AND d2.concept_class_id = 'Dose Form')
SELECT DISTINCT class_code,
       class_name,
       c.*,
       1 AS concept_order,
       'Monocomponent ATC Class' as order_desc
FROM t2 a
  JOIN rx_all_combo b
    ON lower (b.ing_name) = lower (a.ing_name)
   AND lower (b.df_name) = lower (a.df_name)
   AND d_name !~ ' / '
  JOIN concept c
    ON c.concept_id = b.d_id
   AND c.standard_concept = 'S'
WHERE class_code NOT IN (SELECT class_code FROM dev_combo));

-- add everything - greedy version
INSERT INTO class_to_drug_new
WITH t1
AS
(SELECT *
FROM concept_manual
WHERE invalid_reason IS NULL
AND   concept_class_id = 'ATC 5th'),
-- get attributes
t2
AS
(SELECT DISTINCT a.concept_code AS class_code,
       a.concept_name AS class_name,
       d.concept_code AS ing_name,
       d2.concept_code AS df_name
FROM t1 a
  JOIN internal_relationship_stage i ON SUBSTRING (i.concept_code_1,'\w+') = a.concept_code
  JOIN drug_concept_stage d
    ON d.concept_code = i.concept_code_2
   AND d.concept_class_id = 'Ingredient'
  LEFT JOIN internal_relationship_stage i2 ON SUBSTRING (i2.concept_code_1,'\w+') = a.concept_code
  JOIN drug_concept_stage d2
    ON d2.concept_code = i2.concept_code_2
   AND d2.concept_class_id = 'Dose Form')
SELECT DISTINCT class_code,
       class_name,
       c.*,
       2 AS concept_order,
       'Greedy Monocomponent ATC Class' as order_desc
FROM t2 a
  JOIN rx_all_combo b
    ON lower (b.ing_name) = lower (a.ing_name)
   AND lower (b.df_name) = lower (a.df_name)
  JOIN concept c
    ON c.concept_id = b.d_id
   AND c.standard_concept = 'S'
   AND (class_code,c.concept_id) NOT IN (SELECT class_code,concept_id FROM class_to_drug_new)
   AND class_code NOT IN (SELECT class_code FROM dev_combo);
   
/***** PREPARE ATC COMBO CLASSES ******/

-- separate pure ATC Combo Classes with mapping: Primary lateral + Secondary lateral (rnk in (1, 2) in dev_combo)
DROP TABLE IF EXISTS case_1;
CREATE TABLE case_1 
AS
SELECT DISTINCT class_code,
       class_name,
       concept_id,
       concept_name,
       rnk
FROM dev_combo
WHERE class_code IN (SELECT class_code FROM dev_combo WHERE rnk = 1)-- Primary lateral
AND   class_code IN (SELECT class_code FROM dev_combo WHERE rnk = 2)-- Secondary lateral
AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 3)-- exclude Priamry upward
AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 4)
AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 0); -- exclude Secondary upward                      

-- separate pure ATC Combo Classes with 1 defined Ingredient: Primary lateral Ingredients in combination (rnk = 1 in dev_combo)
DROP TABLE if exists case_2;
CREATE TABLE case_2 
AS
(SELECT *
FROM dev_combo
WHERE class_code IN (SELECT class_code FROM dev_combo WHERE rnk = 1)
AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 2)
AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 3)
AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 4)
AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 0)
);

-- separate Primary lateral in combination with excluded Ingredient (rnk in (1,0) in dev_combo)
DROP TABLE if exists case_2_2;
CREATE TABLE case_2_2 
AS
(SELECT *
FROM dev_combo
WHERE class_code IN (SELECT class_code FROM dev_combo WHERE rnk = 1)
AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 2)
AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 3)
AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 4)
AND   class_code IN (SELECT class_code FROM dev_combo WHERE rnk = 0)
);
                   
-- separate Primary upward Ingredients (rnk = 3 in dev_combo)
DROP TABLE IF EXISTS case_3;
CREATE TABLE case_3 
AS
(SELECT DISTINCT class_code,
       class_name,
       concept_id,
       concept_name,
       rnk
FROM dev_combo
WHERE class_code IN (SELECT class_code FROM dev_combo WHERE rnk = 3)--  include Priamry upward
AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 1)-- exclude Primary lateral
AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 2)-- exclude Secondary lateral
AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 4)
AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 0));-- exclude Secondary upward
 
-- add the same Ingredients marked with rnk=1 to create permutations, assume that there will not be more than 3 ingredients in combination
INSERT INTO case_3 -- Primary upward
SELECT class_code, class_name, concept_id, concept_name, 1
  FROM case_3;
  
-- separate Primary upward  + Secondary upward Ingredients (rnk in (3,4) in dev_combo)
DROP TABLE IF EXISTS case_4; 
CREATE TABLE case_4 AS (select distinct 
class_code,
       class_name,
        concept_id,
concept_name,
       rnk
FROM dev_combo
WHERE class_code  IN (SELECT class_code
                         FROM dev_combo
                         WHERE rnk = 3) --  include Priamry upward
AND class_code NOT IN (SELECT class_code
                     FROM dev_combo
                     WHERE rnk = 1) -- exclude Primary lateral
AND   class_code NOT IN (SELECT class_code
                     FROM dev_combo
                     WHERE rnk = 2) -- exclude Secondary lateral
AND   class_code  IN (SELECT class_code
                         FROM dev_combo
                         WHERE rnk = 4)
and  class_code not in (select class_code from  dev_combo where rnk = 0)
);-- exclude Secondary upward

-- separate Primary upward  + Secondary upward with excluded Ingredient  (rnk in (3, 4, 0) in dev_combo)
DROP TABLE IF EXISTS case_4_2;
CREATE TABLE case_4_2 AS (select distinct 
class_code,
       class_name,
        concept_id,
concept_name,
       rnk
FROM dev_combo
WHERE class_code  IN (SELECT class_code
                         FROM dev_combo
                         WHERE rnk = 3) --  include Priamry upward
AND class_code NOT IN (SELECT class_code
                     FROM dev_combo
                     WHERE rnk = 1) -- exclude Primary lateral
AND   class_code NOT IN (SELECT class_code
                     FROM dev_combo
                     WHERE rnk = 2) -- exclude Secondary lateral
AND   class_code  IN (SELECT class_code
                         FROM dev_combo
                         WHERE rnk = 4)
and  class_code  in (select class_code from  dev_combo where rnk = 0)
);-- exclude Secondary upward

--Note, Secondary upward links cannot stand alone in combinations with unmentioned RxN/RxE Drug Product

-- Add ATC Combo Classes with mappings to class_to_drug: 
-- Primary lateral + Secondary lateral (order = 3)
INSERT INTO class_to_drug_new
WITH t1
AS
(SELECT *
FROM concept_manual
WHERE invalid_reason IS NULL
AND   concept_class_id = 'ATC 5th'),
-- get attributes
t2
AS
(SELECT DISTINCT a.concept_code AS class_code,
       a.concept_name AS class_name,
       d.concept_code AS ing_name,
       d2.concept_code AS df_name
FROM t1 a
  JOIN internal_relationship_stage i ON SUBSTRING (i.concept_code_1,'\w+') = a.concept_code
  JOIN drug_concept_stage d
    ON d.concept_code = i.concept_code_2
   AND d.concept_class_id = 'Ingredient'
  LEFT JOIN internal_relationship_stage i2 ON SUBSTRING (i2.concept_code_1,'\w+') = a.concept_code
  JOIN drug_concept_stage d2
    ON d2.concept_code = i2.concept_code_2
   AND d2.concept_class_id = 'Dose Form'
)
SELECT DISTINCT class_code,
       class_name,
       c.*,
       3 AS concept_order,
       'Primary upward + Secondary upward' as order_desc
FROM t2 a
  JOIN rx_all_combo b
    ON lower (b.ing_name) = lower (a.ing_name)
   AND lower (b.df_name) = lower (a.df_name)
  JOIN concept c
    ON c.concept_id = b.d_id
   AND c.standard_concept = 'S'
   AND (class_code,c.concept_id) NOT IN (SELECT class_code,concept_id FROM class_to_drug_new)
   AND class_code IN (SELECT class_code FROM case_2);

-- Primary upward only (order = 4)
INSERT INTO class_to_drug_new
WITH t1
AS
(SELECT *
FROM concept_manual
WHERE invalid_reason IS NULL
AND   concept_class_id = 'ATC 5th'),
-- get attributes
t2
AS
(SELECT DISTINCT a.concept_code AS class_code,
       a.concept_name AS class_name,
       d.concept_code AS ing_name,
       d2.concept_code AS df_name
FROM t1 a
  JOIN internal_relationship_stage i ON SUBSTRING (i.concept_code_1,'\w+') = a.concept_code
  JOIN drug_concept_stage d
    ON d.concept_code = i.concept_code_2
   AND d.concept_class_id = 'Ingredient'
  LEFT JOIN internal_relationship_stage i2 ON SUBSTRING (i2.concept_code_1,'\w+') = a.concept_code
  JOIN drug_concept_stage d2
    ON d2.concept_code = i2.concept_code_2
   AND d2.concept_class_id = 'Dose Form') 
SELECT DISTINCT class_code,
       class_name,
       c.*,
       4 AS concept_order,
       'Primary upward' AS order_desc
FROM t2 a
  JOIN rx_all_combo b
    ON lower (b.ing_name) = lower (a.ing_name)
   AND lower (b.df_name) = lower (a.df_name)
  JOIN concept c
    ON c.concept_id = b.d_id
   AND c.standard_concept = 'S'
   AND (class_code,c.concept_id) NOT IN (SELECT class_code,concept_id FROM class_to_drug_new)
   AND class_code IN (SELECT class_code FROM case_3)
AND c.concept_name ~ ' / ';
                      
-- Primary lateral + Secondary lateral, more than 2 ingreds (order = 5)
INSERT INTO class_to_drug_new
WITH t1
AS
(SELECT DISTINCT a.class_code AS class_code,
       a.class_name AS class_name,
       a.concept_name AS ing_name,
       d2.concept_code AS df_name,
       rnk
FROM case_1 a
  JOIN internal_relationship_stage i2 ON SUBSTRING (i2.concept_code_1,'\w+') = a.class_code
  JOIN drug_concept_stage d2
    ON d2.concept_code = i2.concept_code_2
   AND d2.concept_class_id = 'Dose Form'
),
t2
AS
(SELECT DISTINCT class_code,
       class_name,
       c.*
FROM t1 a
  JOIN rx_all_combo b
    ON lower (b.ing_name) = lower (a.ing_name)
   AND lower (b.df_name) = lower (a.df_name)
JOIN concept c ON c.concept_id = b.d_id AND c.standard_concept = 'S' AND rnk = 1),
t3
AS
(SELECT DISTINCT a.class_code,
       a.class_name,
       a.ing_name,
       c.*
FROM t1 a
  JOIN rx_all_combo b
    ON lower (b.ing_name) = lower (a.ing_name)
   AND lower (b.df_name) = lower (a.df_name)
  JOIN concept c
    ON c.concept_id = b.d_id
   AND c.standard_concept = 'S'
   AND rnk = 2) 
 SELECT DISTINCT a.*,
       5 AS concept_order,
       'more Pr lat + Sec lat' AS order_desc
       FROM t2 a
  JOIN t3 b ON b.class_code = a.class_code
  JOIN t3 c
    ON c.class_code = a.class_code
   AND c.concept_id = b.concept_id
   AND b.ing_name <> c.ing_name
   AND a.concept_id = b.concept_id
   AND a.concept_name ~ ' / ';

-- Primary lateral + Secondary lateral, 2 ingredients
INSERT INTO class_to_drug_new
WITH t1
AS
(SELECT DISTINCT a.class_code AS class_code,
       a.class_name AS class_name,
       a.concept_name AS ing_name,
       d2.concept_code AS df_name,
       rnk
FROM case_1 a
  JOIN internal_relationship_stage i2 ON SUBSTRING (i2.concept_code_1,'\w+') = a.class_code
  JOIN drug_concept_stage d2
    ON d2.concept_code = i2.concept_code_2
   AND d2.concept_class_id = 'Dose Form'),
t2
AS
(SELECT DISTINCT class_code,
       class_name,
       c.*
FROM t1 a
  JOIN rx_all_combo b
    ON lower (b.ing_name) = lower (a.ing_name)
   AND lower (b.df_name) = lower (a.df_name)
  JOIN concept c
    ON c.concept_id = b.d_id
   AND c.standard_concept = 'S'
   AND rnk = 1),
t3
AS
(SELECT DISTINCT a.class_code,
       a.class_name,
       a.ing_name,
       c.*
FROM t1 a
  JOIN rx_all_combo b
    ON lower (b.ing_name) = lower (a.ing_name)
   AND lower (b.df_name) = lower (a.df_name)
JOIN concept c ON c.concept_id = b.d_id AND c.standard_concept = 'S' AND rnk = 2)
SELECT DISTINCT a.*,
       6 AS concept_order,
       'pr lat+sec lat 2 ingreds' as order_desc
FROM t2 a
  JOIN t3 b
    ON b.class_code = a.class_code
   AND a.concept_id = b.concept_id
   AND a.concept_name ~ ' / '
   AND a.class_code NOT IN (SELECT class_code FROM class_to_drug_new)
   AND a.concept_name !~ ' / .* / ';

-- Primary lateral only in combination (order = 7)
INSERT INTO class_to_drug_new
WITH t1
AS
(SELECT DISTINCT a.class_code AS class_code,
       a.class_name AS class_name,
       a.concept_name AS ing_name,
       d2.concept_code AS df_name,
       rnk
FROM case_2 a
  JOIN internal_relationship_stage i2 ON SUBSTRING (i2.concept_code_1,'\w+') = a.class_code
  JOIN drug_concept_stage d2
    ON d2.concept_code = i2.concept_code_2
   AND d2.concept_class_id = 'Dose Form') 
 SELECT DISTINCT class_code,
       class_name,
       c.*,
       7 AS concept_order,
       'Primary lateral only in comb.' AS order_desc
FROM t1 a
  JOIN rx_all_combo b
    ON lower (b.ing_name) = lower (a.ing_name)
   AND lower (b.df_name) = lower (a.df_name)
  JOIN concept c
    ON c.concept_id = b.d_id
   AND c.standard_concept = 'S'
   AND c.concept_name ~ ' / ';

-- Primary lateral only in combination with an excluded Ingredient (order=8)
INSERT INTO class_to_drug_new
WITH t1
AS
(SELECT DISTINCT a.class_code AS class_code,
       a.class_name AS class_name,
       a.concept_name AS ing_name,
       d2.concept_code AS df_name,
       rnk
FROM case_2_2 a
  JOIN internal_relationship_stage i2 ON SUBSTRING (i2.concept_code_1,'\w+') = a.class_code
  JOIN drug_concept_stage d2
    ON d2.concept_code = i2.concept_code_2
   AND d2.concept_class_id = 'Dose Form'),
t2 AS
(SELECT DISTINCT class_code,
       class_name,
       c.*,
       2,
       b.ing_name
FROM t1 a
  JOIN rx_all_combo b
    ON lower (b.ing_name) = lower (a.ing_name)
   AND lower (b.df_name) = lower (a.df_name)
  JOIN concept c
    ON c.concept_id = b.d_id
   AND c.standard_concept = 'S'
   AND rnk = 1)
SELECT DISTINCT class_code,
       class_name,
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
       8,
       'Primary lateral in comb with excl'
FROM t2
WHERE concept_name ~ ' / '
AND   concept_id NOT IN (SELECT d_id
                         FROM rx_all_combo a
                           JOIN t1 b
                             ON LOWER (b.ing_name) = LOWER (a.ing_name)
                            AND LOWER (b.df_name) = LOWER (a.df_name)
                            AND b.rnk = 0);

--  Primary upward only (order= 9)
INSERT INTO class_to_drug_new
WITH t1
AS
(SELECT DISTINCT a.class_code AS class_code,
       a.class_name AS class_name,
       a.concept_name AS ing_name,
       d2.concept_code AS df_name,
       rnk
FROM case_3 a
  JOIN internal_relationship_stage i2 ON SUBSTRING (i2.concept_code_1,'\w+') = a.class_code
  JOIN drug_concept_stage d2
    ON d2.concept_code = i2.concept_code_2
   AND d2.concept_class_id = 'Dose Form') 
   SELECT DISTINCT class_code,
       class_name,
       c.*,
       9,
       ' Primary upward' AS order_desc
FROM t1 a
  JOIN rx_all_combo b
    ON lower (b.ing_name) = lower (a.ing_name)
   AND lower (b.df_name) = lower (a.df_name)
  JOIN concept c
    ON c.concept_id = b.d_id
   AND c.standard_concept = 'S'
   AND c.concept_name ~ ' / ';

-- Primary upward + Secondary upward (order = 10)
INSERT INTO class_to_drug_new
WITH t1
AS
(SELECT DISTINCT a.class_code AS class_code,
       a.class_name AS class_name,
       a.concept_name AS ing_name,
       d2.concept_code AS df_name,
       rnk
FROM case_4 a
  JOIN internal_relationship_stage i2 ON SUBSTRING (i2.concept_code_1,'\w+') = a.class_code
  JOIN drug_concept_stage d2
    ON d2.concept_code = i2.concept_code_2
   AND d2.concept_class_id = 'Dose Form'),
t2
AS
(SELECT DISTINCT class_code,
       class_name,
       c.*
FROM t1 a
  JOIN rx_all_combo b
    ON lower (b.ing_name) = lower (a.ing_name)
   AND lower (b.df_name) = lower (a.df_name)
  JOIN concept c
    ON c.concept_id = b.d_id
   AND c.standard_concept = 'S'
   AND rnk = 3),
t3
AS
(SELECT DISTINCT a.class_code,
       a.class_name,
       a.ing_name,
       c.*
FROM t1 a
  JOIN rx_all_combo b
    ON lower (b.ing_name) = lower (a.ing_name)
   AND lower (b.df_name) = lower (a.df_name)
  JOIN concept c
    ON c.concept_id = b.d_id
   AND c.standard_concept = 'S'
   AND rnk = 4) 
SELECT DISTINCT a.*, 10, 'Primary upward + Secondary upward' 
FROM t2 a
  JOIN t3 b
    ON b.class_code = a.class_code
   AND a.concept_id = b.concept_id
WHERE a.concept_name ~ ' / ';
-------------------------
---- GET MORE LINKS -----
-------------------------
-- separate Primary lateral Ingredients (rnk = 1 in dev_combo)
DROP TABLE IF EXISTS t1;
CREATE UNLOGGED TABLE t1
AS
SELECT DISTINCT class_code, class_name, concept_id, concept_name, rnk
       FROM dev_combo WHERE rnk = 1 -- Primary lateral
       ;

-- separate Secondary lateral Ingredients (rnk = 2  in dev_combo)
DROP TABLE IF EXISTS t2;
CREATE UNLOGGED TABLE t2 
AS
SELECT DISTINCT class_code, class_name, concept_id, concept_name, rnk
       FROM dev_combo WHERE rnk = 2 -- Secondary lateral
       ;

-- separate Primary upward Ingredients (rnk = 3 in dev_combo)
DROP TABLE IF EXISTS t3;
CREATE UNLOGGED TABLE t3
AS
SELECT DISTINCT class_code, class_name, concept_id, concept_name, rnk
       FROM dev_combo 
WHERE rnk = 3 -- Primary upward
;

-- separate Secondary upward Ingredients (rnk = 4  in dev_combo)
DROP TABLE IF EXISTS t4;
CREATE UNLOGGED TABLE t4 
AS
SELECT DISTINCT class_code, class_name, concept_id, concept_name, rnk
       FROM dev_combo
WHERE rnk = 4; -- Secondary upward

-- create a table with aggregated ATC Ingredients per one ATC Combo Class (no more than 3 ingredients per Class is recommended)
-- add Primary lateral AND (Secondary lateral 1 AND/OR Secondary lateral 2) AND/OR Primary upward AND/OR Secondary upward
DROP TABLE if exists full_combo;
CREATE UNLOGGED TABLE full_combo 
AS(
SELECT DISTINCT a.class_code,
       a.class_name,
       a.concept_id||COALESCE('-' || b.concept_id,'') ||COALESCE('-' || c.concept_id,'') ||COALESCE('-' || c1.concept_id,'') ||COALESCE('-' || d.concept_id,'') AS i_combo
FROM t1 a
  JOIN t2 b ON b.class_code = a.class_code-- rank 2
  LEFT JOIN t2 c ON c.class_code = b.class_code-- rank 2
  LEFT JOIN t3 c1 ON c1.class_code = c.class_code-- rank 3 -- is it possible? usually there is no combinations as rnk=1 + rnk=3
  LEFT JOIN t4 d ON d.class_code = c1.class_code-- rank 4
        AND a.concept_id <> b.concept_id
        AND a.concept_id <> c.concept_id
        AND a.concept_id <> d.concept_id
        AND a.concept_id <> c1.concept_id
        AND b.concept_id <> c.concept_id
        AND b.concept_id <> c1.concept_id
        AND b.concept_id <> d.concept_id
        AND c.concept_id <> c1.concept_id
        AND c1.concept_id <> d.concept_id
ORDER BY class_code);

-- add Primary lateral AND/OR Secondary lateral AND/OR Primary upward AND/OR Secondary upward
INSERT INTO full_combo
WITH z1
AS
(SELECT DISTINCT a.class_code,
       a.class_name,
       a.concept_id||COALESCE('-' || b.concept_id,'') ||COALESCE('-' || c.concept_id,'') ||COALESCE('-' || d.concept_id,'') AS i_combo
FROM t1 a
  JOIN t2 b ON b.class_code = a.class_code-- rank 2
  LEFT JOIN t3 c ON c.class_code = b.class_code-- rank 3
  LEFT JOIN t4 d
         ON d.class_code = c.class_code-- rank 4
        AND a.concept_id <> b.concept_id
        AND a.concept_id <> c.concept_id
        AND a.concept_id <> d.concept_id
        AND b.concept_id <> c.concept_id
        AND b.concept_id <> d.concept_id
ORDER BY class_code
)
SELECT *
FROM z1
WHERE i_combo NOT IN (SELECT i_combo FROM full_combo);

-- create temporary table with Ingredient permutations - additional layer of mappings: Primary lateral AND/OR Secondary lateral 1 AND/OR Secondary lateral 2
DROP TABLE IF EXISTS permutations;
CREATE UNLOGGED TABLE permutations 
AS
SELECT distinct a.class_code, a.class_name, a.concept_id||COALESCE('-' || b.concept_id, '')||COALESCE('-' || c.concept_id, '') AS i_combo
        FROM t1 a -- from Primary lateral
LEFT JOIN t2 b ON b.class_code = a.class_code -- to the 1st Secondary lateral
LEFT JOIN t2 c ON c.class_code = a.class_code -- and the 2nd Secondary lateral
WHERE b.concept_id<>c.concept_id AND b.concept_id<>a.concept_id;

-- add newly created permutations to the full_combo table in order to enrich the set of aggregated ATC Ingredients
INSERT INTO full_combo
SELECT * FROM permutations;

--  Separate Primary lateral in combination (rnk = 1 in dev_combo)
DROP TABLE if exists ing_pr_lat_combo; -- ing_pr_lat_combo
CREATE TABLE ing_pr_lat_combo 
AS
(SELECT *
FROM dev_combo a
WHERE class_code IN (SELECT class_code FROM dev_combo WHERE rnk = 1)
AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 2)
AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 3)
AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 4)
AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 0));

-- create temporary table with all possible i_combos for Primary lateral in combinations (with unspecified drugs) 
DROP TABLE if exists ing_pr_lat_combo_to_drug;
CREATE TABLE ing_pr_lat_combo_to_drug 
AS
(WITH z1
AS
(SELECT drug_concept_id,
       REGEXP_SPLIT_TO_TABLE(i_combo,'-')::INT AS i_combo
FROM rx_combo
WHERE i_combo LIKE '%-%') 
  SELECT DISTINCT a.class_code,
       a.class_name,
       d.i_combo
FROM ing_pr_lat_combo a
  JOIN z1 b ON b.i_combo = a.concept_id
  JOIN rx_combo d ON d.drug_concept_id = b.drug_concept_id);

-- separate Primary lateral + Secondary upward  (rnk in (1,4) in dev_combo)
DROP TABLE if exists ing_pr_lat_sec_up_combo; 
CREATE TABLE ing_pr_lat_sec_up_combo 
AS
(SELECT *
FROM dev_combo a
WHERE class_code  IN (SELECT class_code FROM dev_combo WHERE rnk = 1)
AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 2)
AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 3)
AND   class_code IN (SELECT class_code FROM dev_combo WHERE rnk = 4)
AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 0)
);
-- create temporary table with all possible i_combos for Primary lateral + Secondary upward
DROP TABLE if exists ing_pr_lat_sec_up_combo_to_drug;
CREATE TABLE ing_pr_lat_sec_up_combo_to_drug 
AS
(WITH z1
AS
(SELECT drug_concept_id,
       REGEXP_SPLIT_TO_TABLE(i_combo,'-')::INT AS i_combo
FROM rx_combo
WHERE i_combo LIKE '%-%') 
SELECT DISTINCT a.class_code,
       a.class_name,
       c.i_combo
FROM ing_pr_lat_sec_up_combo a
  JOIN z1 b
    ON b.i_combo = a.concept_id
   AND a.rnk = 1
  JOIN ing_pr_lat_sec_up_combo a1
    ON a1.class_code = a.class_code
   AND a1.concept_id <> a.concept_id
  JOIN z1 j
    ON j.i_combo = a1.concept_id
   AND a1.rnk = 4
  JOIN rx_combo c
    ON c.drug_concept_id = b.drug_concept_id
   AND c.drug_concept_id = j.drug_concept_id);
 
-- separate Primary lateral in combination with excluded Ingredient: ing_pr_lat_combo_excl (rnk in (1, 0) in dev_combo))
DROP TABLE if exists ing_pr_lat_combo_excl;
CREATE TABLE ing_pr_lat_combo_excl 
AS
(SELECT *
FROM dev_combo a
WHERE class_code IN (SELECT class_code FROM dev_combo WHERE rnk = 1)
AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 2)
AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 3)
AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 4)
AND   class_code IN (SELECT class_code FROM dev_combo WHERE rnk = 0));

-- create temporary table with all possible i_combos for Primary lateral in combination with excluded Ingredient
DROP TABLE if exists ing_pr_lat_combo_excl_to_drug;
CREATE TABLE ing_pr_lat_combo_excl_to_drug 
AS
(WITH t1
AS
(SELECT drug_concept_id,
       REGEXP_SPLIT_TO_TABLE(i_combo,'-')::INT AS i_combo
FROM rx_combo
WHERE i_combo LIKE '%-%') SELECT DISTINCT a.class_code,a.class_name,d.i_combo FROM ing_pr_lat_combo_excl a JOIN t1 b ON b.i_combo = a.concept_id 
JOIN ing_pr_lat_combo_excl a1 ON a1.class_code = a.class_code AND a1.rnk <> a.rnk AND a1.rnk = 0 JOIN t1 f ON f.i_combo = a1.concept_id
-- excluded
JOIN rx_combo d ON d.drug_concept_id = b.drug_concept_id JOIN rx_combo d1 ON d1.drug_concept_id = f.drug_concept_id
-- excluded
AND d1.drug_concept_id <> d.drug_concept_id);;

-- separate Primary upward + Secondary upward (rnk in (3,4) in dev_combo)
DROP TABLE if exists ing_pr_sec_up_combo;
CREATE TABLE ing_pr_sec_up_combo 
AS
(SELECT *
FROM dev_combo a
WHERE class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 1)
AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 2)
AND   class_code IN (SELECT class_code FROM dev_combo WHERE rnk = 3)
AND   class_code IN (SELECT class_code FROM dev_combo WHERE rnk = 4)
AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 0)
);

-- create a temporary table with all possible i_combos for Primary upward + Secondary upward:  ing_pr_sec_up_combo_to_drug
DROP TABLE if exists ing_pr_sec_up_combo_to_drug;
CREATE TABLE ing_pr_sec_up_combo_to_drug 
AS
(WITH t1
AS
(SELECT drug_concept_id,
       REGEXP_SPLIT_TO_TABLE(i_combo,'-')::INT AS i_combo
FROM rx_combo
WHERE i_combo LIKE '%-%') 
SELECT DISTINCT a.class_code,
       a.class_name,
       c.i_combo
FROM ing_pr_sec_up_combo a
  JOIN t1 b
    ON b.i_combo = a.concept_id
   AND a.rnk = 3
  JOIN ing_pr_sec_up_combo a1
    ON a1.class_code = a.class_code
   AND a1.concept_id <> a.concept_id
  JOIN t1 j
    ON j.i_combo = a1.concept_id
   AND a1.rnk = 4
  JOIN rx_combo c
    ON c.drug_concept_id = b.drug_concept_id
   AND c.drug_concept_id = j.drug_concept_id);

-- separate Primary upward + Secondary upward with excluded Ingredients (currently no match, but it can change in the future)
DROP TABLE if exists ing_pr_sec_up_combo_excl;
CREATE TABLE ing_pr_sec_up_combo_excl 
AS
(SELECT *
FROM dev_combo a
WHERE class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 1)
AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 2)
AND   class_code IN (SELECT class_code FROM dev_combo WHERE rnk = 3)
AND   class_code IN (SELECT class_code FROM dev_combo WHERE rnk = 4)
AND   class_code IN (SELECT class_code FROM dev_combo WHERE rnk = 0));  

-- create temporary table with all possible i_combos for Primary upward + Secondary upward with excluded Ingredients (currently no match, but query works ing_pr_sec_up_combo_excl_to_drug)
DROP TABLE if exists ing_pr_sec_up_combo_excl_to_drug;
CREATE TABLE ing_pr_sec_up_combo_excl_to_drug 
AS
(WITH t1
AS
(SELECT drug_concept_id,
       REGEXP_SPLIT_TO_TABLE(i_combo,'-')::INT AS i_combo
FROM rx_combo
WHERE i_combo LIKE '%-%') 
SELECT DISTINCT a.class_code,
       a.class_name,
       c.i_combo
FROM ing_pr_sec_up_combo_excl a
  JOIN t1 b
    ON b.i_combo = a.concept_id
   AND a.rnk = 3
  JOIN ing_pr_sec_up_combo_excl a1
    ON a1.class_code = a.class_code
   AND a1.concept_id <> a.concept_id
  JOIN t1 j
    ON j.i_combo = a1.concept_id
   AND a1.rnk = 4
  JOIN ing_pr_sec_up_combo_excl a2
    ON a2.class_code = a.class_code
   AND a2.rnk = 0
  JOIN rx_combo c
    ON c.drug_concept_id = b.drug_concept_id
   AND c.drug_concept_id = j.drug_concept_id
  JOIN rx_combo c1
    ON c1.drug_concept_id = j.drug_concept_id
   AND c1.drug_concept_id = c.drug_concept_id
   AND c.i_combo !~ a2.concept_id::VARCHAR);

-- add prepared list of aggregated Ingredients of ATC Combo Classes to full_combo
INSERT INTO full_combo
SELECT *
FROM ing_pr_lat_combo_to_drug
UNION
SELECT *
FROM ing_pr_lat_combo_excl_to_drug
UNION
SELECT *
FROM ing_pr_sec_up_combo_to_drug
UNION
SELECT *
FROM ing_pr_sec_up_combo_excl_to_drug
UNION
SELECT * from ing_pr_lat_sec_up_combo_to_drug;

-- create a table to order aggregated ATC ingredients by an Ingredient
DROP TABLE IF EXISTS full_combo_reodered;
CREATE UNLOGGED TABLE full_combo_reodered AS 
SELECT DISTINCT fc.class_code,
	fc.class_name,
	l.i_combo
FROM full_combo fc
CROSS JOIN LATERAL(SELECT STRING_AGG(s0.ing, '-' ORDER BY s0.ing::INT) AS i_combo FROM (
		SELECT UNNEST(STRING_TO_ARRAY(fc.i_combo, '-')) AS ing
		) AS s0) l;
			
-- create index to make the script faster
CREATE INDEX i_full_combo_reodered ON full_combo_reodered (class_code, i_combo);

--create a table containing aggregated Ingredients + Dose Forms for ATC Combo Classes
DROP TABLE full_combo_with_form;
CREATE UNLOGGED TABLE full_combo_with_form
AS
SELECT DISTINCT a.class_code,
        a.class_name,
       a.i_combo,
       r.concept_id_2::int as df_id
FROM full_combo_reodered a
  JOIN internal_relationship_stage i ON class_code = substring (concept_code_1, '\w+') -- cut ATC code before space character
  JOIN drug_concept_stage b
    ON lower(b.concept_code) = lower(i.concept_code_2)
   AND b.concept_class_id = 'Dose Form'
  JOIN relationship_to_concept r ON r.concept_code_1 = i.concept_code_2;
/********************
***** REFERENCE *****
*********************/
-- create a temporary table of reference containing links between ATC source codes and combinations of ATC_codes AND Dose Forms from drug_concept_stage
DROP TABLE if exists reference;
CREATE TABLE reference 
AS
SELECT DISTINCT class_code,
       concept_code
FROM drug_concept_stage
  LEFT JOIN class_drugs_scraper ON SPLIT_PART (concept_name,' ',1) = class_code;

-- add ATC Combo Classes WO Dose Forms using the 'reference' table 
INSERT INTO full_combo_with_form
(class_code, i_combo)
SELECT DISTINCT f.class_code,
       i_combo
       FROM full_combo_reodered f
  JOIN reference r ON r.class_code = f.class_code
WHERE r.concept_code = r.class_code 
;
CREATE INDEX i_full_combo_with_form ON full_combo_with_form (class_code, i_combo,df_id);
/*******************************
******** CLASS TO DRUG *********
********************************/
-- add the 2nd portion of multicomponent ATC Class mappings:
-- ATC Combo Classes with Dose Forms using full_combo_with_form and rx_combo (order = 11)
INSERT INTO class_to_drug_new
WITH t1
AS
(SELECT c.concept_id,       -- Standard Drug Product
       c.concept_name,
       c.concept_class_id,
       c.vocabulary_id,
       r.concept_id_2 AS df_id,       -- Dose Form
       a.i_combo -- combination of Standard Ingredient IDs as a key for join 
       FROM rx_combo a
  JOIN concept c ON c.concept_id = a.drug_concept_id
  JOIN concept_relationship r ON r.concept_id_1 = c.concept_id
WHERE c.concept_class_id = 'Clinical Drug Form'
AND   c.vocabulary_id LIKE 'RxNorm%'
AND   c.invalid_reason IS NULL
AND   r.relationship_id = 'RxNorm has dose form'
AND   r.invalid_reason IS NULL
    )
  SELECT DISTINCT f.class_code, -- ATC
       c.concept_name as class_name,
       d.*,
       11 AS conept_order,
       'Combo with form'
    FROM full_combo_with_form f
        JOIN concept_manual c on c.concept_code = f.class_code and c.invalid_reason is null and c.concept_class_id = 'ATC 5th'
  JOIN t1 r
    ON r.i_combo = f.i_combo -- combination of Standard Ingredient IDs 
   AND r.df_id = f.df_id
   JOIN concept d on d.concept_id = r.concept_id
   and f.class_code||r.concept_id not in (select class_code||concept_id from class_to_drug_new);

-- add mappings of ATC Combo Classes to Contraceptive Packs (order = 12)
INSERT INTO class_to_drug_new
SELECT class_code,
       class_name,
      c.*,
      12,
      'contraceptive pack'
FROM class_to_drug_new ctd
  JOIN concept_ancestor ON ctd.concept_id = ancestor_concept_id
  JOIN concept c ON descendant_concept_id = c.concept_id
WHERE class_code ~ 'G03FB|G03AB' -- the list can be enriched 
AND   c.concept_class_id IN ('Clinical Pack')
AND  (ctd.class_code, c.concept_id) NOT IN (SELECT class_code, concept_id FROM class_to_drug_new);

-- add manual mappings from concept_relationship_manual (order = 13)
INSERT INTO class_to_drug_new
SELECT DISTINCT a.class_code, 
f.concept_name as class_name, 
c.*,
13,
'from crm'
from class_drugs_scraper a
join concept_relationship_manual b on b.concept_code_1 = a.class_code 
join concept_manual f on f.concept_code = a.class_code 
AND b.relationship_Id in ('ATC - RxNorm')
JOIN concept c on c.concept_code = b.concept_code_2 and c.vocabulary_id = b.vocabulary_id_2
and c.vocabulary_id in ('RxNorm', 'RxNorm Extension') and c.standard_concept = 'S'
 AND  (a.class_code, c.concept_id) NOT IN (SELECT class_code, concept_id FROM class_to_drug_new)
 and f.invalid_reason is null and f.concept_class_id = 'ATC 5th' ;

-- manual clean up for Precise Ingredients and other particular cases (according to the information on the ATC WHO Website)
DELETE
FROM class_to_drug_new
WHERE (class_code = 'A02BA07' AND concept_class_id = 'Clinical Drug Form') -- Branded Drug 'Tritec'
OR class_code = 'G03GA08' -- choriogonadotropin alfa (no Standard Precise Ingredient)
OR class_code='N05AF02' -- clopentixol
OR class_code IN ('D07AB02','D07BB04') -- 	hydrocortisone butyrate + combo that so far doesn't exist
OR class_code = 'C01DA05' -- pentaerithrityl tetranitrate; oral
OR (class_code = 'B02BD14'  AND concept_name LIKE '%Tretten%') -- 2 --catridecacog
OR (class_code IN ('B02BD14','B02BD11') and concept_class_id = 'Ingredient')-- susoctocog alfa | catridecacog
;

-- add additional semi-manual mappings based on pattern-matching  (order=14)
INSERT INTO class_to_drug_new
with t1 as (
SELECT 'B02BD11' as class_code,'catridecacog' as class_name, concept_id
FROM concept
WHERE (vocabulary_id LIKE 'RxNorm%' AND concept_name LIKE 'coagulation factor XIII a-subunit (recombinant)%'
      AND standard_concept = 'S' AND concept_class_id = 'Clinical Drug')
   OR concept_id = 35603348 -- the whole hierarchy (factor XIII Injection [Tretten]	Branded Drug Form)
UNION ALL
SELECT 'B02BD14','susoctocog alfa', concept_id
FROM concept
WHERE (vocabulary_id LIKE 'RxNorm%'
      AND concept_name LIKE 'antihemophilic factor, porcine B-domain truncated recombinant%' AND standard_concept = 'S' AND concept_class_id = 'Clinical Drug')
   OR concept_id IN (35603348, 44109089) -- the whole hierarchy
UNION ALL
SELECT 'A02BA07','ranitidine bismuth citrate',concept_id
FROM concept
WHERE vocabulary_id LIKE 'RxNorm%' AND concept_name LIKE '%Tritec%'
      AND standard_concept = 'S' AND concept_class_id = 'Branded Drug Form'
UNION ALL
SELECT 'G03GA08','choriogonadotropin alfa', concept_id
FROM concept
WHERE vocabulary_id LIKE 'RxNorm%' AND concept_name ~ 'choriogonadotropin alfa'
      AND standard_concept = 'S' AND concept_class_id ~ 'Clinical Drug Comp'
UNION ALL
SELECT 'N05AF02','clopenthixol', concept_id
FROM concept
WHERE vocabulary_id LIKE 'RxNorm%' AND concept_name ~* 'Sordinol|Ciatyl'
      AND standard_concept = 'S' AND concept_class_id = 'Branded Drug Form'
UNION ALL
SELECT 'D07AB02','hydrocortisone butyrate',concept_id
FROM concept
WHERE vocabulary_id LIKE 'RxNorm%' AND concept_name ~* 'Hydrocortisone butyrate' AND concept_class_id = 'Clinical Drug'
      AND standard_concept = 'S'
UNION ALL
SELECT 'C01DA05','pentaerithrityl tetranitrate', concept_id
FROM concept
WHERE vocabulary_id LIKE 'RxNorm%' AND concept_name ILIKE '%Pentaerythritol Tetranitrate%' and
      standard_concept = 'S' AND concept_class_id = 'Clinical Drug Comp'
      )
SELECT DISTINCT a.class_code,
       d.concept_name,
       c.*,
       14,
       'point fix'
FROM t1 a
  JOIN concept c ON c.concept_id = a.concept_id
  JOIN concept_manual d
    ON d.concept_code = a.class_code
   AND d.concept_class_id = 'ATC 5th'
   AND d.invalid_reason IS NULL;
;

-- clean up erroneous amount of ingredients 
DELETE
--select *
FROM class_to_drug_new
WHERE class_name LIKE '%,%and%'
  AND class_name NOT LIKE '%,%,%and%'
  AND NOT class_name ~* 'comb|other|whole root|selective'
  AND concept_name NOT LIKE '% / % / %';
  
--- add missing Clinical Drug Forms and Clinical Drugs using previous version of class_to_drug(order=15)
INSERT INTO class_to_drug_new
SELECT DISTINCT b.concept_code AS class_code,
       b.concept_name AS class_name,
       a.concept_id,
       a.concept_name,
       a.concept_class_id,
       14,
       'from sources.c_t_d'
FROM sources.class_to_drug a
  JOIN concept_manual b ON b.concept_code = a.class_code
  JOIN concept c
    ON a.concept_id = c.concept_id
   AND c.standard_concept = 'S'
   AND b.invalid_reason IS NULL
WHERE (class_code) NOT IN (SELECT class_code FROM class_to_drug_new)
AND   class_code NOT IN ('S02CA01','V03AB05','P03AC54','S02CA03','S02CA03')
AND   (class_code,c.concept_id) NOT IN (
 SELECT 'A06AA02', 40031558 -- oral - otic
 UNION ALL
 SELECT 'A06AA02', 40031561 -- oral - rectal 
  UNION ALL
 SELECT 'A06AA02', 40031561 -- oral - enema
   UNION ALL
 SELECT 'A06AA02', 40723180 -- oral - enema
    UNION ALL
 SELECT 'A06AA02',41080219
    UNION ALL
 SELECT 'A06AA02',41205788
    UNION ALL
 SELECT 'A06AA02',43158334
     UNION ALL
 SELECT 'A06AA02',40036796);
/**********************
****** ADD PACKS ******
***********************/
-- add packs of Primary lateral only in combination (order 16)
INSERT INTO class_to_drug_new
SELECT DISTINCT a.class_code,
       a.class_name,
       j.*,
       16 as concept_order,
       'Pack: Pr lat in combo' as order_desc 
FROM class_to_drug_new a
  JOIN concept_relationship r ON r.concept_id_1 = a.concept_id
  JOIN concept d
    ON d.concept_Id = r.concept_id_2
   AND d.concept_class_id = 'Clinical Drug'
  JOIN concept_relationship r2 ON r2.concept_id_1 = d.concept_id
  JOIN concept j ON j.concept_id = r2.concept_id_2
WHERE a.concept_class_id = 'Clinical Drug Form'
AND   r.invalid_reason IS NULL
AND   r2.invalid_reason IS NULL
AND   j.concept_class_id IN ('Clinical Pack','Clinical Pack Box','Branded Pack')
AND   j.standard_concept = 'S'
AND   a.class_code IN (SELECT class_code
                       FROM dev_combo
                       WHERE class_code IN (SELECT class_code FROM dev_combo WHERE rnk = 1)
                       AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 2)
                       AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 3)
                       AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 4)
                       AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 0))
AND   j.concept_name ~ ' / ' -- combos only
AND   (a.class_code,j.concept_id) NOT IN (SELECT class_code, concept_id FROM class_to_drug_new);

-- add additional packs of Primary lateral Ingredients in combination (Class A, combinations, order = 17)
INSERT INTO class_to_drug_new
SELECT DISTINCT a.class_code,
       a.class_name,
       j.*,
       17,
       'Pack: Pr lat in combo additional'
FROM class_to_drug_new a
  JOIN concept_relationship r2 ON r2.concept_id_1 = a.concept_id
  JOIN concept j ON j.concept_id = r2.concept_id_2
WHERE r2.invalid_reason IS NULL
AND   j.concept_class_id IN ('Clinical Pack','Clinical Pack Box','Branded Pack','Branded Pack Box')
AND   j.standard_concept = 'S'
AND   a.class_code IN (SELECT class_code
                       FROM dev_combo
                       WHERE class_code IN (SELECT class_code FROM dev_combo WHERE rnk = 1)
                       AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 2)
                       AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 3)
                       AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 4)
                       AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 0))
AND   j.concept_name ~ ' / ' -- combos only
AND   (a.class_code,j.concept_id) NOT IN (SELECT class_code, concept_id FROM class_to_drug_new);

-- add packs of Primary lateral + Secondary lateral (Class A AND Class B, order = 18)
INSERT INTO class_to_drug_new
SELECT DISTINCT a.class_code,
       a.class_name,
       j.*,
       18,
       'Pack: Pr lat + Sec lat'
FROM class_to_drug_new a
  JOIN concept_relationship r ON r.concept_id_1 = a.concept_id
  JOIN concept d
    ON d.concept_Id = r.concept_id_2
   AND d.concept_class_id = 'Clinical Drug'
  JOIN concept_relationship r2 ON r2.concept_id_1 = d.concept_id
  JOIN concept j ON j.concept_id = r2.concept_id_2
WHERE a.concept_class_id = 'Clinical Drug Form'
AND   r.invalid_reason IS NULL
AND   r2.invalid_reason IS NULL
AND   j.concept_class_id IN ('Clinical Pack','Clinical Pack Box','Branded Pack')
AND   j.standard_concept = 'S'
AND   a.class_code IN (SELECT class_code
                       FROM dev_combo
                       WHERE class_code IN (SELECT class_code FROM dev_combo WHERE rnk = 1)
                       AND   class_code IN (SELECT class_code FROM dev_combo WHERE rnk = 2)
                       AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 3)
                       AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 4)
                       AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 0))
AND   j.concept_name ~ ' / ' 
AND   (a.class_code,j.concept_id) NOT IN (SELECT class_code, concept_id FROM class_to_drug_new);

-- add Branded packs of Primary lateral + Secondary lateral (order = 19)
INSERT INTO class_to_drug_new
SELECT DISTINCT a.class_code,
       a.class_name,
       j.*,
       19,
       'Pack: Pr lat + Sec lat Branded'
FROM class_to_drug_new a
  JOIN concept_relationship r2 ON r2.concept_id_1 = a.concept_id
  JOIN concept j ON j.concept_id = r2.concept_id_2
WHERE r2.invalid_reason IS NULL
AND   j.concept_class_id IN ('Branded Pack')
-- Boxes are suspicious
AND   j.standard_concept = 'S'
AND   a.class_code IN (SELECT class_code
                       FROM dev_combo
                       WHERE class_code IN (SELECT class_code FROM dev_combo WHERE rnk = 1)
                       AND   class_code IN (SELECT class_code FROM dev_combo WHERE rnk = 2)
                       AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 3)
                       AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 4)
                       AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 0))
AND   j.concept_name ~ ' / '
AND   (a.class_code,j.concept_id) NOT IN (SELECT class_code, concept_id FROM class_to_drug_new);

-- add packs of Primary upward and Secondary upward (Class C AND Class D, order = 20)
INSERT INTO class_to_drug_new
SELECT DISTINCT a.class_code,
       a.class_name,
       j.*,
      20,
      'Pack: Pr up + Sec up'
FROM class_to_drug_new a
  JOIN concept_relationship r ON r.concept_id_1 = a.concept_id
  JOIN concept d
    ON d.concept_Id = r.concept_id_2
   AND d.concept_class_id = 'Clinical Drug'
  JOIN concept_relationship r2 ON r2.concept_id_1 = d.concept_id
  JOIN concept j ON j.concept_id = r2.concept_id_2
WHERE a.concept_class_id = 'Clinical Drug Form'
AND   r.invalid_reason IS NULL
AND   r2.invalid_reason IS NULL
AND   j.concept_class_id IN ('Clinical Pack','Clinical Pack Box','Branded Pack')
AND   j.standard_concept = 'S'
AND   a.class_code IN (SELECT class_code
                       FROM dev_combo
                       WHERE class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 1)
                       AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 2)
                       AND   class_code IN (SELECT class_code FROM dev_combo WHERE rnk = 3)
                       AND   class_code IN (SELECT class_code FROM dev_combo WHERE rnk = 4)
                       AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 0))
AND   j.concept_name ~ ' / ';

-- add packs of Primary lateral and Secondary upward (Class A + Class D, order = 21) 
INSERT INTO class_to_drug_new
SELECT DISTINCT a.class_code,
       a.class_name,
       j.*,
       21,
       'Pack: Pr lat + Sec up'
FROM class_to_drug_new a
  JOIN concept_relationship r ON r.concept_id_1 = a.concept_id
  JOIN concept d
    ON d.concept_Id = r.concept_id_2
   AND d.concept_class_id = 'Clinical Drug'
  JOIN concept_relationship r2 ON r2.concept_id_1 = d.concept_id
  JOIN concept j ON j.concept_id = r2.concept_id_2
WHERE a.concept_class_id = 'Clinical Drug Form'
AND   r.invalid_reason IS NULL
AND   r2.invalid_reason IS NULL
AND   j.concept_class_id IN ('Clinical Pack','Clinical Pack Box','Branded Pack')
AND   j.standard_concept = 'S'
AND   a.class_code IN (SELECT class_code
                       FROM dev_combo
                       WHERE class_code IN (SELECT class_code FROM dev_combo WHERE rnk = 1)
                       AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 2)
                       AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 3)
                       AND   class_code IN (SELECT class_code FROM dev_combo WHERE rnk = 4)
                       AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 0))
AND   j.concept_name ~ ' / '
AND   (a.class_code,j.concept_id) NOT IN (SELECT class_code, concept_id FROM class_to_drug_new);

-- add additional packs of Primary lateral and Secondary upward (Class A + Class D, order = 22) 
INSERT INTO class_to_drug_new
SELECT DISTINCT a.class_code,
       a.class_name,
       j.*,
       22,
       'Pack: Pr lat + Sec up additional'
FROM class_to_drug_new a
  JOIN concept_relationship r2 ON r2.concept_id_1 = a.concept_id
  JOIN concept j ON j.concept_id = r2.concept_id_2
WHERE r2.invalid_reason IS NULL
AND   j.concept_class_id IN ('Clinical Pack','Clinical Pack Box','Branded Pack')
-- Boxes are suspicious
AND   j.standard_concept = 'S'
AND   a.class_code IN (SELECT class_code
                       FROM dev_combo
                       WHERE class_code IN (SELECT class_code FROM dev_combo WHERE rnk = 1)
                       AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 2)
                       AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 3)
                       AND   class_code IN (SELECT class_code FROM dev_combo WHERE rnk = 4)
                       AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 0))
AND   j.concept_name ~ ' / '
AND   (a.class_code,j.concept_id) NOT IN (SELECT class_code, concept_id FROM class_to_drug_new);

--- add missing Packs using previous version of class_to_drug
INSERT INTO class_to_drug_new
SELECT DISTINCT b.concept_code AS class_code,
       b.concept_name AS class_name,
       c.*,
       23,
       'packs: from sources.c_t_d'
FROM sources.class_to_drug a
  JOIN concept_manual b ON b.concept_code = a.class_code
  JOIN concept c
    ON a.concept_id = c.concept_id
   AND c.standard_concept = 'S'
   AND b.invalid_reason IS NULL
WHERE (class_code,a.concept_id) NOT IN (SELECT class_code, concept_id FROM class_to_drug_new)
AND   a.concept_class_id ~ 'Pack'
AND   a.class_code NOT IN ('G01AF55','S03CA04','S01CA03','S02CA03')-- gives packs with erroneous forms
AND   a.class_code NOT IN ('B03AE01','C07BB52','D01AC52','C10AD52') -- wrong ing combo 
;

-- Enrich pool of links to Packs for 'G03FB Progestogens and estrogens, sequential preparations' AND 'G03AB Progestogens and estrogens, sequential preparations' (they are always used as packs)
INSERT INTO class_to_drug_new
SELECT DISTINCT class_code,
       class_name,
       c.*,
       24,
       'Pack: semi-manual'
FROM class_to_drug_new f
  JOIN devv5.concept_ancestor ca ON ca.ancestor_concept_id = CAST (f.concept_id AS INT)
  JOIN devv5.concept c
    ON c.concept_id = descendant_concept_id
   AND c.concept_class_id LIKE '%Pack%'
WHERE f.class_code ~ 'G03FB|G03AB'
;
-- get rid of all other concept_class_ids except Packs for 'G03FB Progestogens and estrogens, sequential preparations' AND 'G03AB Progestogens and estrogens, sequential preparations' 
DELETE
FROM class_to_drug_new
WHERE class_code ~ 'G03FB|G03AB' -- 	Progestogens and estrogens
AND   concept_class_id !~ 'Pack';

--  add links from ATC Classes WO Dose Forms specified, however their possible ancestors are unique
INSERT INTO class_to_drug_new
  WITH ing AS (
SELECT concept_id_2,concept_code_1, count(concept_id_2)  AS cnt
FROM (
  SELECT DISTINCT substring(i.concept_code_1,'\w+'), r.concept_code_1, concept_id_2
FROM relationship_to_concept r
JOIN internal_relationship_stage i on i.concept_code_2 = r.concept_code_1
JOIN drug_concept_stage d on d.concept_code = i.concept_code_2 AND d.concept_class_id = 'Ingredient'
 ) a GROUP BY concept_id_2,concept_code_1 ),
  drug AS (
    SELECT DISTINCT substring(concept_code_1,'\w+') AS code,concept_code_2
FROM internal_relationship_stage i
WHERE not exists (SELECT 1 FROM internal_relationship_stage i2
                           WHERE i.concept_code_2=i2.concept_code_2
                           AND substring(i.concept_code_1,'\w+')!=substring(i2.concept_code_1,'\w+'))
),
  drug_name AS (
SELECT DISTINCT class_code,class_name, concept_id_2
FROM ing
JOIN drug ON concept_code_2 = concept_code_1
JOIN class_drugs_scraper ON code = class_code
WHERE cnt=1 AND class_name = concept_code_1
AND code NOT IN (SELECT class_code FROM class_to_drug_new)
),
all_drug AS (
SELECT class_code, class_name, concept_id, count(concept_id_2) OVER (PARTITION BY class_code) AS cnt
FROM drug_name a
JOIN concept c on c.concept_id = a.concept_id_2
)
SELECT DISTINCT a.class_code,
       a.class_name,
       c.*,
       25,
       'ATC Classes WO Dose Forms to unique Drug Product'
FROM all_drug a
join concept c on c.concept_id = a.concept_id
WHERE cnt = 1
AND   (class_code) NOT IN (SELECT class_code FROM class_to_drug_new);

-- add links from ATC Monocomponent Classes which do not have Dose Forms to Ingredients 
INSERT INTO class_to_drug_new
WITH t1
AS
(SELECT *
FROM concept_manual
WHERE concept_code NOT IN (SELECT class_code FROM class_to_drug_new)
AND   concept_class_Id = 'ATC 5th'
AND   invalid_reason IS NULL
AND   concept_code NOT IN (SELECT class_code FROM atc_inexistent)) 
SELECT DISTINCT a.concept_code,
       a.concept_name,
       c.*,
       26,
       'Monocomponent ATC WO Dose Forms'
FROM t1 a
  JOIN internal_relationship_stage i ON SUBSTRING (concept_code_1,'\w+') = a.concept_code
  JOIN relationship_to_concept r ON r.concept_code_1 = i.concept_code_2
  JOIN concept c
    ON c.concept_id = r.concept_id_2
   AND c.concept_class_id = 'Ingredient'
   AND c.standard_concept = 'S'
   AND a.concept_code NOT IN (SELECT class_code FROM dev_combo);

-- add links from ATC Combo Classes which do not have Dose Forms to Ingredients (do we need them?)
INSERT INTO class_to_drug_new WITH t1
AS
(SELECT *
FROM concept_manual
WHERE concept_code NOT IN (SELECT class_code FROM class_to_drug_new)
AND   concept_class_Id = 'ATC 5th'
AND   invalid_reason IS NULL
AND   concept_code NOT IN (SELECT class_code FROM atc_inexistent)

)
SELECT DISTINCT a.concept_code,
       a.concept_name,
       c.*,
       27,
       'Multicomp ATC Class to Ingredient'
FROM t1 a
  JOIN dev_combo k
    ON k.class_code = a.concept_code
   AND rnk IN (1, 2)
  JOIN concept c
    ON c.concept_id = k.concept_id
   AND c.concept_class_id = 'Ingredient'
   AND c.standard_concept = 'S';

-- remove excessive links to children among Packs
WITH t1 AS
(
  SELECT *
  FROM class_to_drug_new
  WHERE class_code IN (SELECT class_code
                       FROM class_to_drug_new
                       GROUP BY class_code
                       HAVING COUNT(1) >= 2)
  and class_code in (select class_code from class_to_drug_new where  concept_class_id ~ 'Pack')
  and class_code not in (select class_code from class_to_drug_new where concept_class_id !~ 'Pack')
)
delete from class_to_drug_new where class_code||concept_id in ( 
SELECT a1.class_code||
       a2.concept_id
FROM t1 a1 -- papa 
  JOIN t1 a2 -- child
ON a1.class_code = a2.class_code
  JOIN concept_ancestor ca
    ON a1.concept_id = ca.ancestor_concept_id
   AND a2.concept_id = ca.descendant_concept_id
   AND a1.concept_id <> a2.concept_id
   and a2.concept_class_id ~ 'Pack');
   
-- remove excessive links to children among unpacked Drug Products :) 
WITH t1 AS
(
  SELECT *
  FROM class_to_drug_new
  WHERE class_code IN (SELECT class_code
                       FROM class_to_drug_new
                       GROUP BY class_code
                       HAVING COUNT(1) >= 2)
  and class_code not in (select class_code from class_to_drug_new where  concept_class_id ~ 'Pack')
)
delete from class_to_drug_new where class_code||concept_id in ( 
SELECT a1.class_code||
       a2.concept_id -- child mapping
FROM t1 a1 -- papa 
  JOIN t1 a2 -- child
ON a1.class_code = a2.class_code
  JOIN concept_ancestor ca
    ON a1.concept_id = ca.ancestor_concept_id
   AND a2.concept_id = ca.descendant_concept_id
   AND a1.concept_id <> a2.concept_id
   and a2.concept_class_id !~ 'Pack');

-- run load_stage.sql
