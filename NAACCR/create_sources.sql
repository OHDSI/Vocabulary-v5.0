-- NAACCR source fetch tables
-- Run once per schema.  Substitute :schema with the target schema name
-- (sources for production, dev_christian / dev_naaccr during development).
--
-- These tables are populated by the Python fetch scripts and consumed by
-- load_stage.sql to build concept_stage / concept_relationship_stage.
-- They are truncated and reloaded on every pipeline run.

-- ---------------------------------------------------------------------------
-- 1. NAACCR items  (from SEER API)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS :schema.naaccr_items (
    item_number     VARCHAR(10)  NOT NULL,   -- e.g. '400'
    item_name       TEXT          NOT NULL,
    section         VARCHAR(100),            -- e.g. 'Cancer Identification'
    xml_naaccr_id   VARCHAR(100),            -- camelCase XML field name, used to
                                             -- match CSV lookup files
    item_data_type  VARCHAR(20),
    item_length     VARCHAR(10)
);

-- ---------------------------------------------------------------------------
-- 2. Generic permissible values from the SEER API  (allowed_codes)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS :schema.naaccr_api_values (
    item_number     VARCHAR(10)  NOT NULL,
    code            VARCHAR(255) NOT NULL,
    description     TEXT
);

-- ---------------------------------------------------------------------------
-- 3. Generic permissible values from imsweb/layout CSV lookup files
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS :schema.naaccr_csv_values (
    item_number     VARCHAR(10)  NOT NULL,
    code            VARCHAR(255) NOT NULL,
    description     TEXT
);

-- ---------------------------------------------------------------------------
-- 4. EOD staging schemas
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS :schema.naaccr_eod_schemas (
    schema_id       VARCHAR(100) NOT NULL,   -- e.g. 'breast', 'anus_v9_2023'
    schema_name     TEXT          NOT NULL,
    algorithm       VARCHAR(50),             -- 'eod_public'
    version         VARCHAR(20)              -- e.g. '3.3'
);

-- ---------------------------------------------------------------------------
-- 5. EOD schema inputs  (which items belong to which EOD schema)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS :schema.naaccr_eod_schema_inputs (
    schema_id       VARCHAR(100) NOT NULL,
    item_number     VARCHAR(10)  NOT NULL,
    input_name      TEXT                      -- schema-specific display name for
                                             -- this item, if provided
);

-- ---------------------------------------------------------------------------
-- 6. EOD schema-specific values
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS :schema.naaccr_eod_values (
    schema_id       VARCHAR(100) NOT NULL,
    item_number     VARCHAR(10),             -- NULL when the table is referenced
                                             -- without a direct item mapping
    code            VARCHAR(255) NOT NULL,
    description     TEXT
);

-- ---------------------------------------------------------------------------
-- 7. TNM staging schemas
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS :schema.naaccr_tnm_schemas (
    schema_id       VARCHAR(100) NOT NULL,
    schema_name     TEXT          NOT NULL,
    algorithm       VARCHAR(50),             -- 'tnm'
    version         VARCHAR(20)              -- e.g. '2.1'
);

-- ---------------------------------------------------------------------------
-- 8. TNM schema inputs
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS :schema.naaccr_tnm_schema_inputs (
    schema_id       VARCHAR(100) NOT NULL,
    item_number     VARCHAR(10)  NOT NULL,
    input_name      TEXT         
);

-- ---------------------------------------------------------------------------
-- 9. TNM schema-specific values
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS :schema.naaccr_tnm_values (
    schema_id       VARCHAR(100) NOT NULL,
    item_number     VARCHAR(10),
    code            VARCHAR(255) NOT NULL,
    description     TEXT
);

-- ---------------------------------------------------------------------------
-- 10. Surgery procedure concepts
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS :schema.naaccr_surgery_concepts (
    proc_schema     VARCHAR(100) NOT NULL,   -- e.g. 'Breast'
    item_number     VARCHAR(10)  NOT NULL,   -- '1290' or '1291'
    code            VARCHAR(20)  NOT NULL,   -- e.g. 'B200'
    description     TEXT,
    valid_start_date DATE        NOT NULL,
    valid_end_date   DATE        NOT NULL,
    standard_concept VARCHAR(1),             -- 'S' or NULL
    invalid_reason   VARCHAR(1)              -- 'U' or NULL
);

-- ---------------------------------------------------------------------------
-- 11. Surgery replacement relationships
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS :schema.naaccr_surgery_replacements (
    old_proc_schema VARCHAR(100) NOT NULL,
    old_item_number VARCHAR(10)  NOT NULL,
    old_code        VARCHAR(20)  NOT NULL,
    new_proc_schema VARCHAR(100) NOT NULL,
    new_item_number VARCHAR(10)  NOT NULL,
    new_code        VARCHAR(20)  NOT NULL
);
