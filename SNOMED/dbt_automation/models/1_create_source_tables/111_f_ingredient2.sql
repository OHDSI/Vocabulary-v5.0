-- models\1_create_source_tables\111_f_ingredient2.sql
-- Create XML tables for DM+D

{{ config(materialized='table') }}

DROP TABLE IF EXISTS {{ target.schema }}.F_INGREDIENT2;

CREATE TABLE {{ target.schema }}.F_INGREDIENT2 (xmlfield XML);