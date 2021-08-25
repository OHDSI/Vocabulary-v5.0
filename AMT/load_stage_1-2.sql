--Insert ingredients into ingredient_mapped from manual_mapping
INSERT INTO ingredient_mapped (name, new_name, concept_id_2, precedence, mapping_type)
SELECT DISTINCT
    name,
    CASE
        WHEN new_name <> ''
            THEN new_name
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

--Insert brand_names into brand_name_mapped from manual_mapping
INSERT INTO brand_name_mapped (name, new_name, concept_id_2, precedence, mapping_type)
SELECT DISTINCT
    name,
    CASE
        WHEN new_name <> ''
            THEN new_name
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

-- Insert suppliers into supplier_mapped from manual_mapping
INSERT INTO supplier_mapped (name, new_name, concept_id_2, precedence, mapping_type)
SELECT DISTINCT
    name,
    CASE
        WHEN new_name <> ''
            THEN new_name
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

-- Insert dose forms into dose_form_mapped from manual_mapping
INSERT INTO dose_form_mapped (name, new_name, concept_id_2, precedence, mapping_type)
SELECT DISTINCT
    name,
    CASE
        WHEN new_name <> ''
            THEN new_name
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

-- Insert units into unit_mapped from manual_mapping
INSERT INTO unit_mapped (name, new_name, concept_id_2, precedence, conversion_factor, mapping_type)
SELECT DISTINCT
    name,
    CASE
        WHEN new_name <> ''
            THEN new_name
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
