/*
================================================================================
1 - rule-based candidates selection.sql
================================================================================

Purpose
-------
Create the rule-based portion of the oncology mining review set.

The script finds SNOMED, LOINC and NAACCR candidates through oncology keywords,
known oncology source vocabularies, ICD C-code sources, LOINC stage/grade anchors,
SNOMED ancestor expansion and mapped concepts.

Created objects
---------------
- oncology_concepts_mined_with_rules

Run order
---------
Run before the root-seed and Hecate mining steps. The resulting table is merged
with Hecate output in "5 - table assembling.sql".
================================================================================
*/

-- -----------------------------------------------------------------------------
-- Section 01.01: Recreate rule-based candidate table
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS dev_cancer_modifier.oncology_concepts_mined_with_rules;

CREATE TABLE dev_cancer_modifier.oncology_concepts_mined_with_rules AS
WITH target_vocabularies(vocabulary_id) AS (
    VALUES
        ('NAACCR'),
        ('LOINC'),
        ('SNOMED')
),

loinc_stages(concept_id) AS (
    VALUES
        (3008495),
        (3022698),
        (3027109),
        (21490957),
        (21491883)
),

loinc_grades(concept_id) AS (
    VALUES
        (3019275),
        (3022835),
        (3042773),
        (3044724),
        (3047277),
        (3047285),
        (36660173),
        (36660206),
        (40762604),
        (42527714),
        (42527790)
),

snomed AS (
    SELECT
        ca.descendant_concept_id AS concept_id,
        ca.ancestor_concept_id   AS ancestor_concept_id
    FROM concept_ancestor ca
    WHERE ca.ancestor_concept_id IN (
        37163866,
        37168578,
        4216788,
        4264604
    )
),

co_source_paths AS (
    -- -------------------------------------------------------------------------
    -- Collect broad oncology source paths before restricting to target outputs
    -- -------------------------------------------------------------------------

    SELECT
        c.concept_id,
        jsonb_build_object(
            'entry_type', 'keyword_search:cancer',
            'matched_concept_id', c.concept_id
        ) AS path
    FROM concept c
    WHERE c.concept_name ILIKE '%cancer%'

    UNION ALL

    SELECT
        c.concept_id,
        jsonb_build_object(
            'entry_type', 'keyword_search:metasta',
            'matched_concept_id', c.concept_id
        ) AS path
    FROM concept c
    WHERE c.concept_name ILIKE '%metasta%'

    UNION ALL

    SELECT
        c.concept_id,
        jsonb_build_object(
            'entry_type', 'keyword_search:carcino',
            'matched_concept_id', c.concept_id
        ) AS path
    FROM concept c
    WHERE c.concept_name ILIKE '%carcino%'

    UNION ALL

    SELECT
        c.concept_id,
        jsonb_build_object(
            'entry_type', 'keyword_search:malignan with exclusions',
            'matched_concept_id', c.concept_id
        ) AS path
    FROM concept c
    WHERE c.concept_name ILIKE '%malignan%'
      AND c.concept_name NOT ILIKE '%nonmalignant%'
      AND c.concept_name NOT ILIKE '%non-malignant%'
      AND c.concept_name NOT LIKE '%AND/OR%'
      AND c.concept_name NOT ILIKE '%bone pain%'
      AND c.concept_name NOT ILIKE '%cachexia%'
      AND c.concept_name NOT ILIKE '%cerebral artery syndrome%'
      AND c.concept_name NOT ILIKE '%chylothorax%'
      AND c.concept_name NOT ILIKE '%endocarditis%'
      AND c.concept_name NOT ILIKE '%fibrosis%'
      AND c.concept_name NOT ILIKE '%hypertension%'
      AND c.concept_name NOT ILIKE '%hypertensive%'
      AND c.concept_name NOT ILIKE '%hyperthermia%'
      AND c.concept_name NOT ILIKE '%nephrosclerosis%'
      AND c.concept_name NOT ILIKE '%neuroleptic%'
      AND c.concept_name NOT ILIKE '%osteoporosis%'
      AND c.concept_name NOT ILIKE '%otitis%'
      AND c.concept_name NOT ILIKE '%papulosis%'
      AND c.concept_name NOT ILIKE '%pyoderma%'
      AND c.concept_name NOT ILIKE '%sclerosis%'
      AND c.concept_name NOT ILIKE '%seizure%'
      AND c.concept_name NOT ILIKE '%stricture%'
      AND c.concept_name NOT ILIKE '%tertian fever%'
      AND c.concept_name NOT ILIKE '%vasovagal%'
      AND c.concept_name NOT ILIKE '%ventriculitis%'
      AND c.concept_name NOT ILIKE '%vertigo%'
      AND c.concept_name NOT ILIKE '%retinitis%'
      AND c.concept_name NOT ILIKE '%calcification of skin%'
      AND c.concept_name NOT ILIKE '%cord compression%'

    UNION ALL

    SELECT
        c.concept_id,
        jsonb_build_object(
            'entry_type', 'keyword_search:neoplas with exclusions',
            'matched_concept_id', c.concept_id
        ) AS path
    FROM concept c
    WHERE c.concept_name ILIKE '%neoplas%'
      AND c.concept_name NOT ILIKE '%nonmalignant%'
      AND c.concept_name NOT ILIKE '%non-malignant%'

    UNION ALL

    SELECT
        c.concept_id,
        jsonb_build_object(
            'entry_type', 'keyword_search:tumor',
            'matched_concept_id', c.concept_id
        ) AS path
    FROM concept c
    WHERE c.concept_name ILIKE '%tumor%'

    UNION ALL

    SELECT
        c.concept_id,
        jsonb_build_object(
            'entry_type', 'keyword_search:onco',
            'matched_concept_id', c.concept_id
        ) AS path
    FROM concept c
    WHERE c.concept_name ILIKE '% onco%'

    UNION ALL

    SELECT
        c.concept_id,
        jsonb_build_object(
            'entry_type', 'keyword_search:biops',
            'matched_concept_id', c.concept_id
        ) AS path
    FROM concept c
    WHERE c.concept_name ILIKE '%biops%'

    UNION ALL

    SELECT
        c.concept_id,
        jsonb_build_object(
            'entry_type', 'keyword_search:debulk',
            'matched_concept_id', c.concept_id
        ) AS path
    FROM concept c
    WHERE c.concept_name ILIKE '%debulk%'

    UNION ALL

    SELECT
        c.concept_id,
        jsonb_build_object(
            'entry_type', 'keyword_search:chemotherap',
            'matched_concept_id', c.concept_id
        ) AS path
    FROM concept c
    WHERE c.concept_name ILIKE '%chemotherap%'

    UNION ALL

    SELECT
        c.concept_id,
        jsonb_build_object(
            'entry_type', 'keyword_search:radiotherap',
            'matched_concept_id', c.concept_id
        ) AS path
    FROM concept c
    WHERE c.concept_name ILIKE '%radiotherap%'

    UNION ALL

    SELECT
        c.concept_id,
        jsonb_build_object(
            'entry_type', 'target_or_mapping_source_vocabulary',
            'matched_concept_id', c.concept_id
        ) AS path
    FROM concept c
    WHERE c.vocabulary_id IN (
        'ICDO3',
        'CAP',
        'NAACCR',
        'Cancer Modifier',
        'OncoTree',
        'HemOnc'
    )

    UNION ALL

    SELECT
        c.concept_id,
        jsonb_build_object(
            'entry_type', 'icd_c_code_mapping_source',
            'matched_concept_id', c.concept_id
        ) AS path
    FROM concept c
    WHERE c.vocabulary_id IN ('ICD10', 'ICD10CM', 'ICD10GM', 'CIM10')
      AND c.concept_code LIKE 'C%'

    UNION ALL

    SELECT
        ls.concept_id,
        jsonb_build_object(
            'entry_type', 'loinc_stage_question_seed',
            'matched_concept_id', ls.concept_id
        ) AS path
    FROM loinc_stages ls

    UNION ALL

    SELECT DISTINCT
        cr.concept_id_1 AS concept_id,
        jsonb_build_object(
            'entry_type', 'loinc_stage_answer',
            'question_concept_id', cr.concept_id_2
        ) AS path
    FROM concept_relationship cr
    JOIN loinc_stages ls
        ON ls.concept_id = cr.concept_id_2
    WHERE cr.relationship_id = 'Answer of'

    UNION ALL

    SELECT
        lg.concept_id,
        jsonb_build_object(
            'entry_type', 'loinc_grade_question_seed',
            'matched_concept_id', lg.concept_id
        ) AS path
    FROM loinc_grades lg

    UNION ALL

    SELECT DISTINCT
        cr.concept_id_1 AS concept_id,
        jsonb_build_object(
            'entry_type', 'loinc_grade_answer',
            'question_concept_id', cr.concept_id_2
        ) AS path
    FROM concept_relationship cr
    JOIN loinc_grades lg
        ON lg.concept_id = cr.concept_id_2
    WHERE cr.relationship_id = 'Answer of'

    UNION ALL

    SELECT
        s.concept_id,
        jsonb_build_object(
            'entry_type', 'snomed_descendant',
            'ancestor_concept_id', s.ancestor_concept_id
        ) AS path
    FROM snomed s

    UNION ALL

    SELECT
        cr.concept_id_2 AS concept_id,
        jsonb_build_object(
            'entry_type', 'snomed_concept_replaces',
            'concept_id_2', cr.concept_id_2
        ) AS path
    FROM snomed s
    JOIN concept_relationship cr
        ON cr.concept_id_1 = s.concept_id
       AND cr.relationship_id = 'Concept replaces'
),

final_paths AS (

    -- Direct hit: the discovered concept already belongs to a target vocabulary.
    SELECT
        cp.concept_id,
        jsonb_build_object(
            'entry_type', 'direct',
            'source_path', cp.path
        ) AS path
    FROM co_source_paths cp
    JOIN concept c
        ON c.concept_id = cp.concept_id
    JOIN target_vocabularies tv
        ON tv.vocabulary_id = c.vocabulary_id

    UNION ALL

    -- Mapped hit: the discovered source concept maps into a target vocabulary.
    SELECT
        cr.concept_id_2 AS concept_id,
        jsonb_build_object(
            'entry_type', 'mapped',
            'source_path', cp.path
        ) AS path
    FROM co_source_paths cp
    JOIN concept_relationship cr
        ON cr.concept_id_1 = cp.concept_id
       AND cr.invalid_reason IS NULL
       AND cr.relationship_id = 'Mapped from'
       AND cr.concept_id_1 != cr.concept_id_2
    JOIN concept target_c
        ON target_c.concept_id = cr.concept_id_2
    JOIN target_vocabularies tv
        ON tv.vocabulary_id = target_c.vocabulary_id
)

-- -----------------------------------------------------------------------------
-- Section 01.02: Collapse paths into one review row per candidate concept
-- -----------------------------------------------------------------------------
SELECT
    'Rule-based-mine' AS origin,
    c.*,
    jsonb_agg(DISTINCT fp.path) AS concept_paths
FROM final_paths fp
JOIN concept c
    ON c.concept_id = fp.concept_id
GROUP BY
    c.concept_id,
    c.concept_name,
    c.domain_id,
    c.vocabulary_id,
    c.concept_class_id,
    c.standard_concept,
    c.concept_code,
    c.valid_start_date,
    c.valid_end_date,
    c.invalid_reason
ORDER BY
    c.vocabulary_id,
    c.concept_id;
