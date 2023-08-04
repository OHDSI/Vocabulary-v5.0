{% macro set_latest_update() %}

    {% set pVocabularyName = "'SNOMED'" %}
    {% set pVocabularyDevSchema = "'DEV_SNOMED'" %}

    {% set pVocabularyDate_query %}
        SELECT vocabulary_date FROM {{ source('sources', 'sct2_concept_full_merged') }} LIMIT 1
    {% endset %}

    {% set pVocabularyVersion_query %}
        SELECT 
            (SELECT version FROM {{ ref('module_date') }} WHERE moduleid = 900000000000207008) || ' SNOMED CT International Edition; ' ||
            (SELECT version FROM {{ ref('module_date') }} WHERE moduleid = 731000124108) || ' SNOMED CT US Edition; ' ||
            (SELECT version FROM {{ ref('module_date') }} WHERE moduleid = 999000011000000103) || ' SNOMED CT UK Edition'
    {% endset %}

    {% set call_query %}
        SELECT VOCABULARY_PACK.SetLatestUpdate(
            pVocabularyName => {{ pVocabularyName }},
            pVocabularyDate => ({{ pVocabularyDate_query }}),
            pVocabularyVersion => ({{ pVocabularyVersion_query }}),
            pVocabularyDevSchema => {{ pVocabularyDevSchema }}
        );
    {% endset %}

    {{ return(call_query) }}

{% endmacro %}
