/**************************
***** POST-PROCESSING *****
**************************/
DROP TABLE IF EXISTS map_drug_lookup;
CREATE TABLE map_drug_lookup 
AS
(SELECT DISTINCT b.pfc AS source_code,
       TRIM(INITCAP(SUBSTR(CONCAT (vl_wg_unit|| ' ' ||vl_wg_meas,' ',CASE molecule WHEN NULL THEN NULL ELSE CONCAT (molecule,' ') END,CASE strg_unit|| ' ' ||strg_meas WHEN NULL THEN NULL ELSE CONCAT (strg_unit|| ' ' ||strg_meas,' ') END,CASE descr_forme WHEN NULL THEN NULL ELSE descr_forme END,CASE descr_prod WHEN NULL THEN NULL ELSE CONCAT (' [',descr_prod,']') END,' Box of ',pck_size),1,255))) AS source_name,
       vl_wg_unit,
       vl_wg_meas,
       strg_unit,
       strg_meas,
       descr_forme,
       descr_prod,
       c.concept_id,
       c.concept_code,
       c.concept_name,
       c.concept_class_id,
       b.cnt
FROM map_drug a
  JOIN da_france_source b ON b.pfc = a.from_code
  JOIN concept c ON c.concept_id = a.to_id);

DROP TABLE IF EXISTS w_table;
CREATE TABLE w_table 
AS
(SELECT DISTINCT pfc AS source_code,
       TRIM(INITCAP(SUBSTR(CONCAT (vl_wg_unit|| ' ' ||vl_wg_meas,' ',
       CASE molecule WHEN NULL THEN NULL ELSE CONCAT (molecule,' ') END,
       CASE strg_unit|| ' ' ||strg_meas WHEN NULL THEN NULL ELSE CONCAT (strg_unit|| ' ' ||strg_meas,' ') END,
       CASE descr_forme WHEN NULL THEN NULL ELSE descr_forme END,
       CASE descr_prod WHEN NULL THEN NULL ELSE CONCAT (' [',descr_prod,']') END,' Box of ',pck_size),1,255))) AS t_nm,
       molecule AS t_ing,
       strg_unit|| '|' ||strg_meas|| '|' ||vl_wg_unit|| '|' ||vl_wg_meas AS dose,
       descr_forme AS df,
       descr_prod AS bn,
       cnt
FROM da_france_source);
  
-- add additional mappings IF ANY
INSERT INTO map_drug_lookup
SELECT DISTINCT a.source_code,
       a.source_name,
       d.concept_id,
       d.concept_code,
       d.concept_name,
       d.concept_class_id,
       a.cnt
FROM map_drug_lookup a
  JOIN w_table b ON b.t_nm = a.source_name
  JOIN ing_bn_automap c -- table with additional mappings (see 'manual work' folder)
    ON c.t_ing = b.t_ing
   AND c.concept_id <> a.concept_Id
  JOIN concept d ON d.concept_id = c.concept_id
WHERE a.concept_class_id = 'Ingredient'
AND   a.source_code IN (SELECT source_code
                        FROM map_drug_lookup
                        GROUP BY source_code
                        HAVING COUNT(1) = 1)
AND   c.concept_id NOT IN (44785897,42903687,42900317,42899194,40161546,35884376,19136187,19136184,
19136048,19066891,19052489,19050346,19029306,19011035,19010309,1780601,1309204,975125,952045,950056,922570,711452)
; -- 245 

INSERT INTO map_drug_lookup
SELECT DISTINCT a.source_code,
       a.source_name,
       d.concept_id,
       d.concept_code,
       d.concept_name,
       d.concept_class_id,
       a.cnt
FROM map_drug_lookup a
  JOIN w_table b ON b.t_nm = a.source_name
  JOIN ing c -- table with additional mappings (see 'manual work' folder)
    ON c.t_nm = b.t_nm
   AND c.concept_id <> a.concept_Id
  JOIN concept d ON d.concept_id = c.concept_id
WHERE a.concept_class_id = 'Ingredient'
AND   a.source_code IN (SELECT source_code
                        FROM map_drug_lookup
                        GROUP BY source_code
                        HAVING COUNT(1) = 1)
AND   c.concept_id NOT IN (1309204,957393,1112807,43012163,19135825,1301125,19050346,19067085,42899194,984801,993631,19066891,44785897,19009540,19010309);

INSERT INTO map_drug_lookup
SELECT DISTINCT a.pfc AS source_code,
       TRIM(INITCAP(SUBSTR(CONCAT (vl_wg_unit|| ' ' ||vl_wg_meas,' ',
       CASE a.molecule WHEN NULL THEN NULL ELSE CONCAT (a.molecule,' ') END,
       CASE strg_unit|| ' ' ||strg_meas WHEN NULL THEN NULL ELSE CONCAT (strg_unit|| ' ' ||strg_meas,' ') END,
       CASE a.descr_forme WHEN NULL THEN NULL ELSE a.descr_forme END,
       CASE a.descr_prod WHEN NULL THEN NULL ELSE CONCAT (' [',a.descr_prod,']') END,' Box of ',pck_size),1,255))) AS source_name,
       c.concept_id,
       c.concept_code,
       c.concept_name,
       c.concept_class_id,
       b.cnt
FROM da_franca_ins_vacc a -- table with manual mapping
  JOIN da_france_source b ON b.pfc = a.pfc
  JOIN concept c
    ON c.concept_id = a.concept_id
   AND c.standard_concept = 'S';
   
   DROP TABLE IF EXISTS map_drug_patch;
CREATE TABLE map_drug_patch 
AS
(SELECT DISTINCT a.source_code,
       a.source_name,
       c.concept_id,
       c.concept_code,
       c.concept_name,
       c.concept_class_id,
       a.cnt
FROM map_drug_lookup a
  JOIN concept_relationship cr ON cr.concept_id_1 = a.concept_id
  JOIN concept_relationship cr2 ON cr2.concept_id_1 = cr.concept_id_2
  JOIN concept c
    ON c.concept_id = cr2.concept_id_2
   AND c.concept_class_id = 'Clinical Drug Form'
   AND a.source_name ~* 'inj'
   AND c.concept_name ~ 'Injectable Solution'
   AND c.standard_concept = 'S'
WHERE a.source_code IN (SELECT source_code
                        FROM map_drug_lookup
                        GROUP BY source_code
                        HAVING COUNT(1) = 1)
AND   a.concept_class_id = 'Ingredient'
AND   cr.invalid_reason IS NULL
AND   cr2.invalid_reason IS NULL
AND   c.concept_name !~ '/'
AND   cr2.relationship_id = 'Maps to');

INSERT INTO map_drug_patch
SELECT DISTINCT a.source_code,
       a.source_name,
       c.concept_id,
       c.concept_code,
       c.concept_name,
       c.concept_class_id,
       a.cnt
FROM map_drug_lookup a
  JOIN concept_relationship cr ON cr.concept_id_1 = a.concept_id
  JOIN concept_relationship cr2 ON cr2.concept_id_1 = cr.concept_id_2
  JOIN concept c
    ON c.concept_id = cr2.concept_id_2
   AND c.concept_class_id = 'Clinical Drug Form'
  JOIN da_france_source x
    ON x.pfc = a.source_code
   AND c.concept_name ~ 'Oral Solution'
   AND c.concept_name !~* 'granul|powder'
   AND c.standard_concept = 'S'
WHERE a.source_code IN (SELECT source_code
                        FROM map_drug_lookup
                        GROUP BY source_code
                        HAVING COUNT(1) = 1)
AND   a.concept_class_id = 'Ingredient'
AND   cr.invalid_reason IS NULL
AND   cr2.invalid_reason IS NULL
AND   c.concept_name !~ '/'
AND   cr2.relationship_id = 'Maps to'
AND   x.descr_forme IN ('A.BUV','SOL BUV');

INSERT INTO map_drug_patch
SELECT DISTINCT a.source_code,
       a.source_name,
       c.concept_id,
       c.concept_code,
       c.concept_name,
       c.concept_class_id,
       a.cnt
FROM map_drug_lookup a
  JOIN concept_relationship cr ON cr.concept_id_1 = a.concept_id
  JOIN concept_relationship cr2 ON cr2.concept_id_1 = cr.concept_id_2
  JOIN concept c
    ON c.concept_id = cr2.concept_id_2
   AND c.concept_class_id = 'Clinical Drug Form'
  JOIN da_france_source x
    ON x.pfc = a.source_code
   AND c.concept_name ~ 'Oral Tablet'
   AND c.concept_name !~* 'release|Disintegrating|Effervescent'
   AND c.standard_concept = 'S'
WHERE a.source_code IN (SELECT source_code
                        FROM map_drug_lookup
                        GROUP BY source_code
                        HAVING COUNT(1) = 1)
AND   a.concept_class_id = 'Ingredient'
AND   cr.invalid_reason IS NULL
AND   cr2.invalid_reason IS NULL
AND   c.concept_name !~ '/'
AND   cr2.relationship_id = 'Maps to'
AND   x.descr_forme ~* '\yCPR'
AND   x.descr_forme !~* '\yVAGIN';

INSERT INTO map_drug_patch
SELECT DISTINCT a.source_code,
       a.source_name,
       c.concept_id,
       c.concept_code,
       c.concept_name,
       c.concept_class_id,
       a.cnt
FROM map_drug_lookup a
  JOIN concept_relationship cr ON cr.concept_id_1 = a.concept_id
  JOIN concept_relationship cr2 ON cr2.concept_id_1 = cr.concept_id_2
  JOIN concept c
    ON c.concept_id = cr2.concept_id_2
   AND c.concept_class_id = 'Clinical Drug Form'
  JOIN da_france_source x
    ON x.pfc = a.source_code
   AND c.concept_name ~ 'Ophthalmic Solution'
   AND c.standard_concept = 'S'
WHERE a.source_code IN (SELECT source_code
                        FROM map_drug_lookup
                        GROUP BY source_code
                        HAVING COUNT(1) = 1)
AND   a.concept_class_id = 'Ingredient'
AND   cr.invalid_reason IS NULL
AND   cr2.invalid_reason IS NULL
AND   c.concept_name !~ '/'
AND   cr2.relationship_id = 'Maps to'
AND   x.descr_forme IN ('COLLYRE');
 
INSERT INTO map_drug_patch
SELECT DISTINCT a.source_code,
       a.source_name,
       c.concept_id,
       c.concept_code,
       c.concept_name,
       c.concept_class_id,
       a.cnt
FROM map_drug_lookup a
  JOIN concept_relationship cr ON cr.concept_id_1 = a.concept_id
  JOIN concept_relationship cr2 ON cr2.concept_id_1 = cr.concept_id_2
  JOIN concept c
    ON c.concept_id = cr2.concept_id_2
   AND c.concept_class_id = 'Clinical Drug Form'
  JOIN da_france_source x
    ON x.pfc = a.source_code
   AND c.concept_name ~ 'Prefilled Syringe'
   AND c.standard_concept = 'S'
WHERE a.source_code IN (SELECT source_code
                        FROM map_drug_lookup
                        GROUP BY source_code
                        HAVING COUNT(1) = 1)
AND   a.concept_class_id = 'Ingredient'
AND   cr.invalid_reason IS NULL
AND   cr2.invalid_reason IS NULL
AND   c.concept_name !~ '/'
AND   cr2.relationship_id = 'Maps to'
AND   x.descr_forme IN ('SER PREREMPL');

INSERT INTO map_drug_patch
SELECT DISTINCT a.source_code,
       a.source_name,
       c.concept_id,
       c.concept_code,
       c.concept_name,
       c.concept_class_id,
       a.cnt
FROM map_drug_lookup a
  JOIN concept_relationship cr ON cr.concept_id_1 = a.concept_id
  JOIN concept_relationship cr2 ON cr2.concept_id_1 = cr.concept_id_2
  JOIN concept c
    ON c.concept_id = cr2.concept_id_2
   AND c.concept_class_id = 'Clinical Drug Form'
  JOIN da_france_source x
    ON x.pfc = a.source_code
   AND c.concept_name ~ 'Oral Capsule'
   AND c.concept_name !~* 'release|Disintegrating|Effervescent'
   AND c.standard_concept = 'S'
WHERE a.source_code IN (SELECT source_code
                        FROM map_drug_lookup
                        GROUP BY source_code
                        HAVING COUNT(1) = 1)
AND   a.concept_class_id = 'Ingredient'
AND   cr.invalid_reason IS NULL
AND   cr2.invalid_reason IS NULL
AND   c.concept_name !~ '/'
AND   cr2.relationship_id = 'Maps to'
AND   x.descr_forme IN ('LP GELULES','CAPS','GELULE');
 
INSERT INTO map_drug_patch
SELECT DISTINCT a.source_code,
       a.source_name,
       c.concept_id,
       c.concept_code,
       c.concept_name,
       c.concept_class_id,
       a.cnt
FROM map_drug_lookup a
  JOIN concept_relationship cr ON cr.concept_id_1 = a.concept_id
  JOIN concept_relationship cr2 ON cr2.concept_id_1 = cr.concept_id_2
  JOIN concept c
    ON c.concept_id = cr2.concept_id_2
   AND c.concept_class_id = 'Clinical Drug Form'
  JOIN da_france_source x
    ON x.pfc = a.source_code
   AND c.concept_name ~ 'Oral Powder'
   AND c.standard_concept = 'S'
WHERE a.source_code IN (SELECT source_code
                        FROM map_drug_lookup
                        GROUP BY source_code
                        HAVING COUNT(1) = 1)
AND   a.concept_class_id = 'Ingredient'
AND   cr.invalid_reason IS NULL
AND   cr2.invalid_reason IS NULL
AND   c.concept_name !~ '/'
AND   cr2.relationship_id = 'Maps to'
AND   x.descr_forme IN ('SACH PDR');
 
INSERT INTO map_drug_patch
SELECT DISTINCT a.source_code,
       a.source_name,
       c.concept_id,
       c.concept_code,
       c.concept_name,
       c.concept_class_id,
       a.cnt
FROM map_drug_lookup a
  JOIN concept_relationship cr ON cr.concept_id_1 = a.concept_id
  JOIN concept_relationship cr2 ON cr2.concept_id_1 = cr.concept_id_2
  JOIN concept c
    ON c.concept_id = cr2.concept_id_2
   AND c.concept_class_id = 'Clinical Drug Form'
  JOIN da_france_source x
    ON x.pfc = a.source_code
   AND c.concept_name ~ 'Topical Cream'
   AND c.standard_concept = 'S'
WHERE a.source_code IN (SELECT source_code
                        FROM map_drug_lookup
                        GROUP BY source_code
                        HAVING COUNT(1) = 1)
AND   a.concept_class_id = 'Ingredient'
AND   cr.invalid_reason IS NULL
AND   cr2.invalid_reason IS NULL
AND   c.concept_name !~ '/'
AND   cr2.relationship_id = 'Maps to'
AND   x.descr_forme IN ('CREME');

INSERT INTO map_drug_patch
SELECT DISTINCT a.source_code,
       a.source_name,
       c.concept_id,
       c.concept_code,
       c.concept_name,
       c.concept_class_id,
       a.cnt
FROM map_drug_lookup a
  JOIN concept_relationship cr ON cr.concept_id_1 = a.concept_id
  JOIN concept_relationship cr2 ON cr2.concept_id_1 = cr.concept_id_2
  JOIN concept c
    ON c.concept_id = cr2.concept_id_2
   AND c.concept_class_id = 'Clinical Drug Form'
  JOIN da_france_source x
    ON x.pfc = a.source_code
   AND c.concept_name ~ 'Injectable Solution'
   AND c.standard_concept = 'S'
WHERE a.source_code IN (SELECT source_code
                        FROM map_drug_lookup
                        GROUP BY source_code
                        HAVING COUNT(1) = 1)
AND   a.concept_class_id = 'Ingredient'
AND   cr.invalid_reason IS NULL
AND   cr2.invalid_reason IS NULL
AND   c.concept_name !~ '/'
AND   cr2.relationship_id = 'Maps to'
AND   x.descr_forme IN ('AMP.  INJ.','AMP INJ','AMP IM IV')
AND   a.source_code NOT IN (SELECT source_code FROM map_drug_patch);
 
WITH t1 AS
(
  SELECT DISTINCT source_code,
         source_name,
         FIRST_VALUE(concept_id) OVER (PARTITION BY source_code) AS concept_id,
         FIRST_VALUE(concept_code) OVER (PARTITION BY source_code) AS concept_code,
         FIRST_VALUE(concept_name) OVER (PARTITION BY source_code) AS concept_name,
         FIRST_VALUE(concept_class_id) OVER (PARTITION BY source_code) AS concept_class_id,
         cnt
  FROM map_drug_patch
  WHERE source_code IN (SELECT source_code
                        FROM map_drug_patch
                        GROUP BY source_code
                        HAVING COUNT(1) > 1)
) DELETE
FROM map_drug_patch
WHERE source_code IN (SELECT source_code FROM t1)
AND   source_code||concept_id NOT IN (SELECT source_code||concept_id FROM t1);
  
DELETE
FROM map_drug_lookup
WHERE source_code IN (SELECT source_code FROM map_drug_patch)

INSERT INTO map_drug_lookup
SELECT *
FROM map_drug_patch;
