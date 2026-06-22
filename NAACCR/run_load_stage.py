"""
run_load_stage.py
Executes the NAACCR ETL from the source fetch tables into concept_stage and
concept_relationship_stage, using the current DB_WORK_SCHEMA and DB_SOURCES_SCHEMA.
"""

import config

W = config.DB_WORK_SCHEMA
S = config.DB_SOURCES_SCHEMA
V = config.DB_SOURCE_SCHEMA


STEPS = [

# ── Helper function ────────────────────────────────────────────────────────
("Create domain function", f"""
CREATE OR REPLACE FUNCTION {W}.naaccr_variable_domain(p_section TEXT, p_name TEXT)
RETURNS VARCHAR(20) LANGUAGE sql IMMUTABLE AS $fn$
    SELECT CASE
        WHEN p_section = 'Stage/Prognostic Factors' THEN 'Measurement'
        WHEN p_section = 'Treatment-1st Course' AND lower(p_name) LIKE '%date%'
             AND lower(p_name) NOT LIKE '%flag%' THEN 'Metadata'
        WHEN p_section = 'Treatment-1st Course'
             AND (lower(p_name) LIKE 'rx summ--%'
                  OR lower(p_name) LIKE '%radiation treatment modality%')
             THEN 'Episode'
        WHEN p_section = 'Treatment-1st Course'
             AND (   lower(p_name) LIKE '%dose%' OR lower(p_name) LIKE '%fraction%'
                  OR lower(p_name) LIKE '%volume%' OR lower(p_name) LIKE '%margin%'
                  OR lower(p_name) LIKE '%nodes examined%'
                  OR lower(p_name) LIKE '%regional dose%'
                  OR lower(p_name) LIKE '%number of treatment%'
                  OR lower(p_name) LIKE '%surgical margins%'
                  OR lower(p_name) LIKE '%reg ln examined%') THEN 'Measurement'
        WHEN p_section = 'Cancer Identification' AND lower(p_name) LIKE '%date%'
             AND lower(p_name) NOT LIKE '%flag%' THEN 'Metadata'
        WHEN p_section = 'Cancer Identification'
             AND (   lower(p_name) LIKE '%grade%' OR lower(p_name) LIKE '%laterality%'
                  OR lower(p_name) LIKE '%multiplicity%'
                  OR lower(p_name) LIKE '%mult tum%') THEN 'Measurement'
        ELSE 'Observation'
    END
$fn$
"""),

# ── Truncate ───────────────────────────────────────────────────────────────
("Truncate concept_stage",              f"TRUNCATE TABLE {W}.concept_stage"),
("Truncate concept_relationship_stage", f"TRUNCATE TABLE {W}.concept_relationship_stage"),

# ── 2a. Variables ──────────────────────────────────────────────────────────
("2a Variables", f"""
INSERT INTO {W}.concept_stage
    (concept_name,domain_id,vocabulary_id,concept_class_id,
     standard_concept,concept_code,valid_start_date,valid_end_date,invalid_reason)
SELECT
    left(trim(regexp_replace(item_name,'\\s+', ' ','g')), 255),
    {W}.naaccr_variable_domain(section, item_name),
    'NAACCR', 'NAACCR Variable', NULL, item_number,
    '1970-01-01', '2099-12-31',
    CASE WHEN item_name LIKE 'Reserved%' THEN 'D' ELSE NULL END
FROM {S}.naaccr_items
"""),

# ── 2b. Generic values ─────────────────────────────────────────────────────
("2b Generic values", f"""
WITH ssdi AS (
    SELECT DISTINCT item_number FROM {S}.naaccr_eod_schema_inputs
    UNION
    SELECT DISTINCT item_number FROM {S}.naaccr_tnm_schema_inputs
),
merged AS (
    SELECT item_number, code, description, 1 AS p
    FROM {S}.naaccr_api_values
    WHERE item_number NOT IN (SELECT item_number FROM ssdi)
    UNION ALL
    SELECT item_number, code, description, 2 AS p
    FROM {S}.naaccr_csv_values
    WHERE item_number NOT IN (SELECT item_number FROM ssdi)
),
deduped AS (
    SELECT DISTINCT ON (item_number, code) item_number, code, description
    FROM merged ORDER BY item_number, code, p DESC
)
INSERT INTO {W}.concept_stage
    (concept_name,domain_id,vocabulary_id,concept_class_id,
     standard_concept,concept_code,valid_start_date,valid_end_date,invalid_reason)
SELECT
    left(trim(regexp_replace(d.description,'\\s+',' ','g')), 255),
    CASE WHEN {W}.naaccr_variable_domain(i.section,i.item_name)='Measurement'
         THEN 'Meas Value' ELSE 'Observation' END,
    'NAACCR', 'NAACCR Value', NULL,
    d.item_number || '@' || d.code,
    '1970-01-01', '2099-12-31', NULL
FROM deduped d
JOIN {S}.naaccr_items i ON i.item_number = d.item_number
WHERE d.code !~ '^[01]\\d*\\.?\\d*-\\d+\\.?\\d*$'
  AND length(d.item_number || '@' || d.code) <= 50
  AND trim(coalesce(d.description,'')) <> ''
"""),

# ── 2c. EOD schemas ────────────────────────────────────────────────────────
("2c EOD schemas", f"""
INSERT INTO {W}.concept_stage
    (concept_name,domain_id,vocabulary_id,concept_class_id,
     standard_concept,concept_code,valid_start_date,valid_end_date,invalid_reason)
SELECT
    left(trim(regexp_replace(
        CASE WHEN db.concept_name IS NOT NULL THEN
            CASE WHEN s.schema_name ~ '\\[(8th|V\\d+)[^\\]]*\\]'
                      AND db.concept_name NOT LIKE '%[%'
                 THEN db.concept_name || ' ' ||
                      (regexp_match(s.schema_name,'\\[(8th|V\\d+)[^\\]]*\\]'))[1]
                 ELSE db.concept_name END
        ELSE s.schema_name END,
    '\\s+',' ','g')), 255),
    'Observation', 'NAACCR', 'NAACCR Schema', NULL,
    s.schema_id, '1970-01-01', '2099-12-31', NULL
FROM {S}.naaccr_eod_schemas s
LEFT JOIN {V}.concept db
       ON db.concept_code = s.schema_id
      AND db.vocabulary_id = 'NAACCR'
      AND db.concept_class_id = 'NAACCR Schema'
"""),

# ── 2d. TNM schemas ────────────────────────────────────────────────────────
("2d TNM schemas", f"""
INSERT INTO {W}.concept_stage
    (concept_name,domain_id,vocabulary_id,concept_class_id,
     standard_concept,concept_code,valid_start_date,valid_end_date,invalid_reason)
SELECT
    left(trim(regexp_replace(
        CASE WHEN db.concept_name IS NOT NULL THEN
            CASE WHEN s.schema_name ~ '\\[(8th|V\\d+)[^\\]]*\\]'
                      AND db.concept_name NOT LIKE '%[%'
                 THEN db.concept_name || ' ' ||
                      (regexp_match(s.schema_name,'\\[(8th|V\\d+)[^\\]]*\\]'))[1]
                 ELSE db.concept_name END
        ELSE s.schema_name END,
    '\\s+',' ','g')), 255),
    'Observation', 'NAACCR', 'NAACCR Schema', NULL,
    s.schema_id, '1970-01-01', '2099-12-31', NULL
FROM {S}.naaccr_tnm_schemas s
LEFT JOIN {V}.concept db
       ON db.concept_code = s.schema_id
      AND db.vocabulary_id = 'NAACCR'
      AND db.concept_class_id = 'NAACCR Schema'
WHERE s.schema_id NOT IN (
    SELECT concept_code FROM {W}.concept_stage
    WHERE concept_class_id = 'NAACCR Schema')
"""),

# ── 2e. Compound SSDI variables ────────────────────────────────────────────
("2e Compound variables", f"""
WITH all_inputs AS (
    SELECT schema_id, item_number, input_name FROM {S}.naaccr_eod_schema_inputs
    UNION ALL
    SELECT schema_id, item_number, input_name FROM {S}.naaccr_tnm_schema_inputs
),
unique_pairs AS (
    SELECT DISTINCT ON (schema_id, item_number)
        schema_id, item_number,
        first_value(input_name) OVER (
            PARTITION BY schema_id, item_number ORDER BY input_name NULLS LAST
        ) AS input_name
    FROM all_inputs
    WHERE item_number NOT IN ('400','500','522','523','390','10','40')
    ORDER BY schema_id, item_number
)
INSERT INTO {W}.concept_stage
    (concept_name,domain_id,vocabulary_id,concept_class_id,
     standard_concept,concept_code,valid_start_date,valid_end_date,invalid_reason)
SELECT
    left(trim(regexp_replace(
        coalesce(nullif(trim(p.input_name),''), i.item_name),
    '\\s+',' ','g')), 255),
    {W}.naaccr_variable_domain(i.section, i.item_name),
    'NAACCR', 'NAACCR Variable', NULL,
    p.schema_id || '@' || p.item_number,
    '1970-01-01', '2099-12-31', NULL
FROM unique_pairs p
JOIN {S}.naaccr_items i ON i.item_number = p.item_number
WHERE length(p.schema_id || '@' || p.item_number) <= 50
  AND p.schema_id IN (
      SELECT concept_code FROM {W}.concept_stage
      WHERE concept_class_id = 'NAACCR Schema')
"""),

# ── 2f. Schema-specific values ─────────────────────────────────────────────
("2f Schema-specific values", f"""
WITH all_values AS (
    SELECT schema_id, item_number, code, description
    FROM {S}.naaccr_eod_values WHERE item_number IS NOT NULL
    UNION ALL
    SELECT schema_id, item_number, code, description
    FROM {S}.naaccr_tnm_values WHERE item_number IS NOT NULL
),
filtered AS (
    SELECT DISTINCT ON (schema_id, item_number, code)
        schema_id, item_number, code, description
    FROM all_values
    WHERE code NOT LIKE '%{{%'
      AND code !~ '^[01]\\d*\\.?\\d*-\\d+\\.?\\d*$'
      AND trim(coalesce(description,'')) <> ''
      AND length(schema_id || '@' || item_number || '@' || code) <= 50
    ORDER BY schema_id, item_number, code
)
INSERT INTO {W}.concept_stage
    (concept_name,domain_id,vocabulary_id,concept_class_id,
     standard_concept,concept_code,valid_start_date,valid_end_date,invalid_reason)
SELECT
    left(trim(regexp_replace(v.description,'\\s+',' ','g')), 255),
    CASE WHEN {W}.naaccr_variable_domain(i.section, i.item_name) = 'Measurement'
         THEN 'Meas Value' ELSE 'Observation' END,
    'NAACCR', 'NAACCR Value', NULL,
    v.schema_id || '@' || v.item_number || '@' || v.code,
    '1970-01-01', '2099-12-31', NULL
FROM filtered v
JOIN {S}.naaccr_items i ON i.item_number = v.item_number
WHERE (v.schema_id || '@' || v.item_number) IN (
    SELECT concept_code FROM {W}.concept_stage
    WHERE concept_class_id = 'NAACCR Variable')
"""),

# ── 2g. Proc schemas ───────────────────────────────────────────────────────
("2g Proc schemas", f"""
INSERT INTO {W}.concept_stage
    (concept_name,domain_id,vocabulary_id,concept_class_id,
     standard_concept,concept_code,valid_start_date,valid_end_date,invalid_reason)
SELECT DISTINCT
    left(trim(regexp_replace(coalesce(db.concept_name, sc.proc_schema),'\\s+',' ','g')), 255),
    'Observation', 'NAACCR', 'NAACCR Proc Schema', NULL,
    sc.proc_schema, '1970-01-01'::date, '2099-12-31'::date, NULL
FROM {S}.naaccr_surgery_concepts sc
LEFT JOIN {V}.concept db
       ON db.concept_code = sc.proc_schema
      AND db.vocabulary_id = 'NAACCR'
      AND db.concept_class_id = 'NAACCR Proc Schema'
"""),

# ── 2h. Procedures ─────────────────────────────────────────────────────────
("2h Procedures", f"""
INSERT INTO {W}.concept_stage
    (concept_name,domain_id,vocabulary_id,concept_class_id,
     standard_concept,concept_code,valid_start_date,valid_end_date,invalid_reason)
SELECT
    left(trim(regexp_replace(coalesce(description,''),'\\s+',' ','g')), 255),
    'Procedure', 'NAACCR', 'NAACCR Procedure',
    standard_concept,
    proc_schema || '@' || item_number || '@' || code,
    valid_start_date, valid_end_date, invalid_reason
FROM {S}.naaccr_surgery_concepts
"""),

# ── 2i. Retire Permissible Range ───────────────────────────────────────────
("2i Retire Permissible Range", f"""
INSERT INTO {W}.concept_stage
    (concept_name,domain_id,vocabulary_id,concept_class_id,
     standard_concept,concept_code,valid_start_date,valid_end_date,invalid_reason)
SELECT concept_name,domain_id,vocabulary_id,concept_class_id,
       NULL, concept_code, valid_start_date, current_date, 'D'
FROM {V}.concept
WHERE vocabulary_id = 'NAACCR' AND concept_class_id = 'Permissible Range'
  AND invalid_reason IS NULL
  AND concept_code NOT IN (SELECT concept_code FROM {W}.concept_stage)
"""),

# ── 2j. Retire range-notation values ──────────────────────────────────────
("2j Retire range values", f"""
INSERT INTO {W}.concept_stage
    (concept_name,domain_id,vocabulary_id,concept_class_id,
     standard_concept,concept_code,valid_start_date,valid_end_date,invalid_reason)
SELECT concept_name,domain_id,vocabulary_id,concept_class_id,
       NULL, concept_code, valid_start_date, current_date, 'D'
FROM {V}.concept
WHERE vocabulary_id = 'NAACCR' AND concept_class_id = 'NAACCR Value'
  AND concept_code ~ '^[^@]+@[01]\\d*\\.?\\d*-\\d+\\.?\\d*$'
  AND invalid_reason IS NULL
  AND concept_code NOT IN (SELECT concept_code FROM {W}.concept_stage)
"""),

# ── 2k. Pass-through already-deprecated NAACCR concepts from devv5 ─────────
# Preserves retired compound variables (old SSDI items removed from current
# EOD/TNM schemas), retired Reserved items, and other historical concepts
# that no longer appear in any live source but must remain in the vocabulary.
("2k Pass-through retired concepts", f"""
INSERT INTO {W}.concept_stage
    (concept_name,domain_id,vocabulary_id,concept_class_id,
     standard_concept,concept_code,valid_start_date,valid_end_date,invalid_reason)
SELECT concept_name,domain_id,vocabulary_id,concept_class_id,
       NULL, concept_code, valid_start_date, valid_end_date, invalid_reason
FROM {V}.concept
WHERE vocabulary_id = 'NAACCR'
  AND invalid_reason IS NOT NULL
  AND concept_code NOT IN (SELECT concept_code FROM {W}.concept_stage)
"""),

# ── 3a. Has Answer plain ───────────────────────────────────────────────────
("3a Has Answer plain", f"""
INSERT INTO {W}.concept_relationship_stage
    (concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,
     relationship_id,valid_start_date,valid_end_date,invalid_reason)
SELECT DISTINCT
    split_part(concept_code,'@',1), concept_code,
    'NAACCR','NAACCR','Has Answer','1970-01-01'::date,'2099-12-31'::date,NULL
FROM {W}.concept_stage
WHERE concept_class_id = 'NAACCR Value'
  AND concept_code NOT LIKE '%@%@%'
  AND invalid_reason IS NULL
  AND split_part(concept_code,'@',1) IN (
      SELECT concept_code FROM {W}.concept_stage
      WHERE concept_class_id = 'NAACCR Variable')
"""),

# ── 3b. Has Answer compound ────────────────────────────────────────────────
("3b Has Answer compound", f"""
INSERT INTO {W}.concept_relationship_stage
    (concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,
     relationship_id,valid_start_date,valid_end_date,invalid_reason)
SELECT DISTINCT
    split_part(concept_code,'@',1) || '@' || split_part(concept_code,'@',2),
    concept_code,
    'NAACCR','NAACCR','Has Answer','1970-01-01'::date,'2099-12-31'::date,NULL
FROM {W}.concept_stage
WHERE concept_class_id = 'NAACCR Value'
  AND concept_code LIKE '%@%@%'
  AND invalid_reason IS NULL
  AND (split_part(concept_code,'@',1) || '@' || split_part(concept_code,'@',2)) IN (
      SELECT concept_code FROM {W}.concept_stage
      WHERE concept_class_id = 'NAACCR Variable')
"""),

# ── 3c. Schema to Value ────────────────────────────────────────────────────
("3c Schema to Value", f"""
INSERT INTO {W}.concept_relationship_stage
    (concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,
     relationship_id,valid_start_date,valid_end_date,invalid_reason)
SELECT DISTINCT
    split_part(concept_code,'@',1), concept_code,
    'NAACCR','NAACCR','Schema to Value','1970-01-01'::date,'2099-12-31'::date,NULL
FROM {W}.concept_stage
WHERE concept_class_id = 'NAACCR Value'
  AND concept_code LIKE '%@%@%'
  AND invalid_reason IS NULL
  AND split_part(concept_code,'@',1) IN (
      SELECT concept_code FROM {W}.concept_stage
      WHERE concept_class_id = 'NAACCR Schema')
"""),

# ── 3d. Schema to Value proc ───────────────────────────────────────────────
("3d Schema to Value proc", f"""
INSERT INTO {W}.concept_relationship_stage
    (concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,
     relationship_id,valid_start_date,valid_end_date,invalid_reason)
SELECT DISTINCT
    split_part(concept_code,'@',1), concept_code,
    'NAACCR','NAACCR','Schema to Value','1970-01-01'::date,'2099-12-31'::date,NULL
FROM {W}.concept_stage
WHERE concept_class_id = 'NAACCR Procedure'
  AND invalid_reason IS NULL
  AND split_part(concept_code,'@',1) IN (
      SELECT concept_code FROM {W}.concept_stage
      WHERE concept_class_id = 'NAACCR Proc Schema')
"""),

# ── 3e. Concept replaced by ────────────────────────────────────────────────
("3e Concept replaced by", f"""
INSERT INTO {W}.concept_relationship_stage
    (concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,
     relationship_id,valid_start_date,valid_end_date,invalid_reason)
SELECT
    old_proc_schema || '@' || old_item_number || '@' || old_code,
    new_proc_schema || '@' || new_item_number || '@' || new_code,
    'NAACCR','NAACCR','Concept replaced by','1970-01-01'::date,'2099-12-31'::date,NULL
FROM {S}.naaccr_surgery_replacements r
WHERE (r.old_proc_schema || '@' || r.old_item_number || '@' || r.old_code)
        IN (SELECT concept_code FROM {W}.concept_stage)
  AND (r.new_proc_schema || '@' || r.new_item_number || '@' || r.new_code)
        IN (SELECT concept_code FROM {W}.concept_stage)
"""),

# ── 3f. Schema to Variable ─────────────────────────────────────────────────
("3f Schema to Variable", f"""
WITH all_inputs AS (
    SELECT schema_id, item_number FROM {S}.naaccr_eod_schema_inputs
    UNION
    SELECT schema_id, item_number FROM {S}.naaccr_tnm_schema_inputs
)
INSERT INTO {W}.concept_relationship_stage
    (concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,
     relationship_id,valid_start_date,valid_end_date,invalid_reason)
SELECT DISTINCT
    a.schema_id,
    a.schema_id || '@' || a.item_number,
    'NAACCR','NAACCR','Schema to Variable','1970-01-01'::date,'2099-12-31'::date,NULL
FROM all_inputs a
WHERE a.item_number NOT IN ('400','500','522','523','390','10','40')
  AND a.schema_id IN (
      SELECT concept_code FROM {W}.concept_stage
      WHERE concept_class_id = 'NAACCR Schema')
  AND (a.schema_id || '@' || a.item_number) IN (
      SELECT concept_code FROM {W}.concept_stage
      WHERE concept_class_id = 'NAACCR Variable')
"""),

]


def run(verbose=True):
    conn = config.get_db_conn()
    cur = conn.cursor()
    try:
        for label, sql in STEPS:
            cur.execute(sql)
            if verbose:
                print(f"  {cur.rowcount:>7}  {label}")
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


if __name__ == "__main__":
    print("Running load_stage...\n")
    run(verbose=True)

    conn = config.get_db_conn()
    cur = conn.cursor()
    print("\n=== COUNTS ===")
    for tbl, label in [
        (f"{W}.concept_stage",              "SQL build"),
        (f"{W}.concept_stage_py",           "Python build"),
        (f"{W}.concept_relationship_stage", "SQL build"),
        (f"{W}.concept_relationship_stage_py", "Python build"),
    ]:
        cur.execute(f"SELECT count(*) FROM {tbl}")
        print(f"  {tbl:<50} {cur.fetchone()[0]:>7}  ({label})")
    conn.close()
