--Adaptation of AMT code
-- populate manually mapped tables with new concepts before proceeding with rtc_2. _to_map tables should be empty

--TODO: If we have coalesce(im.new_name, im.name) => names should be updated right before this step?

--1. ingredient
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, mapping_type)
SELECT DISTINCT dcs.concept_code, 'DPD', concept_id_2, precedence, mapping_type
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
SELECT DISTINCT dcs.concept_code, 'DPD', concept_id_2, precedence, mapping_type
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
SELECT DISTINCT dcs.concept_code, 'DPD', concept_id_2, precedence, mapping_type
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
SELECT DISTINCT dcs.concept_code, /*dcs.concept_name,*/ 'DPD', concept_id_2, precedence, mapping_type
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
SELECT DISTINCT dcs.concept_code, 'DPD', concept_id_2, precedence, conversion_factor, mapping_type
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
      JOIN devv5.concept c
          ON concept_id_2 = c.concept_id
              AND c.invalid_reason = 'D' AND concept_class_id != 'Ingredient' AND c.vocabulary_id = 'RxNorm Extension'
      );

DELETE
FROM internal_relationship_stage
WHERE concept_code_2 IN
      (
      SELECT concept_code_1
      FROM relationship_to_concept
      JOIN devv5.concept c
          ON concept_id_2 = c.concept_id
              AND c.invalid_reason = 'D' AND concept_class_id != 'Ingredient' AND c.vocabulary_id = 'RxNorm Extension'
      );

DELETE
FROM relationship_to_concept
WHERE concept_code_1 IN (
                        SELECT concept_code_1
                        FROM relationship_to_concept
                        JOIN devv5.concept c
                            ON concept_id_2 = c.concept_id
                                AND c.invalid_reason = 'D' AND concept_class_id != 'Ingredient' AND
                               c.vocabulary_id = 'RxNorm Extension'
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
LEFT JOIN drug_concept_stage_backup dcsb
    ON dcs.concept_code = dcsb.concept_code
WHERE dcs.concept_class_id IN ('Ingredient', 'Brand Name', 'Supplier', 'Dose Form', 'Unit')
;

--remove to be created concepts from mapped tables
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
        WHERE vocabulary_id = 'DPD'
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


-- need for BuildRxE to run
ALTER TABLE relationship_to_concept
DROP COLUMN mapping_type;