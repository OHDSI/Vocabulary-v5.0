DROP TABLE IF EXISTS ingredient_mapped;
CREATE TABLE ingredient_mapped
(
    name         varchar(255),
    new_name     varchar(255),
    concept_id_2 integer,
    precedence   integer,
    mapping_type varchar(50)
);

DROP TABLE IF EXISTS brand_name_mapped;
CREATE TABLE brand_name_mapped
(
    name         varchar(255),
    new_name     varchar(255),
    concept_id_2 integer,
    precedence   integer,
    mapping_type varchar(50)
);

DROP TABLE IF EXISTS supplier_mapped;
CREATE TABLE supplier_mapped
(
    name         varchar(255),
    new_name     varchar(255),
    concept_id_2 integer,
    precedence   integer,
    mapping_type varchar(50)
);

DROP TABLE IF EXISTS dose_form_mapped;
CREATE TABLE dose_form_mapped
(
    name         varchar(255),
    new_name     varchar(255),
    concept_id_2 integer,
    precedence   integer,
    mapping_type varchar(50)
);

DROP TABLE IF EXISTS unit_mapped;
CREATE TABLE unit_mapped
(
    name              varchar(255),
    new_name          varchar(255),
    concept_id_2      integer,
    precedence        integer,
    conversion_factor double precision,
    mapping_type      varchar(50)
);

-- 5. RELATIONSHIP_TO_CONCEPT
DO
$$
    BEGIN
        ALTER TABLE relationship_to_concept
            ADD COLUMN mapping_type varchar(255);
    EXCEPTION
        WHEN duplicate_column THEN RAISE NOTICE 'column mapping_type already exists in relationship_to_concept.';
    END;
$$;


--create a temporary storage of units conversion info before truncating rtc
DROP TABLE IF EXISTS unit_conversions;
CREATE TEMP TABLE unit_conversions AS
SELECT DISTINCT rtc.concept_code_1,
                rtc.conversion_factor
FROM relationship_to_concept rtc
JOIN dev_oleg.drug_concept_stage dcs
    ON rtc.concept_code_1 = dcs.concept_code
WHERE dcs.concept_class_id = 'Unit';


TRUNCATE TABLE relationship_to_concept;


--1. Ingredient
-- insert auto-mapping into rtc by concept_name match
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor,
                                     mapping_type)
SELECT DISTINCT dcs.concept_code, --dcs.concept_name,
                'DPD',
                c.concept_id,     --c.concept_name,
                rank() OVER (PARTITION BY dcs.concept_code ORDER BY c.vocabulary_id, c.concept_id),
                NULL::double precision,
                'am_name_match'
FROM drug_concept_stage dcs
JOIN concept c
    ON lower(c.concept_name) = lower(dcs.concept_name)
        AND c.concept_class_id = 'Ingredient'
        AND c.vocabulary_id LIKE 'RxNorm%'
        AND c.invalid_reason IS NULL
        AND c.standard_concept = 'S'
WHERE dcs.concept_class_id = 'Ingredient'
  AND NOT EXISTS(SELECT 1
                 FROM relationship_to_concept rtc
                 WHERE dcs.concept_code = rtc.concept_code_1
    )
;

-- insert auto-mapping into rtc by Precise Ingredient name match
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor,
                                     mapping_type)
SELECT DISTINCT dcs.concept_code, --dcs.concept_name,
                'DPD',
                cc.concept_id,    --cc.concept_name,
                rank() OVER (PARTITION BY dcs.concept_code ORDER BY c.vocabulary_id, c.concept_id),
                NULL::double precision,
                'am_precise_ing_name_match' AS mapping_type
FROM drug_concept_stage dcs
JOIN concept c
    ON lower(c.concept_name) = lower(dcs.concept_name)
        AND c.concept_class_id = 'Precise Ingredient'
        AND c.vocabulary_id LIKE 'RxNorm%'
        AND c.invalid_reason IS NULL
JOIN concept_relationship cr
    ON c.concept_id = cr.concept_id_1 AND cr.invalid_reason IS NULL
JOIN concept cc
    ON cr.concept_id_2 = cc.concept_id
        AND cc.concept_class_id = 'Ingredient'
        AND cc.vocabulary_id LIKE 'RxNorm%'
        AND cc.invalid_reason IS NULL
        AND cc.standard_concept = 'S'
WHERE dcs.concept_class_id = 'Ingredient'
  AND NOT EXISTS(SELECT 1
                 FROM relationship_to_concept rtc
                 WHERE dcs.concept_code = rtc.concept_code_1
    )
--   AND dcs.concept_code not in (select concept_code from vaccines)
;

-- insert mapping into rtc by concept_name match through U/D ingredients and 'Maps to' link
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor,
                                     mapping_type)
SELECT DISTINCT dcs.concept_code, --dcs.concept_name,
                'DPD',
                cc.concept_id,    --cc.concept_name,
                rank() OVER (PARTITION BY dcs.concept_code ORDER BY cc.vocabulary_id, cc.concept_id),
                NULL::double precision,
                'am_U/D_name_match + link to Valid' AS mapping_type
FROM drug_concept_stage dcs
JOIN concept c
    ON lower(c.concept_name) = lower(dcs.concept_name)
        AND c.concept_class_id = 'Ingredient'
        AND c.vocabulary_id LIKE 'RxNorm%'
        AND (c.standard_concept IS NULL OR c.invalid_reason IS NOT NULL)
JOIN concept_relationship cr
    ON c.concept_id = cr.concept_id_1 AND cr.relationship_id = 'Maps to' AND cr.invalid_reason IS NULL
JOIN concept cc
    ON cr.concept_id_2 = cc.concept_id
        AND cc.concept_class_id = 'Ingredient'
        AND cc.vocabulary_id LIKE 'RxNorm%'
        AND cc.invalid_reason IS NULL
        AND cc.standard_concept = 'S'
WHERE dcs.concept_class_id = 'Ingredient'
  AND NOT EXISTS(SELECT 1
                 FROM relationship_to_concept rtc
                 WHERE dcs.concept_code = rtc.concept_code_1
    )
--   AND dcs.concept_code not in (select concept_code from vaccines_ing)
;

-- update 'U/D' in ingredient_mapped
WITH to_be_updated AS (
                      SELECT DISTINCT im.name,
                                      im.concept_id_2 AS concept_id_2,
                                      c2.concept_id AS new_concept_id_2,
                                      c2.concept_name AS new_concept_name_2
                      FROM ingredient_mapped im
                      JOIN concept c1
                          ON im.concept_id_2 = c1.concept_id
                              AND c1.invalid_reason IN ('U', 'D')
                      JOIN concept_relationship cr
                          ON cr.concept_id_1 = c1.concept_id
                              AND cr.relationship_id = 'Maps to' AND cr.invalid_reason IS NULL
                      JOIN concept c2
                          ON c2.concept_id = cr.concept_id_2
                              AND c2.concept_class_id = 'Ingredient'
                              AND c2.vocabulary_id LIKE 'RxNorm%'
                              AND c2.invalid_reason IS NULL
                              AND c2.standard_concept = 'S'
                      WHERE
--excluding names mapped to > 1 concept
im.name NOT IN (
               SELECT im2.name
               FROM ingredient_mapped im2
               GROUP BY im2.name
               HAVING count(*) > 1
               )
                      )
UPDATE ingredient_mapped im
SET concept_id_2 = to_be_updated.new_concept_id_2,
    mapping_type = 'rtc_backup_U/D + link to Valid'
FROM to_be_updated
WHERE im.name = to_be_updated.name;


--delete from ingredient mapped if target concept is still U/D
WITH to_be_deleted AS (
                      SELECT *
                      FROM ingredient_mapped
                      WHERE concept_id_2 IN (
                                            SELECT concept_id
                                            FROM concept
                                            WHERE invalid_reason IS NOT NULL
                                            )
                      )
DELETE
FROM ingredient_mapped
WHERE name IN (
              SELECT name
              FROM to_be_deleted
              )
;

--Mapping from previous relationship_to_concept run, based on name and concept_class_id match
INSERT INTO relationship_to_concept(concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor, mapping_type)
SELECT DISTINCT dcs.concept_code, 'DPD', c.concept_id, bu.precedence, bu.conversion_factor, 'prev_rtc'
FROM prev_rtc bu
JOIN devv5.concept c
ON bu.concept_id_2 = c.concept_id
JOIN drug_concept_stage dcs
ON upper(dcs.concept_name) = upper(bu.concept_name_1)
WHERE bu.concept_class_id_1 = 'Ingredient'
  AND c.concept_class_id = 'Ingredient'
  AND c.invalid_reason IS NULL
  AND c.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
  AND dcs.concept_class_id = 'Ingredient'
  AND dcs.concept_code NOT IN (
                              SELECT DISTINCT concept_code_1
                              FROM relationship_to_concept
                              )
  AND dcs.concept_name NOT IN (
                              SELECT DISTINCT name
                              FROM ingredient_mapped
                              WHERE name IS NOT NULL
                              )
;


DROP TABLE IF EXISTS ingredient_to_map;

--ingredients to_map
CREATE TABLE IF NOT EXISTS ingredient_to_map AS
SELECT DISTINCT dcs.concept_name AS name,
                '' AS new_name
FROM drug_concept_stage dcs
WHERE concept_class_id = 'Ingredient'
  AND dcs.concept_code NOT IN (
                              SELECT DISTINCT concept_code_1
                              FROM relationship_to_concept
                              )
  AND dcs.concept_name NOT IN (
                              SELECT DISTINCT name
                              FROM ingredient_mapped
                              WHERE name IS NOT NULL
                              )
ORDER BY dcs.concept_name
;

-- ingredient to map
SELECT DISTINCT name,
                '' AS new_name,
                '' AS comment,
                NULL AS precedence,
                NULL AS target_concept_id,
                NULL AS concept_code,
                NULL AS concept_name,
                NULL AS concept_class_id,
                NULL AS standard_concept,
                NULL AS invalid_reason,
                NULL AS domain_id,
                NULL AS target_vocabulary_id
FROM ingredient_to_map itm
WHERE lower(itm.name) NOT IN (
                             SELECT lower(new_name)
                             FROM ingredient_mapped
                             WHERE new_name IS NOT NULL
                             )
ORDER BY itm.name;

--2. Brand Names
--insert auto-mapping into rtc by concept_name match
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor,
                                     mapping_type)
SELECT DISTINCT dcs.concept_code, --dcs.concept_name,
                'DPD',
                c.concept_id,     --c.concept_name,
                rank() OVER (PARTITION BY dcs.concept_code ORDER BY c.vocabulary_id, c.concept_id),
                NULL::double precision,
                'am_name_match'
FROM drug_concept_stage dcs
JOIN concept c
    ON lower(c.concept_name) = lower(dcs.concept_name)
        AND c.concept_class_id = 'Brand Name'
        AND c.vocabulary_id LIKE 'RxNorm%'
        AND c.invalid_reason IS NULL
WHERE dcs.concept_class_id = 'Brand Name'
  AND NOT EXISTS(SELECT 1
                 FROM relationship_to_concept rtc
                 WHERE dcs.concept_code = rtc.concept_code_1
    )
;

-- insert mapping into rtc by concept_name match through U/D ingredients and 'Concept replaced by' link
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor,
                                     mapping_type)
SELECT DISTINCT dcs.concept_code, --dcs.concept_name,
                'DPD',
                cc.concept_id,    --cc.concept_name,
                rank() OVER (PARTITION BY dcs.concept_code ORDER BY cc.vocabulary_id, cc.concept_id),
                NULL::double precision,
                'am_U/D_name_match + link to Valid' AS mapping_type
FROM drug_concept_stage dcs
JOIN concept c
    ON lower(c.concept_name) = lower(dcs.concept_name)
        AND c.concept_class_id = 'Brand Name'
        AND c.vocabulary_id LIKE 'RxNorm%'
        AND c.invalid_reason IS NOT NULL
JOIN concept_relationship cr
    ON c.concept_id = cr.concept_id_1 AND cr.relationship_id = 'Concept replaced by' AND cr.invalid_reason IS NULL
JOIN concept cc
    ON cr.concept_id_2 = cc.concept_id
        AND cc.concept_class_id = 'Brand Name'
        AND cc.vocabulary_id LIKE 'RxNorm%'
        AND cc.invalid_reason IS NULL
WHERE dcs.concept_class_id = 'Brand Name'
  AND NOT EXISTS(SELECT 1
                 FROM relationship_to_concept rtc
                 WHERE dcs.concept_code = rtc.concept_code_1
    )
;


-- update 'U/D' in brand_name_mapped
WITH to_be_updated AS (
                      SELECT DISTINCT bnm.name,
                                      bnm.concept_id_2 AS concept_id_2,
                                      c2.concept_id AS new_concept_id_2,
                                      c2.concept_name AS new_concept_name_2
                      FROM brand_name_mapped bnm
                      JOIN concept c1
                          ON bnm.concept_id_2 = c1.concept_id
                              AND c1.invalid_reason = 'U'
                      JOIN concept_relationship cr
                          ON cr.concept_id_1 = c1.concept_id
                              AND cr.relationship_id = 'Concept replaced by' AND cr.invalid_reason IS NULL
                      JOIN concept c2
                          ON c2.concept_id = cr.concept_id_2
                              AND c2.concept_class_id = 'Brand Name'
                              AND c2.vocabulary_id LIKE 'RxNorm%'
                              AND c2.invalid_reason IS NULL
                      WHERE
--excluding names mapped to > 1 concept
bnm.name NOT IN (
                SELECT bnm2.name
                FROM brand_name_mapped bnm2
                GROUP BY bnm2.name
                HAVING count(*) > 1
                )
                      )
UPDATE brand_name_mapped bnm
SET concept_id_2 = to_be_updated.new_concept_id_2,
    mapping_type = 'rtc_backup_U/D + link to Valid'
FROM to_be_updated
WHERE bnm.name = to_be_updated.name;

--delete from brand_name_mapped if target concept is still U/D
WITH to_be_deleted AS (
                      SELECT *
                      FROM brand_name_mapped
                      WHERE concept_id_2 IN (
                                            SELECT concept_id
                                            FROM concept
                                            WHERE invalid_reason IS NOT NULL
                                            )
                      )
DELETE
FROM brand_name_mapped
WHERE name IN (
              SELECT name
              FROM to_be_deleted
              )
;

--Mapping from previous relationship_to_concept run, based on name and concept_class_id match
INSERT INTO relationship_to_concept(concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor, mapping_type)
SELECT DISTINCT dcs.concept_code, 'DPD', c.concept_id, bu.precedence, bu.conversion_factor, 'prev_rtc'
FROM prev_rtc bu
JOIN devv5.concept c
ON bu.concept_id_2 = c.concept_id
JOIN drug_concept_stage dcs
ON upper(dcs.concept_name) = upper(bu.concept_name_1)
WHERE bu.concept_class_id_1 = 'Brand Name'
  AND c.concept_class_id = 'Brand Name'
  AND c.invalid_reason IS NULL
  AND c.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
  AND dcs.concept_class_id = 'Brand Name'
  AND dcs.concept_code NOT IN (
                              SELECT DISTINCT concept_code_1
                              FROM relationship_to_concept
                              )
  AND dcs.concept_name NOT IN (
                              SELECT DISTINCT name
                              FROM ingredient_mapped
                              WHERE name IS NOT NULL
                              )
;

DROP TABLE IF EXISTS brand_name_to_map;

--brand_name to_map
CREATE TABLE IF NOT EXISTS brand_name_to_map AS
SELECT DISTINCT dcs.concept_name AS name
FROM drug_concept_stage dcs
WHERE concept_class_id = 'Brand Name'
  AND dcs.concept_code NOT IN (
                              SELECT DISTINCT concept_code_1
                              FROM relationship_to_concept
                              )
  AND dcs.concept_name NOT IN (
                              SELECT DISTINCT name
                              FROM brand_name_mapped
                              WHERE name IS NOT NULL
                              )
ORDER BY dcs.concept_name
;

--brand_name_to_map
SELECT DISTINCT tm.name,
                '' AS new_name,
                '' AS comment,
                NULL AS precedence,
                NULL AS target_concept_id,
                NULL AS concept_code,
                NULL AS concept_name,
                NULL AS concept_class_id,
                NULL AS standard_concept,
                NULL AS invalid_reason,
                NULL AS domain_id,
                NULL AS target_vocabulary_id
FROM brand_name_to_map tm
WHERE lower(tm.name) NOT IN (
                            SELECT lower(new_name)
                            FROM brand_name_mapped
                            WHERE new_name IS NOT NULL
                            )
ORDER BY tm.name;

--3. Supplier
-- insert auto-mapping into rtc by concept_name match
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor,
                                     mapping_type)
SELECT DISTINCT dcs.concept_code, --dcs.concept_name,
                'DPD',
                c.concept_id,     --c.concept_name,
                rank() OVER (PARTITION BY dcs.concept_code ORDER BY c.vocabulary_id, c.concept_id),
                NULL::double precision,
                'am_name_match'
FROM drug_concept_stage dcs
JOIN concept c
    ON lower(c.concept_name) = lower(dcs.concept_name)
        AND c.concept_class_id = 'Supplier'
        AND c.vocabulary_id LIKE 'RxNorm%'
        AND c.invalid_reason IS NULL
WHERE dcs.concept_class_id = 'Supplier'
  AND NOT EXISTS(SELECT 1
                 FROM relationship_to_concept rtc
                 WHERE dcs.concept_code = rtc.concept_code_1
    )
;

-- insert mapping into rtc by concept_name match through U/D ingredients and 'Concept replaced by' link
INSERT INTO relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor,
                                     mapping_type)
SELECT DISTINCT dcs.concept_code, --dcs.concept_name,
                'DPD',
                cc.concept_id,    --cc.concept_name,
                rank() OVER (PARTITION BY dcs.concept_code ORDER BY cc.vocabulary_id, cc.concept_id),
                NULL::double precision,
                'am_U/D_name_match + link to Valid' AS mapping_type
FROM drug_concept_stage dcs
JOIN concept c
    ON lower(c.concept_name) = lower(dcs.concept_name)
        AND c.concept_class_id = 'Supplier'
        AND c.vocabulary_id LIKE 'RxNorm%'
        AND c.invalid_reason IS NOT NULL
JOIN concept_relationship cr
    ON c.concept_id = cr.concept_id_1 AND cr.relationship_id = 'Concept replaced by' AND cr.invalid_reason IS NULL
JOIN concept cc
    ON cr.concept_id_2 = cc.concept_id
        AND cc.concept_class_id = 'Supplier'
        AND cc.vocabulary_id LIKE 'RxNorm%'
        AND cc.invalid_reason IS NULL
WHERE dcs.concept_class_id = 'Supplier'
  AND NOT EXISTS(SELECT 1
                 FROM relationship_to_concept rtc
                 WHERE dcs.concept_code = rtc.concept_code_1
    )
;

-- update 'U/D' in supplier_mapped
WITH to_be_updated AS (
                      SELECT DISTINCT sm.name,
                                      sm.concept_id_2 AS concept_id_2,
                                      c2.concept_id AS new_concept_id_2,
                                      c2.concept_name AS new_concept_name_2
                      FROM supplier_mapped sm
                      JOIN concept c1
                          ON sm.concept_id_2 = c1.concept_id
                              AND c1.invalid_reason = 'U'
                      JOIN concept_relationship cr
                          ON cr.concept_id_1 = c1.concept_id
                              AND cr.relationship_id = 'Concept replaced by' AND cr.invalid_reason IS NULL
                      JOIN concept c2
                          ON c2.concept_id = cr.concept_id_2
                              AND c2.concept_class_id = 'Supplier'
                              AND c2.vocabulary_id LIKE 'RxNorm%'
                              AND c2.invalid_reason IS NULL
                      WHERE
--excluding names mapped to > 1 concept
sm.name NOT IN (
               SELECT sm2.name
               FROM supplier_mapped sm2
               GROUP BY sm2.name
               HAVING count(*) > 1
               )
                      )
UPDATE supplier_mapped sm
SET concept_id_2 = to_be_updated.new_concept_id_2,
    mapping_type = 'rtc_backup_U/D + link to Valid'
FROM to_be_updated
WHERE sm.name = to_be_updated.name;

--delete from supplier_mapped if target concept is still U/D
WITH to_be_deleted AS (
                      SELECT *
                      FROM supplier_mapped
                      WHERE concept_id_2 IN (
                                            SELECT concept_id
                                            FROM concept
                                            WHERE invalid_reason IS NOT NULL
                                            )
                      )
DELETE
FROM supplier_mapped
WHERE name IN (
              SELECT name
              FROM to_be_deleted
              )
;

--Mapping from previous relationship_to_concept run, based on name and concept_class_id match
INSERT INTO relationship_to_concept(concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor, mapping_type)
SELECT DISTINCT dcs.concept_code, 'DPD', c.concept_id, bu.precedence, bu.conversion_factor, 'prev_rtc'
FROM prev_rtc bu
JOIN devv5.concept c
ON bu.concept_id_2 = c.concept_id
JOIN drug_concept_stage dcs
ON upper(dcs.concept_name) = upper(bu.concept_name_1)
WHERE bu.concept_class_id_1 = 'Supplier'
  AND c.concept_class_id = 'Supplier'
  AND c.invalid_reason IS NULL
  AND c.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
  AND dcs.concept_class_id = 'Supplier'
  AND dcs.concept_code NOT IN (
                              SELECT DISTINCT concept_code_1
                              FROM relationship_to_concept
                              )
  AND dcs.concept_name NOT IN (
                              SELECT DISTINCT name
                              FROM ingredient_mapped
                              WHERE name IS NOT NULL
                              )
;

DROP TABLE IF EXISTS supplier_to_map;

--supplier to_map
CREATE TABLE IF NOT EXISTS supplier_to_map AS
SELECT DISTINCT dcs.concept_name AS name
FROM drug_concept_stage dcs
WHERE concept_class_id = 'Supplier'
  AND dcs.concept_code NOT IN (
                              SELECT DISTINCT concept_code_1
                              FROM relationship_to_concept
                              )
  AND dcs.concept_name NOT IN (
                              SELECT DISTINCT name
                              FROM supplier_mapped
                              WHERE name IS NOT NULL
                              )
ORDER BY dcs.concept_name
;

-- supplier_to_map
SELECT DISTINCT tm.name,
                '' AS new_name,
                '' AS comment,
                NULL AS precedence,
                NULL AS target_concept_id,
                NULL AS concept_code,
                NULL AS concept_name,
                NULL AS concept_class_id,
                NULL AS standard_concept,
                NULL AS invalid_reason,
                NULL AS domain_id,
                NULL AS target_vocabulary_id
FROM supplier_to_map tm
WHERE lower(tm.name) NOT IN (
                            SELECT lower(new_name)
                            FROM supplier_mapped
                            WHERE new_name IS NOT NULL
                            )
ORDER BY tm.name;

--4. Dose Form
-- update 'U/D' in dose_form_mapped
WITH to_be_updated AS (
                      SELECT DISTINCT dfm.name,
                                      dfm.concept_id_2 AS concept_id_2,
                                      c2.concept_id AS new_concept_id_2,
                                      c2.concept_name AS new_concept_name_2
                      FROM dose_form_mapped dfm
                      JOIN concept c1
                          ON dfm.concept_id_2 = c1.concept_id
                              AND c1.invalid_reason = 'U'
                      JOIN concept_relationship cr
                          ON cr.concept_id_1 = c1.concept_id
                              AND cr.relationship_id = 'Concept replaced by' AND cr.invalid_reason IS NULL
                      JOIN concept c2
                          ON c2.concept_id = cr.concept_id_2
                              AND c2.concept_class_id = 'Dose Form'
                              AND c2.vocabulary_id LIKE 'RxNorm%'
                              AND c2.invalid_reason IS NULL
                      WHERE
--excluding names mapped to > 1 concept
dfm.name NOT IN (
                SELECT dfm2.name
                FROM dose_form_mapped dfm2
                GROUP BY dfm2.name
                HAVING count(*) > 1
                )
                      )
UPDATE dose_form_mapped dfm
SET concept_id_2 = to_be_updated.new_concept_id_2,
    mapping_type = 'rtc_backup_U/D + link to Valid'
FROM to_be_updated
WHERE dfm.name = to_be_updated.name;

--delete from dose_form_mapped if target concept is still U/D
WITH to_be_deleted AS (
                      SELECT *
                      FROM dose_form_mapped
                      WHERE concept_id_2 IN (
                                            SELECT concept_id
                                            FROM concept
                                            WHERE invalid_reason IS NOT NULL
                                            )
                      )
DELETE
FROM dose_form_mapped
WHERE name IN (
              SELECT name
              FROM to_be_deleted
              )
;

--Mapping from previous relationship_to_concept run, based on name and concept_class_id match
INSERT INTO relationship_to_concept(concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor, mapping_type)
SELECT DISTINCT dcs.concept_code, 'DPD', c.concept_id, bu.precedence, bu.conversion_factor, 'prev_rtc'
FROM prev_rtc bu
JOIN devv5.concept c
ON bu.concept_id_2 = c.concept_id
JOIN drug_concept_stage dcs
ON upper(dcs.concept_name) = upper(bu.concept_name_1)
WHERE bu.concept_class_id_1 = 'Dose Form'
  AND c.concept_class_id = 'Dose Form'
  AND c.invalid_reason IS NULL
  AND c.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
  AND dcs.concept_class_id = 'Dose Form'
  AND dcs.concept_code NOT IN (
                              SELECT DISTINCT concept_code_1
                              FROM relationship_to_concept
                              )
  AND dcs.concept_name NOT IN (
                              SELECT DISTINCT name
                              FROM ingredient_mapped
                              WHERE name IS NOT NULL
                              )
;

DROP TABLE IF EXISTS dose_form_to_map;

--dose_form to_map
CREATE TABLE IF NOT EXISTS dose_form_to_map AS
SELECT DISTINCT dcs.concept_name AS name
FROM drug_concept_stage dcs
WHERE concept_class_id = 'Dose Form'
  AND dcs.concept_name NOT IN (
                              SELECT DISTINCT name
                              FROM dose_form_mapped
                              WHERE name IS NOT NULL
                              )
ORDER BY dcs.concept_name
;

-- dose_form_to_map
SELECT DISTINCT tm.name,
                '' AS new_name,
                '' AS comment,
                NULL AS precedence,
                NULL AS target_concept_id,
                NULL AS concept_code,
                NULL AS concept_name,
                NULL AS concept_class_id,
                NULL AS standard_concept,
                NULL AS invalid_reason,
                NULL AS domain_id,
                NULL AS target_vocabulary_id
FROM dose_form_to_map tm
WHERE lower(tm.name) NOT IN (
                            SELECT lower(new_name)
                            FROM dose_form_mapped
                            WHERE new_name IS NOT NULL
                            )
ORDER BY tm.name;

--5. Unit
--delete from unit_mapped if target concept is U/D
WITH to_be_deleted AS (
                      SELECT *
                      FROM unit_mapped
                      WHERE concept_id_2 IN (
                                            SELECT concept_id
                                            FROM concept
                                            WHERE invalid_reason IS NOT NULL
                                            )
                      )
DELETE
FROM unit_mapped
WHERE name IN (
              SELECT name
              FROM to_be_deleted
              )
;

--Mapping from previous relationship_to_concept run, based on name and concept_class_id match
INSERT INTO relationship_to_concept(concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor, mapping_type)
SELECT DISTINCT dcs.concept_code, 'DPD', c.concept_id, bu.precedence, bu.conversion_factor, 'prev_rtc'
FROM prev_rtc bu
JOIN devv5.concept c
ON bu.concept_id_2 = c.concept_id
JOIN drug_concept_stage dcs
ON upper(dcs.concept_name) = upper(bu.concept_name_1)
WHERE bu.concept_class_id_1 = 'Unit'
  AND c.concept_class_id = 'Unit'
  AND c.invalid_reason IS NULL
  AND dcs.concept_class_id = 'Unit'
  AND dcs.concept_code NOT IN (
                              SELECT DISTINCT concept_code_1
                              FROM relationship_to_concept
                              )
  AND dcs.concept_name NOT IN (
                              SELECT DISTINCT name
                              FROM ingredient_mapped
                              WHERE name IS NOT NULL
                              )
;

DROP TABLE IF EXISTS unit_to_map;

--unit to_map
CREATE TABLE IF NOT EXISTS unit_to_map AS
SELECT DISTINCT dcs.concept_name AS name
FROM drug_concept_stage dcs
WHERE concept_class_id = 'Unit'
  AND dcs.concept_name NOT IN (
                              SELECT DISTINCT name
                              FROM unit_mapped
                              WHERE name IS NOT NULL
                              )
ORDER BY dcs.concept_name
;

--unit_to_map
SELECT DISTINCT tm.name,
                '' AS new_name,
                '' AS comment,
                NULL AS precedence,
                NULL AS conversion_factor,
                NULL AS target_concept_id,
                NULL AS concept_code,
                NULL AS concept_name,
                NULL AS concept_class_id,
                NULL AS standard_concept,
                NULL AS invalid_reason,
                NULL AS domain_id,
                NULL AS target_vocabulary_id
FROM unit_to_map tm
WHERE lower(tm.name) NOT IN (
                            SELECT lower(new_name)
                            FROM unit_mapped
                            WHERE new_name IS NOT NULL
                            )
ORDER BY tm.name;

--TODO: Integration into existing load_stage, including names changed during manual mapping
--TODO: Manual review of automapping and mapping through prev_rtc (divide by categories, most attention on units)


-------------------------------------
--TODO: Create backup of rtc (prev_rtc)
/*
CREATE TABLE prev_rtc
(
concept_code_1 varchar(255),
concept_name_1 varchar(255),
concept_class_id_1 varchar(255),
concept_code_2 varchar(255),
concept_name_2 varchar(255),
concept_class_id_2 varchar(255),
concept_id_2 int,
invalid_reason_2 varchar(20),
precedence int,
conversion_factor float
);

select distinct prev_rtc.*
from ingredient_to_map
join prev_rtc
on upper(ingredient_to_map.name) = upper(prev_rtc.concept_name_1)
AND concept_class_id_1 = 'Ingredient';

 */