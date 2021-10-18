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

-- RELATIONSHIP_TO_CONCEPT
DO
$$
    BEGIN
        ALTER TABLE relationship_to_concept
            ADD COLUMN mapping_type varchar(255);
    EXCEPTION
        WHEN duplicate_column THEN RAISE NOTICE 'column mapping_type already exists in relationship_to_concept.';
    END;
$$;


--1. Ingredients
--From prev_rtc (backup relationship_to_concept table from the previous run)
INSERT INTO relationship_to_concept (
	CONCEPT_CODE_1,
	VOCABULARY_ID_1,
	CONCEPT_ID_2,
	PRECEDENCE,
	CONVERSION_FACTOR,
    MAPPING_TYPE
	)
SELECT DISTINCT dcs.concept_code,
	'DPD',
    c.concept_id,
	precedence,
	conversion_factor,
    'prev_rtc'
FROM prev_rtc
JOIN drug_concept_stage dcs ON upper(prev_rtc.concept_name_1) = upper(dcs.concept_name)
	AND prev_rtc.concept_class_id_1 = 'Ingredient'
	AND dcs.concept_class_id = 'Ingredient'
JOIN devv5.concept_relationship cr
ON cr.concept_id_1 = prev_rtc.concept_id_2 AND cr.relationship_id IN ('Maps to', 'Concept replaced by')
JOIN devv5.concept c
ON cr.concept_id_2 = c.concept_id
WHERE c.standard_concept = 'S' AND c.invalid_reason IS NULL AND c.concept_class_id = 'Ingredient' AND c.vocabulary_id LIKE 'RxNorm%';
;

--From concept_name match
INSERT INTO relationship_to_concept (concept_code_1,
                                     vocabulary_id_1,
                                     concept_id_2,
                                     precedence,
                                     conversion_factor,
                                     mapping_type)
SELECT DISTINCT dcs.concept_code, --dcs.concept_name,
                'DPD',
                c.concept_id,     --c.concept_name,
                rank() OVER (PARTITION BY dcs.concept_code ORDER BY c.vocabulary_id, c.concept_id),
                NULL::double precision,
                'am_name_match'
FROM drug_concept_stage dcs
JOIN devv5.concept c
    ON upper(c.concept_name) = upper(dcs.concept_name)
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
INSERT INTO relationship_to_concept (concept_code_1,
                                     vocabulary_id_1,
                                     concept_id_2,
                                     precedence,
                                     conversion_factor,
                                     mapping_type)
SELECT DISTINCT dcs.concept_code, --dcs.concept_name,
                'DPD',
                cc.concept_id,    --cc.concept_name,
                rank() OVER (PARTITION BY dcs.concept_code ORDER BY c.vocabulary_id, c.concept_id),
                NULL::double precision,
                'am_precise_ing_name_match' AS mapping_type
FROM drug_concept_stage dcs
JOIN concept c
    ON upper(c.concept_name) = upper(dcs.concept_name)
        AND c.concept_class_id = 'Precise Ingredient'
        AND c.vocabulary_id LIKE 'RxNorm%'
        AND c.invalid_reason IS NULL
JOIN devv5.concept_relationship cr
    ON c.concept_id = cr.concept_id_1 AND cr.invalid_reason IS NULL
JOIN devv5.concept cc
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

--From DPD - RxNorm eq
INSERT INTO relationship_to_concept (concept_code_1,
                                     vocabulary_id_1,
                                     concept_id_2,
                                     precedence,
                                     conversion_factor,
                                     mapping_type)
SELECT DISTINCT dcs.concept_code, --dcs.concept_name,
                'DPD',
                cc.concept_id,    --cc.concept_name,
                rank() OVER (PARTITION BY dcs.concept_code ORDER BY c.vocabulary_id, c.concept_id),
                NULL::double precision,
                'Source - RxNorm eq' AS mapping_type
FROM drug_concept_stage dcs
JOIN concept c
    ON upper(c.concept_name) = upper(dcs.concept_name)
        AND c.vocabulary_id = 'DPD'
JOIN devv5.concept_relationship cr
    ON c.concept_id = cr.concept_id_1 AND cr.invalid_reason IS NULL AND relationship_id = 'Source - RxNorm eq'
JOIN devv5.concept cc
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


--TODO: Do we need to insert ingredients from ingredients_mapped here? Or they should be already present in prev_rtc (second run)?

--ingredients to_map
DROP TABLE IF EXISTS ingredient_to_map;
CREATE TABLE ingredient_to_map AS
SELECT DISTINCT dcs.concept_name AS name,
                '' AS new_name
FROM drug_concept_stage dcs
WHERE dcs.concept_class_id = 'Ingredient'
  AND dcs.concept_code NOT IN (
                              SELECT DISTINCT concept_code_1
                              FROM relationship_to_concept
                              )
  /*
  AND dcs.concept_name NOT IN (
                              SELECT DISTINCT name
                              FROM ingredient_mapped
                              WHERE name IS NOT NULL
                              )
   */
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
/*
WHERE upper(itm.name) NOT IN (
                             SELECT upper(new_name)
                             FROM ingredient_mapped
                             WHERE new_name IS NOT NULL
                             )
 */
ORDER BY itm.name;


--2. Brand Names
--From prev_rtc (backup relationship_to_concept table from the previous run)
INSERT INTO relationship_to_concept (
	CONCEPT_CODE_1,
	VOCABULARY_ID_1,
	CONCEPT_ID_2,
	PRECEDENCE,
	CONVERSION_FACTOR,
    MAPPING_TYPE
	)
SELECT DISTINCT dcs.concept_code,
	'DPD',
    c.concept_id,
	precedence,
	conversion_factor,
    'prev_rtc'
FROM prev_rtc
JOIN drug_concept_stage dcs ON upper(prev_rtc.concept_name_1) = upper(dcs.concept_name)
	AND prev_rtc.concept_class_id_1 = 'Brand Name'
	AND dcs.concept_class_id = 'Brand Name'
JOIN devv5.concept c
ON prev_rtc.concept_id_2 = c.concept_id
WHERE c.invalid_reason IS NULL AND c.concept_class_id = 'Brand Name' AND c.vocabulary_id LIKE 'RxNorm%';
;

--From concept_name match
INSERT INTO relationship_to_concept (concept_code_1,
                                     vocabulary_id_1,
                                     concept_id_2,
                                     precedence,
                                     conversion_factor,
                                     mapping_type)
SELECT DISTINCT dcs.concept_code, --dcs.concept_name,
                'DPD',
                c.concept_id,     --c.concept_name,
                rank() OVER (PARTITION BY dcs.concept_code ORDER BY c.vocabulary_id, c.concept_id),
                NULL::double precision,
                'am_name_match'
FROM drug_concept_stage dcs
JOIN devv5.concept c
    ON upper(c.concept_name) = upper(dcs.concept_name)
        AND c.concept_class_id = 'Brand Name'
        AND c.vocabulary_id LIKE 'RxNorm%'
        AND c.invalid_reason IS NULL
WHERE dcs.concept_class_id = 'Brand Name'
  AND NOT EXISTS(SELECT 1
                 FROM relationship_to_concept rtc
                 WHERE dcs.concept_code = rtc.concept_code_1
    )
;

--From DPD - RxNorm eq
INSERT INTO relationship_to_concept (concept_code_1,
                                     vocabulary_id_1,
                                     concept_id_2,
                                     precedence,
                                     conversion_factor,
                                     mapping_type)
SELECT DISTINCT dcs.concept_code, --dcs.concept_name,
                'DPD',
                cc.concept_id,    --cc.concept_name,
                rank() OVER (PARTITION BY dcs.concept_code ORDER BY c.vocabulary_id, c.concept_id),
                NULL::double precision,
                'Source - RxNorm eq' AS mapping_type
FROM drug_concept_stage dcs
JOIN concept c
    ON upper(c.concept_name) = upper(dcs.concept_name)
        AND c.vocabulary_id = 'DPD'
JOIN devv5.concept_relationship cr
    ON c.concept_id = cr.concept_id_1 AND cr.invalid_reason IS NULL AND relationship_id = 'Source - RxNorm eq'
    --For target concepts replaced by other RxNorm/Extension concepts
LEFT JOIN devv5.concept_relationship crr
    ON crr.concept_id_1 = cr.concept_id_2 AND crr.relationship_id = 'Concept replaced by'
JOIN devv5.concept cc
    ON coalesce(crr.concept_id_2, cr.concept_id_2) = cc.concept_id
        AND cc.concept_class_id = 'Brand Name'
        AND cc.vocabulary_id LIKE 'RxNorm%'
        AND cc.invalid_reason IS NULL
WHERE dcs.concept_class_id = 'Brand Name'
  AND NOT EXISTS(SELECT 1
                 FROM relationship_to_concept rtc
                 WHERE dcs.concept_code = rtc.concept_code_1
    )
--   AND dcs.concept_code not in (select concept_code from vaccines)
;


--Brand Names to_map
DROP TABLE IF EXISTS brand_name_to_map;
CREATE TABLE brand_name_to_map AS
SELECT DISTINCT dcs.concept_name AS name,
                '' AS new_name
FROM drug_concept_stage dcs
WHERE dcs.concept_class_id = 'Brand Name'
  AND dcs.concept_code NOT IN (
                              SELECT DISTINCT concept_code_1
                              FROM relationship_to_concept
                              )
  /*
  AND dcs.concept_name NOT IN (
                              SELECT DISTINCT name
                              FROM ingredient_mapped
                              WHERE name IS NOT NULL
                              )
   */
ORDER BY dcs.concept_name
;

--TODO: A lot of deprecated target rxnorm/rxnorm extension available through Source - RxNorm eq

-- Brand Names to map
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
FROM brand_name_to_map itm
/*
WHERE upper(itm.name) NOT IN (
                             SELECT upper(new_name)
                             FROM ingredient_mapped
                             WHERE new_name IS NOT NULL
                             )
 */
ORDER BY itm.name;