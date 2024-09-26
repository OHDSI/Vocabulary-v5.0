--! This is the first integration of ATC into the OMOP Vocabularies
--! The code is outdated, left here for the backward compatibility

/*

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
* Authors: Anna Ostropolets, Timur Vakhitov
* Date: Jan 2020
**************************************************************************/

/*
Prerequisites:
1. Get the latest file FROM source, name it class_drugs_scraper. The file should contain class code, class name, additional information.
For example, for ATC the file will be created in the following manner:
SELECT id, atc_code AS class_code, atc_name AS class_name, ddd, u, adm_r, note, description, ddd_description
FROM atc_drugs_scraper;
2. Prepare input tables (drug_concept_stage, internal_relationship_stage, relationship_to_concept)
according to the general rules for drug vocabularies
3. Prepare the following tables:
- reference (represents the original code and concatenated code AND its drug forms INRxNorm format)
- class_to_drug_manual (stores manual mappings, i.g. Insulins)
- ambiguous_class_ingredient (class, code, class_name, ingredients of ATC AS ing, flag [ing for the main ingredient,with for additional ingredients,excl for those that should be excluded]).
For groups of ingredients (e.g. antibiotics) list all the possible variations
*/

-- 1. Update latest_UPDATE field to new date
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'ATC',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.rxnatomarchive LIMIT 1),
	pVocabularyVersion		=> (SELECT vocabulary_version FROM sources.rxnatomarchive LIMIT 1),
	pVocabularyDevSchema	        => 'DEV_ATC'
);
END $_$;



-- 2. Truncate all working tables AND remove indices
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

-- 3. Preliminary work
-- 3.0 create table with manual work
DROP TABLE IF EXISTS  class_to_drug_manual_tbd;
CREATE TABLE class_to_drug_manual_tbd AS
  SELECT * FROM class_drugs_scraper
WHERE class_code ~ '^J07|^A10A'
AND length(class_code)=7;

-- 3.1 create table with combo drugs to be used later
-- 3.1.1 First change names for D07X to represent that they are combos
UPDATE class_drugs_scraper
SET class_name = class_name||', combinations'
  WHERE class_code ~ 'D07X' AND length(class_code)=7 AND class_name NOT LIKE 'combinations of%';--D07XB30

DROP TABLE IF EXISTS  class_1_comb;
CREATE TABLE class_1_comb AS
SELECT *
FROM class_drugs_scraper
WHERE class_name ~ 'comb| and |excl|derivate|other|with'
  AND length(class_code) = 7
 -- AND NOT class_name ~ 'decarboxylase inhibitor' XXX
  AND  class_code NOT IN (SELECT class_code FROM class_to_drug_manual_tbd) -- manual XXX
;

-- add to github script
DELETE
FROM class_1_comb
WHERE class_code in  ('S01XA20','G02BB01','G02BA02','G02BA03','G02BB02')
;--artificial tears and other indifferent preparations, actually not combo; G02% IUD and vaginal rings

-- create unified table with combinations, combos a+b
DROP TABLE IF EXISTS ambiguous_class_ingredient_tst;
CREATE TABLE ambiguous_class_ingredient_tst AS
  -- a+b
SELECT class_code,class_name, concept_code_2, CASE WHEN rnk = 1 THEN 'ing' ELSE 'with' END AS flag, rnk
FROM (
       SELECT class_code,
              concept_code_2,
              class_name,
              coalesce(rnk, CASE
                              WHEN rnk IS NULL
                                THEN rank() OVER (PARTITION BY concept_code_1, rnk ORDER BY concept_code_2) + 1 END) AS rnk
       FROM (
              SELECT DISTINCT class_code,
                              i.concept_code_2,
                              class_name,
                              CASE
                                WHEN concept_code_2 =
                                     regexp_replace(regexp_replace(class_name, ' and.*', ''), '\, .*', '') THEN 1
                                ELSE NULL END AS rnk,
                              concept_code_1
              FROM class_1_comb
                     LEFT JOIN reference USING (class_code)
                     JOIN internal_relationship_stage i ON coalesce(concept_code, class_code) = concept_code_1
                     JOIN drug_concept_stage d
                          ON lower(d.concept_code) = lower(concept_code_2) AND concept_class_id = 'Ingredient'
              WHERE class_name ~ ' and '
                AND NOT class_name ~ 'excl|combinations of|derivate|other|with') a
     ) a
UNION
-- complex combinations
SELECT class_code, class_name, ing, flag, rnk
FROM ambiguous_class_ingredient
;

-- one strange parsing
UPDATE ambiguous_class_ingredient_tst
SET flag = 'ing', rnk = 1
WHERE class_code='A11GB01' AND concept_code_2='ascorbic acid (vit c)';

UPDATE ambiguous_class_ingredient_tst
SET  rnk = 2
WHERE class_code='A11GB01' AND concept_code_2='calcium';


DELETE
FROM ambiguous_class_ingredient_tst
WHERE (class_code, concept_code_2, flag) IN (SELECT a.class_code,a.concept_code_2,a.flag
                                             FROM ambiguous_class_ingredient_tst a
                                                    JOIN ambiguous_class_ingredient_tst b
                                                         ON a.class_code = b.class_code AND a.concept_code_2 = b.concept_code_2
                                             WHERE a.flag = 'with' AND b.flag = 'ing');

-- insert pure combinations
DROP TABLE IF EXISTS pure_combos;
CREATE TABLE pure_combos
  as
  SELECT * FROM  (
  SELECT class_code,i.concept_code_2, class_name, 'ing' AS flag, 1 AS rnk
     FROM class_1_comb
            LEFT JOIN reference USING (class_code)
            JOIN internal_relationship_stage i ON coalesce(concept_code, class_code) = concept_code_1
            JOIN drug_concept_stage d ON lower(d.concept_code) = lower(concept_code_2)  AND concept_class_id = 'Ingredient'
     WHERE class_name IN ('combinations','various combinations')
UNION
    SELECT class_code, i.concept_code_2, class_name, 'with', 2
       FROM class_1_comb a
              JOIN concept c ON regexp_replace(c.concept_code, '..$', '') = regexp_replace(a.class_code, '..$', '') and
                                c.concept_class_id = 'ATC 5th' -- getting siblings for combinations
              JOIN internal_relationship_stage i ON c.concept_code = substring(i.concept_code_1,'\w+')
              JOIN drug_concept_stage d ON lower(d.concept_code) = lower(i.concept_code_2) AND d.concept_class_id = 'Ingredient'
     WHERE a.class_name IN ('combinations','various combinations')
) a
;

UPDATE pure_combos v
SET rnk = 1, flag = 'ing'
FROM (
SELECT class_code, min(concept_code_2) OVER (PARTITION BY class_code ORDER BY concept_code_2) AS min_code
FROM pure_combos
WHERE class_code NOT IN (SELECT class_code FROM pure_combos WHERE rnk=1)
  ) a
WHERE (v.class_code =a.class_code AND v.concept_code_2 = a.min_code)
;

DROP TABLE IF EXISTS combo_of;
CREATE TABLE combo_of
  as
    SELECT class_code, i.concept_code_2, class_name, 'with' AS flag, 2 as rnk
       FROM class_1_comb a
              JOIN concept c ON regexp_replace(c.concept_code, '..$', '') = regexp_replace(a.class_code, '..$', '') and
                                c.concept_class_id = 'ATC 5th' -- getting siblings for combinations
              JOIN internal_relationship_stage i ON c.concept_code = substring(i.concept_code_1,'\w+')
              JOIN drug_concept_stage d ON lower(d.concept_code) = lower(i.concept_code_2) AND d.concept_class_id = 'Ingredient'
 WHERE class_name ~ '(combinations of|in combination)'
      AND NOT class_name ~ ' and |derivate|other drugs|^other |with' AND class_name NOT IN ('combinations','various combinations')
UNION
    SELECT  class_code, i.concept_code_2, class_name, 'with' AS flag, 2 as rnk
       FROM class_1_comb a
              JOIN concept c ON regexp_replace(c.concept_code, '.$', '') = regexp_replace(a.class_code, '...$', '') AND concept_name like '%plain%'
              JOIN concept cc ON  c.concept_code = regexp_replace(cc.concept_code, '..$', '') AND cc.concept_class_id = 'ATC 5th'
              JOIN internal_relationship_stage i ON cc.concept_code = substring(i.concept_code_1,'\w+')
              JOIN drug_concept_stage d ON lower(d.concept_code) = lower(i.concept_code_2) AND d.concept_class_id = 'Ingredient'
 WHERE class_name ~ '(combinations of|in combination)'
   AND NOT class_name ~ ' and |derivate|other drugs|^other |with' AND class_name NOT IN ('combinations','various combinations')
;

-- insert into combo_of same ingredients to create permutations, assume that there won't be > 3 ingredients in combination
INSERT INTO combo_of
SELECT class_code, concept_code_2,class_name, 'ing', 1
  FROM combo_of
;

INSERT INTO ambiguous_class_ingredient_tst
SELECT DISTINCT class_code, class_name, concept_code_2, flag, rnk
FROM combo_of
UNION
SELECT DISTINCT class_code, class_name, concept_code_2, flag, rnk
FROM pure_combos
;


CREATE INDEX ambiguous_class_ingredient_test ON ambiguous_class_ingredient_tst (class_code, concept_code_2, flag);

-- 3.2 create a table with aggregated RxE ingredients
DROP TABLE IF EXISTS rx_combo;
CREATE TABLE rx_combo AS
SELECT drug_concept_id,
       string_agg(ingredient_concept_id::VARCHAR, '-' ORDER BY ingredient_concept_id) AS i_combo
FROM devv5.drug_strength
       JOIN concept ON concept_id = drug_concept_id AND
                       concept_class_id IN ('Clinical Drug Form', 'Ingredient') -- 'Clinical Drug Comp' doesn't exist
GROUP BY drug_concept_id
;

DROP TABLE IF EXISTS full_combo;
CREATE TABLE full_combo
AS
WITH hold AS (
SELECT a.*, concept_id_2, precedence
FROM ambiguous_class_ingredient_tst a
JOIN relationship_to_concept rtc ON rtc.concept_code_1 = concept_code_2
WHERE flag = 'ing'),
     ing AS (
SELECT a.*, concept_id_2, precedence
FROM ambiguous_class_ingredient_tst a
JOIN relationship_to_concept rtc ON rtc.concept_code_1 = concept_code_2
WHERE flag = 'with' AND rnk = 2
     ),
     ing2 AS (
SELECT a.*, concept_id_2, precedence
FROM ambiguous_class_ingredient_tst a
JOIN relationship_to_concept rtc ON rtc.concept_code_1 = concept_code_2
WHERE flag = 'with' AND rnk = 3
     ),
     ing3 AS (
SELECT a.*, concept_id_2, precedence
FROM ambiguous_class_ingredient_tst a
JOIN relationship_to_concept rtc ON rtc.concept_code_1 = concept_code_2
WHERE flag = 'with' AND rnk = 4
     )
SELECT hold.class_code, hold.class_name, hold.concept_id_2||COALESCE('-' || ing.concept_id_2, '')||COALESCE('-' || ing2.concept_id_2, '')||COALESCE('-' || ing3.concept_id_2, '') AS i_combo
       FROM hold
JOIN ing USING (class_code)
LEFT JOIN ing2 USING (class_code)
LEFT JOIN ing3 USING (class_code)
ORDER BY class_code
;

-- adding another layer of permuted concepts. E.g. combination of corticosteroids now can have 3 ingredients
DROP TABLE IF EXISTS permutations;
CREATE TABLE permutations
AS
WITH hold AS
       (SELECT a.*, concept_id_2, precedence
FROM ambiguous_class_ingredient_tst a
JOIN relationship_to_concept rtc ON rtc.concept_code_1 = concept_code_2
WHERE flag = 'ing'),
     ing AS (SELECT a.*, concept_id_2, precedence
FROM ambiguous_class_ingredient_tst a
JOIN relationship_to_concept rtc ON rtc.concept_code_1 = concept_code_2
WHERE flag = 'with' AND rnk = 2
       AND NOT EXISTS  (SELECT 1 FROM ambiguous_class_ingredient_tst b WHERE b.class_code = a.class_code AND rnk=3))
SELECT hold.class_code, hold.class_name, hold.concept_id_2||COALESCE('-' || i.concept_id_2, '')||COALESCE('-' || i2.concept_id_2, '') AS i_combo
        FROM hold
JOIN ing i ON i.class_code = hold.class_code
JOIN ing i2 ON i2.class_code = hold.class_code
WHERE i.concept_id_2!=i2.concept_id_2 AND i.concept_id_2!=hold.concept_id_2
;

INSERT INTO full_combo
SELECT DISTINCT *
FROM permutations;

CREATE INDEX i_full_combo ON full_combo (class_code, i_combo);

DROP TABLE IF EXISTS full_combo_reodered;
CREATE TABLE full_combo_reodered
  AS
WITH a AS (SELECT class_code,class_name, i_combo, rank() OVER (PARTITION BY class_code ORDER BY i_combo) AS rnk
           FROM (SELECT DISTINCT * FROM full_combo) a),
     b AS (SELECT class_code,class_name, rnk, cast(unnest(string_to_array(i_combo, '-')) AS int) AS ing
           FROM a)
SELECT class_code, class_name, string_agg(ing::varchar, '-' ORDER BY ing) AS i_combo
FROM b
GROUP BY class_code, class_name, rnk; -- to array

CREATE INDEX i_full_combo_reodered ON full_combo_reodered (class_code, i_combo);

DROP TABLE IF EXISTS full_combo_with_form;
CREATE TABLE full_combo_with_form
AS
SELECT class_code, class_name, i_combo, concept_id_2
FROM full_combo_reodered
JOIN internal_relationship_stage irs on class_code = substring (irs.concept_code_1,'\w+')
JOIN drug_concept_stage dc on dc.concept_code = irs.concept_code_2 AND dc.concept_class_id = 'Dose Form'
JOIN relationship_to_concept rtc on rtc.concept_code_1 = irs.concept_code_2

UNION ALL

SELECT f.class_code, class_name, i_combo, null -- take from reference those that do not have forms
FROM full_combo_reodered f
JOIN reference r on r.class_code = f.class_code
WHERE r.concept_code = r.class_code
;

CREATE INDEX i_full_combo_with_form ON full_combo_with_form (class_code, i_combo,concept_id_2);

-- Assembling final table
-- Order:
1. Manual
2. Mono: Ingredient A; form
3. Mono: Ingredient A
4. Combo: Ingredient A + Ingredient B
5. Combo: Ingredient A + group B
6. Combo: Ingredient A, combination; form
7. Combo: Ingredient A, combination
8. Any packs

Group A + Group B
other things like Calcium compounds

DROP TABLE IF EXISTS class_to_drug; --747
CREATE TABLE class_to_drug
as
  with rxnorm AS (
    SELECT a.concept_id, a.concept_name,a.concept_class_id,a.vocabulary_id, c.concept_id_2,r.i_combo
    FROM rx_combo r
           JOIN concept a ON r.drug_concept_id = a.concept_id
           JOIN concept_relationship c ON c.concept_id_1 = a.concept_id
    WHERE a.concept_class_id = 'Clinical Drug Form'
      AND a.vocabulary_id LIKE 'RxNorm%'
      AND a.invalid_reason IS NULL
      AND relationship_id = 'RxNorm has dose form'
      AND c.invalid_reason IS NULL
    )
  SELECT DISTINCT class_code, class_name, concept_id, concept_name, concept_class_id, 98 as order
  FROM full_combo_with_form f
  JOIN rxnorm r on r.i_combo = f.i_combo AND r.concept_id_2 = f.concept_id_2
;

-- adding everything we can for combinations
DROP TABLE IF EXISTS combo_not_limited_to_higherATC;
CREATE TABLE combo_not_limited_to_higherATC
AS
  WITH combo AS ( --250
    SELECT c.class_code, c.class_name, concept_id_2
    FROM class_1_comb c
           JOIN internal_relationship_stage i ON c.class_code = substring(i.concept_code_1, '\w+')
           JOIN relationship_to_concept rtc ON rtc.concept_code_1 = i.concept_code_2
    WHERE c.class_name ~ '(, combinations)|(in combination with other drugs)'
      AND NOT c.class_name ~ 'with|and thiazides|and other diuretics' -- gives errors  in C07BB52 AND C07CB53 if removed
    )
    SELECT DISTINCT class_code, class_name, drug_concept_id
    FROM rx_combo
           JOIN combo on i_combo ~ cast(concept_id_2 AS VARCHAR) AND i_combo LIKE '%-%' -- at least two ingredients
    WHERE not exists(SELECT 1
                     FROM ambiguous_class_ingredient_tst a2
                            JOIN relationship_to_concept rtc2 ON rtc2.concept_code_1 = a2.concept_code_2
                     WHERE a2.class_code = combo.class_code
                       AND a2.flag = 'excl'
                       AND i_combo ~ cast(rtc2.concept_id_2 AS VARCHAR))
;

-- inserting those few ATCs that are like A + group B, combinations
INSERT INTO combo_not_limited_to_higherATC
SELECT DISTINCT a.class_code, a.class_name, drug_concept_id
FROM ambiguous_class_ingredient_tst a
       JOIN ambiguous_class_ingredient_tst b ON a.class_code = b.class_code AND a.flag = 'ing' AND b.flag = 'with'
       JOIN relationship_to_concept rtc ON rtc.concept_code_1 = a.concept_code_2
       JOIN relationship_to_concept rtc2 ON rtc2.concept_code_1 = b.concept_code_2
       JOIN rx_combo on i_combo ~ cast(rtc.concept_id_2 AS VARCHAR) AND i_combo ~ cast(rtc2.concept_id_2 AS VARCHAR) AND
                        i_combo ~ '.*-.*-'
where a.class_name ~ '( and .*, combinations$)|(combinations with other drugs)'
;

 WITH rxnorm AS (
    SELECT a.concept_id, a.concept_name,a.concept_class_id,a.vocabulary_id, c.concept_id_2,r.class_code, r.class_name
    FROM combo_not_limited_to_higherATC r
           JOIN concept a ON r.drug_concept_id = a.concept_id
           JOIN concept_relationship c ON c.concept_id_1 = a.concept_id
    WHERE a.concept_class_id = 'Clinical Drug Form'
      AND a.vocabulary_id LIKE 'RxNorm%'
      AND a.invalid_reason IS NULL
      AND relationship_id = 'RxNorm has dose form'
      AND c.invalid_reason IS NULL
    )
INSERT INTO class_to_drug
SELECT  DISTINCT class_code, class_name, concept_id, concept_name, concept_class_id, 6
FROM rxnorm
JOIN internal_relationship_stage i ON substring(i.concept_code_1, '\w+')  = class_code
JOIN relationship_to_concept rtc ON i.concept_code_2 = rtc.concept_code_1
WHERE rxnorm.concept_id_2 = rtc.concept_id_2
;

INSERT INTO class_to_drug
SELECT DISTINCT class_code, class_name, concept_id, concept_name, concept_class_id, 7
FROM combo_not_limited_to_higherATC
JOIN concept ON concept_id = drug_concept_id
JOIN reference r USING (class_code)
WHERE r.concept_code=r.class_code
;

--insert all forms for those ATC that do not specify forms --821
WITH rxnorm AS (
  SELECT a.concept_id, a.concept_name,a.concept_class_id,a.vocabulary_id, c.concept_id_2,r.i_combo
  FROM rx_combo r
         JOIN concept a ON r.drug_concept_id = a.concept_id
         JOIN concept_relationship c ON c.concept_id_1 = a.concept_id
  WHERE a.concept_class_id = 'Clinical Drug Form'
    AND a.vocabulary_id LIKE 'RxNorm%'
    AND a.invalid_reason IS NULL
    AND relationship_id = 'RxNorm has dose form'
    AND c.invalid_reason IS NULL
)
INSERT
INTO class_to_drug
SELECT DISTINCT class_code, class_name, concept_id, concept_name, concept_class_id,99
FROM full_combo_with_form f
       JOIN rxnorm r ON r.i_combo = f.i_combo
WHERE f.concept_id_2 IS NULL
;

--Combinations of propranolol AND hydralazine or dihydralazine are classified INC07FX01. [combinations with other drugs] XXX
-- 3.6.4 start removing incorrectly assigned combo based ON WHO rank
-- XXX https://www.whocc.no/atc_ddd_index/?code=N02BA51&showdescription=yes
-- zero rank (no official rank is present)
SELECT * --XXX
FROM class_to_drug
WHERE class_code ~ 'M03BA73|M03BA72|N02AC74|M03BB72|N02BB52|M03BB73|M09AA72|N02AB72|N02BB72|N02BA77'
  AND concept_name ~*
      'Salicylamide|Phenazone|Aspirin|Acetaminophen|Dipyrocetyl|Bucetin|Phenacetin|Methadone|etamizole|Ergotamine'--acetylsalicylic
;
--starts the official rank
DELETE --90
FROM class_to_drug
WHERE class_code ~ 'N02BB74|N02BB54'
  AND concept_name ~* 'Phenazone|Salicylamide|Aspirin|Acetaminophen|Dipyrocetyl|Bucetin|Phenacetin'
;
DELETE --52
FROM class_to_drug
WHERE class_code ~ 'N02BA75|N02BA55'
  AND concept_name ~* 'Phenazone|Aspirin|Acetaminophen|Dipyrocetyl|Bucetin|Phenacetin'
;
DELETE --6
FROM class_to_drug
WHERE class_code ~ 'N02BB71|N02BB51'
  AND concept_name ~* 'Aspirin|Acetaminophen|Dipyrocetyl|Bucetin|Phenacetin'
;
DELETE --50
FROM class_to_drug
WHERE class_code ~ 'N02BA71|N02BA51'
  AND concept_name ~* 'Acetaminophen|Dipyrocetyl|Bucetin|Phenacetin'
;
DELETE -- 1
FROM class_to_drug
WHERE class_code ~ 'N02BE71|N02BE51'
  AND concept_name ~* 'Dipyrocetyl|Bucetin|Phenacetin'
;
DELETE --108
FROM class_to_drug
WHERE class_code ~ '^N02'
  AND concept_name ~ 'Codeine'
  AND NOT class_name ~ 'codeine';

-- PPI and aspirin -- XXX changes this logic
DELETE
FROM class_to_drug
WHERE class_code ~ 'N02BA51'
  AND concept_name ~* 'meprazole|Pantoprazole|Rabeprazol';

-- contraceptive packs
INSERT INTO class_to_drug
SELECT class_code, class_name, c.concept_id,c.concept_name,"order"
FROM class_to_drug ctd
JOIN devv5.concept_ancestor ON ctd.concept_id = ancestor_concept_id
JOIN concept c ON descendant_concept_id = c.concept_id
WHERE class_code ~ 'G03FB|G03AB'
  AND c.concept_class_id IN ('Clinical Pack');

DELETE FROM class_to_drug
WHERE class_code ~ 'G03FB|G03AB'
  AND concept_class_id NOT IN ('Clinical Pack');

-- insert mono-ATC codes
DROP TABLE IF EXISTS mono_ing;
CREATE TABLE mono_ing as
SELECT DISTINCT class_code, class_name, concept_id_2 AS ing_id
       FROM class_drugs_scraper
JOIN internal_relationship_stage i on class_code = substring(concept_code_1,'\w+')
JOIN drug_concept_stage d on lower(d.concept_code) = lower(i.concept_code_2) AND concept_class_id = 'Ingredient'
JOIN relationship_to_concept rtc on rtc.concept_code_1 = i.concept_code_2
  WHERE  length(class_code)=7
;

DELETE FROM mono_ing
WHERE class_code  IN (SELECT class_code FROM class_1_comb)
OR class_code  IN (SELECT class_code FROM class_to_drug_manual_tbd)
OR (class_name LIKE '% and %' AND class_code!='S01XA20')
;

INSERT INTO class_to_drug --587434
with form AS (
  SELECT class_code, class_name, ing_id, concept_id_2 AS form_id
  FROM mono_ing
         JOIN internal_relationship_stage i on class_code = substring(i.concept_code_1, '\w+')
         JOIN drug_concept_stage d on d.concept_code = i.concept_code_2 AND d.concept_class_id = 'Dose Form'
         JOIN relationship_to_concept rtc on rtc.concept_code_1 = i.concept_code_2
)
SELECT DISTINCT class_code, class_name, concept_id, concept_name, concept_class_id,2
FROM form
JOIN rx_combo r on i_combo = cast(ing_id AS varchar)  --XXX ingr??
JOIN concept a ON r.drug_concept_id = a.concept_id
JOIN concept_relationship c ON c.concept_id_1 = a.concept_id AND form_id = c.concept_id_2
    WHERE a.concept_class_id = 'Clinical Drug Form'
      AND a.vocabulary_id LIKE 'RxNorm%'
      AND a.invalid_reason IS NULL
      AND relationship_id = 'RxNorm has dose form'
      AND c.invalid_reason IS NULL
;

INSERT INTO class_to_drug --785
SELECT DISTINCT class_code, class_name, c.concept_id, c.concept_name, c.concept_class_id, 3
FROM mono_ing m
JOIN internal_relationship_stage i on class_code = substring(concept_code_1,'\w+')
JOIN concept c on m.ing_id = c.concept_id
    WHERE i.concept_code_1 NOT LIKE '% %'
;

INSERT INTO class_to_drug
SELECT class_code, class_name, concept_id, concept_name, concept_class_id, 1
FROM class_to_drug_manual;

-- 3.8.1 manually excluded drugs based on Precise Ingredients
DELETE
FROM class_to_drug
WHERE class_code IN ('B02BD14','B02BD11')
and concept_class_id = 'Ingredient';

INSERT INTO class_to_drug
SELECT 'B02BD11','catridecacog', concept_id, concept_name, concept_class_id,1
FROM concept
WHERE (vocabulary_id LIKE 'RxNorm%' AND concept_name LIKE 'coagulation factor XIII a-subunit (recombinant)%'
      AND standard_concept = 'S' AND concept_class_id = 'Clinical Drug')
   OR concept_id = 35603348 -- the whole hierarchy
;

INSERT INTO class_to_drug
SELECT 'B02BD14','susoctocog alfa', concept_id, concept_name, concept_class_id,1
FROM concept
WHERE (vocabulary_id LIKE 'RxNorm%'
      AND concept_name LIKE 'antihemophilic factor, porcine B-domain truncated recombinant%' AND standard_concept = 'S' AND concept_class_id = 'Clinical Drug')
   OR concept_id IN (35603348, 44109089) -- the whole hierarchy
;

DELETE
FROM class_to_drug
WHERE class_code = 'A02BA07'
  AND concept_class_id = 'Clinical Drug Form'; --Tritec
INSERT INTO class_to_drug
SELECT 'A02BA07','ranitidine bismuth citrate', concept_id, concept_name, concept_class_id,1
FROM concept
WHERE vocabulary_id LIKE 'RxNorm%' AND concept_name LIKE '%Tritec%'
      AND standard_concept = 'S' AND concept_class_id = 'Branded Drug Form'
;

DELETE
FROM class_to_drug -- choriogonadotropin alfa
WHERE class_code = 'G03GA08';
INSERT INTO class_to_drug
SELECT 'G03GA08','choriogonadotropin alfa', concept_id, concept_name, concept_class_id,1
FROM concept
WHERE vocabulary_id LIKE 'RxNorm%' AND concept_name LIKE '%choriogonadotropin alfa%'
      AND standard_concept = 'S' AND concept_class_id = 'Clinical Drug Form'
;

DELETE
FROM class_to_drug
WHERE class_code='N05AF02'; -- clopentixol
INSERT INTO class_to_drug
SELECT 'N05AF02','clopenthixol', concept_id, concept_name, concept_class_id,1
FROM concept
WHERE vocabulary_id LIKE 'RxNorm%' AND concept_name ~* 'Sordinol|Ciatyl'
      AND standard_concept = 'S' AND concept_class_id = 'Branded Drug Form'
;

DELETE
FROM class_to_drug
WHERE class_code IN('D07AB02','D07BB04'); -- 	hydrocortisone butyrate + combo that so far doesn't exist
INSERT INTO class_to_drug
SELECT 'D07AB02','hydrocortisone butyrate', concept_id, concept_name, concept_class_id,1
FROM concept
WHERE vocabulary_id LIKE 'RxNorm%' AND concept_name ~* 'Hydrocortisone butyrate' AND concept_class_id = 'Clinical Drug'
      AND standard_concept = 'S'
;

DELETE
FROM class_to_drug
WHERE class_code = 'C01DA05';

INSERT INTO class_to_drug
SELECT 'C01DA05','pentaerithrityl tetranitrate', concept_id, concept_name, concept_class_id,1
FROM concept
WHERE vocabulary_id LIKE 'RxNorm%' AND concept_name LIKE '%Pentaerythritol Tetranitrate%' and
      standard_concept = 'S' AND concept_class_id = 'Clinical Drug Comp' -- forms do not exist
;

DELETE
FROM class_to_drug
WHERE class_code = 'B02BD14'
  AND concept_name LIKE '%Tretten%'
; --catridecacog

DELETE
FROM class_to_drug -- XXX
WHERE class_name = 'amino acids';

DELETE
FROM class_to_drug
WHERE class_name LIKE '%,%and%'
  AND class_name NOT LIKE '%,%,%and%'
  AND NOT class_name ~* 'comb|other|whole root|selective'
  AND concept_name NOT LIKE '% / % / %';

--combinations FROM ATC 4th, need to be fixed afterwards
DELETE
FROM class_to_drug
WHERE class_name NOT LIKE '% / %'
AND class_code ~ 'S01CB|G03EK|G03CC|D10AA'  -- D10AA smth for acne, unclear; S01CB with whatever you want, G% is strange hormones
;

DROP TABLE IF EXISTS pack_all;
CREATE TABLE pack_all
AS
  WITH a AS (
    SELECT concept_id_1,
           drug_concept_id,
           string_agg(ingredient_concept_id::VARCHAR, '-' ORDER BY ingredient_concept_id) AS i_combo,
           count(drug_concept_id) over (partition by concept_id_1) as cnt
    FROM drug_strength
           JOIN concept_relationship r
                on drug_concept_id = concept_id_2 AND relationship_id = 'Contains' AND r.invalid_reason IS NULL
           JOIN concept c on c.concept_id = concept_id_1 AND concept_class_id = 'Clinical Pack'
    GROUP BY drug_concept_id,concept_id_1),
    b as
      (SELECT class_code, class_name, r.concept_code_1, r.concept_id_2
       FROM class_1_comb
              JOIN internal_relationship_stage i on substring(i.concept_code_1, '\w+') = class_code
              JOIN drug_concept_stage d on d.concept_code = concept_code_2 AND concept_class_id = 'Ingredient'
              JOIN relationship_to_concept r on r.concept_code_1 = i.concept_code_2
       WHERE class_name LIKE '% and %'),
    c AS (SELECT class_code, r.concept_code_1, r.concept_id_2
          FROM class_1_comb
                 JOIN internal_relationship_stage i on substring(i.concept_code_1, '\w+') = class_code
                 JOIN drug_concept_stage d on d.concept_code = concept_code_2 AND concept_class_id = 'Ingredient'
                 JOIN relationship_to_concept r on r.concept_code_1 = i.concept_code_2
          WHERE class_name LIKE '% and %')
    SELECT DISTINCT cc.concept_id, cc.concept_name, cc.concept_class_id, b.class_code, b.class_name
    FROM a
           JOIN a aa on aa.concept_id_1 = a.concept_id_1
           JOIN concept cc on concept_id = a.concept_id_1
           JOIN b on cast(b.concept_id_2 AS varchar) = aa.i_combo
           JOIN c on cast(c.concept_id_2 AS varchar) = a.i_combo
    WHERE a.drug_concept_id != aa.drug_concept_id
      AND b.class_code = c.class_code
      AND b.concept_code_1 != c.concept_code_1
      AND a.cnt = 2
;

-- insert 3-component drugs
INSERT INTO pack_all
 WITH a AS (
    SELECT concept_id_1,
           drug_concept_id,
           string_agg(ingredient_concept_id::VARCHAR, '-' ORDER BY ingredient_concept_id) AS i_combo,
           count(drug_concept_id) over (partition by concept_id_1) as cnt
    FROM drug_strength
           JOIN concept_relationship r
                on drug_concept_id = concept_id_2 AND relationship_id = 'Contains' AND r.invalid_reason IS NULL
           JOIN concept c on c.concept_id = concept_id_1 AND concept_class_id = 'Clinical Pack'
    GROUP BY drug_concept_id,concept_id_1),
    b as
      (SELECT class_code, class_name, r.concept_code_1, r.concept_id_2
       FROM class_1_comb
              JOIN internal_relationship_stage i on substring(i.concept_code_1, '\w+') = class_code
              JOIN drug_concept_stage d on d.concept_code = concept_code_2 AND concept_class_id = 'Ingredient'
              JOIN relationship_to_concept r on r.concept_code_1 = i.concept_code_2
       WHERE class_name LIKE '% and %'),
    c AS (SELECT class_code, r.concept_code_1, r.concept_id_2
          FROM class_1_comb
                 JOIN internal_relationship_stage i on substring(i.concept_code_1, '\w+') = class_code
                 JOIN drug_concept_stage d on d.concept_code = concept_code_2 AND concept_class_id = 'Ingredient'
                 JOIN relationship_to_concept r on r.concept_code_1 = i.concept_code_2
          WHERE class_name LIKE '% and %'),
     d AS (SELECT class_code, r.concept_code_1, r.concept_id_2
          FROM class_1_comb
                 JOIN internal_relationship_stage i on substring(i.concept_code_1, '\w+') = class_code
                 JOIN drug_concept_stage d on d.concept_code = concept_code_2 AND concept_class_id = 'Ingredient'
                 JOIN relationship_to_concept r on r.concept_code_1 = i.concept_code_2
          WHERE class_name LIKE '% and %')
    SELECT DISTINCT cc.concept_id, cc.concept_name, cc.concept_class_id, b.class_code, b.class_name
    FROM a
           JOIN a aa on aa.concept_id_1 = a.concept_id_1
           JOIN a aaa on aaa.concept_id_1 = a.concept_id_1
           JOIN concept cc on concept_id = a.concept_id_1
           JOIN b on cast(b.concept_id_2 AS varchar) = aa.i_combo
           JOIN c on cast(c.concept_id_2 AS varchar) = a.i_combo
           JOIN d on cast(d.concept_id_2 AS varchar) = aaa.i_combo
    WHERE a.drug_concept_id != aa.drug_concept_id
      AND b.class_code = c.class_code
      AND d.class_code = c.class_code
      AND b.concept_code_1 != c.concept_code_1
      AND d.concept_code_1 != c.concept_code_1 AND d.concept_code_1 != b.concept_code_1
      AND a.cnt = 3
;
-- XXX 4-component drugs
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
FROM class_1_comb
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
;

INSERT INTO class_to_drug
(class_code, class_name, concept_id, concept_name, concept_class_id, "order")
SELECT DISTINCT class_code, class_name, concept_id, concept_name, concept_class_id, 8
FROM pack_all;

-- 4.11 fix packs
INSERT INTO class_to_drug
SELECT DISTINCT class_code, class_name,c.concept_id, c.concept_name,c.concept_class_id, 8
FROM class_to_drug f
       JOIN devv5.concept_ancestor ca ON ca.ancestor_concept_id = cast(f.concept_id AS INT)
       JOIN devv5.concept c ON c.concept_id = descendant_concept_id AND c.concept_class_id LIKE '%Pack%'
WHERE f.class_code ~ 'G03FB|G03AB'; -- packs

-- 4.12
DELETE
FROM class_to_drug
WHERE class_code ~ 'G03FB|G03AB'
  AND concept_class_id IN ('Clinical Drug Form', 'Ingredient');

-- XXX Maybe introduce later
/*
SELECT *
FROM class_to_drug
WHERE class_name LIKE '%and estrogen%' -- if there are regular estiol/estradiol/EE
  AND concept_id IN (SELECT concept_id
  FROM class_to_drug GROUP BY concept_id HAVING COUNT(1) > 1);
  */

-- 4.14 Solution for the first run: for inambiguous ATC classes (those that classify an ingredient through only one class)
-- we relate this ATC class to the entire group of drugs that have this ingredient.
DROP TABLE IF EXISTS  interim;
CREATE TABLE interim
AS
WITH a AS (SELECT DISTINCT class_code, class_name, c.concept_id,c.concept_name
FROM class_to_drug crd
JOIN devv5.concept_ancestor on crd.concept_id = descendant_concept_id
JOIN concept c on c.concept_id = ancestor_concept_id AND c.concept_class_id = 'Ingredient')
SELECT *
FROM  (SELECT count (*) OVER (PARTITION BY trim(regexp_replace(class_name, '\(.*\)','')) ) AS cnt, class_code, class_name, a.concept_id,a.concept_name -- regexp for (vit C)
FROM a ) a
WHERE cnt=1
AND class_code NOT IN (SELECT class_code FROM class_to_drug_manual)
--and class_code NOT IN ('G02BB02')
;

DELETE
FROM interim
WHERE class_name IN (
  SELECT class_name
  FROM (SELECT DISTINCT class_code, class_name FROM class_drugs_scraper) a
  GROUP BY class_name
  HAVING count(1) > 1);

DELETE
FROM interim
WHERE concept_id IN (
  SELECT a.concept_id
  FROM interim a
         JOIN interim b ON a.concept_id = b.concept_id
  WHERE a.class_code != b.class_code);


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
  HAVING count(1) > 1);

DELETE FROM class_to_drug -- inambiguous only for forms
WHERE class_code IN (SELECT class_code FROM interim)
;

INSERT INTO class_to_drug -- ingredients are partially inambiguous
(class_code, class_name, concept_id, concept_name, concept_class_id, "order")
SELECT class_code, class_name, c.concept_id, c.concept_name, c.concept_class_id, 2
FROM interim i
JOIN devv5.concept_ancestor ca on i.concept_id = ancestor_concept_id
JOIN concept c on descendant_concept_id = c.concept_id
WHERE  c.concept_class_id = 'Clinical Drug Form' AND c.concept_name NOT LIKE '% / %'
;

DELETE FROM class_to_drug
WHERE class_code IN(SELECT class_code FROM interim_2)
;
INSERT INTO class_to_drug -- ingredients are absolutely inambiguous
(class_code, class_name, concept_id, concept_name, concept_class_id, "order")
SELECT class_code, class_name, concept_id, c.concept_name, c.concept_class_id, 3
FROM interim_2 i
JOIN concept c USING (concept_id)
;

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
;

UPDATE class_to_drug
SET "order" = 4
WHERE class_name ~ ' and '
AND NOT class_name ~ 'adrenergics|analgesics|antispasmodics|antibacterials|antiflatulents|imidazoles|minerals|polyfructosans|triazoles|natural phospholipids|lactic acid producing organisms|antiflatulents|beta-lactamase inhibitor|sulfonylureas|antibiotics|antiinfectives|antiseptics|artificial tears|contact laxatives|corticosteroids|ordinary salt combinations|imidazoles/triazoles|cough suppressants|diuretics|drugs for obstructive airway diseases|expectorants|belladonna alkaloids|mucolytics|mydriatics|non-opioid analgesics|organic nitrates|potassium-sparing agents|proton pump inhibitors|psycholeptics|thiazides|snake venom antiserum|fat emulsions|amino acids|acid preparations|sulfur compounds|stramoni preparations|protamines|penicillins|comt inhibitor|cannabinoids|decarboxylase inhibitor|edetates|barbiturates|excl|combinations of|derivate|with'
AND "order" in (98,99);

UPDATE class_to_drug
SET "order" = 5
WHERE "order" in (98,99);

-- calcium compounds
UPDATE class_to_drug
SET "order" = 7
WHERE class_name ~ 'compounds'
AND "order"  = 2;


-- working with duplicates to remove a and b vs a/b, comb
DELETE FROM class_to_drug
WHERE (class_code,concept_id) IN(
SELECT b.class_code, b.concept_id FROM class_to_drug a
JOIN class_to_drug b on a.concept_id = b.concept_id
WHERE a."order" = 4 AND b."order" in (6,7))
;

--5. Get tables for see what is missing
--5.1 Check new class codes that should be worked out
SELECT *
FROM class_drugs_scraper
WHERE class_code NOT IN
      (SELECT concept_code FROM concept WHERE vocabulary_id = 'ATC');

--5.2 Take a look at new standard ingredients that did not exist before the last ATC release
SELECT *
FROM concept
WHERE vocabulary_id IN('RxNorm', 'RxNorm Extension')
  AND concept_class_id = 'Ingredient'
  AND standard_concept = 'S'
  AND valid_start_date > (SELECT latest_update
                          FROM devv5.vocabulary_conversion
                          WHERE vocabulary_id_v5 = 'ATC');

--5.3 Take a look at the ATC codes that aren't covered in the release
SELECT *
FROM class_drugs_scraper
WHERE class_code NOT IN (SELECT class_code FROM class_to_drug)
and length (class_code) =7
;

-- 6. Add ATC
-- create temporary table atc_tmp_table
DROP TABLE IF EXISTS  atc_tmp_table;
CREATE UNLOGGED TABLE atc_tmp_table AS
SELECT rxcui,
	code,
	concept_name,
	'ATC' AS vocabulary_id,
	'C' AS standard_concept,
	concept_code,
	concept_class_id
FROM (
	SELECT DISTINCT rxcui,
		code,
		SUBSTR(str, 1, 255) AS concept_name,
		code AS concept_code,
		CASE
			WHEN LENGTH(code) = 1
				THEN 'ATC 1st'
			WHEN LENGTH(code) = 3
				THEN 'ATC 2nd'
			WHEN LENGTH(code) = 4
				THEN 'ATC 3rd'
			WHEN LENGTH(code) = 5
				THEN 'ATC 4th'
			WHEN LENGTH(code) = 7
				THEN 'ATC 5th'
			END AS concept_class_id
	FROM sources.rxnconso
	WHERE sab = 'ATC'
		AND tty IN (
			'PT',
			'IN'
			)
		AND code != 'NOCODE'
	) AS s1;


INSERT INTO atc_tmp_table
SELECT NULL,
       class_code,
       class_name,
       'ATC',
       'C',
       class_code,
       CASE
         WHEN LENGTH(class_code) = 1
           THEN 'ATC 1st'
         WHEN LENGTH(class_code) = 3
           THEN 'ATC 2nd'
         WHEN LENGTH(class_code) = 4
           THEN 'ATC 3rd'
         WHEN LENGTH(class_code) = 5
           THEN 'ATC 4th'
         WHEN LENGTH(class_code) = 7
           THEN 'ATC 5th'
         END AS concept_class_id
FROM class_drugs_scraper
WHERE class_code NOT IN (SELECT code FROM atc_tmp_table);

CREATE INDEX idx_atc_code ON atc_tmp_table (code);
CREATE INDEX idx_atc_ccode ON atc_tmp_table (concept_code);
ANALYZE atc_tmp_table;


-- 7. Add atc_tmp_table to concept_stage
INSERT INTO concept_stage (
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
SELECT concept_name,
	'Drug' AS domain_id,
	dv.vocabulary_id,
	concept_class_id,
	standard_concept,
	concept_code,
	v.latest_UPDATE AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM atc_tmp_table dv,
	vocabulary v
WHERE v.vocabulary_id = dv.vocabulary_id;

-- 8. Create all sorts of relationships to self, RxNorm AND SNOMED
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	relationship_id,
	vocabulary_id_1,
	vocabulary_id_2,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT DISTINCT d.concept_code AS concept_code_1,
	e.concept_code AS concept_code_2,
	'VA Class to ATC eq' AS relationship_id,
	'VA Class' AS vocabulary_id_1,
	'ATC' AS vocabulary_id_2,
	v.latest_UPDATE AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM atc_tmp_table d
JOIN sources.rxnconso r ON r.rxcui = d.rxcui
	AND r.code != 'NOCODE'
JOIN atc_tmp_table e ON r.rxcui = e.rxcui
	AND r.code = e.concept_code
JOIN vocabulary v ON v.vocabulary_id = d.vocabulary_id
WHERE d.concept_class_id LIKE 'VA Class'
	AND e.concept_class_id LIKE 'ATC%'

UNION ALL

-- Cross-link between drug class Chemical Structure AND ATC
SELECT DISTINCT d.concept_code AS concept_code_1,
	e.concept_code AS concept_code_2,
	'NDFRT to ATC eq' AS relationship_id,
	'NDFRT' AS vocabulary_id_1,
	'ATC' AS vocabulary_id_2,
	v.latest_UPDATE AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM atc_tmp_table d
JOIN sources.rxnconso r ON r.rxcui = d.rxcui
	AND r.code != 'NOCODE'
JOIN atc_tmp_table e ON r.rxcui = e.rxcui
	AND r.code = e.concept_code
JOIN vocabulary v ON v.vocabulary_id = d.vocabulary_id
WHERE d.concept_class_id = 'Chemical Structure'
	AND e.concept_class_id IN (
		'ATC 1st',
		'ATC 2nd',
		'ATC 3rd',
		'ATC 4th'
		)

UNION ALL

-- Cross-link between drug class ATC AND Therapeutic Class
SELECT DISTINCT d.concept_code AS concept_code_1,
	e.concept_code AS concept_code_2,
	'NDFRT to ATC eq' AS relationship_id,
	'NDFRT' AS vocabulary_id_1,
	'ATC' AS vocabulary_id_2,
	v.latest_UPDATE AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM atc_tmp_table d
JOIN sources.rxnconso r ON r.rxcui = d.rxcui
	AND r.code != 'NOCODE'
JOIN atc_tmp_table e ON r.rxcui = e.rxcui
	AND r.code = e.concept_code
JOIN vocabulary v ON v.vocabulary_id = d.vocabulary_id
WHERE d.concept_class_id LIKE 'Therapeutic Class'
	AND e.concept_class_id LIKE 'ATC%'

UNION ALL

-- Cross-link between drug class SNOMED AND ATC classes (not ATC 5th)
SELECT DISTINCT d.concept_code AS concept_code_1,
	e.concept_code AS concept_code_2,
	'SNOMED - ATC eq' AS relationship_id,
	'SNOMED' AS vocabulary_id_1,
	'ATC' AS vocabulary_id_2,
	d.valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM concept d
JOIN sources.rxnconso r ON r.code = d.concept_code
	AND r.sab = 'SNOMEDCT_US'
	AND r.code != 'NOCODE'
JOIN sources.rxnconso r2 ON r.rxcui = r2.rxcui
	AND r2.sab = 'ATC'
	AND r2.code != 'NOCODE'
JOIN atc_tmp_table e ON r2.code = e.concept_code
	AND e.concept_class_id != 'ATC 5th' -- Ingredients only to RxNorm
WHERE d.vocabulary_id = 'SNOMED'
	AND d.invalid_reason IS NULL

UNION ALL

-- Hierarchy inside ATC
SELECT uppr.concept_code AS concept_code_1,
	lowr.concept_code AS concept_code_2,
	'Is a' AS relationship_id,
	'ATC' AS vocabulary_id_1,
	'ATC' AS vocabulary_id_2,
	v.latest_UPDATE AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM concept_stage uppr,
	concept_stage lowr,
	vocabulary v
WHERE (
		(
			LENGTH(uppr.concept_code) IN (
				4,
				5
				)
			AND lowr.concept_code = SUBSTR(uppr.concept_code, 1, LENGTH(uppr.concept_code) - 1)
			)
		OR (
			LENGTH(uppr.concept_code) IN (
				3,
				7
				)
			AND lowr.concept_code = SUBSTR(uppr.concept_code, 1, LENGTH(uppr.concept_code) - 2)
			)
		)
	AND uppr.vocabulary_id = 'ATC'
	AND lowr.vocabulary_id = 'ATC'
	AND v.vocabulary_id = 'ATC';

-- 9. Add new relationships
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT DISTINCT cs.class_code     AS concept_code_1,
	c.concept_code                  AS concept_code_2,
	'ATC'                           AS vocabulary_id_1,
	c.vocabulary_id                 AS vocabulary_id_2,
	'ATC - RxNorm'                  AS relationship_id,
	CURRENT_DATE                    AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL                            AS invalid_reason
FROM class_to_drug cs --manual source table
JOIN concept c ON c.concept_id = cs.concept_id
WHERE NOT EXISTS  (
		SELECT 1
		FROM concept_relationship_stage crs
		WHERE crs.concept_code_1 = cs.class_code
			AND crs.vocabulary_id_1 = 'ATC'
			AND crs.concept_code_2 = c.concept_code
			AND crs.vocabulary_id_2 = c.vocabulary_id
			AND crs.relationship_id = 'ATC - RxNorm'
		)
AND  c.concept_class_id != 'Ingredient' -- 6 for unambiguous  AND 1 for manual
;


-- Primary unambiguous
INSERT INTO concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
SELECT DISTINCT substring(irs.concept_code_1, '\w+') AS concept_code_1,
                c.concept_code                       AS concept_code_2,
                'ATC'                                AS vocabulary_id_1,
                c.vocabulary_id                      AS vocabulary_id_2,
                'ATC - RxNorm pr lat'                AS relationship_id,
                CURRENT_DATE                         AS valid_start_date,
                TO_DATE('20991231', 'YYYYMMDD')      AS valid_end_date,
                NULL                                 AS invalid_reason
FROM internal_relationship_stage irs
       JOIN relationship_to_concept rtc on irs.concept_code_2 = rtc.concept_code_1
       JOIN concept c on concept_id_2 = c.concept_id AND c.concept_class_id = 'Ingredient'
WHERE rtc.concept_code_1
  NOT IN ('adrenergics', 'analgesics', 'antispasmodics', 'antibacterials', 'antiflatulents', 'imidazoles', 'minerals',
          'polyfructosans', 'triazoles', 'natural phospholipids',
          'lactic acid producing organisms', 'antiflatulents', 'beta-lactamase inhibitor', 'sulfonylureas',
          'antibiotics', 'antiinfectives', 'antiseptics', 'artificial tears', 'contact laxatives', 'corticosteroids',
          'ordinary salt combinations', 'imidazoles/triazoles', 'cough suppressants', 'diuretics',
          'drugs for obstructive airway diseases', 'expectorants', 'belladonna alkaloids', 'mucolytics', 'mydriatics',
          'non-opioid analgesics', 'organic nitrates', 'potassium-sparing agents', 'proton pump inhibitors',
          'psycholeptics', 'thiazides', 'snake venom antiserum', 'fat emulsions',
          'amino acids', 'acid preparations', 'sulfur compounds', 'stramoni preparations', 'protamines', 'penicillins',
          'comt inhibitor', 'cannabinoids', 'decarboxylase inhibitor', 'edetates',
          'barbiturates')
  AND not exists(SELECT 1
                 FROM ambiguous_class_ingredient_tst t
                 WHERE t.concept_code_2 = rtc.concept_code_1
                   AND t.class_code = substring(irs.concept_code_1, '\w+')
                   AND flag = 'with')
;

INSERT INTO concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
SELECT DISTINCT class_code                      AS concept_code_1,
                c.concept_code                  AS concept_code_2,
                'ATC'                           AS vocabulary_id_1,
                c.vocabulary_id                 AS vocabulary_id_2,
                'ATC - RxNorm pr lat'           AS relationship_id,
                CURRENT_DATE                    AS valid_start_date,
                TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date,
                NULL                            AS invalid_reason
FROM ambiguous_class_ingredient_tst a
       JOIN relationship_to_concept rtc on a.concept_code_2 = rtc.concept_code_1 AND flag = 'ing'
       JOIN concept c on concept_id_2 = c.concept_id AND c.concept_class_id = 'Ingredient'
WHERE not exists(SELECT 1
                 FROM ambiguous_class_ingredient_tst a2
                 WHERE a.class_code = a2.class_code
                   AND a.rnk = a2.rnk
                   AND a.concept_code_2 != a2.concept_code_2)
  AND rtc.concept_code_1
  NOT IN ('adrenergics', 'analgesics', 'antispasmodics', 'antibacterials', 'antiflatulents', 'imidazoles', 'minerals',
          'polyfructosans', 'triazoles', 'natural phospholipids',
          'lactic acid producing organisms', 'antiflatulents', 'beta-lactamase inhibitor', 'sulfonylureas',
          'antibiotics', 'antiinfectives', 'antiseptics', 'artificial tears', 'contact laxatives', 'corticosteroids',
          'ordinary salt combinations', 'imidazoles/triazoles', 'cough suppressants', 'diuretics',
          'drugs for obstructive airway diseases', 'expectorants', 'belladonna alkaloids', 'mucolytics', 'mydriatics',
          'non-opioid analgesics', 'organic nitrates', 'potassium-sparing agents', 'proton pump inhibitors',
          'psycholeptics', 'thiazides', 'snake venom antiserum', 'fat emulsions',
          'amino acids', 'acid preparations', 'sulfur compounds', 'stramoni preparations', 'protamines', 'penicillins',
          'comt inhibitor', 'cannabinoids', 'decarboxylase inhibitor', 'edetates',
          'barbiturates')
  AND (class_code, concept_code,'ATC - RxNorm pr lat') not in
      (SELECT concept_code_1,concept_code_2, relationship_id FROM concept_relationship_stage)
  AND class_name != 'combinations'
;

--manual table
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT class_code                      AS concept_code_1,
       concept_code                    AS concept_code_2,
       'ATC'                           AS vocabulary_id_1,
       vocabulary_id                   AS vocabulary_id_2,
       'ATC - RxNorm pr lat'           AS relationship_id,
       CURRENT_DATE                    AS valid_start_date,
       TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date,
       NULL                            AS invalid_reason
FROM class_to_drug_manual_ing
WHERE flag = 0
UNION
SELECT class_code                      AS concept_code_1,
       concept_code                    AS concept_code_2,
       'ATC'                           AS vocabulary_id_1,
       vocabulary_id                   AS vocabulary_id_2,
       'ATC - RxNorm pr lat'           AS relationship_id,
       CURRENT_DATE                    AS valid_start_date,
       TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date,
       NULL                            AS invalid_reason
FROM class_to_drug_manual_ing
WHERE flag = 1
  AND class_name != 'combinations'
  AND (class_code, concept_code) NOT IN (SELECT concept_code_1,concept_code_2 FROM concept_relationship_stage)
  AND class_code NOT IN ('J06AA03');--snake venom antiserum


-- Secondary unambiguous
INSERT INTO concept_relationship_stage
  (concept_code_1,
   concept_code_2,
   vocabulary_id_1,
   vocabulary_id_2,
   relationship_id,
   valid_start_date,
   valid_end_date,
   invalid_reason
   )
SELECT DISTINCT class_code                      AS concept_code_1,
                c.concept_code                  AS concept_code_2,
                'ATC'                           AS vocabulary_id_1,
                c.vocabulary_id                 AS vocabulary_id_2,
                'ATC - RxNorm sec lat'          AS relationship_id,
                CURRENT_DATE                    AS valid_start_date,
                TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date,
                NULL                            AS invalid_reason
FROM ambiguous_class_ingredient_tst a
       JOIN relationship_to_concept rtc on a.concept_code_2 = rtc.concept_code_1 AND flag = 'with'
       JOIN concept c on concept_id_2 = c.concept_id AND c.concept_class_id = 'Ingredient'
WHERE not exists(SELECT 1
                 FROM ambiguous_class_ingredient_tst a2
                 WHERE a.class_code = a2.class_code
                   AND a.rnk = a2.rnk
                   AND a.concept_code_2 != a2.concept_code_2)
  AND rtc.concept_code_1
  NOT IN ('adrenergics', 'analgesics', 'antispasmodics', 'antibacterials', 'antiflatulents', 'imidazoles', 'minerals',
          'polyfructosans', 'triazoles', 'natural phospholipids',
          'lactic acid producing organisms', 'antiflatulents', 'beta-lactamase inhibitor', 'sulfonylureas',
          'antibiotics', 'antiinfectives', 'antiseptics', 'artificial tears', 'contact laxatives', 'corticosteroids',
          'ordinary salt combinations', 'imidazoles/triazoles', 'cough suppressants', 'diuretics',
          'drugs for obstructive airway diseases', 'expectorants', 'belladonna alkaloids', 'mucolytics', 'mydriatics',
          'non-opioid analgesics', 'organic nitrates', 'potassium-sparing agents', 'proton pump inhibitors',
          'psycholeptics', 'thiazides', 'snake venom antiserum', 'fat emulsions',
          'amino acids', 'acid preparations', 'sulfur compounds', 'stramoni preparations', 'protamines', 'penicillins',
          'comt inhibitor', 'cannabinoids', 'decarboxylase inhibitor', 'edetates',
          'barbiturates')
  AND (class_code, concept_code) NOT IN (SELECT concept_code_1,concept_code_2 FROM concept_relationship_stage)
  AND class_name != 'combinations'
  AND (class_code, concept_code) NOT IN (SELECT concept_code_1,concept_code_2 FROM concept_relationship_stage);

--manual table
INSERT INTO concept_relationship_stage
  (concept_code_1,
   concept_code_2,
   vocabulary_id_1,
   vocabulary_id_2,
   relationship_id,
   valid_start_date,
   valid_end_date,
   invalid_reason
   )
SELECT DISTINCT class_code                      AS concept_code_1,
                concept_code                    AS concept_code_2,
                'ATC'                           AS vocabulary_id_1,
                vocabulary_id                   AS vocabulary_id_2,
                'ATC - RxNorm sec lat'          AS relationship_id,
                CURRENT_DATE                    AS valid_start_date,
                TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date,
                NULL                            AS invalid_reason
FROM class_to_drug_manual_ing
WHERE flag > 1
  AND class_name != 'combinations'
  AND (class_code, concept_code) NOT IN (
  SELECT concept_code_1,concept_code_2
  FROM concept_relationship_stage);

-- Primary ambiguous
INSERT INTO concept_relationship_stage
  (concept_code_1,
   concept_code_2,
   vocabulary_id_1,
   vocabulary_id_2,
   relationship_id,
   valid_start_date,
   valid_end_date,
   invalid_reason
   )
SELECT class_code                      AS concept_code_1,
       c.concept_code                  AS concept_code_2,
       'ATC'                           AS vocabulary_id_1,
       c.vocabulary_id                 AS vocabulary_id_2,
       'ATC - RxNorm pr up'            AS relationship_id,
       CURRENT_DATE                    AS valid_start_date,
       TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date,
       NULL                            AS invalid_reason
FROM ambiguous_class_ingredient_tst a
       JOIN relationship_to_concept rtc on a.concept_code_2 = rtc.concept_code_1 AND flag = 'ing'
       JOIN concept c on concept_id_2 = c.concept_id AND c.concept_class_id = 'Ingredient'
WHERE (class_code, concept_code) NOT IN (SELECT concept_code_1,concept_code_2 FROM concept_relationship_stage)
  AND rtc.concept_code_1
  IN('adrenergics', 'analgesics', 'antispasmodics', 'antibacterials', 'antiflatulents', 'imidazoles', 'minerals',
      'polyfructosans', 'triazoles','natural phospholipids',
      'lactic acid producing organisms', 'antiflatulents', 'beta-lactamase inhibitor', 'sulfonylureas', 'antibiotics',
      'antiinfectives', 'antiseptics', 'artificial tears', 'contact laxatives', 'corticosteroids',
      'ordinary salt combinations', 'imidazoles/triazoles', 'cough suppressants', 'diuretics',
      'drugs for obstructive airway diseases', 'expectorants', 'belladonna alkaloids', 'mucolytics', 'mydriatics',
      'non-opioid analgesics', 'organic nitrates', 'potassium-sparing agents', 'proton pump inhibitors',
      'psycholeptics', 'thiazides', 'snake venom antiserum', 'fat emulsions',
      'amino acids', 'acid preparations', 'sulfur compounds', 'stramoni preparations', 'protamines', 'penicillins',
      'comt inhibitor', 'cannabinoids', 'decarboxylase inhibitor', 'edetates', 'barbiturates')
UNION
SELECT class_code                      AS concept_code_1,
       c.concept_code                  AS concept_code_2,
       'ATC'                           AS vocabulary_id_1,
       c.vocabulary_id                 AS vocabulary_id_2,
       'ATC - RxNorm pr up'            AS relationship_id,
       CURRENT_DATE                    AS valid_start_date,
       TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date,
       NULL                            AS invalid_reason
FROM ambiguous_class_ingredient_tst a
       JOIN relationship_to_concept rtc on a.concept_code_2 = rtc.concept_code_1 AND flag = 'ing'
       JOIN concept c on concept_id_2 = c.concept_id AND c.concept_class_id = 'Ingredient'
WHERE exists(SELECT 1
             FROM ambiguous_class_ingredient_tst a2
             WHERE a.class_code = a2.class_code
               AND a.rnk = a2.rnk
               AND a.concept_code_2 != a2.concept_code_2)
;

INSERT INTO concept_relationship_stage
  (concept_code_1,
   concept_code_2,
   vocabulary_id_1,
   vocabulary_id_2,
   relationship_id,
   valid_start_date,
   valid_end_date,
   invalid_reason
   )
SELECT DISTINCT substring(irs.concept_code_1, '\w+') AS concept_code_1,
                c.concept_code                       AS concept_code_2,
                'ATC'                                AS vocabulary_id_1,
                c.vocabulary_id                      AS vocabulary_id_2,
                'ATC - RxNorm pr up'                 AS relationship_id,
                CURRENT_DATE                         AS valid_start_date,
                TO_DATE('20991231', 'YYYYMMDD')      AS valid_end_date,
                NULL                                 AS invalid_reason
FROM internal_relationship_stage irs
       JOIN relationship_to_concept rtc ON irs.concept_code_2 = rtc.concept_code_1
       JOIN concept c ON concept_id_2 = c.concept_id AND c.concept_class_id = 'Ingredient'
WHERE rtc.concept_code_1
  IN('adrenergics', 'analgesics', 'antispasmodics', 'antibacterials', 'antiflatulents', 'imidazoles', 'minerals',
      'polyfructosans', 'triazoles','natural phospholipids',
      'lactic acid producing organisms', 'antiflatulents', 'beta-lactamase inhibitor', 'sulfonylureas', 'antibiotics',
      'antiinfectives', 'antiseptics', 'artificial tears', 'contact laxatives', 'corticosteroids',
      'ordinary salt combinations', 'imidazoles/triazoles', 'cough suppressants', 'diuretics',
      'drugs for obstructive airway diseases', 'expectorants', 'belladonna alkaloids', 'mucolytics', 'mydriatics',
      'non-opioid analgesics', 'organic nitrates', 'potassium-sparing agents', 'proton pump inhibitors',
      'psycholeptics', 'thiazides', 'snake venom antiserum', 'fat emulsions',
      'amino acids', 'acid preparations', 'sulfur compounds', 'stramoni preparations', 'protamines', 'penicillins',
      'comt inhibitor', 'cannabinoids', 'decarboxylase inhibitor', 'edetates', 'barbiturates')
  AND (substring(irs.concept_code_1, '\w+'), concept_code) not in
      (SELECT concept_code_1,concept_code_2 FROM concept_relationship_stage)
  AND substring(irs.concept_code_1, '\w+') NOT IN (SELECT class_code FROM ambiguous_class_ingredient_tst)
;

INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT class_code                      AS concept_code_1,
       concept_code                    AS concept_code_2,
       'ATC'                           AS vocabulary_id_1,
       vocabulary_id                   AS vocabulary_id_2,
       'ATC - RxNorm pr up'            AS relationship_id,
       CURRENT_DATE                    AS valid_start_date,
       TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date,
       NULL                            AS invalid_reason
FROM class_to_drug_manual_ing
WHERE flag = 1
  AND class_name != 'combinations'
  AND (class_code, concept_code) NOT IN (SELECT concept_code_1,concept_code_2 FROM concept_relationship_stage)
  AND class_code IN ('J06AA03');--snake venom antiserum

-- combinations, unambiguous, all secondary
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT class_code                      AS concept_code_1,
       c.concept_code                  AS concept_code_2,
       'ATC'                           AS vocabulary_id_1,
       c.vocabulary_id                 AS vocabulary_id_2,
       'ATC - RxNorm pr up'            AS relationship_id,
       CURRENT_DATE                    AS valid_start_date,
       TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date,
       NULL                            AS invalid_reason
FROM (SELECT class_code,c.concept_code,c.vocabulary_id
      FROM ambiguous_class_ingredient_tst a
             JOIN relationship_to_concept rtc on a.concept_code_2 = rtc.concept_code_1
             JOIN concept c on concept_id_2 = c.concept_id AND c.concept_class_id = 'Ingredient'
      WHERE class_name = 'combinations'
      UNION
      SELECT class_code,concept_code, vocabulary_id
      FROM class_to_drug_manual_ing
      WHERE class_name = 'combinations'
     ) c
WHERE (class_code, concept_code) NOT IN (SELECT concept_code_1,concept_code_2 FROM concept_relationship_stage);


-- Secondary ambiguous
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT DISTINCT class_code                      AS concept_code_1,
                c.concept_code                  AS concept_code_2,
                'ATC'                           AS vocabulary_id_1,
                c.vocabulary_id                 AS vocabulary_id_2,
                'ATC - RxNorm sec up'           AS relationship_id,
                CURRENT_DATE                    AS valid_start_date,
                TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date,
                NULL                            AS invalid_reason
FROM ambiguous_class_ingredient_tst a
       JOIN relationship_to_concept rtc ON a.concept_code_2 = rtc.concept_code_1
       JOIN concept c ON concept_id_2 = c.concept_id AND c.concept_class_id = 'Ingredient'
WHERE (exists(SELECT 1
              FROM ambiguous_class_ingredient_tst a2
              WHERE a.class_code = a2.class_code
                AND a.rnk = a2.rnk
                AND a.concept_code_2 != a2.concept_code_2)
  OR rtc.concept_code_1
         IN
     ('adrenergics', 'analgesics', 'antispasmodics', 'antibacterials', 'antiflatulents', 'imidazoles', 'minerals',
      'polyfructosans', 'triazoles', 'natural phospholipids',
      'lactic acid producing organisms', 'antiflatulents', 'beta-lactamase inhibitor', 'sulfonylureas', 'antibiotics',
      'antiinfectives', 'antiseptics', 'artificial tears', 'contact laxatives', 'corticosteroids',
      'ordinary salt combinations', 'imidazoles/triazoles', 'cough suppressants', 'diuretics',
      'drugs for obstructive airway diseases', 'expectorants', 'belladonna alkaloids', 'mucolytics', 'mydriatics',
      'non-opioid analgesics', 'organic nitrates', 'potassium-sparing agents', 'proton pump inhibitors',
      'psycholeptics', 'thiazides', 'snake venom antiserum', 'fat emulsions',
      'amino acids', 'acid preparations', 'sulfur compounds', 'stramoni preparations', 'protamines', 'penicillins',
      'comt inhibitor', 'cannabinoids', 'decarboxylase inhibitor', 'edetates', 'barbiturates')
  )
  AND flag = 'with'
  AND class_name != 'combinations'
  and (class_code, concept_code) NOT IN (SELECT concept_code_1,concept_code_2 FROM concept_relationship_stage)
;

-- add 'x,combinations'
WITH main_ing AS (
  SELECT class_code, concept_id_2
  FROM class_to_drug c
         JOIN internal_relationship_stage i ON c.class_code = substring(i.concept_code_1, '\w+')
         JOIN relationship_to_concept rtc ON rtc.concept_code_1 = i.concept_code_2
  WHERE class_name ~ '(, combinations)|(in combination with other drugs)'
    AND NOT class_name ~ 'with|and thiazides|and other diuretics' -- gives errors INC07BB52 AND C07CB53 if removed
)
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT DISTINCT class_code                      AS concept_code_1,
                cc.concept_code                 AS concept_code_2,
                'ATC'                           AS vocabulary_id_1,
                cc.vocabulary_id                AS vocabulary_id_2,
                'ATC - RxNorm sec up'           AS relationship_id,
                CURRENT_DATE                    AS valid_start_date,
                TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date,
                NULL                            AS invalid_reason
FROM class_to_drug c
       JOIN devv5.concept_ancestor ON descendant_concept_id = c.concept_id
       JOIN concept cc ON cc.concept_id = ancestor_concept_id AND cc.standard_concept = 'S'
  AND cc.concept_class_id = 'Ingredient' AND cc.vocabulary_id LIKE 'Rx%'
WHERE class_name ~ '(, combinations)|(in combination with other drugs)'
  AND NOT class_name ~ 'with|and thiazides|and other diuretics'
  AND (c.class_code, cc.concept_id) NOT IN (SELECT class_code, concept_id_2 FROM main_ing)
  AND (class_code, cc.concept_code) NOT IN (SELECT concept_code_1,concept_code_2 FROM concept_relationship_stage)
;



-- XXX 8.1 temporary deprecate old rels
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT c.concept_code      AS concept_code_1,
       cc.concept_code     AS concept_code_2,
       c.vocabulary_id     AS vocabulary_id_1,
       cc.vocabulary_id    AS vocabulary_id_2,
       relationship_id     AS relationship_id,
       cr.valid_start_date AS valid_start_date,
       current_date        AS valid_end_date,
       'D'                 AS invalid_reason
FROM concept_relationship cr
       JOIN concept c on concept_id_1 = c.concept_id
       JOIN concept cc on concept_id_2 = cc.concept_id
WHERE c.vocabulary_id = 'ATC'
  AND cc.vocabulary_id LIKE 'RxNorm%'
  AND relationship_id IN ('ATC - RxNorm', 'ATC - RxNorm name') -- 'Maps to', 'Drug class of drug',
  AND cr.invalid_reason IS NULL
  and (c.concept_code, relationship_id, cc.concept_code) NOT IN
      (SELECT concept_code_1,relationship_id, concept_code_2 FROM concept_relationship_stage)
;

INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT c.concept_code,
       cc.concept_code,
       c.vocabulary_id,
       cc.vocabulary_id,
       relationship_id,
       cr.valid_start_date,
       cr.valid_end_date,
       cr.invalid_reason
FROM concept_relationship cr
       JOIN concept c on c.concept_id = concept_id_1
       JOIN concept cc on cc.concept_id = concept_id_2
WHERE cr.invalid_reason IS NULL
  AND cr.relationship_id = 'Maps to'
  AND c.vocabulary_id = 'ATC'
  AND cc.vocabulary_id IN('RxNorm', 'RxNorm Extension', 'CVX')
  AND (c.concept_code, cc.concept_code) IN(SELECT concept_code_1,concept_code_2
                                                FROM concept_relationship_stage
                                                WHERE relationship_id = 'ATC - RxNorm pr lat');

-- primary lateral always go inside, >25 - calcium, 23-24 J07%
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT concept_code_1,
       concept_code_2,
       vocabulary_id_1,
       vocabulary_id_2,
       'Maps to',
       valid_start_date,
       valid_end_date,
       invalid_reason
FROM (
SELECT *, count(concept_code_2) OVER (PARTITION BY concept_code_1) AS cnt
FROM concept_relationship_stage
WHERE relationship_id IN('ATC - RxNorm pr lat') -- 'Maps to', 'Drug class of drug',
and invalid_reason IS NULL
and (concept_code_1, vocabulary_id_1, 'Maps to', concept_code_2,vocabulary_id_2)
      NOT IN (SELECT concept_code_1, vocabulary_id_1, relationship_id, concept_code_2,vocabulary_id_2 FROM concept_relationship_stage)
  ) a
WHERE cnt<25
;

INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT concept_code_1,
       concept_code_2,
       vocabulary_id_1,
       vocabulary_id_2,
       'Maps to',
       valid_start_date,
       valid_end_date,
       invalid_reason
FROM (
SELECT *, count(concept_code_2) OVER (PARTITION BY concept_code_1) AS cnt
FROM concept_relationship_stage
WHERE relationship_id IN('ATC - RxNorm sec lat') -- 'Maps to', 'Drug class of drug',
and invalid_reason IS NULL
and (concept_code_1, vocabulary_id_1, 'Maps to', concept_code_2,vocabulary_id_2)
      NOT IN (SELECT concept_code_1, vocabulary_id_1, relationship_id, concept_code_2,vocabulary_id_2 FROM concept_relationship_stage)
  ) a
WHERE cnt<10
;

-- add deprecated Maps to
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT c.concept_code,
       cc.concept_code,
       c.vocabulary_id,
       cc.vocabulary_id,
       relationship_id,
       cr.valid_start_date,
       current_date,
       'D'
FROM concept_relationship cr
       JOIN concept c on c.concept_id = concept_id_1
       JOIN concept cc on cc.concept_id = concept_id_2
WHERE cr.invalid_reason IS NULL
  AND cr.relationship_id = 'Maps to'
  AND c.vocabulary_id = 'ATC' AND c.invalid_reason IS NULL
  AND cc.vocabulary_id IN('RxNorm', 'RxNorm Extension', 'CVX')
  AND (c.concept_code, cr.relationship_id, cc.concept_code) NOT IN (SELECT concept_code_1,relationship_id, concept_code_2
                                                FROM concept_relationship_stage)
                                                  ;

-- 16. Add synonyms to concept_synonym stage for each of the rxcui/code combinations in atc_tmp_table
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_name,
	synonym_vocabulary_id,
	language_concept_id
	)
SELECT DISTINCT dv.concept_code AS synonym_concept_code,
	SUBSTR(r.str, 1, 1000) AS synonym_name,
	dv.vocabulary_id AS synonym_vocabulary_id,
	4180186 AS language_concept_id
FROM atc_tmp_table dv
JOIN sources.rxnconso r ON dv.code = r.code
	AND dv.rxcui = r.rxcui
	AND r.code != 'NOCODE'
	AND r.lat = 'ENG';


-- 16.2 update concept names for combos
UPDATE concept_stage c
SET concept_name = name
FROM (SELECT c2.concept_name||' - '||c.concept_name AS name, c.concept_code
FROM concept_stage c
JOIN concept_relationship_stage cr ON cr.concept_code_1 = c.concept_code
JOIN concept_stage c2 ON c2.concept_code = cr.concept_code_2 AND relationship_id = 'Is a'
WHERE c.concept_name IN ('various', 'combinations','others')) a
WHERE (c.concept_code = a.concept_code);

UPDATE concept_stage c
SET concept_name = concept_name || ', combinations'
WHERE concept_code IN (
  SELECT DISTINCT concept_code
  FROM concept_stage
         JOIN concept_relationship_stage cr ON concept_code = concept_code_1
  WHERE NOT concept_name ~ ' and |comb|/| with |complex'
    AND cr.invalid_reason IS NULL
    AND relationship_id ~ 'sec')
;

-- 16.3 add forms to names
DROP TABLE IF EXISTS new_name_form;
CREATE TABLE new_name_form
AS
WITH name AS (
  SELECT class_code,
         class_name,
         CASE
           WHEN adm_r = 'O' THEN 'oral'
           WHEN adm_r = 'Chewing gum' THEN 'chewing gum'
           WHEN adm_r LIKE '%Inhal%' THEN 'inhalant'
           WHEN adm_r = 'Instill.sol.' THEN 'instillation solution'
           WHEN adm_r = 'N' THEN 'nasal'
           WHEN adm_r = 'P' THEN 'parenteral'
           WHEN adm_r = 'R' THEN 'rectal'
           WHEN adm_r = 'SL' THEN 'sublingual'
           WHEN adm_r LIKE 'TD%' THEN 'transdermal'
           WHEN adm_r = 'V' THEN 'vaginal'
           WHEN adm_r IN('implant', 'intravesical', 'ointment', 'oral aerosol', 'urethral') THEN adm_r
           WHEN adm_r = 's.c. implant' THEN 'implant'
           ELSE null END AS form
  FROM class_drugs_scraper
  WHERE adm_r IS NOT NULL
  UNION
  SELECT class_code,
         class_name,
         CASE
           WHEN class_code LIKE 'A01AB%' THEN 'local oral'
           WHEN concept_code LIKE '%Oral%' THEN 'oral'
           WHEN concept_code LIKE '%Rectal%' THEN 'rectal'
           WHEN concept_code LIKE '%Vaginal%' THEN 'vaginal'
           WHEN concept_code LIKE '%Injectable%' THEN 'parenteral'
           WHEN concept_code LIKE '%Inhal%' THEN 'inhalant'
           WHEN concept_code LIKE '%Nasal%' THEN 'nasal'
           WHEN concept_code LIKE '%Ophthalmic%' THEN 'ophthalmic'
           WHEN concept_code LIKE '%Topical%' THEN 'topical'
           WHEN concept_code LIKE '%Ophthalmic%' THEN 'ophthalmic'
           ELSE null END AS form
  FROM reference
  JOIN class_drugs_scraper USING (class_code)
  WHERE class_code != concept_code
  AND adm_r IS NULL
),
forms AS (
SELECT class_code,class_name,
       regexp_replace(string_agg(form, ', ' ORDER BY class_code, form),'oral, parenteral','systemic') AS form_list
FROM name
WHERE form IS NOT NULL
GROUP BY class_code,class_name)
SELECT class_code, class_name||'; '||form_list AS new_name
  FROM forms;

UPDATE concept_stage
SET concept_name = new_name
FROM (SELECT class_code, new_name FROM new_name_form) a
WHERE (concept_code = class_code);


-- 18. Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

-- 20. Add mapping FROM deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;


-- 19. Deprecate 'Maps to' mappings to deprecated AND upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;


-- 21. DELETE ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DELETEAmbiguousMAPSTO();
END $_$;

DELETE FROM concept_relationship_stage
WHERE vocabulary_id_1='SNOMED' AND vocabulary_id_2 = 'RxNorm';


 */