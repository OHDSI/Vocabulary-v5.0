--=============================================== INGREDIENTS ==============================================
--1. create table and load mm.data
-- DROP TABLE IF EXISTS ingredient_mm;

CREATE TABLE IF NOT EXISTS ingredient_mm
(
    name                 varchar(255) NOT NULL,
    CONSTRAINT chk_name
        CHECK ((name)::text <> ''::text),
    new_name             varchar(255),
    comment              varchar(255),
    precedence           int,
    target_concept_id    int,
    concept_code         varchar(50),
    concept_name         varchar(255),
    concept_class_id     varchar(20),
    standard_concept     varchar(20),
    invalid_reason       varchar(20),
    domain_id            varchar(20),
    target_vocabulary_id varchar(20)
);


--2. mm. checks
--target concepts exist in the concept table check
SELECT *
FROM ingredient_mm j1
WHERE NOT EXISTS(SELECT *
                 FROM ingredient_mm j2
                 JOIN concept c
                     ON j2.target_concept_id = c.concept_id
                         AND c.concept_name = j2.concept_name
                         AND c.vocabulary_id = j2.target_vocabulary_id
                         AND c.domain_id = j2.domain_id
                         AND c.standard_concept = 'S'
                         AND c.invalid_reason IS NULL
    )
  AND target_concept_id NOT IN (0, 17)
  AND target_concept_id IS NOT NULL
;

-- each concept have 'Ingredient' concept_class_id check
SELECT *
FROM ingredient_mm
WHERE concept_class_id <> 'Ingredient'
  AND target_concept_id NOT IN (0, 17)
  AND target_concept_id IS NOT NULL;

-- each concept with name count > 1 must have manually assigned precedence check
SELECT name
FROM ingredient_mm
WHERE precedence IS NULL
GROUP BY name
HAVING count(name) > 1;

-- target_id validity check
SELECT mm.*
FROM ingredient_mm mm
JOIN concept c
    ON mm.target_concept_id = c.concept_id
WHERE mm.target_concept_id IS NOT NULL
  AND c.standard_concept IS NULL
  AND mm.target_concept_id NOT IN (0, 17);

-- mm mapping consistency (target id-name) check
SELECT *
FROM ingredient_mm mm
JOIN concept c
    ON mm.target_concept_id = c.concept_id
WHERE mm.concept_name <> c.concept_name
  AND mm.target_concept_id NOT IN (0, 17);

-- new_name is equal to space symbol(s)
SELECT *
FROM ingredient_mm mm
WHERE mm.new_name ~* '^[ ]+$';


--3. Insert ingredients into ingredient_mapped from manual_mapping
INSERT INTO ingredient_mapped (name, new_name, concept_id_2, precedence, mapping_type)
SELECT DISTINCT
    name,
    CASE
        WHEN new_name <> ''
            THEN new_name
        ELSE NULL
        END AS new_name,
    target_concept_id,
    coalesce(precedence, 1),
    'manual_mapping'
FROM ingredient_mm
WHERE name NOT IN (
                  SELECT name
                  FROM ingredient_mapped
                  )
--WHERE target_concept_id IS NOT NULL
--  AND target_concept_id NOT IN (17, 0)
;

--=============================================== BRAND NAMES ==============================================
--1. create table and load mm.data
-- DROP TABLE IF EXISTS brand_name_mm;

CREATE TABLE IF NOT EXISTS brand_name_mm
(
    name                 varchar(255) NOT NULL,
    CONSTRAINT chk_name
        CHECK ((name)::text <> ''::text),
    new_name             varchar(255),
    comment              varchar(255),
    precedence           int,
    target_concept_id    int,
    concept_code         varchar(50),
    concept_name         varchar(255),
    concept_class_id     varchar(20),
    standard_concept     varchar(20),
    invalid_reason       varchar(20),
    domain_id            varchar(20),
    target_vocabulary_id varchar(20)
);


--2. brand_name_mm. checks
--target concepts exist in the concept table check
SELECT *
FROM brand_name_mm j1
WHERE NOT EXISTS(SELECT *
                 FROM brand_name_mm j2
                 JOIN concept c
                     ON j2.target_concept_id = c.concept_id
                         AND c.concept_name = j2.concept_name
                         AND c.vocabulary_id = j2.target_vocabulary_id
                         AND c.domain_id = j2.domain_id
                         AND c.invalid_reason IS NULL
    )
  AND target_concept_id NOT IN (0, 17)
  AND target_concept_id IS NOT NULL
;

-- each concept have 'Brand Name' concept_class_id check
SELECT *
FROM brand_name_mm
WHERE concept_class_id <> 'Brand Name'
  AND target_concept_id NOT IN (0, 17)
  AND target_concept_id IS NOT NULL;

-- each concept with name count > 1 must have manually assigned precedence check
SELECT name
FROM brand_name_mm
WHERE precedence IS NULL
GROUP BY name
HAVING count(name) > 1;

-- target_id validity check
SELECT mm.*
FROM brand_name_mm mm
JOIN concept c
    ON mm.target_concept_id = c.concept_id
WHERE mm.target_concept_id IS NOT NULL
  AND c.invalid_reason IS NOT NULL
  AND mm.target_concept_id NOT IN (0, 17);

-- mm mapping consistency (target id-name) check
SELECT *
FROM brand_name_mm mm
JOIN concept c
    ON mm.target_concept_id = c.concept_id
WHERE mm.concept_name <> c.concept_name
  AND mm.target_concept_id NOT IN (0, 17);

-- new_name is equal to space symbol(s)
SELECT *
FROM brand_name_mm mm
WHERE mm.new_name ~* '^[ ]+$';

--3. Insert brand_names into brand_name_mapped from manual_mapping
INSERT INTO brand_name_mapped (name, new_name, concept_id_2, precedence, mapping_type)
SELECT DISTINCT
    name,
    CASE
        WHEN new_name <> ''
            THEN new_name
        ELSE NULL
        END AS new_name,
    target_concept_id,
    coalesce(precedence, 1),
    'manual_mapping'
FROM brand_name_mm
WHERE name NOT IN (
                  SELECT name
                  FROM brand_name_mapped
                  )
--WHERE target_concept_id IS NOT NULL
--  AND target_concept_id NOT IN (17, 0)
;


--=============================================== SUPPLIER ==============================================
--1. create table and load mm.data
-- DROP TABLE IF EXISTS supplier_mm;

CREATE TABLE IF NOT EXISTS supplier_mm
(
    name                 varchar(255) NOT NULL,
    CONSTRAINT chk_name
        CHECK ((name)::text <> ''::text),
    new_name             varchar(255),
    comment              varchar(255),
    precedence           int,
    target_concept_id    int,
    concept_code         varchar(50),
    concept_name         varchar(255),
    concept_class_id     varchar(20),
    standard_concept     varchar(20),
    invalid_reason       varchar(20),
    domain_id            varchar(20),
    target_vocabulary_id varchar(20)
);


--2. _mm checks
--target concepts exist in the concept table check
SELECT *
FROM supplier_mm j1
WHERE NOT EXISTS(SELECT *
                 FROM supplier_mm j2
                 JOIN concept c
                     ON j2.target_concept_id = c.concept_id
                         AND c.concept_name = j2.concept_name
                         AND c.vocabulary_id = j2.target_vocabulary_id
                         AND c.domain_id = j2.domain_id
                         AND c.invalid_reason IS NULL
    )
  AND target_concept_id NOT IN (0, 17)
  AND target_concept_id IS NOT NULL
;

-- each concept have 'Supplier' concept_class_id check
SELECT *
FROM supplier_mm
WHERE concept_class_id <> 'Supplier'
  AND target_concept_id NOT IN (0, 17)
  AND target_concept_id IS NOT NULL;

-- each concept with name count > 1 must have manually assigned precedence check
SELECT name
FROM supplier_mm
WHERE precedence IS NULL
GROUP BY name
HAVING count(name) > 1;

-- target_id validity check
SELECT mm.*
FROM supplier_mm mm
JOIN concept c
    ON mm.target_concept_id = c.concept_id
WHERE mm.target_concept_id IS NOT NULL
  AND c.invalid_reason IS NOT NULL
  AND mm.target_concept_id NOT IN (0, 17);

-- mm mapping consistency (target id-name) check
SELECT *
FROM supplier_mm mm
JOIN concept c
    ON mm.target_concept_id = c.concept_id
WHERE mm.concept_name <> c.concept_name
  AND mm.target_concept_id NOT IN (0, 17);

-- new_name is equal to space symbol(s)
SELECT *
FROM supplier_mm mm
WHERE mm.new_name ~* '^[ ]+$';

--3. Insert suppliers into supplier_mapped from manual_mapping
INSERT INTO supplier_mapped (name, new_name, concept_id_2, precedence, mapping_type)
SELECT DISTINCT
    name,
    CASE
        WHEN new_name <> ''
            THEN new_name
        ELSE NULL
        END AS new_name,
    target_concept_id,
    coalesce(precedence, 1),
    'manual_mapping'
FROM supplier_mm
WHERE name NOT IN (
                  SELECT name
                  FROM supplier_mapped
                  )
--WHERE target_concept_id IS NOT NULL
--  AND target_concept_id NOT IN (17, 0)
;


--=============================================== DOSE FORM ==============================================
--1. create table and load mm.data
-- DROP TABLE IF EXISTS dose_form_mm;

CREATE TABLE IF NOT EXISTS dose_form_mm
(
    name                 varchar(255) NOT NULL,
    CONSTRAINT chk_name
        CHECK ((name)::text <> ''::text),
    new_name             varchar(255),
    comment              varchar(255),
    precedence           int,
    target_concept_id    int,
    concept_code         varchar(50),
    concept_name         varchar(255),
    concept_class_id     varchar(20),
    standard_concept     varchar(20),
    invalid_reason       varchar(20),
    domain_id            varchar(20),
    target_vocabulary_id varchar(20)
);


--2. _mm checks
--target concepts exist in the concept table check
SELECT *
FROM dose_form_mm j1
WHERE NOT EXISTS(SELECT *
                 FROM dose_form_mm j2
                 JOIN concept c
                     ON j2.target_concept_id = c.concept_id
                         AND c.concept_name = j2.concept_name
                         AND c.vocabulary_id = j2.target_vocabulary_id
                         AND c.domain_id = j2.domain_id
                         AND c.invalid_reason IS NULL
    )
  AND target_concept_id NOT IN (0, 17)
  AND target_concept_id IS NOT NULL
;

-- each concept have 'Dose Form' concept_class_id check
SELECT *
FROM dose_form_mm
WHERE concept_class_id <> 'Dose Form'
  AND target_concept_id NOT IN (0, 17)
  AND target_concept_id IS NOT NULL;

-- each concept with name count > 1 must have manually assigned precedence check
SELECT name
FROM dose_form_mm
WHERE precedence IS NULL
GROUP BY name
HAVING count(name) > 1;

-- target_id validity check
SELECT mm.*
FROM dose_form_mm mm
JOIN concept c
    ON mm.target_concept_id = c.concept_id
WHERE mm.target_concept_id IS NOT NULL
  AND c.invalid_reason IS NOT NULL
  AND mm.target_concept_id NOT IN (0, 17);

-- mm mapping consistency (target id-name) check
SELECT *
FROM dose_form_mm mm
JOIN concept c
    ON mm.target_concept_id = c.concept_id
WHERE mm.concept_name <> c.concept_name
  AND mm.target_concept_id NOT IN (0, 17);

-- new_name is equal to space symbol(s)
SELECT *
FROM dose_form_mm mm
WHERE mm.new_name ~* '^[ ]+$';

--3. Insert dose forms into dose_form_mapped from manual_mapping
INSERT INTO dose_form_mapped (name, new_name, concept_id_2, precedence, mapping_type)
SELECT DISTINCT
    name,
    CASE
        WHEN new_name <> ''
            THEN new_name
        ELSE NULL
        END AS new_name,
    target_concept_id,
    coalesce(precedence, 1),
    'manual_mapping'
FROM dose_form_mm
WHERE name NOT IN (
                  SELECT name
                  FROM dose_form_mapped
                  )
--WHERE target_concept_id IS NOT NULL
--  AND target_concept_id NOT IN (17, 0)
;


--=============================================== UNIT ==============================================
--1. create table and load mm.data
-- DROP TABLE IF EXISTS unit_mm;

CREATE TABLE IF NOT EXISTS unit_mm
(
    name                 varchar(255) NOT NULL,
    CONSTRAINT chk_name
        CHECK ((name)::text <> ''::text),
    new_name             varchar(255),
    comment              varchar(255),
    precedence           int,
    conversion_factor    float,
    CONSTRAINT conversion_factor
        CHECK ( conversion_factor IS NOT NULL ),
    target_concept_id    INT,
    concept_code         varchar(50),
    concept_name         varchar(255),
    concept_class_id     varchar(20),
    standard_concept     varchar(20),
    invalid_reason       varchar(20),
    domain_id            varchar(20),
    target_vocabulary_id varchar(20)
);


--2. _mm checks
--target concepts exist in the concept table check
SELECT *
FROM unit_mm j1
WHERE NOT EXISTS(SELECT *
                 FROM unit_mm j2
                 JOIN concept c
                     ON j2.target_concept_id = c.concept_id
                         AND c.concept_name = j2.concept_name
                         AND c.vocabulary_id = j2.target_vocabulary_id
                         AND c.domain_id = j2.domain_id
                         AND c.standard_concept = 'S'
                         AND c.invalid_reason IS NULL
    )
  AND target_concept_id NOT IN (0, 17)
  AND target_concept_id IS NOT NULL
;

-- each concept have 'Unit' concept_class_id check
SELECT *
FROM unit_mm
WHERE concept_class_id <> 'Unit'
  AND target_concept_id NOT IN (0, 17)
  AND target_concept_id IS NOT NULL;

-- each concept with name count > 1 must have manually assigned precedence check
SELECT name
FROM unit_mm
WHERE precedence IS NULL
GROUP BY name
HAVING count(name) > 1;

-- target_id validity check
SELECT mm.*
FROM unit_mm mm
JOIN concept c
    ON mm.target_concept_id = c.concept_id
WHERE mm.target_concept_id IS NOT NULL
  AND c.invalid_reason IS NOT NULL
  AND mm.target_concept_id NOT IN (0, 17);

-- mm mapping consistency (target id-name) check
SELECT *
FROM unit_mm mm
JOIN concept c
    ON mm.target_concept_id = c.concept_id
WHERE mm.concept_name <> c.concept_name
  AND mm.target_concept_id NOT IN (0, 17);

-- new_name is equal to space symbol(s)
SELECT *
FROM unit_mm mm
WHERE mm.new_name ~* '^[ ]+$';

--3. Insert units into unit_mapped from manual_mapping
INSERT INTO unit_mapped (name, new_name, concept_id_2, precedence, conversion_factor, mapping_type)
SELECT DISTINCT
    name,
    CASE
        WHEN new_name <> ''
            THEN new_name
        ELSE NULL
        END AS new_name,
    target_concept_id,
    coalesce(precedence, 1),
    conversion_factor,
    'manual_mapping'
FROM unit_mm
WHERE name NOT IN (
                  SELECT name
                  FROM unit_mapped
                  )
--WHERE target_concept_id IS NOT NULL
--  AND target_concept_id NOT IN (17, 0)
;
