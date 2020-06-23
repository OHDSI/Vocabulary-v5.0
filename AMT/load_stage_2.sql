--1. ingredient
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, mapping_type)
SELECT DISTINCT dcs.concept_code, 'AMT', concept_id_2, precedence, mapping_type
FROM ingredient_mapped im
JOIN drug_concept_stage dcs
    ON dcs.concept_name = coalesce(im.new_name, im.name)
WHERE dcs.concept_class_id = 'Ingredient'
  AND NOT exists(
        SELECT 1
        FROM relationship_to_concept rtc
        WHERE rtc.concept_code_1 = dcs.concept_code
    )
  AND im.concept_id_2 NOT IN (0, 17)
  AND im.concept_id_2 IS NOT NULL
;


--2. brand name rtc
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, mapping_type)
SELECT DISTINCT dcs.concept_code, 'AMT', concept_id_2, precedence, mapping_type
FROM brand_name_mapped bnm
JOIN drug_concept_stage dcs
    ON dcs.concept_name = coalesce(bnm.new_name, bnm.name)
WHERE dcs.concept_class_id = 'Brand Name'
  AND NOT exists(
        SELECT 1
        FROM relationship_to_concept rtc
        WHERE rtc.concept_code_1 = dcs.concept_code
    )
  AND bnm.concept_id_2 NOT IN (0, 17)
  AND bnm.concept_id_2 IS NOT NULL
;


--3.  supplier rtc
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, mapping_type)
SELECT DISTINCT dcs.concept_code, 'AMT', concept_id_2, precedence, mapping_type
FROM supplier_mapped sm
JOIN drug_concept_stage dcs
    ON dcs.concept_name = coalesce(sm.new_name, sm.name)
WHERE dcs.concept_class_id = 'Supplier'
  AND NOT exists(
        SELECT 1
        FROM relationship_to_concept rtc
        WHERE rtc.concept_code_1 = dcs.concept_code
    )
  AND sm.concept_id_2 NOT IN (0, 17)
  AND sm.concept_id_2 IS NOT NULL
;


--4. dose form rtc
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, mapping_type)
SELECT DISTINCT dcs.concept_code, /*dcs.concept_name,*/ 'AMT', concept_id_2, precedence, mapping_type
FROM dose_form_mapped dfm
LEFT JOIN drug_concept_stage dcs
    ON dcs.concept_name = coalesce(dfm.new_name, dfm.name)
WHERE dcs.concept_class_id = 'Dose Form'
  AND NOT exists(
        SELECT 1
        FROM relationship_to_concept rtc
        WHERE rtc.concept_code_1 = dcs.concept_code
    )
  AND dfm.concept_id_2 NOT IN (0, 17)
  AND dfm.concept_id_2 IS NOT NULL
;


--5. unit rtc
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor,
                                     mapping_type)
SELECT DISTINCT dcs.concept_code, 'AMT', concept_id_2, precedence, conversion_factor, mapping_type
FROM unit_mapped um
JOIN drug_concept_stage dcs
    ON dcs.concept_name = coalesce(um.new_name, um.name)
WHERE dcs.concept_class_id = 'Unit'
  AND NOT exists(
        SELECT 1
        FROM relationship_to_concept rtc
        WHERE rtc.concept_code_1 = dcs.concept_code
    )
  AND um.concept_id_2 NOT IN (0, 17)
  AND um.concept_id_2 IS NOT NULL
;

--delete deprecated concepts (mainly wrong BN)
DELETE
FROM drug_concept_stage
WHERE concept_code IN
      (
      SELECT concept_code_1
      FROM relationship_to_concept
      JOIN concept c
          ON concept_id_2 = c.concept_id
              AND c.invalid_reason = 'D' AND concept_class_id != 'Ingredient' AND c.vocabulary_id = 'RxNorm Extension'
              AND concept_id_2 NOT IN (43252204, 43252218)
      );

DELETE
FROM internal_relationship_stage
WHERE concept_code_2 IN
      (
      SELECT concept_code_1
      FROM relationship_to_concept
      JOIN concept c
          ON concept_id_2 = c.concept_id
              AND c.invalid_reason = 'D' AND concept_class_id != 'Ingredient' AND c.vocabulary_id = 'RxNorm Extension'
              AND concept_id_2 NOT IN (43252204, 43252218)
      );

DELETE
FROM relationship_to_concept
WHERE concept_code_1 IN (
                        SELECT concept_code_1
                        FROM relationship_to_concept
                        JOIN concept c
                            ON concept_id_2 = c.concept_id
                                AND c.invalid_reason = 'D' AND concept_class_id != 'Ingredient' AND
                               c.vocabulary_id = 'RxNorm Extension'
                                AND concept_id_2 NOT IN (43252204, 43252218)
                        );

--remove concepts without relations
DELETE
FROM drug_concept_stage
WHERE concept_code IN (
                      SELECT a.concept_code
                      FROM drug_concept_stage a
                      LEFT JOIN internal_relationship_stage b
                          ON a.concept_code = b.concept_code_2
                      WHERE a.concept_class_id = 'Brand Name'
                        AND b.concept_code_1 IS NULL
                      UNION ALL
                      SELECT a.concept_code
                      FROM drug_concept_stage a
                      LEFT JOIN internal_relationship_stage b
                          ON a.concept_code = b.concept_code_2
                      WHERE a.concept_class_id = 'Dose Form'
                        AND b.concept_code_1 IS NULL
                      );

--updating ingredients that create duplicates after mapping to rxnorm
DROP TABLE IF EXISTS ds_sum_2;
CREATE TEMP TABLE ds_sum_2 AS
WITH a AS (
          SELECT DISTINCT ds.*, rc.concept_id_2
          FROM ds_stage ds
          JOIN ds_stage ds2
              ON ds.drug_concept_code = ds2.drug_concept_code AND
                 ds.ingredient_concept_code != ds2.ingredient_concept_code
          JOIN relationship_to_concept rc
              ON ds.ingredient_concept_code = rc.concept_code_1
          JOIN relationship_to_concept rc2
              ON ds2.ingredient_concept_code = rc2.concept_code_1
          WHERE rc.concept_id_2 = rc2.concept_id_2
          )
SELECT DISTINCT drug_concept_code,
                max(ingredient_concept_code)
                OVER (PARTITION BY drug_concept_code,concept_id_2) AS ingredient_concept_code,
                box_size,
                sum(amount_value) OVER (PARTITION BY drug_concept_code) AS amount_value, amount_unit,
                sum(numerator_value) OVER (PARTITION BY drug_concept_code,concept_id_2) AS numerator_value,
                numerator_unit, denominator_value, denominator_unit
FROM a
UNION
SELECT drug_concept_code,
       ingredient_concept_code,
       box_size,
       NULL AS amount_value, NULL AS amount_unit,
       NULL AS numerator_value, NULL AS numerator_unit,
       NULL AS denominator_value, NULL AS denominator_unit
FROM a
WHERE (drug_concept_code, ingredient_concept_code)
          NOT IN (
                 SELECT drug_concept_code, max(ingredient_concept_code)
                 FROM a
                 GROUP BY drug_concept_code
                 );

DELETE
FROM ds_stage
WHERE (drug_concept_code, ingredient_concept_code) IN
      (
      SELECT drug_concept_code, ingredient_concept_code
      FROM ds_sum_2
      );

INSERT INTO ds_stage (drug_concept_code, ingredient_concept_code, box_size, amount_value, amount_unit, numerator_value,
                      numerator_unit, denominator_value, denominator_unit)
SELECT DISTINCT drug_concept_code, ingredient_concept_code, box_size, amount_value, amount_unit, numerator_value,
                numerator_unit, denominator_value, denominator_unit
FROM ds_sum_2
WHERE coalesce(amount_value, numerator_value) IS NOT NULL;

--delete relationship to ingredients that we removed
DELETE
FROM internal_relationship_stage
WHERE (concept_code_1, concept_code_2) IN (
                                          SELECT drug_concept_code, ingredient_concept_code
                                          FROM ds_sum_2
                                          WHERE coalesce(amount_value, numerator_value) IS NULL
                                          );

-- resolve w/w v/v conflicts for different ingredients in the same drug
UPDATE ds_stage
SET denominator_unit = 'Ml',
    numerator_value  = 0.77
WHERE drug_concept_code IN ('1258241000168101', '1258231000168105')
  AND ingredient_concept_code = '31199011000036100' -- ethanol
  AND numerator_value = 700;

UPDATE ds_stage
SET denominator_unit = 'Ml'
WHERE drug_concept_code IN ('1384271000168102', '1384281000168104', '1384291000168101', '1384301000168100',
                            '1384311000168102', '1384321000168109', '1384331000168107', '1384341000168103',
                            '1384351000168101', '1384361000168104', '1384371000168105', '1384381000168108')
  AND ingredient_concept_code = '1934011000036108' -- chlorhexidine gluconate
  AND denominator_unit = 'G';


--deleting drug forms
DELETE
FROM ds_stage
WHERE drug_concept_code IN
      (
      SELECT drug_concept_code
      FROM ds_stage
      WHERE coalesce(amount_value, numerator_value, -1) = -1
      );


--add water
INSERT INTO ds_stage (drug_concept_code, ingredient_concept_code, numerator_value, numerator_unit, denominator_unit)
SELECT concept_name, '11295', 1000, 'Mg', 'Ml'
FROM drug_concept_stage dcs
JOIN (
     SELECT concept_code_1
     FROM internal_relationship_stage
     JOIN drug_concept_stage
         ON concept_code_2 = concept_code AND concept_class_id = 'Supplier'
     LEFT JOIN ds_stage
         ON drug_concept_code = concept_code_1
     WHERE drug_concept_code IS NULL
     UNION
     SELECT concept_code_1
     FROM internal_relationship_stage
     JOIN drug_concept_stage
         ON concept_code_2 = concept_code AND concept_class_id = 'Supplier'
     WHERE concept_code_1 NOT IN (
                                 SELECT concept_code_1
                                 FROM internal_relationship_stage
                                 JOIN drug_concept_stage
                                     ON concept_code_2 = concept_code AND concept_class_id = 'Dose Form'
                                 )
     ) s
    ON s.concept_code_1 = dcs.concept_code
WHERE dcs.concept_class_id = 'Drug Product'
  AND invalid_reason IS NULL
  AND concept_name LIKE 'water%';

--adding missing relations from ds_stage
INSERT INTO internal_relationship_stage
    (concept_code_1, concept_code_2)
SELECT DISTINCT drug_concept_code, ingredient_concept_code
FROM ds_stage
WHERE (drug_concept_code, ingredient_concept_code) NOT IN
      (
      SELECT concept_code_1, concept_code_2
      FROM internal_relationship_stage
      );

--generate mapping review
DROP TABLE IF EXISTS mapping_review;
CREATE TABLE mapping_review AS
SELECT DISTINCT dcs.concept_class_id AS source_concept_calss_id, coalesce(dcsb.concept_name, dcs.concept_name) AS name,
                mapped.new_name AS new_name, dcs.concept_code as concept_code_1, rtc.concept_id_2, rtc.precedence, rtc.mapping_type,
                rtc.conversion_factor, c.*
FROM drug_concept_stage dcs
LEFT JOIN relationship_to_concept rtc
    ON dcs.concept_code = rtc.concept_code_1
LEFT JOIN concept c
    ON rtc.concept_id_2 = c.concept_id
LEFT JOIN (
          SELECT name, new_name, concept_id_2, precedence, NULL::float AS conversion_factor, mapping_type
          FROM ingredient_mapped
          UNION
          SELECT name, new_name, concept_id_2, precedence, NULL::float AS conversion_factor, mapping_type
          FROM brand_name_mapped
          UNION
          SELECT name, new_name, concept_id_2, precedence, NULL::float AS conversion_factor, mapping_type
          FROM supplier_mapped
          UNION
          SELECT name, new_name, concept_id_2, precedence, NULL::float AS conversion_factor, mapping_type
          FROM dose_form_mapped
          UNION
          SELECT name, new_name, concept_id_2, precedence, conversion_factor, mapping_type
          FROM unit_mapped
          ) AS mapped
    ON lower(coalesce(mapped.new_name, mapped.name)) = lower(dcs.concept_name)
LEFT JOIN  drug_concept_stage_backup dcsb
    ON dcs.concept_code = dcsb.concept_code
WHERE dcs.concept_class_id IN ('Ingredient', 'Brand Name', 'Supplier', 'Dose Form', 'Unit')
;

--== remove to be created concepts from mapped tables ==--
DO
$_$
    BEGIN
        --formatter:off
        DELETE FROM ingredient_mapped WHERE concept_id_2 IS NULL;
        DELETE FROM brand_name_mapped WHERE concept_id_2 IS NULL;
        DELETE FROM dose_form_mapped WHERE concept_id_2 IS NULL;
        DELETE FROM supplier_mapped WHERE concept_id_2 IS NULL;
        DELETE FROM unit_mapped WHERE concept_id_2 IS NULL;
        --formatter:on
    END;
$_$;

--create mapping_review, non_drug, pc_stage, relationship_to_concept backup
DO
$body$
    DECLARE
        update text;
    BEGIN
        SELECT latest_update
        INTO update
        FROM vocabulary
        WHERE vocabulary_id = 'AMT'
        LIMIT 1;
        EXECUTE format('drop table if exists %I; create table if not exists %I as select distinct * from mapping_review',
                       'mapping_review_backup_' || update, 'mapping_review_backup_' || update );
        EXECUTE format('drop table if exists %I; create table if not exists %I as select distinct * from non_drug',
                       'non_drug_backup_' || update, 'non_drug_backup_' || update );
        EXECUTE format('drop table if exists %I; create table if not exists %I as select distinct * from pc_stage',
                       'pc_stage_backup_' || update, 'pc_stage_backup_' || update);
        EXECUTE format('drop table if exists %I; create table if not exists %I as select * from relationship_to_concept',
                       'relationship_to_concept_backup_' || update, 'relationship_to_concept_backup_' || update);
    END
$body$;

-- Clean up tables
DO
$_$
    BEGIN
        drop table if exists non_drug;
        drop table if exists supplier;
        drop table if exists supplier_2;
        drop table if exists unit;
        drop table if exists form;
        drop table if exists dcs_bn;
        drop table if exists drug_concept_stage_backup;
        drop table if exists ds_0;
        drop table if exists ds_0_1_1;
        drop table if exists ds_0_1_3;
        drop table if exists ds_0_1_4;
        drop table if exists ds_0_2_0;
        drop table if exists ds_0_2;
        drop table if exists ds_0_3;
        drop table if exists non_S_ing_to_S;
        drop table if exists non_S_form_to_S;
        drop table if exists non_S_bn_to_S;
        drop table if exists drug_to_supplier;
        drop table if exists supp_upd;
        drop table if exists irs_upd;
        drop table if exists irs_upd_2;
        drop table if exists ds_sum;
        drop table if exists pc_0_initial;
        drop table if exists pc_1_ampersand_sep;
        drop table if exists pc_1_comma_sep;
        drop table if exists pc_2_ampersand_sep_amount;
        drop table if exists pc_2_comma_sep_amount;
        drop table if exists pc_3_box_size;
        drop table if exists undetected_packs;
    END;
$_$;


-- need for BuildRxE to run
ALTER TABLE relationship_to_concept
DROP COLUMN mapping_type;
