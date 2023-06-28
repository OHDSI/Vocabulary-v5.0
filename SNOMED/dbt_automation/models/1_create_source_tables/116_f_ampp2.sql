-- models\1_create_source_tables\116_f_ampp2.sql
-- Create XML tables for DM+D

{{ config(materialized='table') }}

DROP TABLE IF EXISTS {{ target.schema }}.F_AMPP2;

CREATE TABLE {{ target.schema }}.F_AMPP2 (xmlfield XML);