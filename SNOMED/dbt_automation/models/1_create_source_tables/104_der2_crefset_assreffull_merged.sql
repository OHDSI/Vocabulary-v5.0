-- models\1_create_source_tables\104_der2_crefset_assreffull_merged.sql

{{ config(materialized='table') }}

DROP TABLE IF EXISTS {{ target.schema }}.DER2_CREFSET_ASSREFFULL_MERGED;

CREATE TABLE {{ target.schema }}.DER2_CREFSET_ASSREFFULL_MERGED
(
    ID                         VARCHAR(256),
    EFFECTIVETIME              VARCHAR(8),
    ACTIVE                     INTEGER,
    MODULEID                   BIGINT,
    REFSETID                   BIGINT,
    REFERENCEDCOMPONENTID      BIGINT,
    TARGETCOMPONENT            BIGINT
);
