-- models\1_create_source_tables\115_f_amp2.sql
-- Create XML tables for DM+D

{{ config(materialized='table') }}

DROP TABLE IF EXISTS {{ target.schema }}.F_VMPP2;

CREATE TABLE {{ target.schema }}.F_VMPP2 (xmlfield XML);