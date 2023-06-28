-- models\1_create_source_tables\101_sct2_concept_full_merged.sql

{{ config(materialized='table') }}

DROP TABLE IF EXISTS {{ target.schema }}.SCT2_CONCEPT_FULL_MERGED;

CREATE TABLE {{ target.schema }}.SCT2_CONCEPT_FULL_MERGED
(
   ID                 BIGINT,
   EFFECTIVETIME      VARCHAR (8),
   ACTIVE             INTEGER,
   MODULEID           BIGINT,
   STATUSID           BIGINT,
   VOCABULARY_DATE    DATE,
   VOCABULARY_VERSION VARCHAR (200)
);

CREATE INDEX idx_concept_merged_id ON {{ target.schema }}.SCT2_CONCEPT_FULL_MERGED (ID);
