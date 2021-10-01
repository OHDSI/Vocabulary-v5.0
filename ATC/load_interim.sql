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
* Authors: Anna Ostropolets, Polina Talapova, Timur Vakhitov
* Date: Sep 2021
* Total script execution time: 33m 56s
**************************************************************************/
/********************
***** RX COMBO *****
*********************/
-- create an interim table of rx_combo with aggregated concept_ids of RxN/RxN Standard Ingredients
DROP TABLE IF EXISTS rx_combo;
CREATE TABLE rx_combo AS
SELECT drug_concept_id,
       string_agg(ingredient_concept_id::VARCHAR, '-' ORDER BY ingredient_concept_id) AS i_combo
FROM devv5.drug_strength
       JOIN devv5.concept ON concept_id = drug_concept_id AND
                       concept_class_id IN ('Clinical Drug Form', 'Ingredient') -- 'Clinical Drug Comp' doesn't exist in ATCs
GROUP BY drug_concept_id;

-- create an interim table of rx_all_combo as the assemblage of Multicomponent RxN/RxE Drug Products, RxN/RxE Standard Ingredients and RxN/RxE Dose Forms 
DROP TABLE rx_all_combo;
CREATE TABLE rx_all_combo 
AS
(SELECT DISTINCT c.concept_id AS d_id,
       c.concept_name AS d_name,
       d.concept_id AS ing_id,
       d.concept_name AS ing_name,
       k.concept_id AS df_id,
       k.concept_name AS df_name
FROM concept c
  JOIN concept_relationship r ON r.concept_id_1 = c.concept_id
  JOIN concept d ON d.concept_id = r.concept_id_2--df
  JOIN concept_relationship r2 ON r2.concept_id_1 = c.concept_id
  JOIN concept k ON k.concept_id = r2.concept_id_2
WHERE c.concept_class_id = 'Clinical Drug Form'
AND   c.standard_concept = 'S'
AND   d.standard_concept = 'S'
AND   d.concept_class_id = 'Ingredient'
AND   r.relationship_id = 'RxNorm has ing'
AND   r2.relationship_id = 'RxNorm has dose form'
AND   k.concept_class_id = 'Dose Form'
AND   k.invalid_reason IS NULL
AND   r.invalid_reason IS NULL
AND   r2.invalid_reason IS NULL);

-- create an interim table of atc_all_combo as the assemblage of Multicomponent ATC Classes, RxN/RxE Standard Ingredients and RxN/RxE Dose Forms 
DROP TABLE IF EXISTS atc_all_combo;
CREATE TABLE atc_all_combo 
AS
(SELECT DISTINCT a.class_code,
       a.class_name,
       a.concept_id AS ing_id,
       a.concept_name AS ing_name,
       c.concept_id AS df_id,
       c.concept_name AS df_name,
       rnk
FROM dev_combo a
  JOIN internal_relationship_stage b ON SPLIT_PART (b.concept_code_1,' ',1) = a.class_code
  JOIN drug_concept_stage d
    ON d.concept_code = b.concept_code_2
   AND d.concept_class_id = 'Dose Form'
  JOIN concept c
    ON c.concept_name = d.concept_name
   AND c.invalid_reason IS NULL);

-- create an interim table of atc_all_combo as the assemblage of Monocomponent ATC Classes, RxN/RxE Standard Ingredients and RxN/RxE Dose Forms 
drop table if exists atc_all_mono;
CREATE TABLE atc_all_mono 
AS
(
SELECT DISTINCT a1.concept_code as class_code,
       a1.concept_name as class_name,
       c.concept_id AS ing_id,
       c.concept_name AS ing_name,
      d.concept_id AS df_id,
      d.concept_name AS df_name,
       1 as rnk
FROM concept_manual a1
  JOIN internal_relationship_stage b1 ON substring (b1.concept_code_1, '\w+') = a1.concept_code
  JOIN drug_concept_stage d1
    ON d1.concept_code = b1.concept_code_2
   AND d1.concept_class_id = 'Ingredient' 
     JOIN concept c 
    ON lower(c.concept_name) = lower( d1.concept_code)  and c.standard_concept = 'S' and c.domain_id = 'Drug' 
   JOIN concept_manual a2 on a2.concept_code = a1.concept_code and a2.invalid_reason is null 
  JOIN internal_relationship_stage b2 ON substring (b2.concept_code_1, '\w+') = a2.concept_code 
  JOIN drug_concept_stage d2  ON d2.concept_code = b2.concept_code_2
   AND d2.concept_class_id = 'Dose Form'
   JOIN concept d on lower(d.concept_name) = lower(d2.concept_code) 
   AND d2.invalid_reason IS NULL and d.domain_id = 'Drug'
   AND a1.concept_code not in (select class_code from dev_combo)
   );
/************************************
***** PREPARE ATC COMBO CLASSES *****
*************************************/
-- create an interim table which contains pure Multicomponent ATC Classes with semantic links of 'Primary lateral' + 'Secondary lateral' (ranks of 1 and 2 in dev_combo)
DROP TABLE IF EXISTS ing_pr_lat_sec_lat;
CREATE TABLE ing_pr_lat_sec_lat 
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

-- create an interim table which contains Multicomponent ATC Classes with semantic links of 'Primary lateral' + 'Secondary upward' (ranks of 1 and 4 in dev_combo)
DROP TABLE if exists ing_pr_lat_sec_up; 
CREATE TABLE ing_pr_lat_sec_up 
AS
(SELECT *
FROM dev_combo a
WHERE class_code  IN (SELECT class_code FROM dev_combo WHERE rnk = 1)
AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 2)
AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 3)
AND   class_code IN (SELECT class_code FROM dev_combo WHERE rnk = 4)
AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 0)
);

-- create an interim table which contains Multicomponent ATC Classes with semantic links of 'Primary lateral' in combination with other drugs (rank of 1 in dev_combo)
DROP TABLE if exists ing_pr_lat_combo;
CREATE TABLE ing_pr_lat_combo 
AS
(SELECT *
FROM dev_combo
WHERE class_code IN (SELECT class_code FROM dev_combo WHERE rnk = 1)
AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 2)
AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 3)
AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 4)
AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 0)
);

-- create an interim table which contains Multicomponent ATC Classes with semantic links of 'Primary lateral' in combination with other drugs and excluded Ingredient
-- (ranks of 1 and 0 in dev_combo)
DROP TABLE if exists ing_pr_lat_combo_excl;
CREATE TABLE ing_pr_lat_combo_excl 
AS
(SELECT *
FROM dev_combo
WHERE class_code IN (SELECT class_code FROM dev_combo WHERE rnk = 1)
AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 2)
AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 3)
AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 4)
AND   class_code IN (SELECT class_code FROM dev_combo WHERE rnk = 0)
);
                   
-- create an interim table which contains Multicomponent ATC Classes with semantic links of 'Primary upward' in combination with other drugs (rank of 3 in dev_combo)
DROP TABLE IF EXISTS ing_pr_up_combo;
CREATE TABLE ing_pr_up_combo 
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
 
-- add the same Ingredients marked with rank of 1 to create permutation
INSERT INTO ing_pr_up_combo -- Primary upward
SELECT class_code, class_name, concept_id, concept_name, 1
  FROM ing_pr_up_combo;
  
-- create an interim table which contains Multicomponent ATC Classes with semantic links of 'Primary upward' + 'Secondary upward' (ranks of 3 and 4 in dev_combo)
DROP TABLE IF EXISTS ing_pr_up_sec_up; 
CREATE TABLE ing_pr_up_sec_up AS (
SELECT DISTINCT class_code,
       class_name,
       concept_id,
       concept_name,
       rnk
FROM dev_combo
WHERE class_code IN (SELECT class_code
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
and  class_code not in (select class_code from  dev_combo where rnk = 0) -- exclude Excluded
);

-- create an interim table which contains Multicomponent ATC Classes with semantic links of 'Primary upward' + 'Secondary upward' with excluded Ingredient 
-- ranks of 3, 4 and 0 in dev_combo
DROP TABLE IF EXISTS ing_pr_up_sec_up_excl;
CREATE TABLE ing_pr_up_sec_up_excl AS (
SELECT distinct class_code,
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
AND  class_code IN (SELECT class_code 
		    FROM dev_combo 
		    WHERE rnk = 0)
);-- Note, Secondary upward links cannot stand alone in combinations with unmentioned RxN/RxE Drug Product

-- create indices
DROP INDEX IF EXISTS idx_atc;
CREATE INDEX idx_atc  ON atc_all_combo (class_code, df_id, ing_id);
ANALYZE atc_all_combo;
DROP INDEX IF EXISTS idx_rx;
CREATE INDEX idx_rx  ON rx_all_combo (ing_id, df_id);
ANALYZE rx_all_combo;
DROP INDEX IF EXISTS idx_rx_0;
CREATE INDEX idx_rx_0  ON rx_combo (i_combo);
ANALYZE rx_combo;
DROP INDEX IF EXISTS idx_rx_1;
CREATE INDEX idx_rx_1  ON rx_combo (drug_concept_id, i_combo);
ANALYZE rx_combo;
DROP INDEX IF EXISTS idx_rx_3;
CREATE INDEX idx_rx_3  ON rx_all_combo (lower(ing_name), lower(df_name));
ANALYZE rx_all_combo;
DROP INDEX IF EXISTS idx_rx_4;
CREATE INDEX idx_rx_4  ON atc_all_combo (lower(ing_name), lower(df_name));
ANALYZE atc_all_combo;
DROP INDEX IF EXISTS irs_x;
CREATE INDEX irs_x  ON internal_relationship_stage (SUBSTRING (concept_code_1,'\w+'));
ANALYZE internal_relationship_stage;
/*************************
***** CLASS TO DRUG ******
**************************/    
-- assemble a table containing ATC Drug Classes which are as ancestors hierarchically connected to RxN/RxE Drug Products (the first line target - Clinical Drug Form)
-- add mappings from Monocomponent ATC Classes to respective Monocomponent RxN/RxE Drug Products (order = 1)
DROP TABLE if exists class_to_drug_new;
CREATE TABLE class_to_drug_new 
AS
(WITH atc
AS
(SELECT DISTINCT a.class_code,
       a.class_name,
       df_id,
       ARRAY_AGG(a.ing_id) OVER (PARTITION BY a.class_code) ings
FROM atc_all_mono a),rx AS (SELECT DISTINCT r.d_id, r.d_name, r.df_id, ARRAY_AGG(r.ing_id) OVER (PARTITION BY r.d_id) ings 
     FROM rx_all_combo r) 
    SELECT DISTINCT atc.class_code,
       atc.class_name,
       c.*,
       1 AS concept_order,
       'ATC Monocomp Class' AS order_desc
FROM atc
  JOIN rx USING (df_id)
  JOIN concept c ON c.concept_id = rx.d_id
WHERE atc.ings @> rx.ings
AND   atc.ings <@ rx.ings);

-- add more mappings from Monocomponent ATC Classes to respective Monocomponent RxN/RxE Drug Products (order = 1)
INSERT INTO class_to_drug_new
WITH t1
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
  LEFT JOIN drug_concept_stage d2
    ON d2.concept_code = i2.concept_code_2
   AND d2.concept_class_id = 'Dose Form')
SELECT DISTINCT class_code,
       class_name,
       c.*,
       1 AS concept_order,
       'ATC Monocomp Class' as order_desc
FROM t2 a
  JOIN rx_all_combo b
    ON lower (b.ing_name) = lower (a.ing_name)
   AND lower (b.df_name) = lower (a.df_name)
   AND d_name !~ ' / ' -- exclude Multicomponent
  JOIN concept c
    ON c.concept_id = b.d_id
   AND c.standard_concept = 'S'
WHERE class_code NOT IN (SELECT class_code FROM dev_combo)
 AND class_code||concept_id NOT IN (SELECT class_code||concept_id FROM class_to_drug_new);-- 1085

-- add mappings of "greedy" ATC Monocomponent Classes, which are matched with Multicomponent RxN/RxE Drug Products (order = 2)
INSERT INTO class_to_drug_new
WITH t1
AS
(SELECT i.class_code,i.class_name,i.ing_id,i.ing_name,i.df_id,i.df_name,i.rnk,i.d_id,i.d_name
FROM (SELECT a.class_code,
             a.class_name,
             a.ing_id,
             a.ing_name,
             a.df_id,
             a.df_name,
             a.rnk,
             r.d_id,
             r.d_name,
             ARRAY_AGG(a.rnk) FILTER (WHERE r.ing_id IS NOT NULL) OVER (PARTITION BY a.class_code) matched_ranks,
             ARRAY_AGG(a.rnk) OVER (PARTITION BY a.class_code) all_ranks
      FROM atc_all_mono a
        LEFT JOIN rx_all_combo r USING (ing_id,df_id)
        ) i
WHERE i.d_id IS NOT NULL) 
  SELECT DISTINCT 
       class_code,
       class_name,
       c.*,
       2 AS concept_order,
       'Greedy ATC Monocomp Class' AS order_desc
  FROM t1 a
  JOIN concept c ON c.concept_id = a.d_id
  WHERE class_code||concept_id NOT IN (SELECT class_code||concept_id FROM class_to_drug_new); -- 60223
  
-- add more mappings of "greedy" ATC Monocomponent Classes, which are matched with Multicomponent RxN/RxE Drug Products (order = 2)
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
   JOIN internal_relationship_stage i2 ON SUBSTRING (i2.concept_code_1,'\w+') = a.concept_code
 JOIN drug_concept_stage d2
    ON d2.concept_code = i2.concept_code_2
   AND d2.concept_class_id = 'Dose Form')
SELECT DISTINCT class_code,
       class_name,
       c.*,
       2 AS concept_order,
       'Greedy ATC Monocomp Class' as order_desc
FROM t2 a
  JOIN rx_all_combo b
    ON lower (b.ing_name) = lower (a.ing_name)
   AND lower (b.df_name) = lower (a.df_name)
  JOIN concept c
    ON c.concept_id = b.d_id
   AND c.standard_concept = 'S'
   AND (class_code,c.concept_id) NOT IN (SELECT class_code,concept_id FROM class_to_drug_new)
   AND class_code NOT IN (SELECT class_code FROM dev_combo);

-- add mappings of Multicomponent ACT Classes of 'Primary lateral' in combination (order = 3)
INSERT INTO class_to_drug_new
WITH t1
AS
(SELECT i.class_code,i.class_name,i.ing_id,i.ing_name,i.df_id,i.df_name,i.rnk,i.d_id,i.d_name
FROM (SELECT a.class_code,
             a.class_name,
             a.ing_id,
             a.ing_name,
             a.df_id,
             a.df_name,
             a.rnk,
             r.d_id,
             r.d_name,
             ARRAY_AGG(a.rnk) FILTER (WHERE r.ing_id IS NOT NULL) OVER (PARTITION BY a.class_code) matched_ranks,
             ARRAY_AGG(a.rnk) OVER (PARTITION BY a.class_code) all_ranks
      FROM atc_all_combo a
        LEFT JOIN rx_all_combo r USING (ing_id,df_id)
      WHERE class_code IN (SELECT class_code FROM ing_pr_lat_combo)) i
WHERE i.d_id IS NOT NULL) 
SELECT DISTINCT 
       class_code,
       class_name,
       c.*,
       3 AS concept_order,
       'ATC Combo Class: Primary lateral in combination' AS order_desc
FROM t1 a
  JOIN concept c
    ON c.concept_id = a.d_id
   AND c.concept_name ~ ' / '
WHERE class_code||concept_id NOT IN (SELECT class_code||concept_id FROM class_to_drug_new); -- 9201

-- add mappings of Multicomponent ACT Classes of 'Primary upward' in combination with other drugs (order = 4)
INSERT INTO class_to_drug_new
WITH t1
AS
(SELECT i.class_code,i.class_name,i.ing_id,i.ing_name,i.df_id,i.df_name,i.rnk,i.d_id,i.d_name
FROM (SELECT a.class_code,
             a.class_name,
             a.ing_id,
             a.ing_name,
             a.df_id,
             a.df_name,
             a.rnk,
             r.d_id,
             r.d_name,
             ARRAY_AGG(a.rnk) FILTER (WHERE r.ing_id IS NOT NULL) OVER (PARTITION BY a.class_code) matched_ranks,
             ARRAY_AGG(a.rnk) OVER (PARTITION BY a.class_code) all_ranks
      FROM atc_all_combo a
        LEFT JOIN rx_all_combo r USING (ing_id,df_id)
      WHERE class_code IN (SELECT class_code FROM ing_pr_up_combo)) i
WHERE i.d_id IS NOT NULL) 
SELECT DISTINCT 
       class_code,
       class_name,
       c.*,
       4 AS concept_order,
       'ATC Combo Class: Primary upward in combination' AS order_desc
FROM t1 a
  JOIN concept c
    ON c.concept_id = a.d_id
   AND c.concept_name ~ ' / '
WHERE class_code||concept_id NOT IN (SELECT class_code||concept_id FROM class_to_drug_new); -- 14307

-- add mappings of Multicomponent ACT Classes of 'Primary lateral' + 'Secondary lateral, 4 ingreds' (order = 5)
INSERT INTO class_to_drug_new
WITH t1
AS
(SELECT a.class_code,
       a.class_name,
       a.ing_id,
       c.*,
       rnk
FROM atc_all_combo a
  JOIN rx_all_combo b USING (ing_id,df_id)
  JOIN concept c ON c.concept_id = d_id
WHERE a.class_code IN (SELECT class_code FROM ing_pr_lat_sec_lat))
SELECT DISTINCT a.class_code,
       a.class_name,
       a.concept_id,
       a.concept_name,
       a.domain_id,
       a.vocabulary_id,
       a.concept_class_id,
       a.standard_concept,
       a.concept_code,
       a.valid_start_date,
       a.valid_end_date,
       a.invalid_reason,
       5,
       'ATC Combo Class: Primary lateral + Secondary lateral, 4 ingreds' AS order_desc
FROM t1 a
  JOIN t1 b
    ON b.class_code = a.class_code
   AND b.concept_id = a.concept_id
   AND a.ing_id <> b.ing_id
  JOIN t1 c
    ON c.class_code = a.class_code
   AND c.concept_id = b.concept_id
   AND a.ing_id <> c.ing_id
   AND b.ing_id <> c.ing_id
  JOIN t1 d
    ON d.class_code = a.class_code
   AND d.concept_id = b.concept_id
   AND a.ing_id <> d.ing_id
   AND d.ing_id <> c.ing_id
   AND d.ing_id <> b.ing_id
WHERE a.rnk = 1
AND   b.rnk <> 1
AND   c.rnk <> 1
AND   d.rnk <> 1
AND a.class_code||a.concept_id NOT IN (SELECT class_code||concept_id
FROM class_to_drug_new)
and a.class_code !~ '^J07'; -- 269

-- add mappings of Multicomponent ACT Classes of 'Primary lateral' + 'Secondary upward', 4 ingreds (order = 50)
INSERT INTO class_to_drug_new
WITH t1
AS
(SELECT a.class_code,
       a.class_name,
       a.ing_id,
       c.*,
       rnk
FROM atc_all_combo a
  JOIN rx_all_combo b USING (ing_id,df_id)
  JOIN concept c ON c.concept_id = d_id
WHERE a.class_code IN (SELECT class_code FROM ing_pr_lat_sec_up))
SELECT DISTINCT a.class_code,
       a.class_name,
       a.concept_id,
       a.concept_name,
       a.domain_id,
       a.vocabulary_id,
       a.concept_class_id,
       a.standard_concept,
       a.concept_code,
       a.valid_start_date,
       a.valid_end_date,
       a.invalid_reason,
       50,
       'ATC Combo Class: Primary lateral + Secondary upward, 4 ingreds' AS order_desc
FROM t1 a
  JOIN t1 b
    ON b.class_code = a.class_code
   AND b.concept_id = a.concept_id
   AND a.ing_id <> b.ing_id
  JOIN t1 c
    ON c.class_code = a.class_code
   AND c.concept_id = b.concept_id
   AND a.ing_id <> c.ing_id
   AND b.ing_id <> c.ing_id
  JOIN t1 d
    ON d.class_code = a.class_code
   AND d.concept_id = b.concept_id
   AND a.ing_id <> d.ing_id
   AND d.ing_id <> c.ing_id
   AND d.ing_id <> b.ing_id
WHERE a.rnk = 1
AND   b.rnk <> 1
AND   c.rnk <> 1
AND   d.rnk <> 1
AND a.class_code||a.concept_id NOT IN (SELECT class_code||concept_id FROM class_to_drug_new)
; -- 141
 
-- add mappings of Multicomponent ACT Classes of 'Primary lateral' + 'Secondary lateral', 3 ingreds (order = 6)
INSERT INTO class_to_drug_new
WITH t1 AS
(
  SELECT a.class_code,
         a.class_name,
         a.ing_id,
         c.*,
         rnk
  FROM atc_all_combo a
    JOIN rx_all_combo b USING (ing_id,df_id)
    JOIN concept c ON c.concept_id = d_id
  WHERE a.class_code IN (SELECT class_code FROM ing_pr_lat_sec_lat)
)
SELECT DISTINCT a.class_code,
       a.class_name,
       a.concept_id,
       a.concept_name,
       a.domain_id,
       a.vocabulary_id,
       a.concept_class_id,
       a.standard_concept,
       a.concept_code,
       a.valid_start_date,
       a.valid_end_date,
       a.invalid_reason,
       6,
       'ATC Combo Class: Primary lateral + Secondary lateral, 3 ingreds' AS order_desc
FROM t1 a
  JOIN t1 b
    ON b.class_code = a.class_code
   AND b.concept_id = a.concept_id
   AND a.ing_id <> b.ing_id
  JOIN t1 c
    ON c.class_code = a.class_code
   AND c.concept_id = b.concept_id
   AND a.ing_id <> c.ing_id
   AND b.ing_id <> c.ing_id
WHERE a.rnk = 1
AND   b.rnk <> 1
AND   c.rnk <> 1
AND   a.class_code||a.concept_id NOT IN (SELECT class_code||concept_id FROM class_to_drug_new); -- 261

-- add mappings of Multicomponent ACT Classes of 'Primary lateral' + 'Secondary upward', 3 ingreds (order = 60)
INSERT INTO class_to_drug_new
WITH t1
AS
(SELECT a.class_code,
       a.class_name,
       a.ing_id,
       c.*,
       rnk
FROM atc_all_combo a
  JOIN rx_all_combo b USING (ing_id,df_id)
  JOIN concept c ON c.concept_id = d_id
WHERE a.class_code IN (SELECT class_code FROM ing_pr_lat_sec_up))
SELECT DISTINCT a.class_code,
       a.class_name,
       a.concept_id,
       a.concept_name,
       a.domain_id,
       a.vocabulary_id,
       a.concept_class_id,
       a.standard_concept,
       a.concept_code,
       a.valid_start_date,
       a.valid_end_date,
       a.invalid_reason,
       60,
       'ATC Combo Class: Primary lateral + Secondary upward, 3 ingreds' AS order_desc
FROM t1 a
  JOIN t1 b
    ON b.class_code = a.class_code
   AND b.concept_id = a.concept_id
   AND a.ing_id <> b.ing_id
  JOIN t1 c
    ON c.class_code = a.class_code
   AND c.concept_id = b.concept_id
   AND a.ing_id <> c.ing_id
   AND b.ing_id <> c.ing_id
WHERE a.rnk = 1
AND   b.rnk <> 1
AND   c.rnk <> 1
AND   a.class_code||a.concept_id NOT IN (SELECT class_code||concept_id FROM class_to_drug_new); -- 2

-- add mappings of Multicomponent ACT Classes of 'Primary lateral' + 'Secondary lateral', 2 ingreds' (order = 7)
INSERT INTO class_to_drug_new
WITH t1 AS
(
  SELECT a.class_code,
         a.class_name,
         a.ing_id,
         c.*,
         rnk
  FROM atc_all_combo a
    JOIN rx_all_combo b USING (ing_id,df_id)
    JOIN concept c ON c.concept_id = d_id
  WHERE a.class_code IN (SELECT class_code FROM ing_pr_lat_sec_lat)
)
SELECT DISTINCT  a.class_code,
       a.class_name,
       a.concept_id,
       a.concept_name,
       a.domain_id,
       a.vocabulary_id,
       a.concept_class_id,
       a.standard_concept,
       a.concept_code,
       a.valid_start_date,
       a.valid_end_date,
       a.invalid_reason,
       7,
       'ATC Combo Class: Primary lateral + Secondary lateral, 2 ingreds' AS order_desc
FROM t1 a
  JOIN t1 b
    ON b.class_code = a.class_code
   AND b.concept_id = a.concept_id
   AND a.ing_id <> b.ing_id
WHERE a.rnk = 1
AND   b.rnk <> 1
AND   a.class_code NOT IN (SELECT class_code FROM class_to_drug_new)
AND a.class_name NOT LIKE '%,%and%' AND a.class_code !~ '^J07'
AND   a.class_code||a.concept_id NOT IN (SELECT class_code||concept_id FROM class_to_drug_new); -- 2426

-- add mappings of Multicomponent ACT Classes of 'Primary lateral' + 'Secondary upward', 2 ingreds' (order = 70)
INSERT INTO class_to_drug_new
WITH t1 AS
(
  SELECT a.class_code,
         a.class_name,
         a.ing_id,
         c.*,
         rnk
  FROM atc_all_combo a
    JOIN rx_all_combo b USING (ing_id,df_id)
    JOIN concept c ON c.concept_id = d_id
  WHERE a.class_code IN (SELECT class_code FROM ing_pr_lat_sec_up)
)
SELECT DISTINCT  a.class_code,
       a.class_name,
       a.concept_id,
       a.concept_name,
       a.domain_id,
       a.vocabulary_id,
       a.concept_class_id,
       a.standard_concept,
       a.concept_code,
       a.valid_start_date,
       a.valid_end_date,
       a.invalid_reason,
       70,
       'ATC Combo Class: Primary lateral + Secondary upward, 2 ingreds' AS order_desc
FROM t1 a
  JOIN t1 b
    ON b.class_code = a.class_code
   AND b.concept_id = a.concept_id
   AND a.ing_id <> b.ing_id
WHERE a.rnk = 1
AND   b.rnk <> 1
AND   a.class_code||a.concept_id NOT IN (SELECT class_code||concept_id FROM class_to_drug_new); -- 0

-- add mappings of Multicomponent ACT Classes of 'Primary lateral' in combination with other drugs and an excluded Ingredient (order = 8)
INSERT INTO class_to_drug_new
WITH t1
AS
(SELECT DISTINCT a.class_code AS class_code,
       a.class_name AS class_name,
       a.concept_name AS ing_name,
       d2.concept_code AS df_name,
       rnk
FROM ing_pr_lat_combo_excl a
  JOIN internal_relationship_stage i2 ON SUBSTRING (i2.concept_code_1,'\w+') = a.class_code
  JOIN drug_concept_stage d2
    ON d2.concept_code = i2.concept_code_2
   AND d2.concept_class_id = 'Dose Form'),
t2 AS
(SELECT DISTINCT class_code,
       class_name,
       c.*,
       11,
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
       8 as concept_order,
       'ATC Combo Class: Primary lateral in combination with excluded Ingredient'
FROM t2
WHERE concept_name ~ ' / '
AND   concept_id NOT IN (SELECT d_id
                         FROM rx_all_combo a
                           JOIN t1 b
                             ON LOWER (b.ing_name) = LOWER (a.ing_name)
                            AND LOWER (b.df_name) = LOWER (a.df_name)
                            AND b.rnk = 0)         
AND   class_code||concept_id NOT IN (SELECT class_code||concept_id FROM class_to_drug_new); -- 0

-- add mappings of Multicomponent ACT Classes of 'Primary upward' + 'Secondary upward' with excluded ingredient' 
-- currently, no such (order = 0)
INSERT INTO class_to_drug_new
WITH t1
AS
(SELECT a.class_code,
       a.class_name,
       a.ing_id,
       a.ing_name,
       a.df_id,
       a.df_name,
       c.*,
       rnk
FROM atc_all_combo a
  JOIN rx_all_combo b USING (ing_id,df_id)
  JOIN concept c ON c.concept_id = d_id
WHERE a.class_code IN (SELECT class_code FROM ing_pr_up_sec_up_excl)),
t2 as ( 
SELECT DISTINCT a.class_code,
       a.class_name,
       a.concept_id,
       a.concept_name,
       a.domain_id,
       a.vocabulary_id,
       a.concept_class_id,
       a.standard_concept,
       a.concept_code,
       a.valid_start_date,
       a.valid_end_date,
       a.invalid_reason,
       0, -- no match up to now, but it can happen in the future
       'ATC Combo Class: Primary upward + Secondary upward with excluded ingredient' AS order_desc
FROM t1 a
  JOIN t1 b
    ON b.class_code = a.class_code
   AND b.concept_id = a.concept_id
   AND a.ing_id <> b.ing_id
WHERE a.rnk = 3
AND   b.rnk <> 3)
SELECT DISTINCT * from t2 
WHERE concept_name ~ ' / '
AND   concept_id NOT IN (SELECT d_id
                         FROM rx_all_combo a
                           JOIN t1 b
                             ON LOWER (b.ing_name) = LOWER (a.ing_name)
                            AND LOWER (b.df_name) = LOWER (a.df_name)
                            AND b.rnk = 0)
AND   class_code||concept_id::varchar NOT IN (SELECT class_code||concept_id::varchar  FROM class_to_drug_new); --0 

-- add mappings of Multicomponent ACT Classes of 'Primary upward' + 'Secondary upward' (order = 9)
INSERT INTO class_to_drug_new
WITH t1
AS
(SELECT DISTINCT a.class_code AS class_code,
       a.class_name AS class_name,
       a.concept_name AS ing_name,
       d2.concept_code AS df_name,
       rnk
FROM ing_pr_up_sec_up a
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
SELECT DISTINCT a.*,
       9 AS concept_order,
       'ATC Combo Class: Primary upward + Secondary upward'
FROM t2 a
  JOIN t3 b
    ON b.class_code = a.class_code
   AND a.concept_id = b.concept_id
WHERE a.concept_name ~ ' / '; -- 325
-------------------------
---- GET MORE LINKS -----
-------------------------
-- create an interim table with all Primary lateral Multicomponent ATC Classes (rnk = 1 in dev_combo)
DROP TABLE IF EXISTS t1;
CREATE UNLOGGED TABLE t1
AS
SELECT DISTINCT class_code, class_name, concept_id, concept_name, rnk
       FROM dev_combo WHERE rnk = 1; -- Primary lateral

-- create an interim table with all Secondary lateral Multicomponent ATC Classes (rnk = 2  in dev_combo)
DROP TABLE IF EXISTS t2;
CREATE UNLOGGED TABLE t2 
AS
SELECT DISTINCT class_code, class_name, concept_id, concept_name, rnk
       FROM dev_combo WHERE rnk = 2; -- Secondary lateral

-- create an interim table with all Primary upward Multicomponent ATC Classes 
DROP TABLE IF EXISTS t3;
CREATE UNLOGGED TABLE t3
AS
SELECT DISTINCT class_code, class_name, concept_id, concept_name, rnk
       FROM dev_combo 
WHERE rnk = 3; -- Primary upward

-- create an interim table with all Secondary upward Multicomponent ATC 
DROP TABLE IF EXISTS t4;
CREATE UNLOGGED TABLE t4 
AS
SELECT DISTINCT class_code, class_name, concept_id, concept_name, rnk
       FROM dev_combo
WHERE rnk = 4; -- Secondary upward

-- create an interim table with aggregated ATC Ingredients per one Multicomponent ATC Class (no more than 3 ingredients per Class is recommended)
-- add Primary lateral AND (Secondary lateral 1 AND/OR Secondary lateral 2) AND/OR Primary upward AND/OR Secondary upward Multicomponent ATC Classes 
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

-- create a temporary table with Ingredient permutations - additional layer of mappings: Primary lateral AND/OR Secondary lateral 1 AND/OR Secondary lateral 2
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
FROM ing_pr_lat_sec_up a
  JOIN z1 b
    ON b.i_combo = a.concept_id
   AND a.rnk = 1
  JOIN ing_pr_lat_sec_up a1
    ON a1.class_code = a.class_code
   AND a1.concept_id <> a.concept_id
  JOIN z1 j
    ON j.i_combo = a1.concept_id
   AND a1.rnk = 4
  JOIN rx_combo c
    ON c.drug_concept_id = b.drug_concept_id
   AND c.drug_concept_id = j.drug_concept_id);

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
AND d1.drug_concept_id <> d.drug_concept_id);

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
FROM ing_pr_up_sec_up a
  JOIN t1 b
    ON b.i_combo = a.concept_id
   AND a.rnk = 3
  JOIN ing_pr_up_sec_up a1
    ON a1.class_code = a.class_code
   AND a1.concept_id <> a.concept_id
  JOIN t1 j
    ON j.i_combo = a1.concept_id
   AND a1.rnk = 4
  JOIN rx_combo c
    ON c.drug_concept_id = b.drug_concept_id
   AND c.drug_concept_id = j.drug_concept_id);
   
-- create temporary table with all possible i_combos for Primary upward + Secondary upward with excluded Ingredients 
-- currently no match, but query works ing_pr_sec_up_combo_excl_to_drug
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
WHERE r.concept_code = r.class_code;

CREATE INDEX i_full_combo_with_form ON full_combo_with_form (class_code, i_combo,df_id);
/*******************************
******** CLASS TO DRUG *********
********************************/
-- add the 2nd portion of mappings of Multicomponent ATC Classes
-- ATC Combo Classes with Dose Forms using full_combo_with_form and rx_combo (order = 10)
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
       10 AS conept_order,
       'ATC Combo Class with Dose Form to Clinical Drug Form by additional permutations'
    FROM full_combo_with_form f
        JOIN concept_manual c on c.concept_code = f.class_code and c.invalid_reason is null and c.concept_class_id = 'ATC 5th'
  JOIN t1 r
    ON r.i_combo = f.i_combo -- combination of Standard Ingredient IDs 
   AND r.df_id = f.df_id
   JOIN concept d on d.concept_id = r.concept_id
   and f.class_code||r.concept_id not in (select class_code||concept_id from class_to_drug_new)
   and f.class_code  in ( 'J07CA10', 'G03FB09', 'G03FB06', 'G03FB05', 'G03FA12', 'G03FA11','G03FA01', 'G03EA03','A11GB01'); -- 63

-- add manual mappings from concept_relationship_manual (order = 11)
INSERT INTO class_to_drug_new
SELECT DISTINCT a.class_code,
       f.concept_name AS class_name,
       c.*,
       11 AS concept_order,
       'ATC Class to Drug Product from concept_relationship_manual'
FROM class_drugs_scraper a
  JOIN concept_relationship_manual b ON b.concept_code_1 = a.class_code
  JOIN concept_manual f
    ON f.concept_code = a.class_code
   AND b.relationship_Id IN ('ATC - RxNorm')
  JOIN concept c
    ON c.concept_code = b.concept_code_2
   AND c.vocabulary_id = b.vocabulary_id_2
   AND c.vocabulary_id IN ('RxNorm', 'RxNorm Extension') 
   AND c.standard_concept = 'S'
   AND (a.class_code,c.concept_id) NOT IN (SELECT class_code,concept_id FROM class_to_drug_new) 
AND f.invalid_reason IS NULL  AND b.invalid_reason is null
AND f.concept_class_id = 'ATC 5th'; -- 7558

-- manual clean up for Precise Ingredients and other particular cases (according to the information on the ATC WHO Website)
DELETE
FROM class_to_drug_new
WHERE (class_code = 'A02BA07' AND concept_class_id = 'Clinical Drug Form') -- Branded Drug 'Tritec'
OR class_code = 'N05AF02' -- clopentixol
OR class_code IN ('D07AB02','D07BB04') -- hydrocortisone butyrate + combo that so far doesn't exist
OR class_code = 'C01DA05' -- pentaerithrityl tetranitrate; oral
OR (class_code = 'B02BD14'  AND concept_name LIKE '%Tretten%') -- 2 --catridecacog
OR (class_code IN ('B02BD14','B02BD11') and concept_class_id = 'Ingredient')-- susoctocog alfa | catridecacog
; -- 310

-- add additional semi-manual mappings based on pattern-matching  (order = 12)
INSERT INTO class_to_drug_new
with t1 as (
SELECT 'B02BD11' as class_code,'catridecacog' as class_name, concept_id
FROM concept
WHERE (vocabulary_id LIKE 'RxNorm%' AND concept_name LIKE 'coagulation factor XIII a-subunit (recombinant)%'
      AND standard_concept = 'S' AND concept_class_id = 'Clinical Drug')
   OR concept_id = 35603348 -- the whole hierarchy (factor XIII Injection [Tretten] Branded Drug Form) 
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
SELECT 'N05AF02','clopenthixol', concept_id
FROM concept
WHERE vocabulary_id LIKE 'RxNorm%' AND concept_name ~* 'Sordinol|Ciatyl'
      AND standard_concept = 'S' AND concept_class_id = 'Branded Drug Form'
UNION ALL
SELECT 'D07AB02','hydrocortisone butyrate',concept_id
FROM concept
WHERE vocabulary_id LIKE 'RxNorm%' AND concept_name ~* 'Hydrocortisone butyrate' AND concept_class_id = 'Clinical Drug'
      AND standard_concept = 'S'
      )
SELECT DISTINCT a.class_code,
       d.concept_name,
       c.*,
       12 as concept_order,
       'ATC Class with semi-manual point fix'
FROM t1 a
  JOIN concept c ON c.concept_id = a.concept_id
  JOIN concept_manual d
    ON d.concept_code = a.class_code
   AND d.concept_class_id = 'ATC 5th'
   AND d.invalid_reason IS NULL
AND a.class_code||c.concept_id NOT IN (SELECT class_code||concept_id FROM class_to_drug_new); -- 13
      
-- clean up erroneous amount of ingredients 
DELETE
--SELECT *
FROM class_to_drug_new
WHERE class_name LIKE '%,%and%'
  AND class_name NOT LIKE '%,%,%and%'
  AND NOT class_name ~* 'comb|other|whole root|selective'
  AND concept_name NOT LIKE '% / % / %'; -- 14

--- add missing Clinical Drug Forms and Clinical Drugs using previous version of class_to_drug (order = 13)
INSERT INTO class_to_drug_new
SELECT DISTINCT b.concept_code AS class_code,
       b.concept_name AS class_name,
      c.*,
      13 as concept_order,
      'ATC Class from old class_to_drug'
FROM sources_class_to_drug_160921 a
  JOIN concept_manual b ON b.concept_code = a.class_code
  JOIN concept c
    ON a.concept_id = c.concept_id
   AND c.standard_concept = 'S' and c.concept_class_id !~ 'Pack|Ingredient'
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
 SELECT 'A06AA02',40036796); --  235
/**********************
****** ADD PACKS ******
***********************/
-- add packs of Primary lateral only in combination (order = 14)
INSERT INTO class_to_drug_new
SELECT DISTINCT a.class_code,
       a.class_name,
       j.*,
       14 as concept_order,
       'Pack: Primary lateral in combo' as order_desc 
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
                       FROM ing_pr_lat_combo)
                       /*dev_combo
                       WHERE class_code IN (SELECT class_code FROM dev_combo WHERE rnk = 1)
                       AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 2)
                       AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 3)
                       AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 4)
                       AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 0))*/
AND   j.concept_name ~ ' / ' -- combos only
AND   (a.class_code,j.concept_id) NOT IN (SELECT class_code, concept_id FROM class_to_drug_new); -- 1174

-- add additional packs of Primary lateral Ingredients in combination (Class A, combinations, order = 15)
INSERT INTO class_to_drug_new
SELECT DISTINCT a.class_code,
       a.class_name,
       j.*,
       15 as concept_order,
       'Pack: Primary lateral in combo additional'
FROM class_to_drug_new a
  JOIN concept_relationship r2 ON r2.concept_id_1 = a.concept_id
  JOIN concept j ON j.concept_id = r2.concept_id_2
WHERE r2.invalid_reason IS NULL
AND   j.concept_class_id IN ('Clinical Pack','Clinical Pack Box','Branded Pack','Branded Pack Box')
AND   j.standard_concept = 'S'
AND   a.class_code IN (SELECT class_code
                       FROM ing_pr_lat_combo)
                       /*dev_combo
                       WHERE class_code IN (SELECT class_code FROM dev_combo WHERE rnk = 1)
                       AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 2)
                       AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 3)
                       AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 4)
                       AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 0)) */
AND   j.concept_name ~ ' / ' -- combos only
AND   (a.class_code,j.concept_id) NOT IN (SELECT class_code, concept_id FROM class_to_drug_new); -- 262

-- add packs of Primary lateral + Secondary lateral (Class A AND Class B, order = 16)
INSERT INTO class_to_drug_new
SELECT DISTINCT a.class_code,
       a.class_name,
       j.*,
       16 as concept_order,
       'Pack: Primary lateral + Secondary lateral'
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
                       FROM ing_pr_lat_sec_lat)
AND   j.concept_name ~ ' / ' 
AND   (a.class_code,j.concept_id) NOT IN (SELECT class_code, concept_id FROM class_to_drug_new); -- 3830

-- add packs of Primary lateral and Secondary upward (Class A + Class D, order = 17) 
INSERT INTO class_to_drug_new
SELECT DISTINCT a.class_code,
       a.class_name,
       j.*,
       17 as concept_order,
       'Pack: Primary lateral + Secondary upward'
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
                       FROM ing_pr_lat_sec_up)
AND   j.concept_name ~ ' / '
AND   (a.class_code,j.concept_id) NOT IN (SELECT class_code, concept_id FROM class_to_drug_new); -- 218

--- add missing Packs using previous version of class_to_drug (order = 18)
INSERT INTO class_to_drug_new
SELECT DISTINCT b.concept_code AS class_code,
       b.concept_name AS class_name,
       c.*,
       18 as concept_order,
       'Additional Pack: from old c_t_d'
FROM sources_class_to_drug_160921 a
  JOIN concept_manual b ON b.concept_code = a.class_code
  JOIN concept c
    ON a.concept_id = c.concept_id
   AND c.standard_concept = 'S'
   AND b.invalid_reason IS NULL
WHERE (class_code,a.concept_id) NOT IN (SELECT class_code, concept_id FROM class_to_drug_new)
AND   a.concept_class_id ~ 'Pack'
AND   a.class_code NOT IN ('G01AF55','S03CA04','S01CA03','S02CA03')-- gives packs with erroneous forms
AND   a.class_code NOT IN ('B03AE01','C07BB52','D01AC52','C10AD52') -- wrong ing combo 
; -- 289

-- еnrich pool of links to Packs for 'G03FB Progestogens and estrogens, sequential preparations' AND 'G03AB Progestogens and estrogens, sequential preparations' 
-- they are always used as packs (order = 19)
INSERT INTO class_to_drug_new
SELECT DISTINCT class_code,
       class_name,
       c.*,
       19 as concept_order,
       'Additional Pack: semi-manual contraceptive'
FROM class_to_drug_new f
  JOIN devv5.concept_ancestor ca ON ca.ancestor_concept_id = CAST (f.concept_id AS INT)
  JOIN devv5.concept c
    ON c.concept_id = descendant_concept_id
   AND c.concept_class_id LIKE '%Pack%'
WHERE f.class_code ~ 'G03FB|G03AB'
AND  (f.class_code, c.concept_id) NOT IN (SELECT class_code, concept_id FROM class_to_drug_new); -- 264

-- get rid of all other concept_class_ids except Packs for 'G03FB Progestogens and estrogens, sequential preparations' AND 'G03AB Progestogens and estrogens, sequential preparations' 
DELETE
FROM class_to_drug_new
WHERE class_code ~ 'G03FB|G03AB' -- Progestogens and estrogens
AND   concept_class_id !~ 'Pack'; -- 81 

--  add links from ATC Classes WO Dose Forms specified, however their possible ancestors are unique (order = 20)
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
       b.concept_name,
       c.*,
       20 as concept_order,
       'ATC Mono WO Dose Form to Ingredient'
FROM all_drug a
join concept_manual b on b.concept_code = a.class_code and b.invalid_reason is null
join concept c on c.concept_id = a.concept_id
WHERE cnt = 1
AND   (class_code) NOT IN (SELECT class_code FROM class_to_drug_new); -- 5 */ -- to check


-- add those which are absent in the drug hierarchy
-- step 1
DROP TABLE if exists no_atc_1;
CREATE TABLE no_atc_1 
AS
(SELECT descendant_concept_id
FROM concept_ancestor
  JOIN dev_atc.class_to_drug_new n ON ancestor_concept_id = n.concept_id);
  
-- step 2
DROP TABLE if exists no_atc_2;
CREATE TABLE no_atc_2 
AS
(SELECT DISTINCT c.*
FROM concept c
WHERE domain_id = 'Drug'
AND   concept_id NOT IN (SELECT descendant_concept_id FROM no_atc_1)
AND   c.vocabulary_id IN ('RxNorm','RxNorm Extension')
AND   c.concept_class_id != 'Ingredient'
AND   c.standard_concept = 'S');

-- step 3
DROP TABLE if exists no_atc_1_with_form;
CREATE TABLE no_atc_1_with_form 
AS
(SELECT DISTINCT a.concept_id,
       a.concept_name,
       a.concept_class_id,
       a.vocabulary_id,
       b.ingredient_concept_id AS ing_id,
       d.concept_name AS ing_nm,
       d.standard_concept,
       g.concept_id AS df_id,
       g.concept_name AS df_nm
FROM no_atc_2 a
  JOIN drug_strength b ON b.drug_concept_id = a.concept_id
  JOIN concept d ON d.concept_id = b.ingredient_concept_id
  JOIN concept_relationship r ON r.concept_id_1 = a.concept_id
  JOIN concept g
    ON g.concept_id = r.concept_id_2
   AND g.concept_class_id = 'Dose Form');

-- add additional mappings for hierarchical absentees (order = 21)
INSERT INTO class_to_drug_new
SELECT DISTINCT k.concept_code AS class_code,
       k.concept_name AS class_name,
       p.*,
       21 as concept_order,
       'ATC Monocomp Class to Drug Product which is out of hierarchy'
FROM no_atc_1_with_form a
  JOIN internal_relationship_stage i ON lower (i.concept_code_2) = lower (a.ing_nm)
  JOIN internal_relationship_stage i2
    ON lower (i2.concept_code_2) = lower (a.df_nm)
   AND i.concept_code_1 = i2.concept_code_1
  JOIN concept_manual k ON k.concept_code = SUBSTRING (i.concept_code_1,'\w+')
  JOIN concept p
    ON p.concept_id = a.concept_id
   AND p.standard_concept = 'S'
WHERE a.concept_name !~ ' / '
AND   k.invalid_reason IS NULL
AND   k.concept_class_id = 'ATC 5th'
AND   k.concept_code NOT IN (SELECT class_code FROM dev_combo)
AND   k.concept_code||p.concept_id NOT IN (SELECT class_code||concept_id FROM class_to_drug_new);--6107

-- obtain more ATC Combo classes 
DROP TABLE no_atc_full_combo;
CREATE TABLE no_atc_full_combo 
AS
SELECT DISTINCT concept_id,
       concept_name,
       df_id,
       STRING_AGG(ing_id::VARCHAR,'-' ORDER BY ing_id::INT) AS i_combo
FROM no_atc_1_with_form
GROUP BY concept_id,
         concept_name,
         df_id;

DROP TABLE IF EXISTS no_atc_reodered;
CREATE UNLOGGED TABLE no_atc_reodered AS
SELECT DISTINCT fc.concept_id, -- missing Rx Drug
	fc.concept_name,
	df_id,
	l.i_combo
FROM no_atc_full_combo fc
CROSS JOIN LATERAL(SELECT STRING_AGG(s0.ing, '-' ORDER BY s0.ing::INT) AS i_combo FROM (
		SELECT UNNEST(STRING_TO_ARRAY(fc.i_combo, '-')) AS ing
		) AS s0) l;
		
INSERT INTO no_atc_full_combo
(concept_id, i_combo, df_id)
SELECT DISTINCT concept_id,
       i_combo, df_id
       FROM no_atc_reodered ;

CREATE INDEX i_no_atc_full_combo ON no_atc_full_combo (concept_id, i_combo,df_id);

-- add mappings of ATC Combo Class to Drug Product which is out of drug hierarchy (order = 22)
INSERT INTO class_to_drug_new
  SELECT DISTINCT k.concept_code as class_code, -- ATC
       k.concept_name as class_name,
       d.*,
       22 AS conept_order,
       'ATC Combo Class to Drug Product which is out of drug hierarchy'
    FROM no_atc_full_combo f
        JOIN full_combo_with_form c on c.i_combo = f.i_combo and c.df_id = f.df_id is null 
        join concept_manual k on k.concept_code = c.class_code and k.concept_class_id = 'ATC 5th' and k.invalid_reason is null
   JOIN concept d on d.concept_id = f.concept_id
   and c.class_code||d.concept_id not in (select class_code||concept_id from class_to_drug_new); -- 6188
   
-- ATC Combo Class to Drug Product which is out of drug hierarchy (order = 23)
INSERT INTO class_to_drug_new
  SELECT DISTINCT 
atc_code,atc_name,c.*,
       23 AS conept_order,
       'ATC Combo Class to Drug Product which is out of drug hierarchy'
    FROM MISSING a 
    join concept c using (concept_id)
   where atc_code||concept_id not in (select class_code||concept_id from class_to_drug_new); -- 2890

-- remove excessive links to children among Packs
WITH t1 AS
(
  SELECT *
  FROM class_to_drug_new
  where  concept_class_id ~ 'Pack')
delete from class_to_drug_new where class_code||concept_id in ( 
SELECT a1.class_code||
       a2.concept_id
FROM t1 a1-- papa 
  JOIN t1 a2 -- child
ON a1.class_code = a2.class_code
  JOIN concept_ancestor ca
    ON a1.concept_id = ca.ancestor_concept_id
   AND a2.concept_id = ca.descendant_concept_id
   AND a1.concept_id <> a2.concept_id
   and a2.concept_class_id ~ 'Pack'
     AND a1.class_code not in ('A02BA07','B02BD11', 'B02BD14', 'J07BK01', 'J07BK02', 'J07AE02','J07BB01','N05AF02' ))-- susoctocog alfa; parenteral, topical, urethral | norgestrel and estrogen | 	varicella, live attenuated; systemic); -- 2558 
   ; -- 3920
   
-- remove excessive links to children among unpacked Drug Products
WITH t0 AS
(
  SELECT *
  FROM class_to_drug_new
  WHERE  concept_class_id !~ 'Pack'
),
t1 as (
select * from t0 where class_code IN (SELECT class_code
                       FROM class_to_drug_new
                       GROUP BY class_code
                       HAVING COUNT(1) >= 2))
DELETE
FROM class_to_drug_new where class_code||concept_id IN ( 
SELECT a1.class_code||
       a2.concept_id -- child mapping
FROM t1 a1-- papa 
  JOIN t1 a2 -- child
ON a1.class_code = a2.class_code
  JOIN concept_ancestor ca
    ON a1.concept_id = ca.ancestor_concept_id
   AND a2.concept_id = ca.descendant_concept_id
   AND a1.concept_id <> a2.concept_id
   and a2.concept_class_id !~ 'Pack'
   AND a1.class_code NOT IN ('A02BA07','B02BD11', 'B02BD14', 'J07BK01', 'J07BK02', 'J07AE02','J07BB01','N05AF02')) -- catridecacog | susoctocog alfa; parenteral, topical, urethral | norgestrel and estrogen | 	varicella, live attenuated; systemic |zoster, live attenuated; systemic
   ;-- 10432
   
-- clean up the same issue among exclusions 
WITH t0 AS
(
  SELECT *
  FROM class_to_drug_new
  WHERE  concept_class_id !~ 'Pack'
  AND class_code  IN ('A02BA07','B02BD11', 'B02BD14', 'J07BK01', 'J07BK02', 'J07AE02','J07BB01','N05AF02')
),
t1 as (
select * from t0 where class_code IN (SELECT class_code
                       FROM class_to_drug_new
                       GROUP BY class_code
                       HAVING COUNT(1) >= 2))
DELETE
FROM class_to_drug_new where class_code||concept_id IN ( 
SELECT a1.class_code||
       a1.concept_id -- papa mapping
FROM t1 a1-- papa 
  JOIN t1 a2 -- child
ON a1.class_code = a2.class_code
  JOIN concept_ancestor ca
    ON a1.concept_id = ca.ancestor_concept_id
   AND a2.concept_id = ca.descendant_concept_id
   AND a1.concept_id <> a2.concept_id
   and a2.concept_class_id !~ 'Pack'
   AND a1.class_code  IN ('A02BA07','B02BD11', 'B02BD14', 'J07BK01', 'J07BK02', 'J07AE02','J07BB01','N05AF02')
   ) -- catridecacog | susoctocog alfa; parenteral, topical, urethral | norgestrel and estrogen | 	varicella, live attenuated; systemic |zoster, live attenuated; systemic
   ;
 
-- clean up the same issue among exclusions - Packs
WITH t0 AS
(
  SELECT *
  FROM class_to_drug_new
  WHERE  concept_class_id ~ 'Pack'
  AND class_code  IN ('A02BA07','B02BD11', 'B02BD14', 'J07BK01', 'J07BK02', 'J07AE02','J07BB01','N05AF02')
),
t1 as (
select * from t0 where class_code IN (SELECT class_code
                       FROM class_to_drug_new
                       GROUP BY class_code
                       HAVING COUNT(1) >= 2))
DELETE
FROM class_to_drug_new where class_code||concept_id IN ( 
SELECT a1.class_code||
       a1.concept_id -- papa mapping
FROM t1 a1-- papa 
  JOIN t1 a2 -- child
ON a1.class_code = a2.class_code
  JOIN concept_ancestor ca
    ON a1.concept_id = ca.ancestor_concept_id
   AND a2.concept_id = ca.descendant_concept_id
   AND a1.concept_id <> a2.concept_id
   and a2.concept_class_id ~ 'Pack'
   AND a1.class_code  IN ('A02BA07','B02BD11', 'B02BD14', 'J07BK01', 'J07BK02', 'J07AE02','J07BB01','N05AF02')
   ) -- catridecacog | susoctocog alfa; parenteral, topical, urethral | norgestrel and estrogen | 	varicella, live attenuated; systemic |zoster, live attenuated; systemic
   ;-- 19
/***************************
******** DF CLEAN UP *******
****************************/
-- clean up oral forms
DROP TABLE IF EXISTS wrong_df;
CREATE TABLE wrong_df as (
SELECT *, 'oral mismatch' as issue_desc
FROM class_to_drug_new
WHERE SPLIT_PART(class_name,';',2) ~ 'oral'
AND   concept_name !~* 'oral|chew|tooth|mouth|elixir|Extended Release Suspension|buccal|Sublingual|Paste|Mucosal|Prefilled Syringe|\...|Oral Ointment|Oral Cream'
AND   class_name !~ 'rectal|topical|inhalant|parenteral|transdermal|otic|vaginal|local oral|nasal'
AND   concept_class_id !~ 'Pack|Ingredient|Clinical Drug Comp'
AND   class_code NOT IN ('A01AA04','A01AA02','G04BD08')
);

INSERT INTO wrong_df
select *, 'vaginal mismatch' from class_to_drug_new  where class_name ~ 'vaginal' 
and concept_name !~* 'vaginal|topical|mucosal|Drug Implant|Douche|Irrigation Solution'
and class_name !~ 'oral|topical|inhalant|parenteral|transdermal|otic|rectal|local oral|systemic' 
and concept_class_id !~ 'Pack|Ingredient|Clinical Drug Comp'; -- 1

-- clean up rectal forms
INSERT INTO wrong_df
SELECT *, 'rectal mismatch'
FROM class_to_drug_new
WHERE class_name ~ 'rectal'
AND   concept_name !~* 'rectal|topical|mucosal|enema'
AND   class_name !~ 'oral|topical|inhalant|parenteral|transdermal|otic|vaginal|local oral|systemic'
AND   concept_class_id !~ 'Pack|Ingredient|Clinical Drug Comp';

-- clean up topical forms
INSERT INTO wrong_df
SELECT *, 'topical mismatch'
FROM class_to_drug_new
WHERE class_name ~ 'topical'
AND   concept_name !~* 'topical|mucosal|Drug Implant|Prefilled Applicator|Shampoo|Paste|Medicated Pad|Transdermal System|Soap|Powder Spray|Medicated Patch|Douche|vaginal|\yNail\y|Intrauterine System|Mouthwash|Oil|Intraperitoneal Solution|Urethral Gel'
AND   concept_name !~* '\yStick|Rectal Foam|Medicated Tape|Medicated Guaze|Paint|Rectal|Nasal|Otic|Ophthalmic Solution|Dry Powder|Urethral Suppository|Intrauterine|irrigation|Cement|Cream|ointment|spray|gum|enema|Ophthalmic'
AND   class_name !~* 'oral|vaginal|inhalant|parenteral|transdermal|otic|rectal|local oral|systemic'
AND   concept_class_id !~ 'Pack|Ingredient|Clinical Drug Comp';

-- clean up local oral forms
INSERT INTO wrong_df
SELECT *, 'local oral mismatch' 
FROM class_to_drug_new
WHERE class_name ~ 'local oral' and class_name !~ 'oral, local oral'
AND   concept_name !~* 'mouth|topical|paste|irrig|Lozenge|gum|buccal|Suspension|solution|subl|Gel|spray|Disintegrating Oral Tablet|Effervescent Oral Tablet|Oral Powder|Chewable Tablet|Oral Film|Oral Granules'
AND   concept_class_id !~ 'Pack|Ingredient|Clinical Drug Comp';

-- clean up inhalant
INSERT INTO wrong_df
SELECT *, 'inhalant mismatch'
FROM class_to_drug_new
WHERE class_name ~* 'inhalant'
AND   concept_name !~* 'inhal|nasal|Powder Spray|Oral Spray| Oral Powder|Prefilled Applicator'
AND   class_name !~ 'oral|local oral|vaginal|parenteral|transdermal|ophthalmic|otic|rectal|systemic|topical'
AND   concept_class_id !~ 'Pack|Ingredient|Clinical Drug Comp';

-- clean up parenteral
INSERT INTO wrong_df
SELECT *, 'parenteral mismatch'
FROM class_to_drug_new
WHERE class_name ~* 'parenteral'
AND   concept_name !~* 'inject|prefill|intrav|intram|cartridge|UNT|Intraperitoneal Solution|Irrigation Solution|MG\/ML|Inhal|Nasal|\...|Drug Implant|transdermal'
AND   class_name !~* 'oral|local oral|vaginal|inhalant|transdermal|topical|ophthalmic|otic|nasal|rectal|systemic|urethral'
AND   concept_class_id !~ 'Pack|Ingredient|Clinical Drug Comp';

-- clean up otic|ophthalmic
INSERT INTO wrong_df
SELECT *, 'otic|ophthalmic mismatch'
FROM class_to_drug_new
WHERE class_name ~* 'otic|ophthalmic'
AND   concept_name !~* 'otic|ophthalmic|topical|Prefilled Applicator'
AND   class_name !~* 'oral|local oral|vaginal|inhalant|transdermal|topical|nasal|rectal|systemic|urethral|parenteral'
AND   concept_class_id !~ 'Pack|Ingredient|Clinical Drug Comp';

-- clean up systemic forms 
INSERT INTO wrong_df
SELECT *, 'systemic mismatch'
FROM class_to_drug_new
WHERE class_name ~* 'systemic'
AND   concept_name ~* 'nasal'
AND   concept_name !~ 'metered'
AND   class_name !~* 'rectal|nasal|vaginal|topical'
AND   concept_class_id !~ 'Pack|Ingredient|Clinical Drug Comp'
AND   concept_name ~* 'caine|azoline|thrombin|sodium chloride|glycerol|acetylcysteine|chlorhexidine|amlexanox|ammonia|Chlorobutanol|phenylephrine|Peppermint oil|pyrilamine|dexpanthenol|Phentolamine|Sodium Chloride|Cellulose|glycerin|pantenol|tetrahydrozoline|triamcinolone|dexamethasone|Ephedrine|Histamine|Hydrocortisone' -- 
;

-- clean up systemic forms 2
INSERT INTO wrong_df
SELECT *, 'systemic mismatch 2'
FROM class_to_drug_new
WHERE class_name ~* 'systemic'
AND   concept_name !~* '\.\.\.$|oral|rectal|inject|chew|Cartridge|Sublingual|MG\ML|syringe|influenza|pertussis|intravenous|Sublingual|Amyl Nitrite|implant|transdermal|Intramuscular|\yInhal|rotavirus|papillomavirus|\ymening|pneumococ|Streptococ|buccal|Extended Release Suspension|Metered Dose Nasal Spray'
AND   class_name !~* 'rectal|nasal|vaginal|topical'
AND   concept_name !~* 'Alfentanil|scopolamine|amyl nitrite|Heroin|Chloroform|dihydroergotamine|estradiol|fentanyl|Furosemide|gonadorelin|Isosorbide Dinitrate|Ketamine|ketorolac|midazolam|naloxone|Thyrotropin-Releasing Hormone|succimer Kit for radiopharmaceutical preparation'
AND   concept_class_id !~ 'Pack|Ingredient|Clinical Drug Comp';

-- clean up instillation packs
INSERT INTO wrong_df
SELECT *, 'instill pack mismatch'
FROM class_to_drug_new
WHERE class_name ~ 'instill'
AND   concept_name !~* 'instil|irrig'
AND   concept_class_id !~ 'Pack|Ingredient|Clinical Drug Comp'
AND   concept_name !~ 'Intratracheal|Phospholipids / Soybean Oil';

-- clean up parenteral packs
INSERT INTO wrong_df
SELECT *, 'parenteral pack mismatch'
FROM class_to_drug_new
WHERE class_name ~* 'parenteral'
AND   concept_name !~* 'inject|prefill|intrav|intram|cartridge|UNT|Intraperitoneal Solution|Irrigation Solution|MG\/ML|Inhal|Nasal|\...|Drug Implant'
AND   class_name !~* 'oral|local oral|vaginal|inhalant|transdermal|topical|ophthalmic|otic|nasal|rectal|systemic|urethral'
AND   concept_class_id ~ 'Pack';

-- clean up systemic packs
INSERT INTO wrong_df
SELECT *, 'systemic pack mismatch 2'
FROM class_to_drug_new
WHERE class_name ~* 'systemic'
AND   concept_name !~* '\...$|\...\) \} Pack$|oral|rectal|inject|chew|Cartridge|Sublingual|MG\ML|syringe|influenza|pertussis|intravenous|Sublingual|Amyl Nitrite|implant|transdermal|Intramuscular|\yInhal|rotavirus|papillomavirus|\ymening|pneumococ|Streptococ|buccal|Extended Release Suspension|Metered Dose Nasal Spray'
AND   class_name !~* 'rectal|nasal|vaginal|topical'
AND   concept_name !~* 'Alfentanil|amyl nitrite|Chloroform|dihydroergotamine|estradiol|fentanyl|Furosemide|gonadorelin|Isosorbide Dinitrate|Ketamine|ketorolac|midazolam|naloxone|Thyrotropin-Releasing Hormone|succimer Kit for radiopharmaceutical preparation'
AND   concept_class_id ~ 'Pack'
and class_code not in ('R03AC130');   -- formoterol Powder for Oral Suspension|

-- clean up systemic packs 2 -  check This next time
INSERT INTO wrong_df
SELECT * , 'systemic pack mismatch 3'
FROM class_to_drug_new
WHERE class_name ~* 'systemic'
AND   concept_name !~* '\.\.\.$|\.\.\.\) \} Pack|oral|rectal|inject|chew|Cartridge|Sublingual|MG\ML|syringe|influenza|pertussis|intravenous|Sublingual|Amyl Nitrite|implant|transdermal|Intramuscular|\yInhal|rotavirus|papillomavirus|\ymening|pneumococ|Streptococ|buccal|Extended Release Suspension|Metered Dose Nasal Spray'
AND   class_name !~* 'rectal|nasal|vaginal|topical'
AND   concept_name !~* 'Alfentanil|amyl nitrite|Chloroform|dihydroergotamine|estradiol|fentanyl|Furosemide|gonadorelin|Isosorbide Dinitrate|Ketamine|ketorolac|midazolam|naloxone|Thyrotropin-Releasing Hormone|succimer Kit for radiopharmaceutical preparation'
AND   concept_class_id ~ 'Pack'
AND concept_code <> 'C02AC01'; -- clonidine Medicated Patch

-- wrong vaginal rings
INSERT INTO wrong_df
SELECT *
FROM class_to_drug_new
WHERE class_name ~ 'vaginal ring'
AND   concept_name !~* 'ring|insert|system|implant';

DELETE FROM wrong_df where class_code in ( 'C02AC01', 'G03GA08', 'R03AC13');

-- look at them and remove from class_to_drug_new
DELETE
FROM class_to_drug_new
WHERE class_code||concept_id IN (SELECT class_code||concept_id FROM wrong_df); -- 891
      
-- add links from ATC Combo Classes which do not have Dose Forms to Ingredients (do we need them?) order = 24
INSERT INTO class_to_drug_new 
WITH t1
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
       24 as concept_order,
       'ATC Combo Class to Ingredient'
FROM t1 a
  JOIN dev_combo k
    ON k.class_code = a.concept_code
   AND rnk IN (1, 2)
  JOIN concept c
    ON c.concept_id = k.concept_id
   AND c.concept_class_id = 'Ingredient'
   AND c.standard_concept = 'S'
   and a.concept_code||c.concept_id not in (select class_code||concept_id from class_to_drug_new);--314
   
-- wrong match
DELETE
FROM class_to_drug_new
WHERE class_code = 'J01CR04'
AND   concept_name ~* 'sulbactam';

-- remove wrong mapping of glafenine; oral (from old class_to_drug)
DELETE
FROM class_to_drug_new
WHERE class_code = 'N02BG03';

-- Remove Drug Components if any
DELETE
FROM class_to_drug_new
WHERE concept_class_id ~ '\yComp';

-- remove suspicious mapping of inexistent drugs (this table should be checked before)
DELETE
--select *
FROM class_to_drug_new
WHERE class_code IN (SELECT class_code FROM atc_inexistent); -- 16

-- remove wrong mappings 
DELETE
--select *
FROM class_to_drug_new
WHERE class_code||concept_code IN (SELECT concept_code_1||concept_code_2
                                   FROM concept_relationship_manual
                                   WHERE invalid_reason IS NOT NULL);-- 3

-- remove dead ATC Classes if any
DELETE
FROM class_to_drug_new
WHERE class_code IN (SELECT concept_code
                     FROM concept_manual
                     WHERE invalid_reason IS NOT NULL);

-- remove non-standard mappings if any
DELETE
FROM class_to_drug_new a
WHERE NOT EXISTS (SELECT 1
                  FROM devv5.concept c
                  WHERE c.standard_concept = 'S'
                  AND   c.concept_id = a.concept_id); 
                     
-- remove duplicates if any (however they should not be there - can be solved in the future)
DELETE
FROM class_to_drug_new
WHERE CTID NOT IN (SELECT MAX(CTID)
                   FROM class_to_drug_new
                   GROUP BY class_code,
                            concept_id);
                            
-- assemble the final of class_to_drug table in the following Concept Order:  
/*1. Manual
2. Mono: Ingredient A; form
3. Mono: Ingredient A
4. Combo: Ingredient A + Ingredient B
5. Combo: Ingredient A + group B 
6. Combo: Ingredient A, combination; form
7. Combo: Ingredient A, combination
8. Any packs*/

TRUNCATE TABLE class_to_drug;
INSERT INTO class_to_drug
SELECT DISTINCT class_code,
       class_name,
       concept_id,
       concept_name,
       concept_class_id,
       CASE
         WHEN class_code NOT IN (SELECT class_code FROM combo_pull) AND concept_order = 11 AND concept_name ~ ' / ' THEN 7
         WHEN concept_class_id ~ 'Pack' THEN 8-- 14, 15, 16, 17, 18, 
         WHEN concept_order IN (11,13) THEN 1-- ATC Class to Drug Product from concept_relationship_manual
         WHEN concept_order IN (1,12) THEN 2-- ATC Monocomp Class
         WHEN concept_order = 20 THEN 3--  Mono: Ingredient A
         WHEN concept_order IN (5,6,7) THEN 4-- ATC Combo Class: Primary lateral + Secondary lateral (2, 3 and 4 ingreds)
         WHEN concept_order IN (9,10,50,60,70) THEN 5-- Combo: Ingredient A  OR Group A + group B
         WHEN concept_order IN (3,4,8) THEN 6-- ATC Combo Class: Primary lateral in combination | ATC Combo Class: Primary lateral in combination with excluded Ingredient
         WHEN concept_order IN (2,21,22,23,24) THEN 7-- 7. Combo: Ingredient A, combination -- 24 - to Ingredients (skipped)
       END AS concept_order
FROM class_to_drug_new
; -- 12

DELETE
FROM class_to_drug
WHERE concept_class_id ~ 'Comp';

-- run load_stage.sql
