/**************************************************************************
* Copyright 2016 Observational Health Data Sciences and Informatics (OHDSI)
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*
* Authors: Christian Reich
* Date: 2026
**************************************************************************/

-- load_stage.sql
-- Builds concept_stage and concept_relationship_stage from the naaccr_* source
-- fetch tables populated by fetch.py.
--
-- Run context: dev_naaccr schema (or dev_christian during development).
-- Source tables are in the sources schema (or dev_christian until permissions granted).
-- The existing OMOP vocabulary is read from devv5.
--
-- All schema references use the search_path set by the calling session.
-- Source tables are referenced as sources.<table> — adjust if using a different schema.


-- ===========================================================================
-- 0.  Vocabulary registration
-- ===========================================================================

DO $_$
BEGIN
    PERFORM VOCABULARY_PACK.SetLatestUpdate(
        pVocabularyName    => 'NAACCR',
        pVocabularyDate    => TO_DATE('2024-01-01', 'yyyy-mm-dd'),
        pVocabularyVersion => 'NAACCR v26',
        pVocabularyDevSchema => 'dev_naaccr'
    );
END $_$;


-- ===========================================================================
-- 0b.  Helper function: domain assignment for Variables
--      Mirrors _variable_domain() in build_concepts.py.
-- ===========================================================================

CREATE OR REPLACE FUNCTION dev_naaccr.naaccr_variable_domain(
    p_section TEXT,
    p_name    TEXT
) RETURNS VARCHAR(20) LANGUAGE sql IMMUTABLE AS $$
    SELECT CASE
        WHEN p_section = 'Stage/Prognostic Factors'
            THEN 'Measurement'
        WHEN p_section = 'Treatment-1st Course'
             AND lower(p_name) LIKE '%date%'
             AND lower(p_name) NOT LIKE '%flag%'
            THEN 'Metadata'
        WHEN p_section = 'Treatment-1st Course'
             AND (lower(p_name) LIKE 'rx summ--%'
                  OR lower(p_name) LIKE '%radiation treatment modality%')
            THEN 'Episode'
        WHEN p_section = 'Treatment-1st Course'
             AND (   lower(p_name) LIKE '%dose%'
                  OR lower(p_name) LIKE '%fraction%'
                  OR lower(p_name) LIKE '%volume%'
                  OR lower(p_name) LIKE '%margin%'
                  OR lower(p_name) LIKE '%nodes examined%'
                  OR lower(p_name) LIKE '%regional dose%'
                  OR lower(p_name) LIKE '%number of treatment%'
                  OR lower(p_name) LIKE '%surgical margins%'
                  OR lower(p_name) LIKE '%reg ln examined%')
            THEN 'Measurement'
        WHEN p_section = 'Cancer Identification'
             AND lower(p_name) LIKE '%date%'
             AND lower(p_name) NOT LIKE '%flag%'
            THEN 'Metadata'
        WHEN p_section = 'Cancer Identification'
             AND (   lower(p_name) LIKE '%grade%'
                  OR lower(p_name) LIKE '%laterality%'
                  OR lower(p_name) LIKE '%multiplicity%'
                  OR lower(p_name) LIKE '%mult tum%')
            THEN 'Measurement'
        ELSE 'Observation'
    END
$$;


-- ===========================================================================
-- 1.  Truncate working tables
-- ===========================================================================

TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;


-- ===========================================================================
-- 2.  concept_stage
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 2a.  NAACCR Variables  (one per item in naaccr_items)
-- ---------------------------------------------------------------------------
INSERT INTO concept_stage (
    concept_name, domain_id, vocabulary_id, concept_class_id,
    standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
SELECT
    left(trim(regexp_replace(item_name, '\s+', ' ', 'g')), 255),
    dev_naaccr.naaccr_variable_domain(section, item_name),
    'NAACCR',
    'NAACCR Variable',
    NULL,
    item_number,
    '1970-01-01',
    '2099-12-31',
    -- Retire placeholder "Reserved XX" items
    CASE WHEN item_name LIKE 'Reserved%' THEN 'D' ELSE NULL END
FROM sources.naaccr_items;


-- ---------------------------------------------------------------------------
-- 2b.  Generic NAACCR Values  (item@code)
--
-- API and CSV values merged; CSV wins where both cover the same item@code.
-- SSDI items (those appearing in any EOD or TNM schema input) are excluded —
-- their values come from 2d (schema-specific) instead.
-- Range-notation codes and codes that would make the concept_code exceed 50
-- chars are excluded.
-- ---------------------------------------------------------------------------
WITH ssdi_items AS (
    SELECT DISTINCT item_number FROM sources.naaccr_eod_schema_inputs
    UNION
    SELECT DISTINCT item_number FROM sources.naaccr_tnm_schema_inputs
),
merged AS (
    SELECT item_number, code, description, 1 AS priority
    FROM sources.naaccr_api_values
    WHERE item_number NOT IN (SELECT item_number FROM ssdi_items)

    UNION ALL

    SELECT item_number, code, description, 2 AS priority
    FROM sources.naaccr_csv_values
    WHERE item_number NOT IN (SELECT item_number FROM ssdi_items)
),
deduped AS (
    -- CSV (priority 2) wins over API (priority 1) for same item@code
    SELECT DISTINCT ON (item_number, code)
        item_number, code, description
    FROM merged
    ORDER BY item_number, code, priority DESC
)
INSERT INTO concept_stage (
    concept_name, domain_id, vocabulary_id, concept_class_id,
    standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
SELECT
    left(trim(regexp_replace(d.description, '\s+', ' ', 'g')), 255),
    CASE WHEN dev_naaccr.naaccr_variable_domain(i.section, i.item_name) = 'Measurement'
         THEN 'Meas Value' ELSE 'Observation' END,
    'NAACCR',
    'NAACCR Value',
    NULL,
    d.item_number || '@' || d.code,
    '1970-01-01',
    '2099-12-31',
    NULL
FROM deduped d
JOIN sources.naaccr_items i ON i.item_number = d.item_number
WHERE d.code !~ '^[01]\d*\.?\d*-\d+\.?\d*$'                       -- exclude range codes
  AND length(d.item_number || '@' || d.code) <= 50             -- exclude overlong codes
  AND trim(coalesce(d.description, '')) <> '';                 -- exclude blank descriptions


-- ---------------------------------------------------------------------------
-- 2c.  EOD Schemas
-- ---------------------------------------------------------------------------
INSERT INTO concept_stage (
    concept_name, domain_id, vocabulary_id, concept_class_id,
    standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
SELECT
    -- Existing schemas: preserve DB name, append edition suffix if EOD title has one.
    -- New schemas: use EOD title directly.
    left(trim(regexp_replace(
        CASE
            WHEN db.concept_name IS NOT NULL THEN
                CASE WHEN s.schema_name ~ '\[(8th|V\d+)[^\]]*\]'
                          AND db.concept_name NOT LIKE '%[%'
                     THEN db.concept_name || ' ' ||
                          (regexp_match(s.schema_name, '\[(8th|V\d+)[^\]]*\]'))[1]
                     ELSE db.concept_name
                END
            ELSE s.schema_name
        END,
    '\s+', ' ', 'g')), 255),
    'Observation',
    'NAACCR',
    'NAACCR Schema',
    NULL,
    s.schema_id,
    '1970-01-01',
    '2099-12-31',
    NULL
FROM sources.naaccr_eod_schemas s
LEFT JOIN devv5.concept db
       ON db.concept_code     = s.schema_id
      AND db.vocabulary_id    = 'NAACCR'
      AND db.concept_class_id = 'NAACCR Schema';


-- ---------------------------------------------------------------------------
-- 2d.  TNM Schemas  (same logic; skip schema_ids already inserted from EOD)
-- ---------------------------------------------------------------------------
INSERT INTO concept_stage (
    concept_name, domain_id, vocabulary_id, concept_class_id,
    standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
SELECT
    left(trim(regexp_replace(
        CASE
            WHEN db.concept_name IS NOT NULL THEN
                CASE WHEN s.schema_name ~ '\[(8th|V\d+)[^\]]*\]'
                          AND db.concept_name NOT LIKE '%[%'
                     THEN db.concept_name || ' ' ||
                          (regexp_match(s.schema_name, '\[(8th|V\d+)[^\]]*\]'))[1]
                     ELSE db.concept_name
                END
            ELSE s.schema_name
        END,
    '\s+', ' ', 'g')), 255),
    'Observation',
    'NAACCR',
    'NAACCR Schema',
    NULL,
    s.schema_id,
    '1970-01-01',
    '2099-12-31',
    NULL
FROM sources.naaccr_tnm_schemas s
LEFT JOIN devv5.concept db
       ON db.concept_code     = s.schema_id
      AND db.vocabulary_id    = 'NAACCR'
      AND db.concept_class_id = 'NAACCR Schema'
WHERE s.schema_id NOT IN (SELECT concept_code FROM concept_stage
                          WHERE concept_class_id = 'NAACCR Schema');


-- ---------------------------------------------------------------------------
-- 2e.  Compound SSDI Variables  (schema@item)
--
-- One concept per schema-item pair from EOD + TNM inputs combined.
-- Excluded items (too generic to be SSDI): 400, 500, 522, 523, 390, 10, 40.
-- Name: schema-specific input_name if provided, else generic item_name.
-- Domain: inherited from the parent Variable.
-- ---------------------------------------------------------------------------
WITH all_inputs AS (
    SELECT schema_id, item_number, input_name FROM sources.naaccr_eod_schema_inputs
    UNION ALL
    SELECT schema_id, item_number, input_name FROM sources.naaccr_tnm_schema_inputs
),
unique_pairs AS (
    SELECT DISTINCT ON (schema_id, item_number)
        schema_id,
        item_number,
        first_value(input_name) OVER (
            PARTITION BY schema_id, item_number
            ORDER BY input_name NULLS LAST
        ) AS input_name
    FROM all_inputs
    WHERE item_number NOT IN ('400','500','522','523','390','10','40')
    ORDER BY schema_id, item_number
)
INSERT INTO concept_stage (
    concept_name, domain_id, vocabulary_id, concept_class_id,
    standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
SELECT
    left(trim(regexp_replace(
        coalesce(nullif(trim(p.input_name), ''), i.item_name),
    '\s+', ' ', 'g')), 255),
    dev_naaccr.naaccr_variable_domain(i.section, i.item_name),
    'NAACCR',
    'NAACCR Variable',
    NULL,
    p.schema_id || '@' || p.item_number,
    '1970-01-01',
    '2099-12-31',
    NULL
FROM unique_pairs p
JOIN sources.naaccr_items i ON i.item_number = p.item_number
WHERE length(p.schema_id || '@' || p.item_number) <= 50
  AND p.schema_id IN (SELECT concept_code FROM concept_stage
                      WHERE concept_class_id = 'NAACCR Schema');


-- ---------------------------------------------------------------------------
-- 2f.  Schema-specific Values  (schema@item@code)
--
-- From EOD + TNM value rows.
-- Excluded: template placeholders (code contains '{{'), range-notation codes,
-- blank descriptions.  The concept_code <= 50 guard is a safety net; in
-- practice all current codes fit.
-- Only inserted when the corresponding compound Variable exists in concept_stage.
-- ---------------------------------------------------------------------------
WITH all_values AS (
    SELECT schema_id, item_number, code, description
    FROM sources.naaccr_eod_values
    WHERE item_number IS NOT NULL

    UNION ALL

    SELECT schema_id, item_number, code, description
    FROM sources.naaccr_tnm_values
    WHERE item_number IS NOT NULL
),
filtered AS (
    SELECT DISTINCT ON (schema_id, item_number, code)
        schema_id, item_number, code, description
    FROM all_values
    WHERE code NOT LIKE '%{{%'
      AND code !~ '^[01]\d*\.?\d*-\d+\.?\d*$'
      AND trim(coalesce(description, '')) <> ''
      AND length(schema_id || '@' || item_number || '@' || code) <= 50
    ORDER BY schema_id, item_number, code
)
INSERT INTO concept_stage (
    concept_name, domain_id, vocabulary_id, concept_class_id,
    standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
SELECT
    left(trim(regexp_replace(v.description, '\s+', ' ', 'g')), 255),
    CASE WHEN dev_naaccr.naaccr_variable_domain(i.section, i.item_name) = 'Measurement'
         THEN 'Meas Value' ELSE 'Observation' END,
    'NAACCR',
    'NAACCR Value',
    NULL,
    v.schema_id || '@' || v.item_number || '@' || v.code,
    '1970-01-01',
    '2099-12-31',
    NULL
FROM filtered v
JOIN sources.naaccr_items i ON i.item_number = v.item_number
WHERE (v.schema_id || '@' || v.item_number) IN
        (SELECT concept_code FROM concept_stage
         WHERE concept_class_id = 'NAACCR Variable');


-- ---------------------------------------------------------------------------
-- 2g.  NAACCR Proc Schemas
-- ---------------------------------------------------------------------------
INSERT INTO concept_stage (
    concept_name, domain_id, vocabulary_id, concept_class_id,
    standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
SELECT DISTINCT
    left(trim(regexp_replace(
        coalesce(db.concept_name, sc.proc_schema),
    '\s+', ' ', 'g')), 255),
    'Observation',
    'NAACCR',
    'NAACCR Proc Schema',
    NULL,
    sc.proc_schema,
    '1970-01-01',
    '2099-12-31',
    NULL
FROM sources.naaccr_surgery_concepts sc
LEFT JOIN devv5.concept db
       ON db.concept_code     = sc.proc_schema
      AND db.vocabulary_id    = 'NAACCR'
      AND db.concept_class_id = 'NAACCR Proc Schema';


-- ---------------------------------------------------------------------------
-- 2h.  NAACCR Procedures  (surgery codes, items 1290 / 1291)
-- ---------------------------------------------------------------------------
INSERT INTO concept_stage (
    concept_name, domain_id, vocabulary_id, concept_class_id,
    standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
SELECT
    left(trim(regexp_replace(coalesce(description, ''), '\s+', ' ', 'g')), 255),
    'Procedure',
    'NAACCR',
    'NAACCR Procedure',
    standard_concept,
    proc_schema || '@' || item_number || '@' || code,
    valid_start_date,
    valid_end_date,
    invalid_reason
FROM sources.naaccr_surgery_concepts;


-- ---------------------------------------------------------------------------
-- 2i.  Retire Permissible Range concepts still in devv5
-- ---------------------------------------------------------------------------
INSERT INTO concept_stage (
    concept_name, domain_id, vocabulary_id, concept_class_id,
    standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
SELECT
    concept_name, domain_id, vocabulary_id, concept_class_id,
    NULL, concept_code, valid_start_date, current_date, 'D'
FROM devv5.concept
WHERE vocabulary_id    = 'NAACCR'
  AND concept_class_id = 'Permissible Range'
  AND invalid_reason IS NULL
  AND concept_code NOT IN (SELECT concept_code FROM concept_stage);


-- ---------------------------------------------------------------------------
-- 2j.  Retire range-notation 2-part NAACCR Values still in devv5
--      (concept_code like '1234@002-988')
-- ---------------------------------------------------------------------------
INSERT INTO concept_stage (
    concept_name, domain_id, vocabulary_id, concept_class_id,
    standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
SELECT
    concept_name, domain_id, vocabulary_id, concept_class_id,
    NULL, concept_code, valid_start_date, current_date, 'D'
FROM devv5.concept
WHERE vocabulary_id    = 'NAACCR'
  AND concept_class_id = 'NAACCR Value'
  AND concept_code ~ '^[^@]+@[01]\d*\.?\d*-\d+\.?\d*$'
  AND invalid_reason IS NULL
  AND concept_code NOT IN (SELECT concept_code FROM concept_stage);


-- ---------------------------------------------------------------------------
-- 2k.  Pass-through already-deprecated NAACCR concepts from devv5
--      Preserves retired compound variables (SSDI items removed from current
--      EOD/TNM schemas), retired Reserved variables, and any other historical
--      concepts no longer appearing in live sources.
-- ---------------------------------------------------------------------------
INSERT INTO concept_stage (
    concept_name, domain_id, vocabulary_id, concept_class_id,
    standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
)
SELECT
    concept_name, domain_id, vocabulary_id, concept_class_id,
    NULL, concept_code, valid_start_date, valid_end_date, invalid_reason
FROM devv5.concept
WHERE vocabulary_id = 'NAACCR'
  AND invalid_reason IS NOT NULL
  AND concept_code NOT IN (SELECT concept_code FROM concept_stage);


-- ===========================================================================
-- 3.  concept_relationship_stage
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 3a.  Has Answer  —  plain Variable → generic Value  (item → item@code)
-- ---------------------------------------------------------------------------
INSERT INTO concept_relationship_stage (
    concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2,
    relationship_id, valid_start_date, valid_end_date, invalid_reason
)
SELECT DISTINCT
    split_part(concept_code, '@', 1),
    concept_code,
    'NAACCR', 'NAACCR',
    'Has Answer',
    '1970-01-01', '2099-12-31', NULL
FROM concept_stage
WHERE concept_class_id = 'NAACCR Value'
  AND concept_code NOT LIKE '%@%@%'        -- 2-part codes only
  AND invalid_reason IS NULL
  AND split_part(concept_code, '@', 1) IN
        (SELECT concept_code FROM concept_stage
         WHERE concept_class_id = 'NAACCR Variable');


-- ---------------------------------------------------------------------------
-- 3b.  Has Answer  —  compound Variable → schema-specific Value
--      (schema@item → schema@item@code)
-- ---------------------------------------------------------------------------
INSERT INTO concept_relationship_stage (
    concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2,
    relationship_id, valid_start_date, valid_end_date, invalid_reason
)
SELECT DISTINCT
    split_part(concept_code, '@', 1) || '@' || split_part(concept_code, '@', 2),
    concept_code,
    'NAACCR', 'NAACCR',
    'Has Answer',
    '1970-01-01', '2099-12-31', NULL
FROM concept_stage
WHERE concept_class_id = 'NAACCR Value'
  AND concept_code LIKE '%@%@%'            -- 3-part codes only
  AND invalid_reason IS NULL
  AND (split_part(concept_code, '@', 1) || '@' || split_part(concept_code, '@', 2))
        IN (SELECT concept_code FROM concept_stage
            WHERE concept_class_id = 'NAACCR Variable');


-- ---------------------------------------------------------------------------
-- 3c.  Schema to Value  —  Schema → schema-specific Value
--      (schema → schema@item@code)
-- ---------------------------------------------------------------------------
INSERT INTO concept_relationship_stage (
    concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2,
    relationship_id, valid_start_date, valid_end_date, invalid_reason
)
SELECT DISTINCT
    split_part(concept_code, '@', 1),
    concept_code,
    'NAACCR', 'NAACCR',
    'Schema to Value',
    '1970-01-01', '2099-12-31', NULL
FROM concept_stage
WHERE concept_class_id = 'NAACCR Value'
  AND concept_code LIKE '%@%@%'
  AND invalid_reason IS NULL
  AND split_part(concept_code, '@', 1) IN
        (SELECT concept_code FROM concept_stage
         WHERE concept_class_id = 'NAACCR Schema');


-- ---------------------------------------------------------------------------
-- 3d.  Schema to Value  —  Proc Schema → Procedure
--      (proc_schema → proc_schema@item@code)
-- ---------------------------------------------------------------------------
INSERT INTO concept_relationship_stage (
    concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2,
    relationship_id, valid_start_date, valid_end_date, invalid_reason
)
SELECT DISTINCT
    split_part(concept_code, '@', 1),
    concept_code,
    'NAACCR', 'NAACCR',
    'Schema to Value',
    '1970-01-01', '2099-12-31', NULL
FROM concept_stage
WHERE concept_class_id = 'NAACCR Procedure'
  AND invalid_reason IS NULL
  AND split_part(concept_code, '@', 1) IN
        (SELECT concept_code FROM concept_stage
         WHERE concept_class_id = 'NAACCR Proc Schema');


-- ---------------------------------------------------------------------------
-- 3e.  Concept replaced by  —  surgery code supersessions
-- ---------------------------------------------------------------------------
INSERT INTO concept_relationship_stage (
    concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2,
    relationship_id, valid_start_date, valid_end_date, invalid_reason
)
SELECT
    old_proc_schema || '@' || old_item_number || '@' || old_code,
    new_proc_schema || '@' || new_item_number || '@' || new_code,
    'NAACCR', 'NAACCR',
    'Concept replaced by',
    '1970-01-01', '2099-12-31', NULL
FROM sources.naaccr_surgery_replacements r
WHERE (r.old_proc_schema || '@' || r.old_item_number || '@' || r.old_code)
        IN (SELECT concept_code FROM concept_stage)
  AND (r.new_proc_schema || '@' || r.new_item_number || '@' || r.new_code)
        IN (SELECT concept_code FROM concept_stage);


-- ---------------------------------------------------------------------------
-- 3f.  Schema to Variable  —  Schema → compound SSDI Variable
--      (schema → schema@item)
-- ---------------------------------------------------------------------------
INSERT INTO concept_relationship_stage (
    concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2,
    relationship_id, valid_start_date, valid_end_date, invalid_reason
)
WITH all_inputs AS (
    SELECT schema_id, item_number FROM sources.naaccr_eod_schema_inputs
    UNION
    SELECT schema_id, item_number FROM sources.naaccr_tnm_schema_inputs
)
SELECT DISTINCT
    a.schema_id,
    a.schema_id || '@' || a.item_number,
    'NAACCR', 'NAACCR',
    'Schema to Variable',
    '1970-01-01', '2099-12-31', NULL
FROM all_inputs a
WHERE a.item_number NOT IN ('400', '500', '522', '523', '390', '10', '40')
  AND a.schema_id IN
        (SELECT concept_code FROM concept_stage
         WHERE concept_class_id = 'NAACCR Schema')
  AND (a.schema_id || '@' || a.item_number) IN
        (SELECT concept_code FROM concept_stage
         WHERE concept_class_id = 'NAACCR Variable');


-- ===========================================================================
-- 4.  OHDSI vocabulary pipeline post-processing
-- ===========================================================================

--1. ProcessManualConcepts
DO $_$
BEGIN
    PERFORM VOCABULARY_PACK.ProcessManualConcepts();
END $_$;

--2. Add manual relationships
DO $_$
BEGIN
    PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--3. Working with replacement mappings
DO $_$
BEGIN
    PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

--4. Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
    PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

--5. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
    PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

-- concept_stage, concept_relationship_stage, and concept_synonym_stage are
-- now ready to feed into generic_update.sql.
