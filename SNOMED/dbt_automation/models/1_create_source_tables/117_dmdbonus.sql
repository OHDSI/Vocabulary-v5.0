-- models\1_create_source_tables\117_dmdbonus.sql
-- Create XML tables for DM+D

{{ config(materialized='table') }}

DROP TABLE IF EXISTS {{ target.schema }}.DMDBONUS;

CREATE TABLE {{ target.schema }}.DMDBONUS (xmlfield XML);