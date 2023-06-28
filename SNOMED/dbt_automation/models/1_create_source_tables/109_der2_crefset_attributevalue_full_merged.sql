-- models\1_create_source_tables\108_der2_iisssccrefset_extendedmapfull_us.sql

{{ config(materialized='table') }}

DROP TABLE IF EXISTS {{ target.schema }}.DER2_CREFSET_ATTRIBUTEVALUE_FULL_MERGED;

CREATE TABLE {{ target.schema }}.DER2_CREFSET_ATTRIBUTEVALUE_FULL_MERGED
(
   ID                         VARCHAR(256),
   EFFECTIVETIME              VARCHAR (8),
   ACTIVE                     INTEGER,
   MODULEID                   BIGINT,
   REFSETID                   BIGINT,
   REFERENCEDCOMPONENTID      BIGINT,
   VALUEID                    BIGINT
);