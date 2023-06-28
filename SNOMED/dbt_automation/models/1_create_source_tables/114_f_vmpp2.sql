-- models\1_create_source_tables\114_f_vmpp2.sql
-- Create XML tables for DM+D

{{ config(materialized='table') }}

DROP TABLE IF EXISTS {{ target.schema }}.F_AMP2;

CREATE TABLE {{ target.schema }}.F_AMP2 (xmlfield XML);