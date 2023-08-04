-- models\1_create_source_tables\106_der2_crefset_language_merged.sql

{{ config(materialized='table') }}

DROP TABLE IF EXISTS {{ target.schema }}.DER2_CREFSET_LANGUAGE_MERGED;

CREATE TABLE {{ target.schema }}.DER2_CREFSET_LANGUAGE_MERGED
(
    ID                         VARCHAR(256),
    EFFECTIVETIME              VARCHAR(8),
    ACTIVE                     INTEGER,
    MODULEID                   BIGINT,
    REFSETID                   BIGINT,
    REFERENCEDCOMPONENTID      BIGINT,
    ACCEPTABILITYID            BIGINT,
    SOURCE_FILE_ID             VARCHAR(10)
);

CREATE INDEX idx_lang_merged_refid ON {{ target.schema }}.DER2_CREFSET_LANGUAGE_MERGED (REFERENCEDCOMPONENTID);