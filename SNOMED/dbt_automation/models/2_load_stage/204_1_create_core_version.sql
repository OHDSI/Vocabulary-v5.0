-- models\2_load_stage\204_1_create_core_version.sql

{% set concept_stage_table = 'concept_stage' %}

WITH selected_concepts AS (
    SELECT
        vocabulary_pack.CutConceptName(d.term) AS concept_name,
        d.conceptid::TEXT AS concept_code,
        TO_DATE(c.effectivetime, 'yyyymmdd') AS valid_start_date,
        TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
        NULL AS invalid_reason,
        ROW_NUMBER() OVER (
            PARTITION BY d.conceptid
            ORDER BY
                c.active DESC,
                d.active DESC,
                -- ... (all the ordering logic from the original script) ...
                d.term
            ) AS rn
    FROM
        {{ ref('sources_sct2_concept_full_merged') }} c
    JOIN
        {{ ref('sources_sct2_desc_full_merged') }} d
        ON d.conceptid = c.id
    JOIN
        {{ ref('sources_der2_crefset_language_merged') }} l
        ON l.referencedcomponentid = d.id
)
INSERT INTO {{ target.schema }}.{{ concept_stage_table }} (
    concept_name,
    vocabulary_id,
    concept_code,
    valid_start_date,
    valid_end_date,
    invalid_reason
)
SELECT
    sct2.concept_name,
    'SNOMED' AS vocabulary_id,
    sct2.concept_code,
    sct2.valid_start_date,
    sct2.valid_end_date,
    sct2.invalid_reason
FROM
    selected_concepts sct2
WHERE
    sct2.rn = 1;
