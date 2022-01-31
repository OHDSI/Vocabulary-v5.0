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
* Author: Polina Talapova
**************************************************************************
-- This is an extract from a full-cycle drug mapping script to get more ingrediens
-- To use it here, assemble a simplified w_table (using the source table) with the following fields: 
source_code VARCHAR,
t_nm VARCHAR, -- normalized Drug Product name
t_ing VARCHAR, -- normalized Ingredient name
cnt
***************************************************************************/
---------------------------
------ING_BN_AUTOMAP-------
---------------------------
DROP TABLE if exists drug_attr_pool;
CREATE TABLE drug_attr_pool 
AS
(WITH t1
AS
(SELECT t_ing,
       REGEXP_REPLACE(UPPER(t_ing),'((\d+)?(\.)?\d+(\.)?(,)?(/)?(\-)?(\d+)?(\.)?(\d+)?(\s)?(MG|ML|%|GM|G|MCG|UNITS|HOUR|UNIT|IU|U|CC|MEQ)(/)?(\d+)?(\.\d+)?(\s)?(MG|ML|%|GM|G|ACT|INH|MCG|UNITS|HOUR|UNIT|IU|U|HR|CC|MEQ)?(((-|\s-\s)\d+(\.\d+)?\s?(MG|ML|%|GM|G|HOUR|ACT|INH|HR|MCG|UNITS|UNIT|IU|U|CC|MEQ))+)?((PER\s)?/\d+(\.\s+)?(\s)?ML|ACT|INH|HR)?)|TABL?E?T?|CAPSULE|ORAL''\W+|:|\<|\>|\[|\]|\_|=|\%','','g') AS nm2
FROM w_table),

t2 AS (SELECT DISTINCT t_ing, REGEXP_SPLIT_TO_TABLE(nm2,'\s+|\/|-|\+') AS nm2 
     FROM t1) 
     SELECT DISTINCT*
     FROM t2
WHERE nm2 <> ''
AND   nm2 !~ 'INJ|C-IV|^OR$|^.$|^IV');

DROP INDEX if exists m_attr_name;
CREATE INDEX m_attr_name 
  ON drug_attr_pool (nm2);
  
ANALYZE drug_attr_pool;

--get rid of too short codes 
DELETE
FROM drug_attr_pool
WHERE LENGTH(nm2) < 3; -- 18639

DELETE
FROM drug_attr_pool
WHERE nm2 ~ '^^.$|^\w+\d+$|^\d+$|^\d+\w+$|\yFROM\|MEDICINE\?|VIII|PROBIOTICS|\yUSE\y'; -- 8222 

DELETE
FROM drug_attr_pool
WHERE LENGTH(nm2) <= 4
AND   nm2 !~ 'ACID|NACL|ZINC|DNA|UDCA|SOY|OIL|MINT|IRON'; -- 22569

UPDATE drug_attr_pool 
set nm2 = trim(regexp_replace(nm2, ',',''));

DELETE
FROM drug_attr_pool
WHERE nm2 ~ '^\d+'; -- 3 

-- look at possible wrong patterns to delete them in next steps
SELECT nm2,
       COUNT(nm2)
FROM drug_attr_pool
GROUP BY nm2
ORDER BY COUNT DESC;

delete from drug_attr_pool where nm2 in  ('OTHER', 'ASSOCIATED','ASSOCIATION','TREATMENT','VARIOUS','INHIBITORS','LOCAL','OPHTHALMIC','HOMEOPATHY',
'ASSOCIATIONS','ANTIBACTERIAL','DERIVES','MEDICATIONS','PRODUCTS','TREATMENTS',
'ACIDS','SYSTEMIC','PHYTOTHERAPY','CORTICOIDES','ASSOCIATES','SOLUTIONS','ACTIVITY','DERMOCORTICOIDES','BASED',
'INFLAMMATORY','DERIVATIVES','ANTIHISTAMINES','APPARENT','ANTISEPTICS','ANTISPASMODIC','SUBSTANCES',
'INHIBITOR','AMINE','SELECTIVE','DIAGNOSTIC','ALONE','CORTICOIDE','CONTRAST','TOPICAL','SALTS',
'VITAMINS','COMPLEX','TARGET','ANESTHETICS','ANTAGONISTS','RADIOPHARMACEUTICAL','SEDATIVE',
'PHYTOTHERAPIE','INHALATION','AGONISTS','ALPHA','ANTICHOLINERGIC','STRONG','ESTROPROGESTATIVE',
'IMIDAZOLES','FACTORS','GROUP','IMMUNOGLOBULINS','VASOCONSTRICTOR','ANTIBACTERIALS','HORMONES',
'DIGESTIVE','ANTIFUNGALS','ANTIFUNGAL','ACTION','WITHOUT','ANTISEPTIC','ASTHENIC','THERAPEUTIC',
'SYSTEM','ARRHYTHMIC','ANTIHYPERTENSIVES','DISORDERS','ELEMENTS','DENTAL','ACNEIC','CARDIOVASCULAR','CENTRAL','CONTRACEPTIVE','ALLERGIC','THIAZIDIC','TESTS',
'CEPHALOSPORINS','ANTIHYPERTENSIVE','MEDICINES','NUTRITION','INTESTINAL','NASAL','DIURETICS','AGENTS','FUNCTION','MISCELLANEOUS','TOPICS',
'MOUTHWASHES','(SARTANS','LIPIDES','ANTIPYRETIC');

-- from pool for Rx vocabs
DROP TABLE if exists rx_attr_pool;
CREATE TABLE rx_attr_pool 
AS
(WITH t1
AS
(SELECT concept_id,
       standard_concept,
       concept_class_id,
       concept_name AS nm,
       UPPER(REGEXP_SPLIT_TO_TABLE(concept_name,'\s+|\/|-')) AS nm2
FROM devv5.concept
WHERE vocabulary_id ~ '^Rx'
AND   domain_id = 'Drug'
AND   invalid_reason IS NULL
AND   concept_class_id IN ('Ingredient','Brand Name','Precise Ingredient')) SELECT DISTINCT*FROM t1 WHERE nm2 <> '');

DROP INDEX if exists r_attr_name;

CREATE INDEX r_attr_name 
  ON rx_attr_pool (nm2);
ANALYZE rx_attr_pool;
--=============================================================================================================
-- obtain 1 to 1 mapping
DROP TABLE if exists ing_bn_automap;
CREATE TABLE ing_bn_automap 
AS
(WITH t1
AS
(SELECT *
FROM rx_attr_pool
WHERE concept_id IN (SELECT concept_id
                     FROM rx_attr_pool
                     GROUP BY concept_id
                     HAVING COUNT(1) = 1))
--  Brand Names 
,t2 AS (SELECT *
        FROM drug_attr_pool
        WHERE t_ing IN (SELECT t_ing
                       FROM drug_attr_pool
                       GROUP BY t_ing
                       HAVING COUNT(1) = 1)),t3 AS (SELECT DISTINCT b.*,
                                                           a.concept_id,
                                                           a.nm AS concept_name,
                                                           a.concept_class_id,
                                                           a.standard_concept
                                                    FROM t1 a
                                                      JOIN t2 b
                                                        ON a.nm2 = b.nm2
                                                       AND a.concept_class_id = 'Brand Name'),
--  Ingreds
t4 AS (SELECT DISTINCT b.*,
              a.concept_id,
              a.nm AS concept_name,
              a.concept_class_id,
              a.standard_concept
       FROM t1 a
         JOIN t2 b
           ON a.nm2 = b.nm2
          AND a.concept_class_id = 'Ingredient'
          AND a.standard_concept = 'S'),t5 AS (SELECT DISTINCT b.*,
                                                      d.concept_id,
                                                      d.concept_name AS concept_name,
                                                      d.concept_class_id,
                                                      d.standard_concept
                                               FROM t1 a
                                                 JOIN t2 b ON a.nm2 = b.nm2
                                                 JOIN concept_relationship r
                                                   ON r.concept_id_1 = a.concept_id
                                                  AND a.standard_concept IS NULL
                                                 JOIN concept d
                                                   ON d.concept_id = r.concept_id_2
                                                  AND d.concept_class_id = 'Ingredient'
                                                  AND d.vocabulary_id ~ 'Rx'
                                               WHERE d.standard_concept = 'S') SELECT*FROM t3
UNION
SELECT *
FROM t4
UNION
SELECT *
FROM t5);

select * from ing_bn_automap; -- 1239
--=============================================================================================================
-- obtain 2 to 2 mapping
INSERT INTO ing_bn_automap
WITH t1
AS
(SELECT *
FROM rx_attr_pool
WHERE concept_id IN (SELECT concept_id
                     FROM rx_attr_pool
                     GROUP BY concept_id
                     HAVING COUNT(1) = 2)),t2 AS (SELECT *
                                                  FROM drug_attr_pool
                                                  WHERE t_ing IN (SELECT t_ing
                                                                 FROM drug_attr_pool
                                                                 GROUP BY t_ing
                                                                 HAVING COUNT(1) = 2)),
-- Brand Names 
t3 AS (SELECT DISTINCT b1.*,
              a1.concept_id,
              a1.nm,
              a1.concept_class_id,
              a1.standard_concept
       FROM t1 a1
         JOIN t2 b1 ON a1.nm2 = b1.nm2
         JOIN t1 a2 ON a2.nm2 <> a1.nm2
         JOIN t2 b2
           ON a2.nm2 = b2.nm2
          AND a2.concept_id = a1.concept_id
          AND b2.t_ing = b1.t_ing
          AND a1.concept_class_id = 'Brand Name'),t4 AS (
-- Ingred
SELECT DISTINCT b1.*,
       a1.concept_id,
       a1.nm,
       a1.concept_class_id,
       a1.standard_concept
FROM t1 a1
  JOIN t2 b1 ON a1.nm2 = b1.nm2
  JOIN t1 a2 ON a2.nm2 <> a1.nm2
  JOIN t2 b2
    ON a2.nm2 = b2.nm2
   AND a2.concept_id = a1.concept_id
   AND b2.t_ing = b1.t_ing
   AND a1.concept_class_id = 'Ingredient'
   AND a1.standard_concept = 'S'),t5 AS (
-- non standard concepts to standard
SELECT DISTINCT b1.*,
       d.concept_id,
       d.concept_name AS nm,
       d.concept_class_id AS concept_class_id,
       d.standard_concept
FROM t1 a1
  JOIN t2 b1 ON a1.nm2 = b1.nm2
  JOIN t1 a2 ON a2.nm2 <> a1.nm2
  JOIN t2 b2
    ON a2.nm2 = b2.nm2
   AND a2.concept_id = a1.concept_id
   AND b2.t_ing = b1.t_ing
  JOIN concept_relationship r
    ON a1.concept_id = r.concept_id_1
   AND a1.standard_concept IS NULL
  JOIN concept d
    ON d.concept_id = r.concept_id_2
   AND d.concept_class_id = 'Ingredient'
   AND d.vocabulary_id ~ 'Rx'
WHERE d.standard_concept = 'S') SELECT*FROM t3
UNION
SELECT *
FROM t4
UNION
SELECT *
FROM t5;

--=============================================================================================================
-- obtain 2 to 1 mapping
INSERT INTO ing_bn_automap
WITH t1
AS
(SELECT *
FROM rx_attr_pool
WHERE concept_id IN (SELECT concept_id
                     FROM rx_attr_pool
                     GROUP BY concept_id
                     HAVING COUNT(1) = 1)
AND   concept_class_id = 'Ingredient'),t2 AS (SELECT *
                                              FROM drug_attr_pool
                                              WHERE t_ing IN (SELECT t_ing
                                                             FROM drug_attr_pool
                                                             GROUP BY t_ing
                                                             HAVING COUNT(1) = 2)),t3 AS (SELECT DISTINCT b1.*,
                                                                                                 a1.concept_id,
                                                                                                 a1.nm AS concept_name,
                                                                                                 a1.concept_class_id,
                                                                                                 a1.standard_concept
                                                                                          FROM t1 a1
                                                                                            JOIN t2 b1 ON a1.nm2 = b1.nm2
                                                                                            JOIN t1 a2 ON a2.nm2 <> a1.nm2
                                                                                            JOIN t2 b2
                                                                                              ON a2.nm2 = b2.nm2
                                                                                             AND b2.t_ing = b1.t_ing),
--Precise Ingredient - 1 
t4 AS (SELECT DISTINCT a.*,
              d.concept_id AS ci2,
              d.concept_name AS cn2,
              d.concept_class_id AS cci2,
              d.standard_concept AS sc2
       FROM t3 a
         JOIN t3 b
           ON a.t_ing = b.t_ing
          AND a.concept_id <> b.concept_id
         JOIN devv5.concept c
           ON UPPER (a.concept_name|| ' ' ||b.concept_name) = UPPER (c.concept_name)
          AND c.concept_class_id IN ('Precise Ingredient')
          AND c.invalid_reason IS NULL
         JOIN concept_relationship r
           ON r.concept_id_1 = c.concept_id
          AND r.relationship_id = 'Form of'
         JOIN concept d
           ON d.concept_id = r.concept_id_2
          AND d.standard_concept = 'S'
          AND d.concept_class_id = 'Ingredient'),t5 AS (SELECT DISTINCT a.*,
                                                               d.concept_ID AS ci2,
                                                               d.concept_name AS cn2,
                                                               d.concept_class_id AS cci2,
                                                               d.standard_concept AS sc2
                                                        FROM t3 a
                                                          JOIN t3 b
                                                            ON a.t_ing = b.t_ing
                                                           AND a.concept_id <> b.concept_id
                                                          JOIN devv5.concept c
                                                            ON UPPER (b.concept_name|| ' ' ||a.concept_name) = UPPER (c.concept_name)
                                                           AND c.concept_class_id IN ('Ingredient')
                                                           AND c.invalid_reason IS NULL
                                                          JOIN concept_relationship r
                                                            ON r.concept_id_1 = c.concept_id
                                                           AND c.standard_concept IS NULL
                                                          JOIN concept d
                                                            ON d.concept_id = r.concept_id_2
                                                           AND d.concept_class_id = 'Ingredient'
                                                           AND d.vocabulary_id ~ 'Rx'
                                                        WHERE d.standard_concept = 'S'),
    t6 AS 
     (SELECT *
  FROM t3
  WHERE (t_ing,concept_id) NOT IN (SELECT t_ing, concept_id FROM t4)
  AND   (t_ing,concept_id) NOT IN (SELECT t_ing, concept_id FROM t5)
  UNION
  SELECT t_ing,
       nm2,
       ci2 AS concept_id,
       cn2 AS concept_name,
       cci2 AS concept_class_id,
       sc2 AS standard_concept
  FROM t4
  UNION
  SELECT t_ing,
       nm2,
       ci2 AS concept_id,
       cn2 AS concept_name,
       cci2 AS concept_class_id,
       sc2 AS standard_concept
  FROM t5
  WHERE (t_ing,ci2) NOT IN (SELECT t_ing, ci2 FROM t4)) 
  SELECT DISTINCT *
  FROM t6
  WHERE concept_id NOT IN (19029306,19103572,43013872,711452,911486,19126510,42903718,42900561,19049024,19136048,43014259,43532032,43532444,45775975);

--=============================================================================================================
-- obtain 1 to 1 mapping (simple match)
INSERT INTO ing_bn_automap
SELECT DISTINCT t_ing,
       nm2,
       concept_id,
       concept_name,
       concept_class_id,
       standard_concept
FROM drug_attr_pool a
  JOIN concept c
    ON lower (c.concept_name) = lower (nm2)
   AND c.concept_class_id = 'Ingredient'
   AND c.standard_concept = 'S'
WHERE t_ing NOT IN (SELECT t_ing FROM ing_bn_automap); -- 307

INSERT INTO ing_bn_automap
SELECT DISTINCT t_ing,
       nm2,
       c.concept_id,
       c.concept_name,
       c.concept_class_id,
       c.standard_concept
FROM drug_attr_pool a
  JOIN devv5.concept_synonym cs ON lower (cs.concept_synonym_name) = lower (nm2)
  JOIN concept c
    ON c.concept_id = cs.concept_id
   AND c.concept_class_id = 'Ingredient'
   AND c.standard_concept = 'S'
WHERE t_ing NOT IN (SELECT t_ing FROM ing_bn_automap); -- 307

-- remove duplicates
DELETE
FROM ing_bn_automap
WHERE ctid NOT IN (SELECT MIN(ctid) FROM ing_bn_automap GROUP BY t_ing, concept_id);-- 3867

-- add problematic maps
-- 1549786	4124	ethinyl estradiol	Ingredient	Standard	Valid	Drug	RxNorm
INSERT INTO ing_bn_automap
SELECT t_ing,
       nm2,
       1549786,
       'ethinyl estradiol',
       'Ingredient',
       'S'
FROM ing_bn_automap
WHERE t_ing ~* 'ETHINYLESTRADIOL';

-- 1125315	161	acetaminophen	Ingredient	Standard	Valid	Drug	RxNorm
INSERT INTO ing_bn_automap
SELECT t_ing,
       nm2,
       1125315,
       'acetaminophen',
       'Ingredient',
       'S'
FROM ing_bn_automap
WHERE t_ing ~* 'PARACETAMOL';

-- get rid BN - only Ingredients are  there
DELETE
FROM ing_bn_automap
WHERE concept_class_id = 'Brand Name';

-- look at those which are uncovered
SELECT *
FROM w_table a
  LEFT JOIN ing_bn_automap b ON lower (a.t_ing) = lower (b.t_ing)
WHERE b.t_ing IS NULL;
----------------
------ING-------
----------------
DROP TABLE if exists ing;
-- add mappings from ing_bn_automap
CREATE TABLE ing 
AS
(SELECT DISTINCT a.t_nm, a.t_ing,
       b.concept_id,
       b.concept_name,
       'automap' AS extra
FROM w_table a
  JOIN ing_bn_automap b ON a.t_ing = b.t_ing
WHERE b.concept_class_id = 'Ingredient');

INSERT INTO ing
SELECT DISTINCT a.t_nm,
       a.t_ing,
       b.concept_id,
       b.concept_name,
       'automap' AS extra
FROM w_table a
  JOIN ing_bn_automap_2 b ON a.t_nm = b.t_nm
WHERE b.concept_class_id = 'Ingredient'
AND   a.t_nm NOT IN (SELECT t_nm FROM ing);

-- weird maps
DELETE
FROM ing
WHERE t_nm IN (SELECT t_nm FROM ing GROUP BY t_nm HAVING COUNT(1) > 5);--0

-- Add mapping for Drugs which are usually ingreds of combo drugs and those with ugly name formulation
-- 1196677	25255	formoterol
INSERT INTO ing
(t_nm,t_ing, concept_id,concept_name,extra)
SELECT DISTINCT *
FROM (SELECT t_nm,t_ing,
             1196677 AS concept_Id,
             'formoterol' AS concept_name,
             'add_map' AS extra
      FROM w_table
      WHERE t_ing ~* '\yFORMO?TEROL'
      --1338005		Bisoprolol
      UNION
      SELECT t_nm,t_ing, 
             1338005,
             'Bisoprolol',
             'add_map'
      FROM w_table
      WHERE t_ing ~* '\yBISO?PROLOL'
      UNION
      -- 974166		Hydrochlorothiazide
      SELECT t_nm,t_ing, 
             974166,
             'Hydrochlorothiazide',
             'add_map'
      FROM w_table
      WHERE t_ing ~* 'HCTZ\y|HYDROCHLOROTH?IAZ?S?IDE?'
      UNION
      -- 1521592	7518	Norgestrel
      SELECT t_nm,t_ing, 
             1521592,
             'Norgestrel',
             'add_map'
      FROM w_table
      WHERE t_ing ~* '\yNORGESTREL|\yNorgestrol'
      UNION
      -- NORETHINDRONE 1521369	7514	Norethindrone
      SELECT t_nm,t_ing, 
             1521369,
             'Norethindrone',
             'add_map'
      FROM w_table
      WHERE t_ing ~* 'NORETHINDRONE'
      UNION
      -- 1539403	36567	Simvastatin
      SELECT t_nm,t_ing, 
             1539403,
             'Simvastatin',
             'add_map'
      FROM w_table
      WHERE t_ing ~* '\ySIMV?ASTATIN'
      UNION
      -- VITAMIN D  19009405	Vitamin D
      SELECT t_nm,t_ing, 
             19095164,
             'Cholecalciferol',
             'automap'
      FROM w_table
      WHERE ((t_ing ~* '\yD\y' AND t_ing ~* '\y3\y' AND t_ing ~* '\yVIT') OR t_ing ~* 'Cho?lecalci?fe?ro?l?' OR t_ing ~* '\yD3')
      UNION
      -- 914335	1223	Atropine
      SELECT t_nm,t_ing, 
             914335,
             'Atropine',
             'add_map'
      FROM w_table
      WHERE t_ing ~* '\yATRO?PINE?'
      UNION
      --740560	2019	Carbidopa
      SELECT t_nm,t_ing, 
             740560,
             'Carbidopa',
             'add_map'
      FROM w_table
      WHERE t_ing ~* '\yCARBIDOPA'
      UNION
      -- 1335539	8153	Phentolamine
      SELECT t_nm,t_ing, 
             1335539,
             'Phentolamine',
             'add_map'
      FROM w_table
      WHERE t_ing ~* '\yPHENTOLAMIN'
      UNION
      -- 1741122	37617	tazobactam
      SELECT t_nm,t_ing, 
             1741122,
             'tazobactam',
             'add_map'
      FROM w_table
      WHERE t_ing ~* '\yTAZOBACTAM'
      UNION
      --939871	36709	sodium phosphate
      SELECT t_nm,t_ing, 
             939871,
             'sodium phosphate',
             'add_map'
      FROM w_table
      WHERE t_ing ~* 'SODIUM\s+PHOSPHATE|SOD\s+PHOS' and t_ing !~* 'BETAMETH|DEXAMETH'
      UNION
      -- PREDNISOLONE 1550557	8638	prednisolone
      SELECT t_nm,t_ing, 
             1550557,
             'prednisolone',
             'add_map'
      FROM w_table
      WHERE t_ing ~* '\yPREDNISOLON'
      AND   t_ing !~* 'Methyl'
      UNION
      -- TRIMETHOPRIM 1705674	10829	Trimethoprim 
      SELECT t_nm,t_ing, 
             1705674,
             'Trimethoprim',
             'add_map'
      FROM w_table
      WHERE t_ing ~* '\yTRI?METH?OPRIM'
      UNION
      -- 1174888	5489	Hydrocodone
      SELECT t_nm,t_ing, 
             1174888,
             'Hydrocodone',
             'add_map'
      FROM w_table
      WHERE t_ing ~* 'HYDROCO?DONE?'
      UNION
      -- 1137529	36117	salmeterol 
      SELECT t_nm,t_ing, 
             1137529,
             'salmeterol',
             'add_map'
      FROM w_table
      WHERE t_ing ~* '\ySAL?ME?O?TE?ROL'
      UNION
      -- 915981	7299	Neomycin
      SELECT t_nm,t_ing, 
             915981,
             'Neomycin',
             'add_map'
      FROM w_table
      WHERE t_ing ~* 'Neomy?i?ci?y?n'
      UNION
      -- 948582	8536	Polymyxin B
      SELECT t_nm,t_ing, 
             948582,
             'Polymyxin B',
             'add_map'
      FROM w_table
      WHERE t_ing ~* 'poly?i?my?i?xi?y?n') b
WHERE (t_nm,concept_id) NOT IN (SELECT t_nm, concept_id FROM ing); -- 30
--======================================================================
-- B Complex 
INSERT INTO ing
(t_nm,t_ing,  concept_id,concept_name,extra)
SELECT DISTINCT *
FROM (SELECT t_nm,t_ing, 
             19010970 AS concept_id,
             'Vitamin B Complex' AS concept_name,
             'automap' AS extra
      FROM w_table
      WHERE t_ing ~* '\yB\y'
      AND   t_ing ~* '\yCOMPL?'
      UNION
      -- 19035704	1897	Calcium Carbonate + (D3)
      SELECT t_nm,t_ing, 
             19035704,
             'Calcium Carbonate',
             'automap'
      FROM w_table
      WHERE t_ing ~* 'calcium'
      AND   t_ing !~* '\y\w+ate\y|\yPHOS'
      AND   ((t_ing ~* '\yD\y' AND t_ing ~* '\y3\y' AND t_ing ~* '\yVIT') OR t_ing ~* 'Cho?lecalci?fe?ro?l?' OR t_ing ~* '\yD3')
      UNION
      --993631	6582	Magnesium Oxide
      SELECT t_nm,t_ing, 
             993631,
             'Magnesium Oxide',
             'automap'
      FROM w_table
      WHERE t_ing ~* 'magnesium\s*\W*|\yma?g\y'
      AND   t_ing !~* '\y\w+ate\y|\y\w+ide\y|сhelated|\ygel\y|\yIV\y|\yOIL\y|\yspray\y|\ytopical\y'
      AND   t_ing !~* '\d+|\|\/mg\/gm|mg oral tablet|\yCBC\y|\yBMP\y|Labratory|level'
      AND   t_ing !~* 'AVELOX|e?s?z?omeprazole|Medicated tar|normal saline|\yNS\y|oxycodone|NEURONTIN'
      AND   t_ing !~* '\|MG\||\(\?mg\)|\|MG ORAL\|'
      --1469
      UNION
      --911064	11423	Zinc Oxide
      SELECT t_nm,t_ing, 
             911064,
             'Zinc Oxide',
             'automap'
      FROM w_table
      WHERE t_ing ~* '\yzinc\y|\yzn\y'
      AND   t_ing !~* '\y\w+ate\y|chloride|\ychelat?ed\y|Hydrocortisone|BACITRACIN'
      --838
      UNION
      --19137312	10454	Thiamine
      SELECT t_nm,t_ing, 
             19137312,
             'Thiamine',
             'automap'
      FROM w_table
      WHERE t_ing ~* 'thiamine|\yB\s*\W*1\y|\yvit\s*\W*b\s*\W*1\y'
      AND   t_ing !~* 'MOAB|Anti-B1|gluta?o?thiamine|Estrogen|Lactobacillus'
      --143
      UNION
      --1353228	42954	Vitamin B6
      SELECT t_nm,t_ing, 
             1353228,
             'Vitamin B6',
             'automap'
      FROM w_table
      WHERE t_ing ~* 'pyridoxine|\yB\s*\W*6\y|\yvit\s*\W*b\s*\W*6\y'
      --423
      UNION
      --19111620	4511	Folic Acid
      SELECT t_nm,t_ing, 
             19111620,
             'Folic Acid',
             'automap'
      FROM w_table
      WHERE t_ing ~* 'folic\s*\W*acid|\yB\s*\W*9\y|\yvit\s*\W*b\s*\W*9\y|\yfoli?c?'
      AND   t_ing !~* 'FOLEY|football|follow|Finasteride|Folinate|FOLDING|follistum|Follitropin|CDDP|Foll?istim|FOLDED|folapro|Folinic|methyl?\s+folate|Folfox|foloplex|calcuim folinate|FOLFIRI|folisee|folicullar|folafy|ARA|Folitrax|folliculitis|Xymogen|FOLFIRINOX|^DIDEAZA|Methylated Folate|folbac|folicacio|Folfox'
      --857
      UNION
      --19024770	1588	Biotin
      SELECT t_nm,t_ing, 
             19024770,
             'Biotin',
             'automap'
      FROM w_table
      WHERE t_ing ~* 'biotin|\yB\s*\W*7\y|\yvit\s*\W*b\s*\W*7\y|\yvit\s*\W*b\s*\W*H\y'
      AND   t_ing !~* 'prebiotin|Biotinol') b
WHERE (t_nm,concept_id) NOT IN (SELECT t_nm, concept_id FROM ing); --35
--============================================================================
-- add  mappings for ingredients of frequent occurrence is the source data manually 
INSERT INTO ing
(t_nm,t_ing,  concept_id,concept_name,extra)--19011773	1151	Ascorbic Acid
SELECT *
FROM (SELECT t_nm,t_ing, 
             19011773 AS concept_id,
             'Ascorbic Acid' AS concept_name,
             'automap'
      FROM w_table
      WHERE t_ing ~* '\yASCORB\y|\yASCORB\s+ACID?|\yASCORBIC\y|\yASCORBAT\y'
      OR    (t_ing ~* '\yVIT' AND t_ing ~* '\yC\y')
      UNION
      --915175	1291	Bacitracin
      SELECT  t_nm,t_ing, 
             915175,
             'Bacitracin',
             'automap'
      FROM w_table
      WHERE t_ing ~* '\yBACIT|\yBACITRACIN'
      UNION
      --- 917006	1399	Benzocaine      
      SELECT t_nm,t_ing, 
             917006,
             'Benzocaine',
             'automap'
      FROM w_table
      WHERE t_ing ~* '\yBENZOC'
      UNION
      -- 19035704	1897	Calcium Carbonate
      SELECT t_nm,t_ing, 
             19035704,
             'Calcium Carbonate',
             'automap'
      FROM w_table
      WHERE t_ing ~* '\yCAL\s*CARB|\yCALCIUM\s+CARB|CARB\s+CALC'
      UNION
      -- 1560524	4850	Glucose
      SELECT  t_nm,t_ing, 
             1560524,
             'Glucose',
             'automap'
      FROM w_table a
      WHERE t_ing ~* '(\yD5\/W|\yD5W|\yD5|\yDE?I?XTROS|\yDEXT?\s*\d+\s*%|\yDEXTROSE|\yD5-|\yDX\d+%|\yD\s+5\%|\yD\d+%|\yD10|\yD10W|\yGLUCOSE\y)(?!$)'
      AND   t_ing !~* 'GLUCOSA?O?MIN|GLUCOSE\s+INTOLERANCE|D5000'
      UNION
      --967823	9863	Sodium Chloride
      SELECT  t_nm,t_ing, 
             967823,
             'Sodium Chloride',
             'automap'
      FROM w_table
      WHERE t_ing ~* '\yNOR\s+SALIN|\ySOD\s+CHL|\yNACL\y|\y45NS\y|\ySOCCHLO|\yNORMAL\s+SALIN|\yN\.S\.\y|\ySALIN\y|\ySODIUM\s+CHLORID|\yNA\s+CL\y|\y\d+NACL|\y\d+NS\y|\yNORM\.SAL\.'
      AND   t_ing !~* 'HYPERBARIC|N400|COLLAR |NSY|CS-CATHLON|HOUR|TAPE |N455|CLEANSER|MIN|VISIT|VITAMINS|OTOACOUST|GOWNS|SHEATH|RESOLUTIONS|DAKINS|NST'
      --AND   ing NOT IN (SELECT ing FROM ing WHERE ing !~* 'D5W|D5|DEXTROSE 5\%|DEX 5\%|DEXTROSE|DEX|DEXT 5\%|D5\-|DEXT5\%|DEXT5\%|DX5\%|D 5\%|D5\%|DIXTROSE');
      UNION
      --19049105	8591	Potassium Chloride
      SELECT  t_nm,t_ing, 
             19049105,
             'Potassium Chloride',
             'automap'
      FROM w_table
      WHERE t_ing ~* '\yPOT\s+CHL|\yPT\s+CHL|\yKCL\y|\yPOTAS.*CHL(O)?RID|POTASSIUM\s+CHO'
      UNION
      --1125315	161	Acetaminophen       
      SELECT  t_nm,t_ing, 
             1125315,
             'Acetaminophen',
             'automap'
      FROM w_table
      WHERE t_ing ~* '\yACETAMIN|\yACETO?A?MINOPHE|\yAPAP\y'
      UNION
      -- 1154343	435	Albuterol
      SELECT  t_nm,t_ing, 
             1154343,
             'Albuterol',
             'automap'
      FROM w_table
      WHERE t_ing ~* '\yALBUT'
      AND   t_ing !~* '\yLEVALBUT'
      UNION
      --1112921	7213	Ipratropium
      SELECT  t_nm,t_ing, 
             1112921,
             'Ipratropium',
             'automap'
      FROM w_table
      WHERE t_ing ~* '\yIPRAT?R?'
      UNION
      -- 588017	OMOP3138396	Amino Acids
      SELECT  t_nm,t_ing, 
             588017,
             'Amino Acids',
             'automap'
      FROM w_table
      WHERE t_ing ~* '\yA\.A\.\y|\yAMINO\s+ACID|\yAMINOSYN'
      UNION
      -- 1713332	723	Amoxicillin
      SELECT t_nm,t_ing, 
             1713332,
             'Amoxicillin',
             'automap'
      FROM w_table
      WHERE t_ing ~* '\yAMOX|\yclavulin'
      UNION
      -- 1759842	48203	Clavulanate
      SELECT t_nm,t_ing, 
             1759842,
             'Clavulanate',
             'automap'
      FROM w_table
      WHERE t_ing ~* '\yCLAVU'
      UNION
      -- 19027362	34322	potassium phosphate
      SELECT  t_nm,t_ing, 
             19027362,
             'potassium phosphate',
             'automap'
      FROM w_table
      WHERE t_ing ~* '\yPOTASS?I?U?M?\s+PHOS|\yPOT\.?PHOS\.?|\yK\s*PHOS'
      UNION
      -- 989878	6387	Lidocaine
      SELECT  t_nm,t_ing, 
             989878,
             'Lidocaine',
             'automap'
      FROM w_table
      WHERE t_ing ~* '\yLIDOC'
      UNION
      -- 1139042	197	Acetylcysteine
      SELECT  t_nm,t_ing, 
             1139042,
             'Acetylcysteine',
             'automap'
      FROM w_table
      WHERE t_ing ~* '\yACETYLCYST'
      UNION
      -- 1301125	105694	Epoetin Alfa
      SELECT  t_nm,t_ing, 
             1301125,
             'Epoetin Alfa',
             'automap'
      FROM w_table
      WHERE t_ing ~* '\yEPOETIN'
      AND   t_ing !~* 'darbepoe'
      UNION
      -- 1343916	3992	Epinephrine
      SELECT t_nm,t_ing, 
             1343916,
             'Epinephrine',
             'automap'
      FROM w_table
      WHERE t_ing ~* '\yEPINE|EPI\s*-?PEN'
      UNION
      -- 974166	5487	Hydrochlorothiazide
      SELECT  t_nm,t_ing, 
             974166,
             'Hydrochlorothiazide',
             'automap'
      FROM w_table
      WHERE t_ing ~* '\yHYDR?OCHLORO?TH?IAZ?S?ID|\yHCT|\yHYDROCHIL|HYDROCHLORATHIAZID'
      UNION
      --1335471	18867	benazepril  
      SELECT  t_nm,t_ing, 
             1335471,
             'benazepril',
             'automap'
      FROM w_table
      WHERE t_ing ~* '\yBENE?A?ZA?I?E?PRIL|BENZAPINE|BENZAPRIL|BENZIPRIL|BENAZEPRIL|BENEZAPRIL|BENEZPRIL'
      UNION
      --1332418	17767	Amlodipine
      SELECT  t_nm,t_ing, 
             1332418,
             'Amlodipine',
             'automap'
      FROM w_table
      WHERE t_ing ~* '\yAMLI?O?DI?O?P'
      UNION
      --1518254	3264	Dexamethasone
      SELECT t_nm,t_ing, 
             1518254,
             'Dexamethasone',
             'automap'
      FROM w_table
      WHERE t_ing ~* '\yDEXAM'
      UNION
      --1134439	1886	Caffeine
      SELECT  t_nm,t_ing, 
             1134439,
             'Caffeine',
             'automap'
      FROM w_table
      WHERE t_ing ~* 'Ca?o?ff?ei'
      UNION
      --19037596	193	Acetylcarnitine
      SELECT  t_nm,t_ing, 
             19037596,
             'Acetylcarnitine',
             'automap'
      FROM w_table
      WHERE t_ing ~* '\yACETYL\s*-?L-?\s*CARN'
      UNION
      --36878782	OMOP994671	Multivitamin preparation
      SELECT  t_nm,t_ing, 
             36878782,
             'Multivitamin preparation',
             'automap'
      FROM w_table
      WHERE t_ing ~* 'MULTIPLE ADULT|\yEYE HEALTH|MULTIPLE VITAMIN|CENTRUM|HEXAVITAMIN|MULTIVITS|\yMVI\y|VITAMINS MULTIPLE|FORMULA 3|\yWOMEN\y|^MEN\y|^PROSTATE''\yABC\s+|\yS VITAMIN|MULTIVITAMIN|\yANIMAL SHAPE|\yDAILY VITAMINS|\yMULTIPLE CHILDREN|ABC PLUS|^ALIVE|CORVITE|POLY-VI-SOL''\yI\s*-?CAPS?|WOMENS ONE|ANTIOXIDANT MULTIPLE|KAPS FILMTAB|MULTIPLE VITAMIN|MULTI VITAMIN|MULTIPLE PEDIATRIC|MULITVITAMIN|VITAMINS\, THERAPEUTIC''DAILY VITE|PRENATAL 1|FLINTSTONES|MULTIPLE INFANT|MULIVITAMIN|MULITIVITAMIN|\yONE\s*-?A\s*-?DAY|VITAMINS,\s+MULTIPLE|VITA-KAPS|MULTI-VIT''VITAMINS THERAPEUTIC|MULTIPLE CHILD|DAILY MULTI|DAILY MULTI|MULTIPLE 1|NATAL VITAMIN|MULTI VIT|RENATAL MVI|I-CAPS|^MV$|MUTLIVITAMIN|I-CAP|ONE A DAY''^ONE A|PRENATAL VITAMIN|MULTI VITAMINS|PRE\s*-?NATAL|VITAMIN DAILY|DAILY VITAMIN|VITAMINS, MULTIPLE|M\.V\.I\.|DAILY MULTIPLE|MEGA VITAMIN' 
      )a
WHERE (a.t_nm,a.concept_id) NOT IN (SELECT t_nm, concept_id FROM ing); -- 125
---===============================================================================
/*-- add ingredients of stable brand names 
INSERT INTO ing
(t_nm,t_ing,concept_id,concept_name,extra)
SELECT DISTINCT h.t_nm,h.t_ing,
       c.concept_id,
       c.concept_name,
       'brands_stable_list' AS extra
FROM bn_2 b
  JOIN brand_rx r ON b.concept_id = r.b_id
  JOIN w_table h ON UPPER (TRIM (h.t_nm)) = UPPER (b.t_nm)
  JOIN concept c ON c.concept_id = r.i_id
WHERE( h.t_nm, c.concept_id) NOT IN (SELECT t_nm, concept_id FROM ing)
 and  c.concept_id NOT IN (924309,1350310,19098505,19018544,19124906,19095164)
AND   h.t_ing !~* 'FLINTSTONES|FERRAPLUS|GAS-X|GERM DEFENSE|VORTEX'; -- 1941 */

-- add more ingredients, using  name similarity;  
INSERT INTO ing
SELECT *
FROM (SELECT DISTINCT a.t_nm, a.t_ing,
             c.concept_id,
             c.concept_name,
             'name=name=ingred (3 words)' AS extra
      FROM w_table a
        JOIN concept c
          ON UPPER (concept_name) = UPPER (SUBSTRING (t_ing,'^\w+\s*\w+\s*\w+|^\w+-?\w+\s*\w+|^\w+\s*\w+-?\w+'))
         AND concept_class_id = 'Ingredient'
         AND standard_concept = 'S') a
WHERE (t_nm,concept_id) NOT IN (SELECT t_nm, concept_id FROM ing); -- 2456

INSERT INTO ing
SELECT *
FROM (SELECT DISTINCT a.t_nm, a.t_ing,
             c.concept_id,
             c.concept_name,
             'name=name=ingred (3 words)' AS extra
      FROM w_table a
        JOIN concept c
          ON UPPER (concept_name) = UPPER (SUBSTRING (t_ing,'\w+\s*\w+\s*\w+$|\w+-?\w+\s*\w+$|\w+\s*\w+-?\w+$'))
         AND concept_class_id = 'Ingredient'
         AND standard_concept = 'S') a
WHERE (t_nm,concept_id) NOT IN (SELECT t_nm, concept_id FROM ing)
AND   concept_id NOT IN (19018544,19124906); -- 341

-- one word at the beginning
INSERT INTO ing
SELECT *
FROM (SELECT DISTINCT a.t_nm, a.t_ing, 
             c.concept_id,
             c.concept_name,
             'name=name=ingred (1 words)' AS extra
      FROM w_table a
        JOIN concept c
          ON UPPER (concept_name) = UPPER (SUBSTRING (t_ing,'^\w+'))
         AND concept_class_id = 'Ingredient'
         AND standard_concept = 'S') a
WHERE (t_nm) NOT IN (SELECT t_nm FROM ing)
AND   concept_id NOT IN (19018544,19124906,19103572,42898412,42898412,19010696,19010309,19136048,40799093); -- 0

-- 2 words at the end of a string 
INSERT INTO ing
SELECT *
FROM (SELECT DISTINCT a.t_nm, a.t_ing,
             c.concept_id,
             c.concept_name,
             'name=name=ingred (1 words)' AS extra
      FROM w_table a
        JOIN concept c
          ON UPPER (concept_name) = UPPER (SUBSTRING (t_ing,'\w+\s+\w+$'))
         AND concept_class_id = 'Ingredient'
         AND standard_concept = 'S') a
WHERE (t_nm,concept_id) NOT IN (SELECT t_nm, concept_id FROM ing)
AND   concept_id NOT IN (42709324); -- 3

-- add normal ingredients of dead brand names (use a 'dead_bn' table)
INSERT INTO ing
(t_nm,t_ing,concept_id,concept_name,extra)
SELECT DISTINCT b.t_nm,b.t_ing,
       c.concept_id,
       c.concept_name,
       'ing_of_dead_bn'
FROM dead_bn a
  JOIN w_table b ON a.t_nm = b.t_nm
  JOIN devv5.concept c
    ON a.concept_Id = c.concept_id
   AND c.standard_concept = 'S'
WHERE (b.t_nm,c.concept_id) NOT IN (SELECT t_nm, concept_id FROM ing)
AND   c.concept_id NOT IN (901318,950435,1119510,1360067,19043395,43532148,19136048,19059817,19005046,19009405,19049024,19011773,989727,1704758)
AND   t_ing !~* 'FORTE$|CEREFOLIN|ACID RELIEF|CA-REZZ|EPICERAM|FLEET PEDIATRIC|NAUSEA|NAUZENE'; -- 98

INSERT INTO ing
SELECT *
FROM (SELECT DISTINCT a.t_nm,a.t_ing,
             c.concept_id,
             c.concept_name,
             'name=name=ingred (2 words)' AS extra
      FROM w_table a
        JOIN concept c
          ON UPPER (concept_name) = UPPER (SUBSTRING (t_ing,'\w+\s*\w+|w+\-?\w+|\w+-?\d+'))
         AND concept_class_id = 'Ingredient'
         AND standard_concept = 'S') a
WHERE (a.t_nm,a.concept_id) NOT IN (SELECT t_nm, concept_id FROM ing); -- 0

-- use concept_synonym to get more mappings, using concept_relationship
INSERT INTO ing
SELECT *
FROM (SELECT DISTINCT a.t_nm,a.t_ing,
             d.concept_id,
             d.concept_name,
             'synonym_name=name(2 words)=ingred' AS extra
      FROM w_table a
        JOIN devv5.concept_synonym cs ON UPPER (cs.concept_synonym_name) = UPPER (SUBSTRING (t_ing,'\w+\s+\w+|\w+-\w+|w+-\d+|\d+-\w+'))
        JOIN devv5.concept c ON cs.concept_id = c.concept_id
        JOIN devv5.concept_relationship cr
          ON cr.concept_id_1 = c.concept_id
         AND cr.invalid_reason IS NULL
         AND cr.relationship_id = 'Maps to'
        JOIN devv5.concept d
          ON cr.concept_id_2 = d.concept_id
         AND d.concept_class_id = 'Ingredient'
         AND d.standard_concept = 'S') n
WHERE t_nm NOT IN (SELECT t_nm FROM ing)
AND   concept_id NOT IN (1369939,528323,19010696,42800027) 
and t_ing !~ 'CHLORAL|COLY-|LOXO-101'; -- 21

-- add mappings of ingredients, using both 2 words combination similarity and conversion of some drugs to the ingredients by concept_relationship
INSERT INTO ing
SELECT *
FROM (SELECT DISTINCT a.t_nm,a.t_ing,
             d.concept_id,
             d.concept_name,
             'name=name(2 words)=has_stand_ingred' AS extra
      FROM w_table a
        JOIN devv5.concept c ON UPPER (c.concept_name) = UPPER (SUBSTRING (t_ing,'\w+\s\w+|\w+-\w+|w+-\d+|\d+-\w+'))
        JOIN devv5.concept_relationship cr
          ON cr.concept_id_1 = c.concept_id
         AND cr.invalid_reason IS NULL
        JOIN devv5.concept d
          ON cr.concept_id_2 = d.concept_id
         AND d.concept_class_id = 'Ingredient'
         AND d.standard_concept = 'S'
      WHERE c.concept_name !~* 'B\s*Complex') a
WHERE t_nm NOT IN (SELECT t_nm FROM ing)
AND   concept_name !~* '\yvitam'
AND   concept_id NOT IN (1369939,528323,19010696,42800027)
AND   t_ing !~* 'Coagulation|\yvita|os\s*-?cal|\ymega\y|cal-?\s/?mag|HUMALOG|NOVOLOG|PREPARATION|Alka-?\s*S?z?eltz?s?er'; -- 15

-- add mappings of ingredients, using both 1 word combination similarity and conversion of some drugs to the ingredients by concept_relationship
INSERT INTO ing
SELECT *
FROM (SELECT DISTINCT a.t_nm,a.t_ing,
             d.concept_id,
             d.concept_name,
             'name=name(1 word)=has_stand_ingred' AS extra
      FROM w_table a
        JOIN devv5.concept c ON UPPER (c.concept_name) = UPPER (SUBSTRING (t_ing,'^\w+'))
        JOIN devv5.concept_relationship cr
          ON cr.concept_id_1 = c.concept_id
         AND cr.invalid_reason IS NULL
         AND cr.relationship_id = 'Maps to'
        JOIN devv5.concept d
          ON cr.concept_id_2 = d.concept_id
         AND d.concept_class_id = 'Ingredient'
         AND d.standard_concept = 'S'
      WHERE d.concept_name !~* 'B\s*Complex|Benzocaine|^\w+\s+D') a
WHERE (t_nm) NOT IN (SELECT t_nm FROM ing)
AND   t_ing !~* 'BUFFER|^CALCIUM WITH D|^EYE DROP'
AND   concept_name !~* '\w+ate\y'
AND   concept_id NOT IN (19010696,19010309,19019206,19056118,940426,992409,993631,1000995,1036525,1501309,19018544,19024068,19103572,19124906,19135931,19136048,40799093,42898412,42898532,42900133,43526876,46276228,19018663,19066891,939881)
AND   t_ing !~* '^thyroid|INSULINE|Chloride|Prosta'; -- 114

-- 1 word + concept_relationship
INSERT INTO ing
SELECT *
FROM (SELECT DISTINCT a.t_nm,a.t_ing,
             d.concept_id,
             d.concept_name,
             'to check - synonym_name=name(1word)=has_stand_ingred'
      FROM w_table a
        JOIN devv5.concept_synonym cs ON UPPER (cs.concept_synonym_name) = UPPER (SUBSTRING (t_ing,'\w+'))
        JOIN devv5.concept c ON cs.concept_id = c.concept_id
        JOIN devv5.concept_relationship cr
          ON cr.concept_id_1 = c.concept_id
         AND cr.relationship_id = 'Maps to'
         AND cr.invalid_reason IS NULL
        JOIN devv5.concept d
          ON cr.concept_id_2 = d.concept_id
         AND d.concept_class_id = 'Ingredient'
         AND d.standard_concept = 'S') n
WHERE t_nm NOT IN (SELECT t_nm FROM ing)
AND   t_ing NOT IN ('HC','UNI','THC','MB','INSULIN','HCG','HC','DOC','BAL','ALUM','ADH','BUFFERED','FL','IgA','hc','FL','PTFE','T4','CPM','INTERLEUKIN','Co','CO')
AND   concept_id NOT IN (19010696,19010309,19019206,19056118,940426,992409,993631,1000995,1036525,1501309,19018544,19024068,19103572,19124906,19028950,979096,19135931,19136048,40799093,42898412,42898532,42900133,43526876,46276228,914310,929128,978555,1311409,1396131,19030692,19035704,19037038,19037401,19066891,19066894,19079204,19112944,19115033,19115055,19125390,45775351)
AND   t_ing !~* 'TAM|thyroid|^AG$|^CO$|^Prosta|^FIG$|^IL$|^HEMA$'; -- 39

INSERT INTO ing
SELECT *
FROM (SELECT DISTINCT  a.t_nm, a.t_ing,
             d.concept_id,
             d.concept_name,
             'to check - synonym_name=name(1word)=has_stand_ingred'
      FROM w_table a
        JOIN devv5.concept_synonym cs ON UPPER (cs.concept_synonym_name) = UPPER (SUBSTRING (t_nm,'\w+$'))
        JOIN devv5.concept c ON cs.concept_id = c.concept_id
        JOIN devv5.concept_relationship cr
          ON cr.concept_id_1 = c.concept_id
         AND cr.relationship_id = 'Maps to'
         AND cr.invalid_reason IS NULL
        JOIN devv5.concept d
          ON cr.concept_id_2 = d.concept_id
         AND d.concept_class_id = 'Ingredient'
         AND d.standard_concept = 'S') n
WHERE t_nm NOT IN (SELECT t_nm FROM ing)
AND   t_ing NOT IN ('HC','UNI','THC','MB','INSULIN','HCG','HC','DOC','BAL','ALUM','ADH','BUFFERED','FL','IgA','hc','FL','PTFE','T4','CPM','INTERLEUKIN','Co','CO')
AND   concept_id NOT IN (19010696,19010309,19019206,19056118,940426,992409,993631,1000995,1036525,1501309,19018544,19024068,19103572,19124906,19135931,19136048,40799093,42898412,42898532,42900133,43526876,46276228,914310,929128,978555,1311409,1396131,19030692,19035704,19037038,19037401,19066891,19066894,19079204,19112944,19115033,19115055,19125390,45775351,42904235,45776882,19050104,19018192,19059097,19011034,19011034,19057346,19071128,19010955,42903552,1518254,19007600,44507484,976309,19018663,19126511,1360067,43532444,43532257,43532032,40175801,42903621,1116109,36878914,19007595,1195334,19061821,950435,19011082,1351935,19111620,19058092,42903801,42899196,42900474,1553610,19091701,42899323,42903970,19106973,1326901,922191,19031378,19043395,1389502,986417,19049024,19066774,966913,19136043,19136247,42900156,42900177,19041085,40799146,979096,19009540)
AND   t_ing !~* 'TAM|thyroid|^AG$|^CO$|^Prosta|^FIG$|^IL$|^HEMA$|^DHEA'
AND   concept_name !~* '^\w+ate$'; -- 13

DELETE 
FROM ing
WHERE t_ing ~* 'Influenza Virus|vaccine|bcg|VAXIGRIP'; --  should be mapped manually

DELETE FROM ing
WHERE LENGTH(t_ing) <= 3
AND   t_ing !~* 'PVA|RID|D5W(?!$)|NS|MCT|MVI|SPS|BSS|FAT|EPI|PEG|BAC|D5(?!$)|^UNI|D10|SMX|MTX|^ASA$|^ASA |^IN$|^INE$|^LV$|^U$|^S W$|^CTX$'; -- 5739

DELETE
FROM ing
WHERE t_ing IN (SELECT t_ing
                FROM ing
                WHERE concept_name ~ 'calcium phosphate'
                AND   t_nm !~* 'centrum')
AND   UPPER(t_ing) <>UPPER(concept_name)
AND   concept_id = 19018544;

-- possible mistakes
-- 19066894	9778	silicones
select *  FROM ing WHERE concept_id = 19066894; -- 1
-- Alprenolol instead of propranolol
select * FROM ing WHERE t_ing ~* 'propranolol' AND  concept_id = 19081284; -- 0
select * FROM ing WHERE t_ing IN ('Balanced B','Flintstones Complete','Mega B','Multi B', 'Stress Formula'); -- 0
select * from ing where concept_name ~* '\ycysteine' and t_ing ~'\yL\y';  

--valearate
DELETE
FROM ing
WHERE concept_id IN (19103572,43014259,46275493);

-- clean up the worktable (ing) - delete incorrect ingredient identification
DELETE
FROM ing
WHERE t_nm IN (SELECT t_nm FROM ing GROUP BY t_nm HAVING COUNT(1) >= 2)
AND   concept_id IN (992409,1314928,1330144,1351935,1352213,1369939,1387104,1401437,1436169,952045,1780601,19003472,19008867,
19018663,19054245,19056694,19061406,19106100,529411,35606695,42898711,45775353,919839,19017390,19050104,19091804,42903865); -- 47

DELETE
FROM ing
WHERE t_nm IN (SELECT t_nm
                      FROM ing
                      GROUP BY t_nm
                                          HAVING COUNT(1) >= 2)
AND   concept_id IN (19009405,911064)
AND   t_ing !~ '\/|-|\&|VITAMIN D|ANUSOL'; -- 5 

--delete duplicates with incorrect mapping
WITH t1 AS
(SELECT * FROM ing WHERE t_nm IN (
    SELECT t_nm FROM ing GROUP BY t_nm
    HAVING COUNT(1) > 1) AND TRIM(UPPER(REGEXP_REPLACE(t_ing,'\s+','','g'))) = TRIM(UPPER(REGEXP_REPLACE(concept_name,'\s+','','g')))
) 
DELETE FROM ing
WHERE t_nm IN (
SELECT t_nm FROM ing GROUP BY t_nm HAVING COUNT(1) > 1)
AND   t_nm IN (SELECT t_nm FROM t1)
AND   concept_id NOT IN (SELECT concept_id FROM t1)
AND   t_ing !~* '^iron$' 
AND   concept_id <> 19063297; -- 18

INSERT INTO ing
SELECT t_nm,
       t_ing,
       c.concept_id,
       c.concept_name,
       'string_match'
FROM ing a
  JOIN devv5.concept c
    ON UPPER (c.concept_name) = TRIM(UPPER (SUBSTRING (t_ing,'^\w+')))
   AND c.standard_concept = 'S'
   AND c.concept_class_id = 'Ingredient'
   AND (t_ing,c.concept_id) NOT IN (SELECT t_ing,concept_id FROM ing)
WHERE a.t_ing ~ '/'; -- 340

INSERT INTO ing
SELECT t_nm,
       t_ing,       
       c.concept_id,
       c.concept_name,
       'string_match'
FROM ing a
  JOIN devv5.concept c
    ON UPPER (c.concept_name) = TRIM(UPPER (SUBSTRING (t_ing,'\w+\s*$')))
   AND c.standard_concept = 'S'
   AND c.concept_class_id = 'Ingredient'
AND (t_ing,c.concept_id) NOT IN (SELECT t_ing,concept_id FROM ing)
WHERE a.t_ing ~ '/';

INSERT INTO ing
SELECT t_nm,
       t_ing,
       c.concept_id,
       c.concept_name,
       'string_match'
FROM ing a
  JOIN devv5.concept c
    ON UPPER (c.concept_name) = TRIM(UPPER (SUBSTRING (t_ing,'\w+$')))||'S'
   AND c.standard_concept = 'S'
   AND c.concept_class_id = 'Ingredient'
--   AND (ing,c.concept_id) NOT IN (SELECT ing,concept_id FROM ing)
WHERE a.t_ing ~ '/';

DELETE
FROM ing
WHERE concept_id IN (19018544,19124906,19103572,42898412,42898412,19136048,40799093,19029306,19052059,19029824,19059097,19061821,19011034,19071128,
1360067,1387426,19010955,19011097,19066774,19069019,19126511,19126516,36444867,40799146,42903718,43532032,43532336,43532444,44507733,43532032,42903718,
19050104,1195334,19011082,42900561,43013471,711452,19126510,19011035);

--delete duplicates
DELETE
FROM ing
WHERE ctid NOT IN (SELECT MIN(ctid) FROM ing GROUP BY t_nm,  concept_id); 

-- remove wrong maps
DELETE
FROM ing
WHERE t_ing = 'PARACETAMOL'
AND   concept_id = 1112807;

DELETE
FROM ing
WHERE t_ing ~* 'Acetylsalicylate'
AND   concept_name ~* 'aspirin'; 

DELETE
FROM ing
WHERE t_ing IN (SELECT t_ing FROM ing WHERE concept_name ~* 'ethinyl estradiol')
AND   t_ing IN (SELECT t_ing FROM ing WHERE t_ing ~* 'medicine')
AND   concept_id = '1549786' ;

DELETE
FROM ing
WHERE t_ing ~* '^paracetamol$'
AND   concept_name !~* 'acetaminoph';

-- add additional mappings (IF ANY) from the tables of ing_bn_automap and ing to map_drug_lookup
