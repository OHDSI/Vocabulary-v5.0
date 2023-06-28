-- models\2_load_stage\201_module_date.sql
-- Creates a view named module_date that extracts unique module versions based on certain criteria

{{ config(materialized='view') }}

{% set module_ids = [
    900000000000207008, --Core (international) module
    999000011000000103, --UK edition
    731000124108 --US edition
] %}

WITH module_date_unsorted AS (
    SELECT
        m.moduleid,
        TO_CHAR(m.sourceeffectivetime, 'yyyy-mm-dd') AS version
    FROM {{ source('sources', 'der2_ssrefset_moduledependency_merged') }} m
    WHERE m.active = 1
        AND m.referencedcomponentid = 900000000000012004
        AND m.moduleid IN ({{ module_ids|join(', ') }})
)
, module_date_ranked AS (
    SELECT
        moduleid,
        version,
        ROW_NUMBER() OVER (PARTITION BY moduleid ORDER BY version DESC) AS rn
    FROM module_date_unsorted
)
SELECT
    moduleid,
    version
FROM module_date_ranked
WHERE rn = 1
