-- models\1_create_source_tables\113_f_vmp2.sql
-- Create XML tables for DM+D

{{ config(materialized='table') }}

DROP TABLE IF EXISTS {{ target.schema }}.F_VMP2;

CREATE TABLE {{ target.schema }}.F_VMP2 (xmlfield XML);