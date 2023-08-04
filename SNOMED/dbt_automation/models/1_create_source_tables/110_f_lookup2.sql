-- models\1_create_source_tables\110_f_lookup2.sql
-- Create XML tables for DM+D

{{ config(materialized='table') }}

DROP TABLE IF EXISTS {{ target.schema }}.F_LOOKUP2;

CREATE TABLE {{ target.schema }}.F_LOOKUP2 (xmlfield XML);