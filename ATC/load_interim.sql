/********************
***** REFERENCE *****
*********************/
-- create temporary table containing links bwetween ATC Сlass codes and combinations of (ATC_code + Dose Form) from drug_concept_stage
DROP TABLE if exists reference;
CREATE TABLE reference 
AS
SELECT DISTINCT class_code,
       concept_code
FROM drug_concept_stage
  LEFT JOIN class_drugs_scraper ON SPLIT_PART (concept_name,' ',1) = class_code;

-- create a table with aggregated RxE ingredients: rx_combo
DROP TABLE IF EXISTS rx_combo;
CREATE TABLE rx_combo AS
SELECT drug_concept_id,
       string_agg(ingredient_concept_id::VARCHAR, '-' ORDER BY ingredient_concept_id) AS i_combo
FROM devv5.drug_strength
       JOIN concept ON concept_id = drug_concept_id AND
                       concept_class_id IN ('Clinical Drug Form', 'Ingredient') -- 'Clinical Drug Comp' doesn't exist in ATCs
GROUP BY drug_concept_id ;

--ambiguous_class_ingredient
DROP TABLE IF EXISTS ambiguous_class_ingredient_tst;
CREATE UNLOGGED TABLE ambiguous_class_ingredient_tst 
AS
SELECT DISTINCT a.class_code,
       a.class_name,
       a.concept_name AS concept_code_2,
       rnk
FROM dev_combo a
 JOIN internal_relationship_stage i ON SUBSTRING (i.concept_code_1,'\w+') = a.class_code
 JOIN drug_concept_stage c
    ON c.concept_code = i.concept_code_2
   AND c.concept_class_id = 'Ingredient'
   AND lower (a.concept_name) = lower (c.concept_name); 
   
-- add rnk 0 - excluded Ingredients
INSERT INTO ambiguous_class_ingredient_tst
SELECT DISTINCT class_code,
       class_name,
       concept_name AS concept_code_2,
       rnk
FROM dev_combo
WHERE rnk = 0; -- 3726
                                 
-- separate pure ATC combinations (Primary lateral + Secondary lateral)
DROP TABLE IF EXISTS pure_combos;
CREATE TABLE pure_combos 
AS
SELECT DISTINCT class_code,
        concept_code_2,
       class_name,
       rnk
FROM ambiguous_class_ingredient_tst
WHERE class_code IN (SELECT class_code
                     FROM ambiguous_class_ingredient_tst
                     WHERE rnk = 1) -- Primary lateral
AND   class_code IN (SELECT class_code
                     FROM ambiguous_class_ingredient_tst
                     WHERE rnk = 2) -- Secondary lateral
AND   class_code NOT IN (SELECT class_code
                         FROM ambiguous_class_ingredient_tst
                         WHERE rnk = 3) -- exclude Priamry upward
AND   class_code NOT IN (SELECT class_code
                         FROM ambiguous_class_ingredient_tst
                         WHERE rnk = 4); -- exclude Secondary upward
                         -- 1629
                         
-- separate Primary upward Ingredients (ATC Groupers mentioned at the beginning of ATC Class name) -- rnk 3 only
DROP TABLE IF EXISTS ing_pr_up;
CREATE TABLE ing_pr_up AS 
SELECT DISTINCT class_code,
       concept_code_2,
       class_name,
       rnk
FROM ambiguous_class_ingredient_tst
WHERE class_code  IN (SELECT class_code
                         FROM ambiguous_class_ingredient_tst
                         WHERE rnk = 3) --  include Priamry upward
AND class_code NOT IN (SELECT class_code
                     FROM ambiguous_class_ingredient_tst
                     WHERE rnk = 1) -- exclude Primary lateral
AND   class_code NOT IN (SELECT class_code
                     FROM ambiguous_class_ingredient_tst
                     WHERE rnk = 2) -- exclude Secondary lateral
AND   class_code NOT IN (SELECT class_code
                         FROM ambiguous_class_ingredient_tst
                         WHERE rnk = 4);-- exclude Secondary upward

-- add the same Ingredients marked  as rnk=1 to create permutations, assume that there will not be more than 3 ingredients in combination
INSERT INTO ing_pr_up
SELECT class_code, concept_code_2,class_name, 1
  FROM ing_pr_up; -- 3186

-- combine pure ATC combos with ATC groupers
INSERT INTO ambiguous_class_ingredient_tst
SELECT DISTINCT class_code, class_name, concept_code_2, rnk
FROM ing_pr_up
UNION
SELECT DISTINCT class_code, class_name, concept_code_2, rnk
FROM pure_combos
; -- 7920

-- create index to make the script faster
CREATE INDEX ambiguous_class_ingredient_test ON ambiguous_class_ingredient_tst (class_code, concept_code_2, rnk);

-- create a table with aggregated ATC ingredients: full_combo (for 3 ingredients only)
-- separate direct ingredients 
DROP TABLE IF EXISTS ing_pr_lat;
CREATE UNLOGGED TABLE ing_pr_lat 
AS
SELECT DISTINCT a.*,  -- distinct is required here
       concept_id_2,
       1 AS precedence -- will be changed a bit later for some ATC codes
       FROM ambiguous_class_ingredient_tst a
  JOIN relationship_to_concept rtc ON rtc.concept_code_1 = concept_code_2
WHERE rnk = 1; -- 4119

-- separate Secondary lateral ingredients (rnk = 2)
DROP TABLE IF EXISTS ing_sec_lat;
CREATE UNLOGGED TABLE ing_sec_lat 
AS
SELECT DISTINCT a.*,
       concept_id_2,
       1 as precedence -- distinct is required here (can be filled in a futher release)
       FROM ambiguous_class_ingredient_tst a
  JOIN relationship_to_concept rtc ON rtc.concept_code_1 = concept_code_2
WHERE rnk = 2; -- 1213

-- separate Primary upward ingredients (rnk = 3)
DROP TABLE IF EXISTS ing_pr_up;
CREATE UNLOGGED TABLE ing_pr_up 
AS
SELECT DISTINCT a.*,
       concept_id_2,
       1 as precedence
FROM ambiguous_class_ingredient_tst a
  JOIN relationship_to_concept rtc ON rtc.concept_code_1 = concept_code_2
WHERE rnk = 3; -- 4086

-- separate Secondary upward ingredients (rnk = 4)
DROP TABLE IF EXISTS ing_sec_up;
CREATE UNLOGGED TABLE ing_sec_up 
AS
SELECT DISTINCT a.*, -- distinct is required here
       concept_id_2,
       precedence 
       FROM ambiguous_class_ingredient_tst a
  JOIN relationship_to_concept rtc ON rtc.concept_code_1 = concept_code_2
WHERE rnk = 4; -- Secondary upward

-- obtain the full list of all possible combinations of ingredients for a one ATC-combo (48m 46s)
DROP TABLE if exists full_combo;
CREATE UNLOGGED TABLE full_combo 
AS
SELECT DISTINCT a.class_code,
       a.class_name,
       a.concept_id_2||COALESCE('-' || b.concept_id_2,'') ||COALESCE('-' || c.concept_id_2,'') ||COALESCE('-' || d.concept_id_2,'') AS i_combo
FROM ing_pr_lat a
  JOIN ing_sec_lat b USING (class_code)-- rank 2
  LEFT JOIN ing_pr_up c USING (class_code)-- rank 3
  LEFT JOIN ing_sec_up d USING (class_code)-- rank 4
ORDER BY class_code;

-- create table with Ingredient permutations
DROP TABLE IF EXISTS permutations;
CREATE UNLOGGED TABLE permutations 
AS
SELECT distinct a.class_code, a.class_name, a.concept_id_2||COALESCE('-' || b.concept_id_2, '')||COALESCE('-' || c.concept_id_2, '') AS i_combo
        FROM ing_pr_lat a -- from Primary lateral
LEFT JOIN ing_sec_lat b ON b.class_code = a.class_code -- to the 1st Secondary lateral
LEFT JOIN ing_sec_lat c ON c.class_code = a.class_code -- and the 2nd Secondary lateral
WHERE b.concept_id_2<>c.concept_id_2 AND b.concept_id_2<>a.concept_id_2;--34262

-- add newly created permutations to the full_combo table in oreder to enrich the set of aggregated ATC ingredients
INSERT INTO full_combo
SELECT * FROM permutations; -- 34262

--  Separate 1 Pr lateral in combination
DROP TABLE if exists ing_pr_lat_combo;

CREATE TABLE ing_pr_lat_combo 
AS
(SELECT *
FROM dev_combo a
WHERE class_code IN (SELECT class_code FROM dev_combo WHERE rnk = 1)
AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 2)
AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 3)
AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 4)
AND   class_code NOT IN (SELECT class_code FROM dev_combo WHERE rnk = 0));

-- create temporary table with all possible i_combos for Primary laterla in combinations (with unspecified drugs) 
DROP TABLE if exists ing_pr_lat_combo_to_drug;

CREATE TABLE ing_pr_lat_combo_to_drug 
AS
(WITH t1
AS
(SELECT drug_concept_id,
       REGEXP_SPLIT_TO_TABLE(i_combo,'-')::INT AS i_combo
FROM rx_combo
WHERE i_combo LIKE '%-%') 
  SELECT DISTINCT a.class_code,
       a.class_name,
       d.i_combo
FROM ing_pr_lat_combo a
  JOIN t1 b ON b.i_combo = a.concept_id
  JOIN rx_combo d ON d.drug_concept_id = b.drug_concept_id);

-- 2 Pr lat in combinations 
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

DROP TABLE if exists ing_pr_lat_combo_excl_to_drug;
CREATE TABLE ing_pr_lat_combo_excl_to_drug 
AS
(WITH t1
AS
(SELECT drug_concept_id,
       REGEXP_SPLIT_TO_TABLE(i_combo,'-')::INT AS i_combo
FROM rx_combo
WHERE i_combo LIKE '%-%') SELECT DISTINCT a.class_code,a.class_name,d.i_combo FROM ing_pr_lat_combo_excl a JOIN t1 b ON b.i_combo = a.concept_id JOIN ing_pr_lat_combo_excl a1 ON a1.class_code = a.class_code AND a1.rnk <> a.rnk AND a1.rnk = 0 JOIN t1 f ON f.i_combo = a1.concept_id
-- excluded
JOIN rx_combo d ON d.drug_concept_id = b.drug_concept_id JOIN rx_combo d1 ON d1.drug_concept_id = f.drug_concept_id
-- excluded
AND d1.drug_concept_id <> d.drug_concept_id);;

-- 3 Pr up+Sec up  
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

-- 4 Pr up+Sec up with excluded ingreds 
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

-- currently no match, but query works
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
FROM ing_pr_sec_up_combo_excl_to_drug; -- 10086 

-- create a table full_combo_reodered to order aggregated ATC ingredients by an Ingredient
DROP TABLE IF EXISTS full_combo_reodered;
CREATE UNLOGGED TABLE full_combo_reodered AS 
SELECT DISTINCT fc.class_code,
	fc.class_name,
	l.i_combo
FROM full_combo fc
CROSS JOIN LATERAL(SELECT STRING_AGG(s0.ing, '-' ORDER BY s0.ing::INT) AS i_combo FROM (
		SELECT UNNEST(STRING_TO_ARRAY(fc.i_combo, '-')) AS ing
		) AS s0) l;
			
-- create index to make the script faster -- 30m 7s (ask Timur to check whether these indices are useful) - 55m 38s
CREATE INDEX i_full_combo_reodered ON full_combo_reodered (class_code, i_combo);

-- create full_combo_with_form table containig aggregated ATC ingredients + Dose Form -- 6.03s
DROP TABLE full_combo_with_form;
CREATE UNLOGGED TABLE full_combo_with_form
AS
SELECT DISTINCT a.class_code,
        a.class_name,
       a.i_combo,
       r.concept_id_2::int
FROM full_combo_reodered a
  JOIN internal_relationship_stage i ON class_code = substring (concept_code_1, '\w+') -- cut ATC code before space character
  JOIN drug_concept_stage b
    ON b.concept_code = i.concept_code_2
   AND b.concept_class_id = 'Dose Form'
  JOIN relationship_to_concept r ON r.concept_code_1 = i.concept_code_2;
  
-- add ATC combos without forms from the 'reference' table -- 27 740 577 rows affected 
INSERT INTO full_combo_with_form
(class_code, i_combo)
SELECT DISTINCT f.class_code,
       i_combo
       FROM full_combo_reodered f
  JOIN reference r ON r.class_code = f.class_code
WHERE r.concept_code = r.class_code 
; --  17 (7640)

CREATE INDEX i_full_combo_with_form ON full_combo_with_form (class_code, i_combo,concept_id_2); -- 10m 8s
DROP TABLE IF EXISTS combo_not_limited_to_higher_ATC;
CREATE UNLOGGED TABLE combo_not_limited_to_higher_ATC 
AS
WITH t1 AS
(
  SELECT drug_concept_id, regexp_split_to_table (i_combo, '-')::INT AS i_combo FROM rx_combo
WHERE i_combo LIKE '%-%' -- at least two ingredients
AND drug_concept_id NOT IN (SELECT drug_concept_id FROM ing_excl)  -- filter out drugs containig excluded ingredients if any
)
SELECT DISTINCT b.class_code,
       d.class_name,
       a.drug_concept_id
FROM t1 a-- Pr up
  JOIN ing_pr_sec_up b -- Primary and Secondary upward with Ingredients
      ON b.concept_id_2  = a.i_combo
      JOIN dev_combo d on d.class_code = b.class_code
           and d.rnk = 3 
    JOIN t1 k -- Sec up
    on k.drug_concept_id = a.drug_concept_id
       JOIN ing_pr_sec_up c on c.concept_id_2  = k.i_combo
       JOIN dev_combo d2 on d2.class_code = c.class_code
      and a.i_combo <> k.i_combo
      and d2.rnk = 4; 
      
/*******************************
******** CLASS TO DRUG *********
********************************/
-- create table with one-step links between ATC combos of 5th class and Rx/RxN Drug Products using the full macth of an Ingredient and Dose Form 
DROP TABLE IF EXISTS class_to_drug;
CREATE TABLE class_to_drug AS
-- separate all Rx/RxN combo drugs of 'Clinical Drug Form' concept class
WITH t1 AS
(
  SELECT c.concept_id, -- Standard Drug Product
       c.concept_name,
       c.concept_class_id,
       c.vocabulary_id,
       r.concept_id_2, -- Dose Form
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
       f.class_name,
       r.concept_id, -- Standard Drug Product
       r.concept_name,
       r.concept_class_id,
       1 AS ORDER -- specific number for cases with the same order of ids in i_combo?
       FROM full_combo_with_form f
  JOIN t1 r
    ON r.i_combo = f.i_combo -- combination of Standard Ingredient IDs 
   AND r.concept_id_2 = f.concept_id_2   ;

-- add additional links using the table of 'combo_not_limited_to_higher_ATC' (this step gives errors!!!)
INSERT INTO class_to_drug
 WITH t1 AS (
 -- separate Rx/RxN combo Drug Forms
  SELECT a.concept_id, -- Rx
       a.concept_name,
       a.concept_class_id,
       a.vocabulary_id,
       c.concept_id_2, -- Rx Dose Form
       r.class_code, -- ATC
       r.class_name
FROM combo_not_limited_to_higher_ATC r
           JOIN concept a ON r.drug_concept_id = a.concept_id
           JOIN concept_relationship c ON c.concept_id_1 = a.concept_id
    WHERE a.concept_class_id = 'Clinical Drug Form'
      AND a.vocabulary_id LIKE 'RxNorm%'
      AND a.invalid_reason IS NULL
      AND relationship_id = 'RxNorm has dose form'
      AND c.invalid_reason IS NULL
    )
SELECT DISTINCT a.class_code,
       a.class_name,
       a.concept_id,
       a.concept_name,
       a.concept_class_id,
       6 -- combo_not_limited_to_higher_ATC
FROM t1 a
  JOIN internal_relationship_stage i ON SUBSTRING (i.concept_code_1,'\w+') = a.class_code
  JOIN relationship_to_concept rtc ON i.concept_code_2 = rtc.concept_code_1
WHERE a.concept_id_2 = rtc.concept_id_2
AND   (a.class_code, a.concept_id) NOT IN (SELECT class_code, concept_id FROM class_to_drug) -- prevent duplicates
; -- 1416

-- contraceptive packs
INSERT INTO class_to_drug
SELECT class_code,
       class_name,
       c.concept_id,
       c.concept_name,
       c.concept_class_id -- was added 17.06
       "order"
FROM class_to_drug ctd
  JOIN concept_ancestor ON ctd.concept_id = ancestor_concept_id
  JOIN concept c ON descendant_concept_id = c.concept_id
WHERE class_code ~ 'G03FB|G03AB'
AND   c.concept_class_id IN ('Clinical Pack')
AND  (ctd.class_code, c.concept_id) NOT IN (SELECT class_code, concept_id FROM class_to_drug); -- 440

-- insert mono-ATC codes
DROP TABLE IF EXISTS mono_ing;
CREATE UNLOGGED TABLE mono_ing 
AS
SELECT DISTINCT a.class_code,
       a.class_name,
       rtc.concept_id_2 AS ing_id
FROM class_drugs_scraper a
  JOIN internal_relationship_stage i ON class_code = SUBSTRING (concept_code_1,'\w+')
  JOIN drug_concept_stage d
    ON lower (d.concept_code) = lower (i.concept_code_2)
   AND concept_class_id = 'Ingredient'
  JOIN relationship_to_concept rtc ON rtc.concept_code_1 = i.concept_code_2
WHERE LENGTH(class_code) = 7
AND class_code NOT IN (SELECT class_code FROM dev_combo)
AND class_code NOT IN (SELECT class_code FROM class_drugs_scraper where  class_code ~ '^J07|^A10A' AND length(class_code)=7)
AND class_name !~* '\yand\y' 
and class_code not in (select class_code from class_to_drug) 
; -- 5462

-- add Forms
DROP TABLE if exists mono_ing_with_form;

CREATE TABLE mono_ing_with_form 
AS
(SELECT class_code,
       class_name,
       ing_id,
       concept_id_2 AS form_id
FROM mono_ing
  JOIN internal_relationship_stage i ON class_code = SUBSTRING (i.concept_code_1,'\w+')
  JOIN drug_concept_stage d
    ON d.concept_code = i.concept_code_2
   AND d.concept_class_id = 'Dose Form'
  JOIN relationship_to_concept rtc ON rtc.concept_code_1 = i.concept_code_2);;
         
INSERT INTO class_to_drug
with t1 as (SELECT distinct drug_concept_id, i_combo::INT AS i_combo FROM rx_combo
WHERE i_combo NOT LIKE '%-%')
SELECT DISTINCT k.class_code, k.class_name, a.concept_id, a.concept_name, a.concept_class_id,2
FROM mono_ing_with_form k -- ATC
JOIN t1 r -- Rx
ON r.i_combo = k.ing_id  
JOIN concept a ON r.drug_concept_id = a.concept_id
JOIN concept_relationship c ON c.concept_id_1 = a.concept_id AND k.form_id = c.concept_id_2
    WHERE a.concept_class_id = 'Clinical Drug Form'
      AND a.vocabulary_id LIKE 'RxNorm%'
      AND a.invalid_reason IS NULL
      AND relationship_id = 'RxNorm has dose form'
      AND c.invalid_reason IS NULL
 AND  (k.class_code, a.concept_id) NOT IN (SELECT class_code, concept_id FROM class_to_drug);  -- 14119

-- additional links
INSERT INTO class_to_drug
SELECT DISTINCT m.class_code,
       m.class_name,
       c.concept_id,
       c.concept_name,
       c.concept_class_id,
       3
FROM mono_ing m
  JOIN internal_relationship_stage i ON class_code = SUBSTRING (concept_code_1,'\w+')
  JOIN concept c ON m.ing_id = c.concept_id
WHERE i.concept_code_1 not in (select concept_code_1 from internal_relationship_stage where concept_code_1 LIKE '% %') -- exclude ATC classes with Forms (they contain space inbetween)
 AND  (m.class_code, c.concept_id) NOT IN (SELECT class_code, concept_id FROM class_to_drug)
;-- 1168

-- add manual links using concept_relationship_manual -- TO DO: relatioship_id for J07BM J07BM from Subsumes to ATC - RxNorn pr lat
-- check in old class_to_drug whether there are additional ingredients
INSERT INTO class_to_drug
SELECT DISTINCT a.class_code, 
f.concept_name as class_name, 
c.concept_id, 
c.concept_name,
c.concept_class_id,
--relationship_id,
1
from class_drugs_scraper a
join concept_relationship_manual b on b.concept_code_1 = a.class_code 
join concept_manual f on f.concept_code = a.class_code
AND b.relationship_Id in ('ATC - RxNorm') --'ATC - RxNorm pr lat', 'ATC - RxNorm sec lat', 'ATC - RxNorm pr up', 'ATC - RxNorm sec up')
JOIN concept c on c.concept_code = b.concept_code_2 and c.vocabulary_id = b.vocabulary_id_2
and c.vocabulary_id in ('RxNorm', 'RxNorm Extension')
 AND  (a.class_code, c.concept_id) NOT IN (SELECT class_code, concept_id FROM class_to_drug)
 and f.invalid_reason is null; -- 4920
 
DELETE
FROM class_to_drug
WHERE (class_code = 'A02BA07' AND concept_class_id = 'Clinical Drug Form') -- Branded Drug 'Tritec'
OR class_code = 'G03GA08' -- choriogonadotropin alfa (no Standard Precise Ingredient)
OR class_code='N05AF02' -- clopentixol
OR class_code IN ('D07AB02','D07BB04') -- 	hydrocortisone butyrate + combo that so far doesn't exist
OR class_code = 'C01DA05' -- pentaerithrityl tetranitrate; oral
OR (class_code = 'B02BD14'  AND concept_name LIKE '%Tretten%') -- 2 --catridecacog
OR (class_code IN ('B02BD14','B02BD11') and concept_class_id = 'Ingredient')-- susoctocog alfa | catridecacog
;

INSERT INTO class_to_drug
SELECT 'B02BD11','catridecacog', concept_id, concept_name, concept_class_id,1
FROM concept
WHERE (vocabulary_id LIKE 'RxNorm%' AND concept_name LIKE 'coagulation factor XIII a-subunit (recombinant)%'
      AND standard_concept = 'S' AND concept_class_id = 'Clinical Drug')
   OR concept_id = 35603348 -- the whole hierarchy (35603348	1668002	factor XIII Injection [Tretten]	Branded Drug Form) -- 2 
;
INSERT INTO class_to_drug
SELECT 'B02BD14','susoctocog alfa', concept_id, concept_name, concept_class_id,1
FROM concept
WHERE (vocabulary_id LIKE 'RxNorm%'
      AND concept_name LIKE 'antihemophilic factor, porcine B-domain truncated recombinant%' AND standard_concept = 'S' AND concept_class_id = 'Clinical Drug')
   OR concept_id IN (35603348, 44109089) -- the whole hierarchy
; -- 3

INSERT INTO class_to_drug
SELECT 'A02BA07','ranitidine bismuth citrate', concept_id, concept_name, concept_class_id,1
FROM concept
WHERE vocabulary_id LIKE 'RxNorm%' AND concept_name LIKE '%Tritec%'
      AND standard_concept = 'S' AND concept_class_id = 'Branded Drug Form'
; -- 1 

INSERT INTO class_to_drug
SELECT 'G03GA08','choriogonadotropin alfa', concept_id, concept_name, concept_class_id,1
FROM concept
WHERE vocabulary_id LIKE 'RxNorm%' AND concept_name ~ 'choriogonadotropin alfa'
      AND standard_concept = 'S' AND concept_class_id ~ 'Clinical Drug Comp'
; -- 1


INSERT INTO class_to_drug
SELECT 'N05AF02','clopenthixol', concept_id, concept_name, concept_class_id,1
FROM concept
WHERE vocabulary_id LIKE 'RxNorm%' AND concept_name ~* 'Sordinol|Ciatyl'
      AND standard_concept = 'S' AND concept_class_id = 'Branded Drug Form'
; -- 4 

INSERT INTO class_to_drug
SELECT 'D07AB02','hydrocortisone butyrate', concept_id, concept_name, concept_class_id,1
FROM concept
WHERE vocabulary_id LIKE 'RxNorm%' AND concept_name ~* 'Hydrocortisone butyrate' AND concept_class_id = 'Clinical Drug'
      AND standard_concept = 'S'
;-- 6 

-- remove pentaerithrityl tetranitrate; oral
DELETE
FROM class_to_drug
WHERE class_code = 'C01DA05' -- pentaerithrityl tetranitrate; oral
; -- 7

INSERT INTO class_to_drug
SELECT 'C01DA05','pentaerithrityl tetranitrate', concept_id, concept_name, concept_class_id,1
FROM concept
WHERE vocabulary_id LIKE 'RxNorm%' AND concept_name ILIKE '%Pentaerythritol Tetranitrate%' and
      standard_concept = 'S' AND concept_class_id = 'Clinical Drug Comp' -- forms do not exist
; -- 9

-- clean up erroneous amount of ingredients 
DELETE
FROM class_to_drug
WHERE class_name LIKE '%,%and%'
  AND class_name NOT LIKE '%,%,%and%'
  AND NOT class_name ~* 'comb|other|whole root|selective'
  AND concept_name NOT LIKE '% / % / %'; -- 135

-- process Packs, which should be added to the ATC hiearchy in parallel (to be shown in Athena as well)
DROP TABLE IF EXISTS pack_a;
  create table pack_a AS (
    SELECT DISTINCT concept_id_1,
           drug_concept_id,
           string_agg(ingredient_concept_id::VARCHAR, '-' ORDER BY ingredient_concept_id) AS i_combo,
           count(drug_concept_id) over (partition by concept_id_1) as cnt
    FROM drug_strength
           JOIN concept_relationship r
                on drug_concept_id = concept_id_2 AND relationship_id = 'Contains' AND r.invalid_reason IS NULL
           JOIN concept c on c.concept_id = concept_id_1 AND concept_class_id = 'Clinical Pack'
    GROUP BY drug_concept_id,concept_id_1);
    
DROP TABLE IF EXISTS pack_b;
 create table pack_b as
      (SELECT DISTINCT class_code, class_name, r.concept_code_1, r.concept_id_2
       FROM dev_combo
              JOIN internal_relationship_stage i on substring(i.concept_code_1, '\w+') = class_code
              JOIN drug_concept_stage d on d.concept_code = concept_code_2 AND concept_class_id = 'Ingredient'
              JOIN relationship_to_concept r on r.concept_code_1 = i.concept_code_2
       WHERE class_name LIKE '% and %');
       
DROP TABLE IF EXISTS pack_c;       
 create table pack_c AS (SELECT DISTINCT class_code, r.concept_code_1, r.concept_id_2
          FROM dev_combo
                 JOIN internal_relationship_stage i on substring(i.concept_code_1, '\w+') = class_code
                 JOIN drug_concept_stage d on d.concept_code = concept_code_2 AND concept_class_id = 'Ingredient'
                 JOIN relationship_to_concept r on r.concept_code_1 = i.concept_code_2
          WHERE class_name LIKE '% and %');
          
DROP TABLE IF EXISTS pack_all;
CREATE TABLE pack_all as
    SELECT DISTINCT cc.concept_id, cc.concept_name, cc.concept_class_id, b.class_code, b.class_name
    FROM pack_a a
           JOIN pack_a aa on aa.concept_id_1 = a.concept_id_1
           JOIN concept cc on concept_id = a.concept_id_1
           JOIN pack_b b on cast(b.concept_id_2 AS varchar) = aa.i_combo
           JOIN pack_c c  on cast(c.concept_id_2 AS varchar) = a.i_combo
    WHERE a.drug_concept_id != aa.drug_concept_id
      AND b.class_code = c.class_code
      AND b.concept_code_1 != c.concept_code_1
      AND a.cnt = 2;

-- errnoues pack match
DELETE 
FROM pack_all
  WHERE (class_code='A02BD11' AND concept_id=42731634)
  OR    (class_code='R03AL08' AND concept_id=43045404);

DROP TABLE IF EXISTS pack_temp;
CREATE TABLE pack_temp
as
with a AS (SELECT concept_id_1,
                  string_agg(ingredient_concept_id::varchar, '-' ORDER BY ingredient_concept_id) AS i_combo
           FROM drug_strength
                  JOIN concept_relationship r on drug_concept_id = concept_id_2 AND relationship_id = 'Contains' AND r.invalid_reason IS NULL
                  JOIN concept c on c.concept_id = concept_id_1 AND concept_class_id = 'Clinical Pack'
           GROUP BY concept_id_1),
     b AS (
SELECT DISTINCT class_code, class_name, r.concept_code_1, r.concept_id_2
FROM dev_combo
JOIN internal_relationship_stage i on substring(i.concept_code_1, '\w+') = class_code
JOIN drug_concept_stage d on d.concept_code = concept_code_2 AND concept_class_id = 'Ingredient'
JOIN relationship_to_concept r on r.concept_code_1 = i.concept_code_2
WHERE class_name LIKE '%, combinations')
SELECT DISTINCT cc.concept_id, cc.concept_name, cc.concept_class_id, b.class_code, b.class_name
FROM a
JOIN b on i_combo ~ cast(b.concept_id_2 AS varchar)
and i_combo!=cast(b.concept_id_2 AS varchar)
JOIN concept cc on concept_id_1 = concept_id
;

INSERT INTO pack_all
with a AS (
  SELECT p.concept_id, p.concept_name, p.concept_class_id, class_code,class_name, r.concept_id_2
  FROM pack_temp p
         JOIN internal_relationship_stage ON substring(concept_code_1, '\w+') = class_code
         JOIN drug_concept_stage d ON concept_code_2 = concept_code AND d.concept_class_id = 'Dose Form'
         JOIN relationship_to_concept r ON r.concept_code_1 = concept_code_2),
     b AS (SELECT p.*, r2.concept_id_2
           FROM pack_temp p
                  JOIN devv5.concept_ancestor r on concept_id = descendant_concept_id
                  JOIN concept_relationship r2
                       ON r2.concept_id_1 = ancestor_concept_id AND r2.invalid_reason IS NULL
                       AND  relationship_id = 'RxNorm has dose form')
SELECT a.concept_id, a.concept_name, a.concept_class_id, a.class_code, a.class_name
FROM a
JOIN b USING (concept_id, concept_id_2)
WHERE (concept_id, a.class_code) NOT IN (SELECT concept_id, class_code FROM pack_all)
UNION
SELECT p.*
FROM pack_temp p
JOIN reference r on concept_code = p.class_code
WHERE (concept_id, p.class_code) NOT IN (SELECT concept_id, class_code FROM pack_all)
; -- 3945

INSERT INTO class_to_drug
(
  class_code,
  class_name,
  concept_id,
  concept_name,
  concept_class_id,
  "order"
)
SELECT DISTINCT class_code,
       class_name,
       concept_id,
       concept_name,
       concept_class_id,
       8
FROM pack_all; -- 4882

-- 4.11 fix packs
INSERT INTO class_to_drug
SELECT DISTINCT class_code,
       class_name,
       c.concept_id,
       c.concept_name,
       c.concept_class_id,
       8
FROM class_to_drug f
  JOIN devv5.concept_ancestor ca ON ca.ancestor_concept_id = CAST (f.concept_id AS INT)
  JOIN devv5.concept c
    ON c.concept_id = descendant_concept_id
   AND c.concept_class_id LIKE '%Pack%'
WHERE f.class_code ~ 'G03FB|G03AB' -- packs
; -- 1809

-- get rid of all other forms except Packs
-- 4.12 Progestogens and estrogens
DELETE
FROM class_to_drug
WHERE class_code ~ 'G03FB|G03AB' -- 	Progestogens and estrogens
AND   concept_class_id IN ('Clinical Drug Form','Ingredient'); -- 68

-- 4.14 Solution for the first run: for inambiguous ATC classes (those that classify an ingredient through only one class)
-- we relate this ATC class to the entire group of drugs that have this ingredient.
DROP TABLE IF EXISTS  interim;
CREATE TABLE interim
AS
WITH a AS
(
  SELECT DISTINCT class_code,
         class_name,
         c.concept_id,
         c.concept_name
  FROM class_to_drug crd
    JOIN devv5.concept_ancestor ON crd.concept_id = descendant_concept_id
    JOIN concept c
      ON c.concept_id = ancestor_concept_id
     AND c.concept_class_id = 'Ingredient'
)
SELECT *
FROM (SELECT COUNT(*) OVER (PARTITION BY TRIM(REGEXP_REPLACE(class_name,'\(.*\)',''))) AS cnt,
             class_code,
             class_name,
             a.concept_id,
             a.concept_name -- regexp for (vit C)
             FROM a) a
WHERE cnt = 1
AND   class_code NOT IN (SELECT class_code FROM class_drugs_scraper
WHERE class_code ~ '^J07|^A10A'
AND length(class_code)=7)
--and class_code NOT IN ('G02BB02')
;

DELETE
FROM interim
WHERE class_name IN (
  SELECT class_name
  FROM (SELECT DISTINCT class_code, class_name FROM class_drugs_scraper) a
  GROUP BY class_name
  HAVING count(1) > 1); -- 58

DELETE
FROM interim
WHERE concept_id IN (
  SELECT a.concept_id
  FROM interim a
         JOIN interim b ON a.concept_id = b.concept_id
  WHERE a.class_code != b.class_code); -- 105

DROP TABLE IF EXISTS interim_2;
CREATE TABLE interim_2 AS
WITH a AS (
SELECT DISTINCT class_code, class_name, c.concept_id,c.concept_name
FROM class_to_drug crd
JOIN devv5.concept_ancestor on crd.concept_id = descendant_concept_id
JOIN concept c on c.concept_id = ancestor_concept_id AND c.concept_class_id = 'Ingredient'
  ),
b AS (SELECT concept_id FROM a
GROUP BY concept_id having count(1)=1),
c AS (SELECT a.class_code, a.class_name, a.concept_id FROM a JOIN b USING(concept_id)
  )
SELECT c.*
FROM c
JOIN interim USING(class_code)
WHERE class_code NOT IN (SELECT class_code FROM class_to_drug_manual)
;

DELETE
FROM interim_2
WHERE class_name IN (
  SELECT class_name
  FROM (SELECT DISTINCT class_code, class_name FROM class_drugs_scraper) a
  GROUP BY class_name
  HAVING count(1) > 1); --0

-- -- inambiguous only for forms
DELETE FROM class_to_drug 
WHERE class_code IN (SELECT class_code FROM interim)
; -- 6988 (9196)

-- add missing forms for the monocomponent ATC Drug Classes
INSERT INTO class_to_drug -- ingredients are partially inambiguous
(class_code, class_name, concept_id, concept_name, concept_class_id, "order")
SELECT class_code, class_name, c.concept_id, c.concept_name, c.concept_class_id, 2
FROM interim i
JOIN devv5.concept_ancestor ca on i.concept_id = ancestor_concept_id
JOIN concept c on descendant_concept_id = c.concept_id
WHERE  c.concept_class_id = 'Clinical Drug Form' AND c.concept_name NOT LIKE '% / %'
and (class_code, c.concept_id) not in (select class_code, concept_id from class_to_drug)
; -- 8653

-- remove absolutely inambiguous Ingredient 
DELETE FROM class_to_drug
WHERE class_code IN(SELECT class_code FROM interim_2)
; -- 4019
-- add their maps 
INSERT INTO class_to_drug -- ingredients are absolutely inambiguous
(class_code, class_name, concept_id, concept_name, concept_class_id, "order")
SELECT DISTINCT class_code, class_name, concept_id, c.concept_name, c.concept_class_id, 3
FROM interim_2 i
JOIN concept c USING (concept_id)
where (class_code, c.concept_id) not in (select class_code, concept_id from class_to_drug)
; -- 1415

-- also adding those that don't have forms, but are unique
with ing AS (
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
JOIN drug ON concept_code_2=concept_code_1
JOIN class_drugs_scraper ON code = class_code
WHERE cnt=1 AND class_name = concept_code_1
and code NOT IN (SELECT class_code FROM class_to_drug)
   ),
all_drug AS (
SELECT class_code,class_name, concept_id,concept_name, concept_class_id, count(concept_id_2) OVER (PARTITION BY class_code) AS cnt
FROM drug_name
JOIN concept on concept_id_2 = concept_id
)
INSERT INTO class_to_drug
SELECT class_code, class_name, concept_id, concept_name,concept_class_id,3
FROM all_drug
WHERE  cnt=1
and (class_code, concept_id) not in (select class_code, concept_id from class_to_drug)
; -- 25

UPDATE class_to_drug
SET "order" = 5
WHERE "order" in (98,99); -- 649

UPDATE class_to_drug
SET "order" = 4
WHERE class_name ~ ' and '
AND NOT class_name ~ 'adrenergics|analgesics|antispasmodics|antibacterials|antiflatulents|imidazoles|minerals|polyfructosans|triazoles|natural phospholipids|lactic acid producing organisms|antiflatulents|beta-lactamase inhibitor|sulfonylureas|antibiotics|antiinfectives|antiseptics|artificial tears|contact laxatives|corticosteroids|ordinary salt combinations|imidazoles/triazoles|cough suppressants|diuretics|drugs for obstructive airway diseases|expectorants|belladonna alkaloids|mucolytics|mydriatics|non-opioid analgesics|organic nitrates|potassium-sparing agents|proton pump inhibitors|psycholeptics|thiazides|snake venom antiserum|fat emulsions|amino acids|acid preparations|sulfur compounds|stramoni preparations|protamines|penicillins|comt inhibitor|cannabinoids|decarboxylase inhibitor|edetates|barbiturates|excl|combinations of|derivate|with'
AND "order" in (98,99); -- 89

-- calcium compounds
UPDATE class_to_drug
SET "order" = 7
WHERE class_name ~ 'compounds'
AND "order"  = 2; -- 2 

-- working with duplicates to remove a and b vs a/b, comb
DELETE FROM class_to_drug
WHERE (class_code,concept_id) IN(
SELECT b.class_code, b.concept_id FROM class_to_drug a
JOIN class_to_drug b on a.concept_id = b.concept_id
WHERE a."order" = 4 AND b."order" in (6,7))
; -- 0

--  	'Progestogens and estrogens, sequential preparations' should be Clinical Packs only
-- check manual links for this!!! -- fix concept_class_ids 
DELETE
FROM class_to_drug
WHERE class_code ~ 'G03FB|G03AB'
AND   concept_class_id NOT IN ('Clinical Pack')
; -- 1371

update class_to_drug 
set "order" = 99
where  "order" is null; -- 440

-- add missing alive OLD links(to solve)
insert into class_to_drug
WITH t1 AS
(
  SELECT atc_code,
         concept_id,
         concept_code,
         concept_name
  FROM dev_atc.atc_all_relationships
  WHERE vocabulary_id ~ 'Rx' and relationship_id = 'ATC - RxNorm'
  and concept_class_id = 'Clinical Drug Form'
EXCEPT 
 SELECT atc_code,concept_id,concept_code,concept_name FROM dev_atc.atc_all_new_relationships_2 
WHERE vocabulary_id ~ 'Rx' and relationship_id = 'ATC - RxNorm'
  and concept_class_id = 'Clinical Drug Form'
)
SELECT distinct atc_code, d.concept_name as class_name, c.concept_id, c.concept_name, c.concept_class_id, 23 
FROM t1 a
  JOIN concept c
    ON c.concept_id = a.concept_id
      JOIN concept_manual d on d.concept_code = a.atc_code
   AND c.standard_concept = 'S'
   AND d.invalid_reason is null
   where (atc_code, c.concept_id) not in (select class_code, concept_id from class_to_drug); -- 878 (855)
