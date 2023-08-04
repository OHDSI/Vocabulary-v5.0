-- models\2_load_stage\204_2_create_core_version.sql

{% set concept_stage_table = 'concept_stage' %}

WITH inactive AS (
    SELECT
        c.id,
        MAX(c.effectivetime) AS effectiveend
    FROM
        {{ ref('sources_sct2_concept_full_merged') }} c
    LEFT JOIN
        {{ ref('sources_sct2_concept_full_merged') }} c2
        ON c2.active = 1 AND c.id = c2.id AND c.effectivetime < c2.effectivetime
    WHERE
        c2.id IS NULL AND c.active = 0
    GROUP BY
        c.id
)
UPDATE
    {{ target.schema }}.{{ concept_stage_table }} cs
SET
    invalid_reason = 'D',
    valid_end_date = TO_DATE(i.effectiveend, 'yyyymmdd')
FROM
    inactive i
WHERE
    i.id::TEXT = cs.concept_code;
