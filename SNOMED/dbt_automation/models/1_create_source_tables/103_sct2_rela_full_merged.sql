-- models/create_tables/create_sct2_rela_full_merged.sql

{{ config(materialized='table') }}

DROP TABLE IF EXISTS {{ target.schema }}.SCT2_RELA_FULL_MERGED;

CREATE TABLE {{ target.schema }}.SCT2_RELA_FULL_MERGED
(
   ID                     BIGINT,
   EFFECTIVETIME          VARCHAR (8),
   ACTIVE                 INTEGER,
   MODULEID               BIGINT,
   SOURCEID               BIGINT,
   DESTINATIONID          BIGINT,
   RELATIONSHIPGROUP      INTEGER,
   TYPEID                 BIGINT,
   CHARACTERISTICTYPEID   BIGINT,
   MODIFIERID             BIGINT
);

CREATE INDEX idx_rela_merged_id ON {{ target.schema }}.SCT2_RELA_FULL_MERGED (ID);
