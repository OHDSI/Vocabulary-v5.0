-- models/create_tables/103_sct2_desc_full_merged.sql

{{ config(materialized='table') }}

DROP TABLE IF EXISTS {{ target.schema }}.SCT2_DESC_FULL_MERGED;

CREATE TABLE {{ target.schema }}.SCT2_DESC_FULL_MERGED
(
   ID                   BIGINT,
   EFFECTIVETIME        VARCHAR (8),
   ACTIVE               INTEGER,
   MODULEID             BIGINT,
   CONCEPTID            BIGINT,
   LANGUAGECODE         VARCHAR (2),
   TYPEID               BIGINT,
   TERM                 VARCHAR (256),
   CASESIGNIFICANCEID   BIGINT
);

CREATE INDEX idx_desc_merged_id ON {{ target.schema }}.SCT2_DESC_FULL_MERGED (CONCEPTID);
