--insert relationship_to_concept_manual  into r_t_c which contains mappings of relationship_to_concept_to_map table created in a first part
--insert all manual work into r_t_c, do it 1 time, if you are using this script more than 1 time
INSERT INTO relationship_to_concept
(concept_code_1,
 vocabulary_id_1,
 concept_id_2,
 precedence,
 conversion_factor)
SELECT dcs.concept_code, dcs.vocabulary_id, mt.target_concept_id, mt.precedence, mt.conversion_factor
FROM drug_concept_stage dcs
         JOIN relationship_to_concept_manual mt ON upper(mt.source_attr_name) = upper(dcs.concept_name)
WHERE target_concept_id IS NOT NULL
  AND (dcs.concept_code, target_concept_id) NOT IN (SELECT concept_code_1, concept_id_2 FROM relationship_to_concept);

--delete attributes they aren't mapped to RxNorm% and which we don't want to create RxNorm Extension from
DELETE
--SELECT *
FROM drug_concept_stage
WHERE concept_code IN (SELECT concept_code
                       FROM drug_concept_stage dcs
                                JOIN relationship_to_concept_manual rtc
                                     ON upper(rtc.source_attr_name) = upper(dcs.concept_name)
                       WHERE rtc.indicator_rxe IS NULL
                         AND rtc.target_concept_id IS NULL);


--fill internal relationship table which include relation between source drugs and their attributes
TRUNCATE TABLE internal_relationship_stage;

INSERT INTO internal_relationship_stage
SELECT fcc,
       concept_code
FROM grr_form_2
UNION
--drug to bn
SELECT fcc,
       concept_code
FROM grr_bn_2
         JOIN drug_concept_stage ON UPPER(bn) = UPPER(concept_name)
WHERE concept_class_id = 'Brand Name'
UNION
--drug to supp
SELECT fcc,
       concept_code
FROM grr_manuf
         JOIN drug_concept_stage ON UPPER(PRI_ORG_LNG_NM) = UPPER(concept_name)
WHERE concept_class_id = 'Supplier'
UNION
--drug to ingr
SELECT fcc,
       concept_code
FROM grr_ing_2
         JOIN drug_concept_stage b
              ON UPPER(ingredient) = UPPER(concept_name)
                  AND concept_class_id = 'Ingredient';

--extract dosage from source_data
DROP TABLE IF EXISTS ds_0_sd_2;

CREATE TABLE ds_0_sd_2
AS
SELECT DISTINCT a.fcc,
                substance,
                CASE
                    WHEN STRENGTH = '0.0' THEN NULL
                    ELSE STRENGTH
                    END                                                  AS STRENGTH,
                CASE
                    WHEN STRENGTH_UNIT = 'Y/H' THEN 'MCG'
                    WHEN STRENGTH_UNIT = 'K.' THEN 'K'
                    ELSE STRENGTH_UNIT
                    END                                                  AS STRENGTH_UNIT,
                CASE
                    WHEN VOLUME = '0.0' THEN NULL
                    ELSE VOLUME
                    END                                                  AS VOLUME,
                CASE
                    WHEN STRENGTH_UNIT = 'Y/H' THEN 'HOUR'
                    WHEN VOLUME_UNIT = 'K.' THEN 'K'
                    WHEN VOLUME_UNIT IS NULL AND VOLUME IS NOT NULL AND therapy_name ~ '\/(ML|MG|G)'
                        THEN SUBSTRING(therapy_name, '\/(ML|MG|G)')
                    WHEN VOLUME_UNIT IS NULL AND VOLUME IS NOT NULL AND therapy_name !~ '\/(ML|MG|G)'
                        THEN SUBSTRING(therapy_name, '\.?\d+(ML)')
                    WHEN VOLUME_UNIT IS NULL AND VOLUME IS NOT NULL AND therapy_name !~ '\/(ML|MG|G)' AND
                         therapy_name ~ '\.?\d+G$' THEN SUBSTRING(therapy_name, '\.?\d+(G)$')
                    WHEN VOLUME_UNIT IS NULL AND VOLUME IS NOT NULL AND therapy_name !~ '\/(ML|MG|G)' AND
                         therapy_name ~ '\.?\d+G\s\(' THEN SUBSTRING(therapy_name, '\d+(G)\s\(')
                    ELSE VOLUME_UNIT
                    END                                                  AS VOLUME_UNIT,
                b.concept_code,
                b.concept_name,
                SUBSTRING(CAST(PACKSIZE AS VARCHAR), '(\d+)\.\d+')::INT4 AS box_size,
                PRODUCT_FORM_NAME,
                therapy_name
FROM source_data_1 a
         LEFT JOIN grr_form_2 b ON a.fcc = b.fcc
WHERE STRENGTH != '0'
  AND substance NOT LIKE '%+%';

UPDATE ds_0_sd_2
SET volume_unit = 'ML'
WHERE volume_unit = 'G'
  AND (therapy_name ~ 'ML\s\(' OR therapy_name ~ 'ML$');

UPDATE ds_0_sd_2
SET volume_unit = NULL
WHERE volume_unit = '';

UPDATE ds_0_sd_2
SET STRENGTH_UNIT = NULL
WHERE STRENGTH_UNIT = '';

--convert percent to normal units
DROP TABLE IF EXISTS ds_0_sd_1;

CREATE TABLE ds_0_sd_1
AS
SELECT fcc,
       therapy_name,
       concept_name,
       box_size,
       substance,
       strength              AS amount,
       strength_unit         AS amount_unit,
       CASE
           WHEN strength_unit = '%' THEN CAST(strength AS FLOAT) * 10
           ELSE CAST(strength AS FLOAT)
           END               AS numerator,
       strength_unit         AS numerator_unit,
       CAST(volume AS FLOAT) AS denominator,
       volume_unit           AS denominator_unit
FROM ds_0_sd_2;

UPDATE ds_0_sd_1
SET amount_unit = NULL
WHERE amount IS NULL;

UPDATE ds_0_sd_1
SET denominator_unit = 'G',
    numerator=numerator / 1000
WHERE numerator_unit = '%'
  AND denominator_unit IS NULL
  AND therapy_name ~ '\d+(G)';

UPDATE ds_0_sd_1
SET denominator_unit = 'ML'
WHERE numerator_unit = '%'
  AND denominator_unit IS NULL;

UPDATE ds_0_sd_1
SET numerator_unit = 'MG'
WHERE numerator_unit = '%';

UPDATE ds_0_sd_1
SET numerator      = NULL,
    numerator_unit = NULL
WHERE amount IS NOT NULL
  AND amount_unit IS NOT NULL
  AND denominator IS NULL
  AND denominator_unit IS NULL;

UPDATE ds_0_sd_1
SET amount      = NULL,
    amount_unit = NULL
WHERE amount IS NOT NULL
  AND amount_unit IS NOT NULL
  AND numerator IS NOT NULL
  AND numerator_unit IS NOT NULL
  AND denominator_unit IS NOT NULL;

--extract dosage from therapy_name
DROP TABLE IF EXISTS ds_0_sd;

CREATE TABLE ds_0_sd
AS
SELECT fcc,
       therapy_name,
       concept_name,
       box_size,
       amount,
       amount_unit,
       substance,
       CASE
           WHEN therapy_name ~ '\d+(IU|MG|MCG|D|Y|C)(\s)?\/\d+ML' AND denominator IS NOT NULL
               THEN (numerator / 5) * denominator
           WHEN therapy_name ~ '\d+(IU|MG|MCG|D|Y|C)\s?\/(ML|G)' AND denominator IS NOT NULL
               THEN numerator * denominator
           WHEN therapy_name ~ '\%' AND therapy_name ~ '\d+(G)' AND denominator IS NOT NULL
               THEN numerator * denominator * 1000
           WHEN therapy_name ~ '\%' AND denominator IS NOT NULL THEN numerator * denominator
           ELSE numerator
           END numerator,
       numerator_unit,
       denominator,
       denominator_unit
FROM ds_0_sd_1;

--delete drugs with wrong units
DELETE
FROM ds_0_sd
WHERE fcc IN (SELECT fcc
              FROM ds_0_sd
              WHERE amount_unit IN ('--', 'LM', 'NR')
                 OR numerator_unit IN ('--', 'LM', 'NR')
                 OR denominator_unit IN ('--', 'LM', 'NR'));

DELETE
FROM ds_0_sd
WHERE amount IS NULL
  AND amount_unit IS NULL
  AND numerator IS NULL
  AND numerator_unit IS NULL
  AND denominator IS NOT NULL
  AND denominator_unit IS NOT NULL;
DELETE
FROM ds_0_sd
WHERE fcc IN ('1150583_11012020', '1056198_10012018', '1165067_03012021', '1108317_06152019', '1113551_04011991',
              '1119460_01012020', '1119461_01012020', '1119465_01012020',
              '959075_05152017', '1166339_05152017', '1117410_01011959', '1140606_02012008');

INSERT INTO ds_0_sd
SELECT a.fcc,
       therapy_name,
       concept_name,
       cast(packsize AS numeric),
       NULL,
       NULL,
       substance,
       cast(strength AS float8) * 10 AS numerator,
       'MG'                          AS numerator_unit,
       cast(volume AS float8)        AS denominator,
       volume_unit                   AS denominator_unit
FROM source_data_1 a
         LEFT JOIN grr_form_2 b ON a.fcc = b.fcc
WHERE a.fcc IN ('1150583_11012020', '1056198_10012018', '1165067_03012021', '1108317_06152019', '1113551_04011991',
                '1119460_01012020', '1119461_01012020', '1119465_01012020',
                '959075_05152017', '1166339_05152017', '1117410_01011959', '1140606_02012008');


UPDATE ds_0_sd
SET numerator      = numerator * 1000,
    numerator_unit = 'IU'
WHERE numerator_unit = 'K'
  AND therapy_name !~* 'ZOSTAVAX';
UPDATE ds_0_sd
SET numerator_unit = 'MCG'
WHERE numerator_unit = 'Y';
UPDATE ds_0_sd
SET amount_unit = 'MCG'
WHERE amount_unit = 'Y';
UPDATE ds_0_sd
SET amount      = amount * 1000,
    amount_unit = 'IU'
WHERE amount_unit = 'K';
--fill ds_stage with extracted dosage from table that was used before
TRUNCATE TABLE ds_stage;

INSERT INTO ds_stage
(DRUG_CONCEPT_CODE,
 INGREDIENT_CONCEPT_CODE,
 BOX_SIZE,
 AMOUNT_VALUE,
 AMOUNT_UNIT,
 NUMERATOR_VALUE,
 NUMERATOR_UNIT,
 DENOMINATOR_VALUE,
 DENOMINATOR_UNIT)
SELECT fcc,
       b.concept_code,
       box_size,
       amount::float8,
       AMOUNT_UNIT,
       NUMERATOR::float8,
       NUMERATOR_UNIT,
       DENOMINATOR::float8,
       DENOMINATOR_UNIT
FROM ds_0_sd a
         JOIN drug_concept_stage b
              ON UPPER(b.concept_name) = UPPER(substance)
                  AND b.concept_class_id = 'Ingredient';

DELETE
FROM ds_stage
WHERE numerator_unit = 'O'
   OR amount_unit = 'O';

DELETE
FROM ds_stage
WHERE numerator_value = 0.0
   OR amount_value = 0.0;

DELETE
FROM ds_stage
WHERE drug_concept_code IN (SELECT drug_concept_code
                            FROM ds_stage
                            WHERE amount_unit IS NULL
                              AND numerator_unit IS NULL);



UPDATE ds_stage
SET denominator_value = NULL,
    denominator_unit  = NULL
WHERE denominator_value = 0.0;

UPDATE ds_stage
SET numerator_value = NULL,
    numerator_unit  = NULL
WHERE amount_value = numerator_value
  AND amount_unit = numerator_unit;

--find dosage for drugs which contains two ingredients
DROP TABLE IF EXISTS grr_mult;

CREATE TABLE grr_mult
AS
WITH r_ds AS
         (
             SELECT DISTINCT drug_concept_id,
                             STRING_AGG(ingredient_concept_id::VARCHAR, '-'
                                        ORDER BY ingredient_concept_id)                            AS r_i_combo,
                             STRING_AGG(amount_value::VARCHAR, '-' ORDER BY ingredient_concept_id) AS r_d_combo
             FROM drug_strength
                      JOIN concept
                           ON concept_id = drug_concept_id
                               AND concept_class_id = 'Clinical Drug'
             GROUP BY drug_concept_id,
                      vocabulary_id
             HAVING COUNT(1) = 2
         ),

     q_ds
         AS
         (
             SELECT fcc                                                                          AS q_code,
                    STRING_AGG(rtc.concept_Id_2::VARCHAR, '-' ORDER BY concept_Id_2)             AS q_ing_combo,
                    SUBSTRING(therapy_name, '(\d+\.?\d?)(/|-- )') || '-' ||
                    regexp_replace(SUBSTRING(therapy_name, '((/|-- )\d+\.?\d?)'), '(/|-- )', '') AS q_d_combo
             FROM source_data_1
                      JOIN internal_relationship_stage irs ON fcc = irs.concept_code_1
                      JOIN relationship_to_concept rtc
                           ON irs.concept_code_2 = rtc.concept_code_1
                               AND precedence = 1
                      JOIN concept
                           ON concept_id = concept_id_2
                               AND concept_class_id = 'Ingredient'
             WHERE substance LIKE '%+%'
             GROUP BY fcc,
                      therapy_name
             UNION
             SELECT fcc                                                              AS q_code,
                    STRING_AGG(rtc.concept_Id_2::VARCHAR, '-' ORDER BY concept_Id_2) AS q_ing_combo,
                    REGEXP_REPLACE(SUBSTRING(therapy_name, '((/|-- )\d+\.?\d?)'), '(/|-- )', '') || '-' ||
                    SUBSTRING(therapy_name, '(\d+\.?\d?)(/|-- )')                    AS q_d_combo
             FROM source_data_1
                      JOIN internal_relationship_stage irs ON fcc = irs.concept_code_1
                      JOIN relationship_to_concept rtc
                           ON irs.concept_code_2 = rtc.concept_code_1
                               AND precedence = 1
                      JOIN concept
                           ON concept_id = concept_id_2
                               AND concept_class_id = 'Ingredient'
             WHERE substance LIKE '%+%'
             GROUP BY fcc,
                      therapy_name
         ),

     c_m
         AS
         (
             SELECT DISTINCT q_code,
                             SUBSTRING(q_ing_combo, '(\d+)\-')        AS ing,
                             SUBSTRING(q_d_combo, '(\d+(\.?)(\d+)?)') AS d1
             FROM q_ds
                      JOIN r_ds
                           ON q_ing_combo = r_i_combo
                               AND q_d_combo = r_d_combo
             UNION
             SELECT DISTINCT q_code,
                             SUBSTRING(q_ing_combo, '\d+\-(\d+)')                                AS ing,
                             REGEXP_REPLACE(SUBSTRING(q_d_combo, '(\-\d+(\.)?(\d+)?)'), '-', '') AS d1
             FROM q_ds
                      JOIN r_ds
                           ON q_ing_combo = r_i_combo
                               AND q_d_combo = r_d_combo
         )

SELECT q_code,
       rtc.concept_code_1,
       d1
FROM c_m
         JOIN relationship_to_concept rtc ON CAST(c_m.ing AS INTEGER) = rtc.concept_id_2;

DELETE
FROM grr_mult
WHERE q_code IN ('1143155_08012020')
  AND d1 = '10'
  AND concept_code_1 IN (SELECT concept_code
                         FROM drug_concept_stage
                         WHERE concept_name = 'Ramipril'
                           AND concept_class_id = 'Ingredient');
DELETE
FROM grr_mult
WHERE q_code IN ('1143155_08012020')
  AND d1 = '5'
  AND concept_code_1 IN (SELECT concept_code
                         FROM drug_concept_stage
                         WHERE concept_name = 'Amlodipine'
                           AND concept_class_id = 'Ingredient');
DELETE
FROM grr_mult
WHERE q_code IN ('1143153_08012020')
  AND d1 = '5'
  AND concept_code_1 IN (SELECT concept_code
                         FROM drug_concept_stage
                         WHERE concept_name = 'Ramipril'
                           AND concept_class_id = 'Ingredient');
DELETE
FROM grr_mult
WHERE q_code IN ('1143153_08012020')
  AND d1 = '10'
  AND concept_code_1 IN (SELECT concept_code
                         FROM drug_concept_stage
                         WHERE concept_name = 'Amlodipine'
                           AND concept_class_id = 'Ingredient');
DELETE
FROM grr_mult
WHERE q_code IN ('1136517_05012020')
  AND d1 = '12.5'
  AND concept_code_1 IN (SELECT concept_code
                         FROM drug_concept_stage
                         WHERE concept_name = 'Valsartan'
                           AND concept_class_id = 'Ingredient');
DELETE
FROM grr_mult
WHERE q_code IN ('1136517_05012020')
  AND d1 = '80'
  AND concept_code_1 IN (SELECT concept_code
                         FROM drug_concept_stage
                         WHERE concept_name = 'Hydrochlorothiazide'
                           AND concept_class_id = 'Ingredient');



DELETE
FROM ds_stage
WHERE drug_concept_code IN (SELECT q_code FROM grr_mult);

-- insert only solid multicomponent drugs
INSERT INTO ds_stage
(DRUG_CONCEPT_CODE,
 INGREDIENT_CONCEPT_CODE,
 BOX_SIZE,
 AMOUNT_VALUE,
 AMOUNT_UNIT)
SELECT q_code,
       concept_code_1,
       CAST(SUBSTRING(CAST(packsize AS VARCHAR), '\d+') AS INTEGER),
       CAST(d1 AS FLOAT),
       'MG'
FROM grr_mult
         JOIN source_data_1 ON fcc = q_code
    AND nfc != 'DGJ';

-- find dosage for liquid multicomponent drugs which have source doses in mg per tablespoon
INSERT INTO ds_stage
(DRUG_CONCEPT_CODE,
 INGREDIENT_CONCEPT_CODE,
 numerator_value,
 numerator_unit,
 denominator_value,
 denominator_unit)
SELECT q_code,
       concept_code_1,
       (TRIM(d1)::FLOAT) / 5 * CAST(volume AS float),
       'MG',
       volume::FLOAT,
       'ML'
FROM grr_mult
         JOIN source_data_1
              ON q_code = fcc
WHERE nfc = 'DGJ';

--delete liquid homeopathy 
DELETE
FROM drug_concept_stage
WHERE concept_code IN (SELECT drug_concept_code
                       FROM ds_stage
                       WHERE numerator_unit IN ('DH', 'C', 'CH', 'D', 'TM', 'X', 'XMK')
                         AND denominator_value IS NOT NULL);

DELETE
FROM relationship_to_concept
WHERE concept_code_1 IN ('DH', 'C', 'CH', 'D', 'TM', 'X', 'XMK')
;

DELETE
FROM internal_relationship_stage
WHERE concept_code_1 IN (SELECT drug_concept_code
                         FROM ds_stage
                         WHERE numerator_unit IN ('DH', 'C', 'CH', 'D', 'TM', 'X', 'XMK')
                           AND denominator_value IS NOT NULL);

DELETE
FROM ds_stage
WHERE numerator_unit IN ('DH', 'C', 'CH', 'D', 'TM', 'X', 'XMK')
  AND denominator_value IS NOT NULL;

--delete units that we aren't used
DELETE
FROM drug_concept_stage
WHERE concept_code IN (SELECT CONCEPT_CODE
                       FROM drug_concept_Stage a
                                LEFT JOIN relationship_to_concept b ON a.concept_code = b.concept_code_1
                       WHERE concept_class_id IN ('Unit')
                         AND b.concept_code_1 IS NULL);

--delete supplier from drugs without dosage
DELETE
FROM internal_relationship_stage
WHERE (concept_code_1, concept_code_2) IN (SELECT concept_code_1,
                                                  concept_code_2
                                           FROM internal_relationship_stage
                                                    JOIN drug_concept_stage
                                                         ON concept_code_2 = concept_code
                                                             AND concept_class_id = 'Supplier'
                                                    LEFT JOIN ds_stage ON drug_concept_code = concept_code_1
                                           WHERE drug_concept_code IS NULL);

-- update concept code for concept that already exist in devv5
DROP TABLE IF EXISTS code_replace;

CREATE TABLE code_replace
AS
SELECT DISTINCT d.concept_code                                                                 AS old_code,
                d.concept_name                                                                 AS name,
                MIN(c.concept_code) OVER (PARTITION BY c.concept_name,c.vocabulary_id = 'GRR') AS new_code
FROM drug_concept_stage d
         JOIN concept c
              ON UPPER(c.concept_name) = TRIM(UPPER(d.concept_name))
                  AND c.vocabulary_id = 'GRR'
                  AND c.concept_class_id NOT IN ('Device', 'Drug Product')
WHERE d.concept_code LIKE 'OMOP%';

UPDATE drug_concept_stage a
SET concept_code = b.new_code
FROM code_replace b
WHERE a.concept_code = b.old_code;

UPDATE relationship_to_concept a
SET concept_code_1 = b.new_code
FROM code_replace b
WHERE a.concept_code_1 = b.old_code;

UPDATE ds_stage a
SET ingredient_concept_code = b.new_code
FROM code_replace b
WHERE a.ingredient_concept_code = b.old_code;

UPDATE ds_stage a
SET drug_concept_code = b.new_code
FROM code_replace b
WHERE a.drug_concept_code = b.old_code;

UPDATE internal_relationship_stage a
SET concept_code_1 = b.new_code
FROM code_replace b
WHERE a.concept_code_1 = b.old_code;

UPDATE internal_relationship_stage a
SET concept_code_2 = b.new_code
FROM code_replace b
WHERE a.concept_code_2 = b.old_code;

UPDATE pc_stage a
SET drug_concept_code = b.new_code
FROM code_replace b
WHERE a.drug_concept_code = b.old_code;

--create name like in RxNorm for source concepts
DROP TABLE IF EXISTS ds_stage_cnc;

CREATE TABLE ds_stage_cnc
AS
SELECT CONCAT(denominator_value, ' ', denominator_unit) AS quant,
       drug_concept_code,
       CASE
           WHEN therapy_name ~ '\d+\.?\d+?(MG|G|Y|K)\s\/(\d+)?(ML|G)'
               THEN CONCAT(i.concept_name, ' ', TRIM(TRAILING '.' FROM TO_CHAR(
                       COALESCE(amount_value, numerator_value) / COALESCE(denominator_value, 1),
                       'FM9999999999999999999990.999999999999999999999')), ' ', COALESCE(amount_unit, numerator_unit),
                           COALESCE('/' || denominator_unit))
           ELSE CONCAT(i.concept_name, ' ',
                       TRIM(TRAILING '.' FROM TO_CHAR(ROUND((COALESCE(amount_value,
                                                                      numerator_value / COALESCE(denominator_value, 1)))::numeric,
                                                            (1 - FLOOR(LOG(COALESCE(amount_value,
                                                                                    numerator_value / COALESCE(denominator_value, 1)))) -
                                                             1)::INT),
                                                      'FM9999999999999999999990.999999999999999999999')))
           END                                          AS dosage_name
FROM ds_stage
         JOIN source_data_1 ON fcc = drug_concept_code
         JOIN drug_concept_stage i ON i.concept_code = ingredient_concept_code;

DROP TABLE IF EXISTS ds_stage_cnc2;

CREATE TABLE ds_stage_cnc2
AS
SELECT quant,
       drug_concept_code,
       STRING_AGG(dosage_name, ' / ' ORDER BY DOSAGE_NAME ASC) AS dos_name_cnc
FROM ds_stage_cnc
GROUP BY quant,
         drug_concept_code;

DROP TABLE IF EXISTS ds_stage_cnc3;

CREATE TABLE ds_stage_cnc3
AS
SELECT quant,
       drug_concept_code,
       CASE
           WHEN quant ~ '^\d.*' THEN CONCAT(quant, ' ', dos_name_cnc)
           ELSE dos_name_cnc
           END AS strength_name
FROM ds_stage_cnc2;

DROP TABLE IF EXISTS rel_to_name;

CREATE TABLE rel_to_name
AS
SELECT ri.*,
       d.concept_name,
       d.concept_class_id
FROM internal_relationship_stage ri
         JOIN drug_concept_stage d ON concept_code = concept_code_2;

DROP TABLE IF EXISTS new_name;

CREATE TABLE new_name
AS
SELECT DISTINCT c.drug_concept_code,
                CONCAT(strength_name,
                       CASE WHEN f.concept_name IS NOT NULL THEN CONCAT(' ', f.concept_name) ELSE NULL END,
                       CASE WHEN b.concept_name IS NOT NULL THEN CONCAT(' [', b.concept_name, ']') ELSE NULL END,
                       CASE WHEN ds.box_size IS NOT NULL THEN CONCAT(' Box of ', ds.box_size) ELSE NULL END, CASE
                                                                                                                 WHEN s.concept_name IS NOT NULL
                                                                                                                     THEN CONCAT(' by ', s.concept_name)
                                                                                                                 ELSE NULL END) AS concept_name
FROM ds_stage_cnc3 c
         LEFT JOIN rel_to_name f
                   ON c.drug_concept_code = f.concept_code_1
                       AND f.concept_class_id = 'Dose Form'
         LEFT JOIN rel_to_name b
                   ON c.drug_concept_code = b.concept_code_1
                       AND b.concept_class_id = 'Brand Name'
         LEFT JOIN rel_to_name s
                   ON c.drug_concept_code = s.concept_code_1
                       AND s.concept_class_id = 'Supplier'
         LEFT JOIN ds_stage ds ON c.drug_concept_code = ds.drug_concept_code;

INSERT INTO new_name
SELECT DISTINCT a.concept_code,
                trim(CONCAT(
                        a.ingred_name,
                        CASE
                            WHEN f.concept_name IS NOT NULL
                                THEN CONCAT(' ', f.concept_name)
                            ELSE NULL END,
                        CASE
                            WHEN b.concept_name IS NOT NULL
                                THEN CONCAT(' [', b.concept_name, ']')
                            ELSE NULL END,
                        CASE
                            WHEN ds.box_size IS NOT NULL
                                THEN CONCAT(' Box of ', ds.box_size)
                            ELSE NULL END,
                        CASE
                            WHEN s.concept_name IS NOT NULL
                                THEN CONCAT(' by ', s.concept_name)
                            ELSE NULL END
                    )) AS concept_name
FROM (SELECT DISTINCT ca.concept_code,
                      STRING_AGG(i.concept_name, '/') OVER (PARTITION BY ca.concept_code) AS ingred_name
      FROM (SELECT DISTINCT *
            FROM drug_concept_stage
            WHERE UPPER(concept_name) IN (SELECT therapy_name FROM source_data_1)) ca
               JOIN rel_to_name i
                    ON ca.concept_code = i.concept_code_1
                        AND i.concept_class_id = 'Ingredient') a
         LEFT JOIN rel_to_name f
                   ON a.concept_code = f.concept_code_1
                       AND f.concept_class_id = 'Dose Form'
         LEFT JOIN rel_to_name b
                   ON a.concept_code = b.concept_code_1
                       AND b.concept_class_id = 'Brand Name'
         LEFT JOIN rel_to_name s
                   ON a.concept_code = s.concept_code_1
                       AND s.concept_class_id = 'Supplier'
         LEFT JOIN ds_stage ds ON a.concept_code = ds.drug_concept_code
WHERE a.concept_code NOT IN (SELECT drug_concept_code FROM new_name);


--insert attributes in r_t_c_all from current rtc for future usage
INSERT INTO r_t_c_all
(concept_name,
 concept_class_id,
 concept_id,
 precedence,
 conversion_factor)
SELECT concept_name,
       concept_class_id,
       concept_id_2,
       precedence,
       conversion_factor
FROM drug_concept_stage
         JOIN relationship_to_concept ON concept_code = concept_code_1
WHERE UPPER(concept_name) NOT IN (SELECT UPPER(concept_name) FROM r_t_c_all);

DELETE
FROM r_t_c_all
WHERE concept_name = 'Zinksalbe';
UPDATE ds_stage
SET box_size = NULL
WHERE drug_concept_code IN (
    SELECT drug_concept_code
    FROM ds_stage
    WHERE drug_concept_code NOT IN (
        SELECT drug_concept_code
        FROM ds_stage ds
                 JOIN internal_relationship_stage i ON concept_code_1 = drug_concept_code
                 JOIN drug_concept_stage ON concept_code = concept_code_2
            AND concept_class_id = 'Dose Form'
        WHERE ds.box_size IS NOT NULL
    )
      AND box_size IS NOT NULL
);
UPDATE ds_stage
SET box_size = NULL
WHERE drug_concept_code IN (
    SELECT drug_concept_code
    FROM ds_stage
    WHERE numerator_value IS NOT NULL
      AND denominator_value IS NULL
      AND box_size IS NOT NULL);

UPDATE ds_stage
SET box_size = NULL
WHERE box_size = 1;

DROP TABLE IF EXISTS new_names;
CREATE TABLE new_names
(
    drug_concept_code varchar,
    new_name          varchar
);
INSERT INTO new_names
SELECT *
FROM (
         WITH a AS
                  (
                      SELECT ds.drug_concept_code,
                             concat(d2.concept_name, ' ', ds.amount_value, ' ', ds.amount_unit) AS comp_name
                      FROM ds_stage ds
                               JOIN drug_concept_stage d2 ON ds.ingredient_concept_code = d2.concept_code
                               JOIN drug_concept_stage d1 ON d1.concept_code = ds.drug_concept_code
                      WHERE numerator_value IS NULL)
         SELECT DISTINCT drug_concept_code,
                         string_agg(comp_name, '/') OVER (PARTITION BY drug_concept_code ORDER BY comp_name ASC)
         FROM a) AS s;

INSERT INTO new_names
SELECT *
FROM (
         WITH a AS
                  (
                      SELECT ds.drug_concept_code,
                             CASE
                                 WHEN denominator_value IS NOT NULL THEN concat(d2.concept_name, ' ',
                                                                                ds.numerator_value * ds.denominator_value,
                                                                                ' ', ds.numerator_unit, '/',
                                                                                denominator_unit)
                                 WHEN denominator_value IS NULL THEN concat(d2.concept_name, ' ', ds.numerator_value,
                                                                            ' ', ds.numerator_unit, '/',
                                                                            denominator_unit) END AS comp_name
                      FROM ds_stage ds
                               JOIN drug_concept_stage d2 ON ds.ingredient_concept_code = d2.concept_code
                               JOIN drug_concept_stage d1 ON d1.concept_code = ds.drug_concept_code

                      WHERE amount_value IS NULL
                  )
         SELECT DISTINCT drug_concept_code,
                         string_agg(comp_name, ' / ') OVER (PARTITION BY drug_concept_code ORDER BY comp_name ASC)
         FROM a) AS s;
;

DROP TABLE IF EXISTS name_dup;
CREATE TABLE name_dup AS (SELECT DISTINCT first_value(a.new_name)
                                          OVER (PARTITION BY a.drug_concept_code ORDER BY length(a.new_name) DESC,
                                              a.new_name ASC) AS cor,
                                          drug_concept_code
                          FROM new_names a
);
DELETE
FROM name_dup a
WHERE a.ctid <> (SELECT min(b.ctid)
                 FROM dev_da_france_2.name_dup b
                 WHERE a.drug_concept_code = b.drug_concept_code
                   AND a.cor = b.cor);



DROP TABLE IF EXISTS a;
CREATE TABLE a AS (
    SELECT DISTINCT n.drug_concept_code AS code, concat(ds.denominator_value, ' ', ds.denominator_unit, ' ', n.cor) AS d
    FROM name_dup n
             JOIN ds_stage ds ON n.drug_concept_code = ds.drug_concept_code AND ds.denominator_value IS NOT NULL
);


UPDATE name_dup x
SET cor = (SELECT DISTINCT d FROM a WHERE code = x.drug_concept_code)
WHERE drug_concept_code IN (SELECT DISTINCT drug_concept_code FROM a WHERE code = x.drug_concept_code);
DROP TABLE IF EXISTS d;

CREATE TABLE d AS (
    SELECT DISTINCT n.drug_concept_code AS code, concat(n.cor, ' ', d.concept_name) AS d
    FROM name_dup n
             JOIN internal_relationship_stage i ON n.drug_concept_code = i.concept_code_1
             JOIN drug_concept_stage d ON i.concept_code_2 = d.concept_code AND d.concept_class_id = 'Dose Form');
UPDATE name_dup x
SET cor = (SELECT DISTINCT d FROM d WHERE code = x.drug_concept_code)
WHERE drug_concept_code IN (SELECT DISTINCT drug_concept_code FROM d WHERE code = x.drug_concept_code);


DROP TABLE IF EXISTS b;
CREATE TABLE b AS (
    SELECT ds.drug_concept_code AS code, concat(cor, ' ', '[', d3.concept_name, ']') AS comp_name
    FROM name_dup ds
             JOIN internal_relationship_stage i ON ds.drug_concept_code = i.concept_code_1
             JOIN drug_concept_stage d3 ON i.concept_code_2 = d3.concept_code AND d3.concept_class_id = 'Brand Name');

UPDATE name_dup x
SET cor = (SELECT DISTINCT comp_name FROM b WHERE code = x.drug_concept_code)
WHERE drug_concept_code IN (SELECT DISTINCT code FROM b WHERE code = x.drug_concept_code);

DROP TABLE IF EXISTS s;
CREATE TABLE s AS (
    SELECT DISTINCT n.drug_concept_code AS code, concat(n.cor, ' ', 'by', ' ', d.concept_name) AS d
    FROM name_dup n
             JOIN internal_relationship_stage i ON n.drug_concept_code = i.concept_code_1
             JOIN drug_concept_stage d ON i.concept_code_2 = d.concept_code AND d.concept_class_id = 'Supplier');
UPDATE name_dup x
SET cor = (SELECT DISTINCT d FROM s WHERE code = x.drug_concept_code)
WHERE drug_concept_code IN (SELECT DISTINCT drug_concept_code FROM s WHERE code = x.drug_concept_code);



UPDATE name_dup x
SET cor = (
    SELECT CASE
               WHEN LENGTH(TRIM(cor)) > 255
                   THEN TRIM(SUBSTR(TRIM(cor), 1, 252)) || '...'
               ELSE TRIM(cor) END
    FROM name_dup c
    WHERE c.drug_concept_code = x.drug_concept_code)
WHERE drug_concept_code IN
      (SELECT DISTINCT drug_concept_code FROM name_dup c WHERE c.drug_concept_code = x.drug_concept_code);



UPDATE drug_concept_stage x
SET concept_name = (SELECT DISTINCT cor FROM name_dup WHERE drug_concept_code = x.concept_code)
WHERE concept_code IN (SELECT DISTINCT drug_concept_code FROM name_dup WHERE drug_concept_code = x.concept_code);



UPDATE drug_concept_stage x
SET concept_name = (
    SELECT CASE
               WHEN LENGTH(TRIM(concept_name)) > 255
                   THEN TRIM(SUBSTR(TRIM(concept_name), 1, 252)) || '...'
               ELSE TRIM(concept_name) END
    FROM drug_concept_stage c
    WHERE c.concept_code = x.concept_code)
WHERE concept_code IN (SELECT DISTINCT concept_code FROM drug_concept_stage c WHERE c.concept_code = x.concept_code);

--SET APPROPRIATE DATA TYPES
ALTER TABLE relationship_to_concept
    ALTER COLUMN precedence TYPE smallint,
    ALTER COLUMN conversion_factor TYPE numeric;
ALTER TABLE ds_stage
    ALTER COLUMN amount_value TYPE numeric,
    ALTER COLUMN numerator_value TYPE numeric,
    ALTER COLUMN denominator_value TYPE numeric,
    ALTER COLUMN box_size TYPE smallint;

--SET PROPER value for denominators
UPDATE ds_stage
SET denominator_unit = NULL
-- SELECT * FROM ds_stage
WHERE denominator_unit = ' '
;

--Check that there are no cases when amount_value and numerator_value are populated simultaneously;
SELECT * FROM ds_stage where amount_value is not null and numerator_value is not null

--SET PROPER value for amount_value
UPDATE ds_stage
SET amount_value = numerator_value,
       amount_unit = ' @ '|| numerator_unit
--SELECT drug_concept_code FROM ds_stage
WHERE denominator_unit IS NULL
  AND amount_value IS NULL
  AND drug_concept_code IN (SELECT dcs.concept_code
                            FROM drug_concept_stage dcs
                                     JOIN internal_relationship_stage irs ON dcs.concept_code = irs.concept_code_1
                                     JOIN relationship_to_concept rtc ON irs.concept_code_2 = rtc.concept_code_1
                                     JOIN CONCEPT c ON rtc.concept_id_2 = c.concept_id
                            WHERE c.concept_name !~* 'solu|inj|susp|Syri' -- to set amount value for SOLIDs only
)
;
--SET PROPER value for amount_unit and numerator_value
UPDATE ds_stage
SET numerator_value =  NULL,
       numerator_unit = NULL,
    amount_unit = regexp_replace(amount_unit,'^ @ ','','gi')
--SELECT drug_concept_code FROM ds_stage
WHERE amount_unit ilike ' @ %'
and amount_value is not null and numerator_value is not null
;


--Emulate LU statement
DO
$_$
    BEGIN
        PERFORM VOCABULARY_PACK.SetLatestUpdate(
                pVocabularyName => 'GRR',
                pVocabularyDate => (SELECT max(to_date(product_launch_date, 'DD.MM.YYYY')) FROM source LIMIT 1),
                pVocabularyVersion => (SELECT 'GRR ' || max(to_date(product_launch_date, 'DD.MM.YYYY'))::varchar
                                       FROM source
                                       LIMIT 1),
                pVocabularyDevSchema => 'DEV_GRR'
            );
    END
$_$;
