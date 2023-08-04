-- models\1_create_source_tables\105_der2_srefset_simplemapfull_int.sql

{{ config(materialized='table') }}

DROP TABLE IF EXISTS {{ target.schema }}.DER2_SREFSET_SIMPLEMAPFULL_INT;

CREATE TABLE {{ target.schema }}.DER2_SREFSET_SIMPLEMAPFULL_INT
(
    ID                         VARCHAR(256),
    EFFECTIVETIME              VARCHAR(8),
    ACTIVE                     INTEGER,
    MODULEID                   BIGINT,
    REFSETID                   BIGINT,
    REFERENCEDCOMPONENTID      BIGINT,
    MAPTARGET                  VARCHAR(8)
);