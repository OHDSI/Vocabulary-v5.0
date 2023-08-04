-- models\1_create_source_tables\108_der2_iisssccrefset_extendedmapfull_us.sql

{{ config(materialized='table') }}

DROP TABLE IF EXISTS {{ target.schema }}.DER2_IISSSCCREFSET_EXTENDEDMAPFULL_US;

CREATE TABLE {{ target.schema }}.DER2_IISSSCCREFSET_EXTENDEDMAPFULL_US
(
    ID                         VARCHAR(256),
    EFFECTIVETIME              VARCHAR(8),
    ACTIVE                     INTEGER,
    MODULEID                   BIGINT,
    REFSETID                   BIGINT,
    REFERENCEDCOMPONENTID      BIGINT,
    MAPGROUP                   INT2,
    MAPPRIORITY                TEXT,
    MAPRULE                    TEXT,
    MAPADVICE                  TEXT,
    MAPTARGET                  TEXT,
    CORRELATIONID              VARCHAR(256),
    MAPCATEGORYID              VARCHAR(256)
);