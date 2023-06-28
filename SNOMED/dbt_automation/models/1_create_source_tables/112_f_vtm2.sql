-- models\1_create_source_tables\112_f_vtm2.sql
-- Create XML tables for DM+D

{{ config(materialized='table') }}

DROP TABLE IF EXISTS {{ target.schema }}.F_VTM2;

CREATE TABLE {{ target.schema }}.F_VTM2 (xmlfield XML);