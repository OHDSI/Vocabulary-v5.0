--1. ingredient ---
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


--2. brand name rtc ---
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


--3.  supplier rtc ---
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


--4. dose form rtc ---
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


--5. unit rtc ---
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

INSERT INTO internal_relationship_stage
    (concept_code_1, concept_code_2)
SELECT DISTINCT drug_concept_code, ingredient_concept_code
FROM ds_stage
WHERE (drug_concept_code, ingredient_concept_code) NOT IN
      (
      SELECT concept_code_1, concept_code_2
      FROM internal_relationship_stage
      );

--== create mapping review table backup ==--
-- generate mapping review
DROP TABLE IF EXISTS mapping_review
CREATE TABLE mapping_review AS
SELECT DISTINCT dcs.concept_class_id AS source_concept_calss_id, dcs.concept_name AS name,
                NULL AS new_name, rtc.concept_id_2, rtc.precedence, rtc.mapping_type,
                rtc.conversion_factor, c.*
FROM relationship_to_concept rtc
JOIN drug_concept_stage dcs
    ON dcs.concept_code = rtc.concept_code_1
JOIN concept c
    ON rtc.concept_id_2 = c.concept_id
;

--create non_drug table backup
DO
$body$
    DECLARE
        version text;
    BEGIN
        SELECT vocabulary_version
        INTO version
        FROM devv5.vocabulary
        WHERE vocabulary_id = 'AMT'
        LIMIT 1;
        EXECUTE format('create table if not exists %I as select distinct * from non_drug',
                       'mapping_review_backup_' || version);
    END
$body$;

-- need for BuildRxE to run
/*ALTER TABLE relationship_to_concept
DROP COLUMN mapping_type;*/