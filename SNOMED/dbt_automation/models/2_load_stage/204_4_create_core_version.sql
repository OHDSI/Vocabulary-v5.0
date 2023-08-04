-- models\2_load_stage\204_4_create_core_version.sql

{% set concept_stage_table = 'concept_stage' %}

UPDATE {{ target.schema }}.{{ concept_stage_table }}
SET concept_name = vocabulary_pack.CutConceptName(TRANSLATE(concept_name, '>,<,^', '-'))
WHERE (
        (concept_name LIKE '%>%' AND concept_name LIKE '%<%')
        OR concept_name LIKE '%^%^%'
    )
    AND LENGTH(concept_name) > 5;
