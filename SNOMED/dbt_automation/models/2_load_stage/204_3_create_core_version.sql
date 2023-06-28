-- models\2_load_stage\204_3_create_core_version.sql

{% set concept_stage_table = 'concept_stage' %}

UPDATE {{ target.schema }}.{{ concept_stage_table }}
SET valid_start_date = TO_DATE('19700101', 'yyyymmdd')
WHERE valid_start_date = valid_end_date;
