-- models\1_create_source_tables\107_der2_ssrefset_moduledependency_merged.sql

{{ config(materialized='table') }}

DROP TABLE IF EXISTS {{ target.schema }}.DER2_SSREFSET_MODULEDEPENDENCY_MERGED;

CREATE TABLE {{ target.schema }}.DER2_SSREFSET_MODULEDEPENDENCY_MERGED
(
    ID                         VARCHAR(256),
    EFFECTIVETIME              VARCHAR(8),
    ACTIVE                     INTEGER,
    MODULEID                   BIGINT,
    REFSETID                   BIGINT,
    REFERENCEDCOMPONENTID      BIGINT,
    SOURCEEFFECTIVETIME        DATE,
    TARGETEFFECTIVETIME        DATE
);