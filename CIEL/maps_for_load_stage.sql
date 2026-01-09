--- Total script execution time: 1m 43s
/* ===========================================================
   PREPARE CIEL SOURCE MAPPING LOOKUP FOR THE LOAD STAGE
   =========================================================== */
DROP TABLE IF EXISTS ciel_mapping_lookup;
CREATE TABLE ciel_mapping_lookup AS
(
WITH allowed_source_vocabs AS (
  SELECT unnest(ARRAY[
    'LOINC','SNOMED-CT','RxNORM','ICD-10-WHO', 'ICD-10-WHO-2nd', 'SNOMED-UK','SNOMED-US',
    'OMOP-RxNORM','UCUM','HL-7-CVX','OMOP-Extension',
    'ICD-10-WHO-NP','NAACCR'
  ]) AS to_source_name
),
norm_vocab AS (
  /* ===========================================================
   Normalize external labels to OMOP vocabulary_id for joining
   =========================================================== */
  SELECT * FROM (VALUES
    ('SNOMED-CT','SNOMED'),
    ('SNOMED-UK','SNOMED'),
    ('SNOMED-US','SNOMED'),
    ('RxNORM','RxNorm'),
    ('OMOP-RxNORM','RxNorm Extension'),
    ('ICD-10-WHO','ICD10'),
    ('ICD-10-WHO-2nd','ICD10'),
    ('HL-7-CVX','CVX'),
    ('OMOP-Extension','OMOP Extension'),
    ('LOINC','LOINC'),
    ('UCUM','UCUM'),
    ('NAACCR','NAACCR')
  ) AS v(to_source_name, vocab_id)
),
/* ===========================================================
   1) Source rows: ACTIVE CIEL concepts + ACTIVE mappings, allowed external systems
   =========================================================== */
src AS (
  SELECT
    cm.from_concept_code AS source_code,
    cm.from_concept_name_resolved AS source_name,
    cc.concept_class AS source_class,
   cm.to_source_name AS from_vocabulary_id,    -- external label (e.g., 'SNOMED-UK')
    btrim(cm.to_concept_code) AS to_concept_code,       -- raw external code (trim)
    cm.map_type,
    nv.vocab_id AS target_vocab_norm      -- normalized OMOP vocab for join
  FROM sources.ciel_mappings cm
  JOIN sources.ciel_concepts  cc
    ON cc.id::varchar = cm.from_concept_code
   AND cc.retired = FALSE                           -- only active CIEL concepts
  JOIN allowed_source_vocabs asv
    ON asv.to_source_name = cm.to_source_name
  JOIN norm_vocab nv
    ON nv.to_source_name = cm.to_source_name
  WHERE cm.retired = FALSE                          -- only active mappings
    AND cm.map_type IN ('SAME-AS','NARROWER-THAN','BROADER-THAN')
    AND cm.to_concept_code IS NOT NULL
),
/* ===========================================================
   2) Attach OMOP target concept provided by CIEL
   =========================================================== */
map as (
  SELECT
    s.*,
    c.concept_id AS target_concept_id,
    c.concept_code AS target_concept_code,
    c.concept_name AS target_concept_name,
    c.vocabulary_id AS target_vocabulary_id,
    c.domain_id AS target_domain_id,
    c.concept_class_id AS target_concept_class_id,
    c.standard_concept AS target_standard_concept,
    c.invalid_reason AS target_invalid_reason
  FROM src s
  LEFT JOIN devv5.concept c
    ON c.vocabulary_id = s.target_vocab_norm
   AND c.concept_code  = s.to_concept_code)
SELECT DISTINCT source_code,
       source_name,
       source_class,
       map_type,
       target_concept_id,
       target_concept_code,
       target_concept_name,
       target_vocabulary_id,
       target_domain_id,
       target_concept_class_id,
       target_standard_concept,
       target_invalid_reason
FROM map);
/* ===========================================================
   RANK 1 SAME-AS
   =========================================================== */
DROP TABLE if exists ciel_rank_1_same_as;
CREATE TABLE ciel_rank_1_same_as AS
WITH
-- Base SAME-AS to Standard rows to avoid rescanning full table
base_same AS (
  SELECT *
  FROM ciel_mapping_lookup
  WHERE map_type = 'SAME-AS'
    AND target_standard_concept = 'S'
),
-- Sources with exactly one SAME-AS standard mapping
single_same_src AS (
  SELECT source_code
  FROM base_same
  GROUP BY source_code
  HAVING COUNT(*) = 1
),
-- Sources with more than one SAME-AS standard mapping
multi_same_src AS (
  SELECT source_code
  FROM base_same
  GROUP BY source_code
  HAVING COUNT(*) > 1
),
/* ===========================================================
   1.01: Exactly one standard SAME-AS row (unique 1-to-1 mapping)
   =========================================================== */
one_same_as AS (
  SELECT
    b.*,
    'Maps to' AS relationship_id,
    1 AS rank_num,
    '1.01: Unique 1-to-1 SAME-AS (standard)' AS rule_applied
  FROM base_same b
  JOIN single_same_src s
    USING (source_code)
),
/* ===========================================================
   1.02: 1-to-many SAME-AS for obvious combination drugs (by name or known exceptions)
   =========================================================== */
many_same_as_combo_drugs AS (
  SELECT
    b.*,
    'Maps to' AS relationship_id,
    1 AS rank_num,
    '1.02: 1-to-many SAME-AS combo drug ingredients/components' AS rule_applied
  FROM base_same b
  JOIN multi_same_src m
    USING (source_code)
  WHERE b.source_class = 'Drug'
    AND (b.source_name ~ ' / ' OR b.source_code IN ('166088','165445')) -- REGN-COV2(casirivimab+imdevimab), Water of Alibour (camphor+zinc sulfate+copper sulfate)
    AND NOT EXISTS (SELECT 1 FROM one_same_as x WHERE x.source_code = b.source_code)
),
/* ===========================================================
   1.03: 1-to-many SAME-AS Radiology/Imaging mapped to SNOMED procedures
   =========================================================== */
many_same_as_radiology AS (
  SELECT
    b.*,
    'Maps to' AS relationship_id,
    1 AS rank_num,
    '1.03: 1-to-many SAME-AS SNOMED imaging procedure' AS rule_applied
  FROM base_same b
  JOIN multi_same_src m
    USING (source_code)
  WHERE b.source_class = 'Radiology/Imaging Procedure'
    AND b.target_vocabulary_id = 'SNOMED'
    AND NOT EXISTS (SELECT 1 FROM one_same_as x WHERE x.source_code = b.source_code)
    AND NOT EXISTS (SELECT 1 FROM many_same_as_combo_drugs x WHERE x.source_code = b.source_code)
),
/* ===========================================================
   1.04: 1-to-many SAME-AS Question/Test mapped to LOINC
   =========================================================== */
many_same_as_question AS (
  SELECT
    b.*,
    'Maps to' AS relationship_id,
    1 AS rank_num,
    '1.04: 1-to-many SAME-AS test/question LOINC' AS rule_applied
  FROM base_same b
  JOIN multi_same_src m
    USING (source_code)
  WHERE b.source_class IN ('Question','Test')
    AND b.target_vocabulary_id = 'LOINC'
    AND NOT EXISTS (SELECT 1 FROM one_same_as x WHERE x.source_code = b.source_code)
    AND NOT EXISTS (SELECT 1 FROM many_same_as_combo_drugs x WHERE x.source_code = b.source_code)
    AND NOT EXISTS (SELECT 1 FROM many_same_as_radiology x WHERE x.source_code = b.source_code)
),
/* ===========================================================
   1.05: 1-to-many SAME-AS vaccine-related concepts mapped to CVX
   =========================================================== */
many_same_as_cvx AS (
  SELECT
    b.*,
    'Maps to' AS relationship_id,
    1 AS rank_num,
    '1.05: 1-to-many SAME-AS vaccine CVX' AS rule_applied
  FROM base_same b
  JOIN multi_same_src m
    USING (source_code)
  WHERE b.source_class IN ('Drug','Procedure')
    AND b.target_vocabulary_id = 'CVX'
    AND NOT EXISTS (SELECT 1 FROM one_same_as x WHERE x.source_code = b.source_code)
    AND NOT EXISTS (SELECT 1 FROM many_same_as_combo_drugs x WHERE x.source_code = b.source_code)
    AND NOT EXISTS (SELECT 1 FROM many_same_as_radiology x WHERE x.source_code = b.source_code)
    AND NOT EXISTS (SELECT 1 FROM many_same_as_question x WHERE x.source_code = b.source_code)
),
/* ===========================================================
   1.06: 1-to-many SAME-AS where all targets are assumed to be single-drug RxNorm/RxNorm Extension
   =========================================================== */
many_same_as_mono_drug AS (
  SELECT
    b.*,
    'Maps to' AS relationship_id,
    1 AS rank_num,
    '1.06: 1-to-many SAME-AS single-drug RxNorm/RxNorm Extension' AS rule_applied
  FROM base_same b
  JOIN multi_same_src m
    USING (source_code)
  WHERE b.source_class = 'Drug'
    AND b.target_vocabulary_id IN ('RxNorm','RxNorm Extension')
    AND NOT EXISTS (SELECT 1 FROM one_same_as x WHERE x.source_code = b.source_code)
    AND NOT EXISTS (SELECT 1 FROM many_same_as_combo_drugs x WHERE x.source_code = b.source_code)
    AND NOT EXISTS (SELECT 1 FROM many_same_as_radiology x WHERE x.source_code = b.source_code)
    AND NOT EXISTS (SELECT 1 FROM many_same_as_question x WHERE x.source_code = b.source_code)
    AND NOT EXISTS (SELECT 1 FROM many_same_as_cvx x WHERE x.source_code = b.source_code)
),
/* ===========================================================
   1.07: 1-to-many SAME-AS Meas Value SNOMED (multiple Meas Value targets per source)
   =========================================================== */
many_same_as_value AS (
  SELECT
    b.*,
    'Maps to' AS relationship_id,
    1 AS rank_num,
    '1.07: 1-to-many SAME-AS Meas Value SNOMED' AS rule_applied
  FROM base_same b
  JOIN multi_same_src m
    USING (source_code)
  WHERE b.target_vocabulary_id = 'SNOMED'
    AND b.target_domain_id     = 'Meas Value'
    AND b.source_code IN (
      SELECT source_code
      FROM base_same
      WHERE target_domain_id = 'Meas Value'
      GROUP BY source_code
      HAVING COUNT(*) > 1
    )
    AND NOT EXISTS (SELECT 1 FROM one_same_as x WHERE x.source_code = b.source_code)
    AND NOT EXISTS (SELECT 1 FROM many_same_as_combo_drugs x WHERE x.source_code = b.source_code)
    AND NOT EXISTS (SELECT 1 FROM many_same_as_radiology x WHERE x.source_code = b.source_code)
    AND NOT EXISTS (SELECT 1 FROM many_same_as_question x WHERE x.source_code = b.source_code)
    AND NOT EXISTS (SELECT 1 FROM many_same_as_cvx x WHERE x.source_code = b.source_code)
    AND NOT EXISTS (SELECT 1 FROM many_same_as_mono_drug x WHERE x.source_code = b.source_code)
),
/* ===========================================================
   1.08: 1-to-many SAME-AS where a SNOMED Disorder has an exact name match with the source
   =========================================================== */
many_same_as_name_similarity_disorder AS (
  SELECT
    b.*,
    'Maps to' AS relationship_id,
    1 AS rank_num,
    '1.08: 1-to-many SAME-AS exact name match + SNOMED Disorder' AS rule_applied
  FROM base_same b
  JOIN multi_same_src m
    USING (source_code)
  WHERE b.target_concept_class_id = 'Disorder'
    AND LOWER(b.source_name) = LOWER(b.target_concept_name)
    AND NOT EXISTS (SELECT 1 FROM one_same_as x WHERE x.source_code = b.source_code)
    AND NOT EXISTS (SELECT 1 FROM many_same_as_combo_drugs x WHERE x.source_code = b.source_code)
    AND NOT EXISTS (SELECT 1 FROM many_same_as_radiology x WHERE x.source_code = b.source_code)
    AND NOT EXISTS (SELECT 1 FROM many_same_as_question x WHERE x.source_code = b.source_code)
    AND NOT EXISTS (SELECT 1 FROM many_same_as_cvx x WHERE x.source_code = b.source_code)
    AND NOT EXISTS (SELECT 1 FROM many_same_as_mono_drug x WHERE x.source_code = b.source_code)
    AND NOT EXISTS (SELECT 1 FROM many_same_as_value x WHERE x.source_code = b.source_code)
),
/* ===========================================================
   Remaining multi-SAME-AS rows with Disorder targets, excluding all above buckets
   =========================================================== */
disorder_candidates AS (
  SELECT
    b.*,
    ROW_NUMBER() OVER (
      PARTITION BY b.source_code
      ORDER BY b.target_concept_id
    ) AS rn
  FROM base_same b
  JOIN multi_same_src m
    USING (source_code)
  WHERE b.target_concept_class_id = 'Disorder'
    AND NOT EXISTS (SELECT 1 FROM one_same_as x WHERE x.source_code = b.source_code)
    AND NOT EXISTS (SELECT 1 FROM many_same_as_combo_drugs x WHERE x.source_code = b.source_code)
    AND NOT EXISTS (SELECT 1 FROM many_same_as_radiology x WHERE x.source_code = b.source_code)
    AND NOT EXISTS (SELECT 1 FROM many_same_as_question x WHERE x.source_code = b.source_code)
    AND NOT EXISTS (SELECT 1 FROM many_same_as_cvx x WHERE x.source_code = b.source_code)
    AND NOT EXISTS (SELECT 1 FROM many_same_as_mono_drug x WHERE x.source_code = b.source_code)
    AND NOT EXISTS (SELECT 1 FROM many_same_as_value x WHERE x.source_code = b.source_code)
    AND NOT EXISTS (SELECT 1 FROM many_same_as_name_similarity_disorder x WHERE x.source_code = b.source_code)
),
/* ===========================================================
   1.09: Fallback 1-to-many SAME-AS to first SNOMED Disorder by concept_id (precedence)
   =========================================================== */
many_same_as_first_value_disorder AS (
 SELECT d.source_code,
       d.source_name,
       d.source_class,
       d.map_type,
       d.target_concept_id,
       d.target_concept_code,
       d.target_concept_name,
       d.target_vocabulary_id,
       d.target_domain_id,
       d.target_concept_class_id,
       d.target_standard_concept,
       d.target_invalid_reason,
       'Maps to' AS relationship_id,
       1 AS rank_num,
       '1.09: 1-to-many SAME-AS first SNOMED Disorder by precedence' AS rule_applied
  FROM disorder_candidates d
  WHERE d.rn = 1
),
/* ===========================================================
   Remaining multi-SAME-AS rows with SNOMED targets (any class), excluding all above
   =========================================================== */
snomed_candidates AS (
  SELECT
    b.*,
    ROW_NUMBER() OVER (
      PARTITION BY b.source_code
      ORDER BY b.target_concept_id
    ) AS rn
  FROM base_same b
  JOIN multi_same_src m
    USING (source_code)
  WHERE b.target_vocabulary_id = 'SNOMED'
    AND NOT EXISTS (SELECT 1 FROM one_same_as x WHERE x.source_code = b.source_code)
    AND NOT EXISTS (SELECT 1 FROM many_same_as_combo_drugs x WHERE x.source_code = b.source_code)
    AND NOT EXISTS (SELECT 1 FROM many_same_as_radiology x WHERE x.source_code = b.source_code)
    AND NOT EXISTS (SELECT 1 FROM many_same_as_question x WHERE x.source_code = b.source_code)
    AND NOT EXISTS (SELECT 1 FROM many_same_as_cvx x WHERE x.source_code = b.source_code)
    AND NOT EXISTS (SELECT 1 FROM many_same_as_mono_drug x WHERE x.source_code = b.source_code)
    AND NOT EXISTS (SELECT 1 FROM many_same_as_value x WHERE x.source_code = b.source_code)
    AND NOT EXISTS (SELECT 1 FROM many_same_as_first_value_disorder x WHERE x.source_code = b.source_code)
    AND NOT EXISTS (SELECT 1 FROM many_same_as_name_similarity_disorder x WHERE x.source_code = b.source_code)
),
/* ===========================================================
   1.10: Remaining 1-to-many SAME-AS to first SNOMED target (non-Disorder or mixed)
   =========================================================== */
many_same_as_first_value_others AS (
 SELECT s.source_code,
       s.source_name,
       s.source_class,
       s.map_type,
       s.target_concept_id,
       s.target_concept_code,
       s.target_concept_name,
       s.target_vocabulary_id,
       s.target_domain_id,
       s.target_concept_class_id,
       s.target_standard_concept,
       s.target_invalid_reason,
    'Maps to' AS relationship_id,
    1 AS rank_num,
    '1.10: 1-to-many SAME-AS first SNOMED (other classes)' AS rule_applied
  FROM snomed_candidates s
  WHERE s.rn = 1
)
SELECT * FROM one_same_as
UNION ALL
SELECT * FROM many_same_as_combo_drugs
UNION ALL
SELECT * FROM many_same_as_radiology
UNION ALL
SELECT * FROM many_same_as_question
UNION ALL
SELECT * FROM many_same_as_cvx
UNION ALL
SELECT * FROM many_same_as_mono_drug
UNION ALL
SELECT * FROM many_same_as_value
UNION ALL
SELECT * FROM many_same_as_first_value_disorder
UNION ALL
SELECT * FROM many_same_as_first_value_others
UNION ALL
SELECT * FROM many_same_as_name_similarity_disorder; -- 37303 (36116)
/* ===========================================================
   RANK 1 NARROWER-THAN
   =========================================================== */
DROP TABLE IF EXISTS ciel_rank_1_narrower_than;
CREATE TABLE ciel_rank_1_narrower_than AS
WITH
-- Base NARROWER-THAN mappings to Standard concepts, excluding rank 1 SAME-AS
nt_base AS (
    SELECT *
    FROM ciel_mapping_lookup c
    WHERE c.map_type = 'NARROWER-THAN'
      AND c.target_standard_concept = 'S'
      AND NOT EXISTS (
            SELECT 1
            FROM ciel_rank_1_same_as x
            WHERE x.source_code = c.source_code
          )
),
-- Count NARROWER-THAN mappings per source_code
nt_counts AS (
    SELECT
        source_code,
        COUNT(*) AS nt_cnt
    FROM nt_base
    GROUP BY source_code
),
-- Exactly one NARROWER-THAN mapping (single)
nt_single AS (
    SELECT b.*
    FROM nt_base b
    JOIN nt_counts c USING (source_code)
    WHERE c.nt_cnt = 1
),
-- More than one NARROWER-THAN mapping (composite / multiple)
nt_multi AS (
    SELECT b.*
    FROM nt_base b
    JOIN nt_counts c USING (source_code)
    WHERE c.nt_cnt > 1
),
-- Hard-coded exclusions for "and/or" composite diagnoses/mappings (they have maps in the concept_relationship_manual)
bad_composite_codes AS (
    SELECT unnest(ARRAY[
        '142746','142747','142791','145185','146687','146774','146785',
        '127253','127274','136617','131951'
    ]) AS source_code
),
-- Hard-coded exclusions for vaccination procedures (to preserve maps to drugs only)
vaccine_procedure_codes AS (
    SELECT unnest(ARRAY[
        '166356','166147','166145','166144','166143','166142'
    ]) AS source_code
),
/* ===========================================================
   2.01: 1 NARROWER-THAN SNOMED vs SAME-AS ICD10
   =========================================================== */
one_narrower_1 AS (
    SELECT
        n.*,
        'Maps to' AS relationship_id,
        1 AS rank_num,
        '2.01: 1 NARROWER-THAN SNOMED vs SAME-AS ICD10' AS rule_applied
    FROM nt_single n
    WHERE n.target_vocabulary_id = 'SNOMED'
      AND EXISTS (SELECT 1 FROM ciel_mapping_lookup x WHERE x.source_code = n.source_code AND x.map_type = 'SAME-AS' AND x.target_vocabulary_id = 'ICD10'
          )
),
/* ===========================================================
   2.02: 1 NARROWER-THAN SNOMED alone
   =========================================================== */
one_narrower_2 AS (
    SELECT
        n.*,
        'Maps to' AS relationship_id,
        1 AS rank_num,
        '2.02: 1 NARROWER-THAN SNOMED alone' AS rule_applied
    FROM nt_single n
    WHERE n.target_vocabulary_id = 'SNOMED'
      AND NOT EXISTS (SELECT 1 FROM one_narrower_1 x WHERE x.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM ciel_mapping_lookup x WHERE x.source_code = n.source_code AND x.source_class = 'Test' AND x.map_type = 'BROADER-THAN' AND x.target_vocabulary_id = 'LOINC')  
),
/* ===========================================================
   2.03: 1 NARROWER-THAN CVX alone
   =========================================================== */
one_narrower_cvx AS (
    SELECT
        n.*,
        'Maps to' AS relationship_id,
        1 AS rank_num,
        '2.03: 1 NARROWER-THAN CVX alone' AS rule_applied
    FROM nt_single n
    WHERE n.target_vocabulary_id = 'CVX'
      AND NOT EXISTS (SELECT 1 FROM one_narrower_1 x WHERE x.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM one_narrower_2 x WHERE x.source_code = n.source_code)
),
/* ===========================================================
   2.04: 1 NARROWER-THAN RxNorm / RxNorm Extension alone
   =========================================================== */
one_narrower_rxnorm AS (
    SELECT
        n.*,
        'Maps to' AS relationship_id,
        1 AS rank_num,
        '2.04: 1 NARROWER-THAN RxNorm/RxE alone' AS rule_applied
    FROM nt_single n
    WHERE n.target_vocabulary_id IN ('RxNorm','RxNorm Extension')
      AND NOT EXISTS (SELECT 1 FROM one_narrower_1 x WHERE x.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM one_narrower_2 x WHERE x.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM one_narrower_cvx x WHERE x.source_code = n.source_code)
),
/* ===========================================================
   2.05: 1 NARROWER-THAN LOINC alone
   =========================================================== */
one_narrower_loinc AS (
    SELECT
        n.*,
        'Maps to' AS relationship_id,
        1 AS rank_num,
        '2.05: 1 NARROWER-THAN LOINC alone' AS rule_applied
    FROM nt_single n
    WHERE n.target_vocabulary_id = 'LOINC'
      AND n.source_class <> 'Radiology/Imaging Procedure'  -- exclude radiology: prefer SNOMED broader-than
      AND NOT EXISTS (SELECT 1 FROM one_narrower_1 x WHERE x.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM one_narrower_2 x WHERE x.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM one_narrower_cvx x WHERE x.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM one_narrower_rxnorm x WHERE x.source_code = n.source_code)
),
/* ===========================================================
   2.06: many NARROWER-THAN SNOMED composite maps (with ICD10)
   =========================================================== */
many_narrower_composite AS (
    SELECT
        n.*,
        'Maps to' AS relationship_id,
        1 AS rank_num,
        '2.06: many NARROWER-THAN SNOMED composite maps' AS rule_applied
    FROM nt_multi n
    WHERE n.target_vocabulary_id = 'SNOMED'
      AND EXISTS (
            SELECT 1
            FROM ciel_mapping_lookup x
            WHERE x.source_code = n.source_code
              AND x.target_vocabulary_id = 'ICD10'
          )
      AND NOT EXISTS (SELECT 1 FROM bad_composite_codes b WHERE b.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM one_narrower_1 x WHERE x.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM one_narrower_2 x WHERE x.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM one_narrower_cvx x WHERE x.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM one_narrower_rxnorm x WHERE x.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM one_narrower_loinc x WHERE x.source_code = n.source_code)
),
/* ===========================================================
   2.07: many NARROWER-THAN SNOMED Spec Anatomic Site
   =========================================================== */
many_narrower_anatomy AS (
    SELECT
        n.*,
        'Maps to' AS relationship_id,
        1 AS rank_num,
        '2.07: many NARROWER-THAN SNOMED Spec Anatomic Site' AS rule_applied
    FROM nt_multi n
    WHERE n.target_vocabulary_id = 'SNOMED'
      AND n.source_class = 'Anatomy'
      AND n.target_domain_id = 'Spec Anatomic Site'
      AND NOT EXISTS (SELECT 1 FROM bad_composite_codes b WHERE b.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM one_narrower_1 x WHERE x.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM one_narrower_2 x WHERE x.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM one_narrower_cvx x WHERE x.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM one_narrower_rxnorm x WHERE x.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM one_narrower_loinc x WHERE x.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM many_narrower_composite x WHERE x.source_code = n.source_code)
),
/* ===========================================================
   2.08: many NARROWER-THAN SNOMED Procedure (composite + mono)
   - Exclude known vaccine-like procedures (handled via CVX)
   =========================================================== */
many_narrower_procedure AS (
    SELECT
        n.*,
        'Maps to' AS relationship_id,
        1 AS rank_num,
        '2.08: many NARROWER-THAN composite and mono SNOMED Procedure' AS rule_applied
    FROM nt_multi n
    WHERE n.target_vocabulary_id = 'SNOMED'
      AND n.source_class IN ('Procedure','ConvSet','Radiology/Imaging Procedure')
      AND n.target_domain_id = 'Procedure'
      AND NOT EXISTS (SELECT 1 FROM vaccine_procedure_codes b  WHERE b.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM one_narrower_1 x WHERE x.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM one_narrower_2 x WHERE x.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM one_narrower_cvx x WHERE x.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM one_narrower_rxnorm x WHERE x.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM one_narrower_loinc x WHERE x.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM many_narrower_composite x WHERE x.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM many_narrower_anatomy x WHERE x.source_code = n.source_code)
),
/* ===========================================================
   2.09: many NARROWER-THAN LOINC Test/Question
   =========================================================== */
many_narrower_lab_test_quest AS (
    SELECT
        n.*,
        'Maps to' AS relationship_id,
        1 AS rank_num,
        '2.09: many NARROWER-THAN LOINC Test/Question' AS rule_applied
    FROM nt_multi n
    WHERE n.target_vocabulary_id = 'LOINC'
      AND n.source_class IN ('LabSet','Test','Question')  -- ConvSet excluded: handled manually
      AND n.target_domain_id = 'Measurement'
      AND NOT EXISTS (SELECT 1 FROM one_narrower_1 x WHERE x.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM one_narrower_2 x WHERE x.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM one_narrower_cvx x WHERE x.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM one_narrower_rxnorm x WHERE x.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM one_narrower_loinc x WHERE x.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM many_narrower_composite x WHERE x.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM many_narrower_anatomy x WHERE x.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM many_narrower_procedure x WHERE x.source_code = n.source_code)
),
/* ===========================================================
   2.10: many NARROWER-THAN SNOMED composite Diagnosis/Finding
   =========================================================== */
many_narrower_composite_diagn_find AS (
    SELECT
        n.*,
        'Maps to' AS relationship_id,
        1 AS rank_num,
        '2.10: many NARROWER-THAN SNOMED composite Diagnosis' AS rule_applied
    FROM nt_multi n
    WHERE n.target_vocabulary_id = 'SNOMED'
      AND n.source_class IN ('Diagnosis','Finding')
      AND NOT EXISTS (SELECT 1 FROM bad_composite_codes b WHERE b.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM one_narrower_1 x WHERE x.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM one_narrower_2 x WHERE x.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM one_narrower_cvx x WHERE x.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM one_narrower_rxnorm x WHERE x.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM one_narrower_loinc x WHERE x.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM many_narrower_composite x WHERE x.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM many_narrower_anatomy x WHERE x.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM many_narrower_procedure x WHERE x.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM many_narrower_lab_test_quest x WHERE x.source_code = n.source_code)
),
/* ===========================================================
   2.11: many NARROWER-THAN CVX Vaccines
   =========================================================== */
many_narrower_cvx AS (
    SELECT
        n.*,
        'Maps to' AS relationship_id,
        1 AS rank_num,
        '2.11: many NARROWER-THAN CVX Vaccines' AS rule_applied
    FROM nt_multi n
    WHERE n.target_vocabulary_id = 'CVX'
      AND NOT EXISTS (SELECT 1 FROM one_narrower_1 x WHERE x.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM one_narrower_2 x WHERE x.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM one_narrower_cvx x WHERE x.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM one_narrower_rxnorm x WHERE x.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM one_narrower_loinc x WHERE x.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM many_narrower_composite x WHERE x.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM many_narrower_anatomy x WHERE x.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM many_narrower_procedure x WHERE x.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM many_narrower_composite_diagn_find x WHERE x.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM many_narrower_lab_test_quest x WHERE x.source_code = n.source_code)
),
/* ===========================================================
   2.12: many NARROWER-THAN Drugs and Regimens (RxNorm/RxE)
   =========================================================== */
many_narrower_drugs_and_regimens_rx AS (
    SELECT
        n.*,
        'Maps to' AS relationship_id,
        1 AS rank_num,
        '2.12: many NARROWER-THAN Drugs and Regimens' AS rule_applied
    FROM nt_multi n
    WHERE n.target_vocabulary_id IN ('RxNorm','RxNorm Extension')
      AND n.source_class IN ('Misc','Drug')
      AND n.source_name ~* ' / |single agent | and '
      AND NOT EXISTS (SELECT 1 FROM one_narrower_1 x WHERE x.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM one_narrower_2 x WHERE x.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM one_narrower_cvx x WHERE x.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM one_narrower_rxnorm x WHERE x.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM one_narrower_loinc x WHERE x.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM many_narrower_composite x WHERE x.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM many_narrower_anatomy x WHERE x.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM many_narrower_procedure x WHERE x.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM many_narrower_composite_diagn_find x WHERE x.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM many_narrower_lab_test_quest x WHERE x.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM many_narrower_cvx x WHERE x.source_code = n.source_code)
),
/* ===========================================================
   2.13: many NARROWER-THAN SNOMED Regimens
   - Target in Therapeutic regimen hierarchy
   =========================================================== */
many_narrower_regimens_sn AS (
    SELECT
        n.*,
        'Maps to' AS relationship_id,
        1 AS rank_num,
        '2.13: many NARROWER-THAN SNOMED Regimens' AS rule_applied
    FROM nt_multi n--ciel_mapping_lookup n
    WHERE n.target_vocabulary_id = 'SNOMED'
      AND n.source_class = 'Misc'
      AND n.source_name ~* ' / |single agent'
      AND n.target_concept_id IN (
          SELECT descendant_concept_id
          FROM concept_ancestor
          WHERE ancestor_concept_id = 4045950  -- Therapeutic regimen
      )
),
/* ===========================================================
   2.14: many NARROWER-THAN SNOMED composite maps (selected cases)
   =========================================================== */
many_narrower_composite_2 AS (
    SELECT
        n.*,
        'Maps to' AS relationship_id,
        1 AS rank_num,
        '2.14: many NARROWER-THAN SNOMED composite maps' AS rule_applied
    FROM nt_multi n
    WHERE n.target_vocabulary_id = 'SNOMED'
    AND source_code in ('162203', '160075', '159710', '166603', '166526', '165224', '163283', '162572', '160562', '160260', '168731')
)
SELECT * FROM one_narrower_1
UNION ALL
SELECT * FROM one_narrower_2
UNION ALL
SELECT * FROM one_narrower_cvx
UNION ALL
SELECT * FROM one_narrower_rxnorm
UNION ALL
SELECT * FROM one_narrower_loinc
UNION ALL
SELECT * FROM many_narrower_composite
UNION ALL
SELECT * FROM many_narrower_anatomy
UNION ALL
SELECT * FROM many_narrower_procedure
UNION ALL
SELECT * FROM many_narrower_lab_test_quest
UNION ALL
SELECT * FROM many_narrower_composite_diagn_find
UNION ALL
SELECT * FROM many_narrower_cvx
UNION ALL
SELECT * FROM many_narrower_drugs_and_regimens_rx
UNION ALL
SELECT * FROM many_narrower_regimens_sn
UNION ALL
SELECT * FROM many_narrower_composite_2; -- 15203
/* ===========================================================
   RANK 1 BROADER-THAN
   =========================================================== */
DROP TABLE IF EXISTS ciel_rank_1_broader_than;
CREATE TABLE ciel_rank_1_broader_than AS
WITH
-- Base BROADER-THAN mappings to Standard concepts, excluding maps already ranked via SAME-AS or NARROWER-THAN
bt_base AS (
    SELECT *
    FROM ciel_mapping_lookup c
    WHERE c.map_type = 'BROADER-THAN'
      AND c.target_standard_concept = 'S'
      AND NOT EXISTS (SELECT 1 FROM ciel_rank_1_narrower_than x WHERE x.source_code = c.source_code)
      AND NOT EXISTS (SELECT 1 FROM ciel_rank_1_same_as y WHERE y.source_code = c.source_code)
),
-- Count BROADER-THAN mappings per source_code
bt_counts AS (
    SELECT
        source_code,
        COUNT(*) AS bt_cnt
    FROM bt_base
    GROUP BY source_code
),
-- Exactly one BROADER-THAN mapping
bt_single AS (
    SELECT b.*
    FROM bt_base b
    JOIN bt_counts c USING (source_code)
    WHERE c.bt_cnt = 1
),
-- More than one BROADER-THAN mapping (composite / multiple broader targets)
bt_multi AS (
    SELECT b.*
    FROM bt_base b
    JOIN bt_counts c USING (source_code)
    WHERE c.bt_cnt > 1
),
/* ===========================================================
   3.01: 1 BROADER-THAN SNOMED only
   - No SAME-AS / NARROWER-THAN rank already assigned
   =========================================================== */
one_broader AS (
    SELECT
        n.*,
        'Maps to' AS relationship_id,
        1 AS rank_num,
        '3.01: 1 BROADER-THAN SNOMED only' AS rule_applied
    FROM bt_single n
    WHERE n.target_vocabulary_id = 'SNOMED'
),
/* ===========================================================
   3.02: many BROADER-THAN Radiology/Imaging procedures to SNOMED
   =========================================================== */
many_broader_radiology AS (
    SELECT
        n.*,
        'Maps to' AS relationship_id,
        1 AS rank_num,
        '3.02: many BROADER-THAN SNOMED Radiology' AS rule_applied
    FROM bt_multi n
    WHERE n.source_class = 'Radiology/Imaging Procedure'
      AND n.target_vocabulary_id = 'SNOMED'
      AND NOT EXISTS (SELECT 1 FROM one_broader x WHERE x.source_code = n.source_code)
),
/* ===========================================================
   3.03: many BROADER-THAN LOINC Test
   =========================================================== */
many_broader_labs AS (
    SELECT
        n.*,
        'Maps to' AS relationship_id,
        1 AS rank_num,
        '3.03: many BROADER-THAN LOINC Test' AS rule_applied
    FROM bt_multi n
    WHERE n.target_vocabulary_id = 'LOINC'
      AND n.source_class = 'Test'
      AND NOT EXISTS (SELECT 1 FROM one_broader x WHERE x.source_code = n.source_code)
      AND NOT EXISTS (SELECT 1 FROM many_broader_radiology x WHERE x.source_code = n.source_code)
),
/* ===========================================================
   3.04: one BROADER-THAN LOINC Test
   =========================================================== */
one_broader_labs AS (
    SELECT
        n.*,
        'Maps to' AS relationship_id,
        1 AS rank_num,
        '3.04: one BROADER-THAN LOINC Test' AS rule_applied
    FROM  ciel_mapping_lookup n
    WHERE n.target_vocabulary_id = 'LOINC'
      AND n.source_class = 'Test'
      AND n.map_type = 'BROADER-THAN'
      AND EXISTS (SELECT 1 FROM ciel_mapping_lookup x WHERE x.source_code = n.source_code AND x.map_type = 'NARROWER-THAN' AND x.target_vocabulary_id = 'SNOMED')
     AND source_code IN (SELECT source_code FROM ciel_mapping_lookup GROUP BY source_code HAVING COUNT(1)= 2)
     AND NOT EXISTS (SELECT 1 FROM one_broader x WHERE x.source_code = n.source_code)
     AND NOT EXISTS (SELECT 1 FROM many_broader_radiology x WHERE x.source_code = n.source_code)
     AND NOT EXISTS (SELECT 1 FROM many_broader_labs x WHERE x.source_code = n.source_code)
)
SELECT * FROM one_broader
UNION ALL
SELECT * FROM many_broader_radiology
UNION ALL
SELECT * FROM many_broader_labs
UNION ALL
SELECT * FROM one_broader_labs
;
/* ===========================================================
   Add missing ingredients for combo drugs
   =========================================================== */
DROP TABLE IF EXISTS missing_drugs_rank_1;
CREATE TABLE missing_drugs_rank_1 AS
WITH mapped AS (
    SELECT * FROM ciel_rank_1_same_as
    UNION ALL
    SELECT * FROM ciel_rank_1_narrower_than
    UNION ALL
    SELECT * FROM ciel_rank_1_broader_than
),
-- Base: combo Drug/Misc rows with non-standard targets
-- for sources whose rank-1 mappings are ONLY Ingredients
base AS (
    SELECT DISTINCT
        a.source_code,
        a.source_name,
        a.source_class,
        a.map_type,
        a.target_concept_id
    FROM ciel_mapping_lookup a
    WHERE a.source_class IN ('Drug','Misc')
      AND a.source_name ~* '/| and | with |single agent'
      AND a.target_standard_concept IS NULL
      -- Source has at least one rank-1 mapping to an Ingredient
      AND EXISTS (SELECT 1 FROM mapped m WHERE m.source_code = a.source_code AND m.target_concept_class_id = 'Ingredient')
      -- Source has no rank-1 mappings to other Drug concept classes
      AND NOT EXISTS (SELECT 1 FROM mapped m WHERE m.source_code = a.source_code AND m.target_concept_class_id <> 'Ingredient' AND m.target_domain_id = 'Drug')
      -- Exclude CVX rank-1 mappings (vaccines handled separately)
      AND NOT EXISTS (SELECT 1 FROM mapped m WHERE m.source_code = a.source_code AND m.target_vocabulary_id = 'CVX')
),
-- Crosswalk ingredients to Standard concepts via existing 'Maps to' relationships
joined AS (
    SELECT
        b.source_code,
        b.source_name,
        b.source_class,
        b.map_type,
        r.relationship_id,
        d.concept_id AS target_concept_id,
        d.concept_code AS target_concept_code,
        d.concept_name AS target_concept_name,
        d.vocabulary_id AS target_vocabulary_id,
        d.domain_id AS target_domain_id,
        d.concept_class_id AS target_concept_class_id,
        d.standard_concept AS target_standard_concept,
        d.invalid_reason AS target_invalid_reason
    FROM base b
    JOIN concept_relationship r
      ON r.concept_id_1 = b.target_concept_id
     AND r.relationship_id = 'Maps to'
     AND r.invalid_reason IS NULL
    JOIN concept d
      ON d.concept_id = r.concept_id_2
     AND d.standard_concept = 'S'
    -- Exclude ingredient-standard pairs already present in any rank-1 bucket
    WHERE NOT EXISTS (SELECT 1 FROM mapped t WHERE t.source_code = b.source_code AND t.target_concept_id = d.concept_id)
)
SELECT
  source_code,
  source_name,
  source_class,
  STRING_AGG(DISTINCT map_type, ', ' ORDER BY map_type) AS map_type,
  target_concept_id,
  target_concept_code,
  target_concept_name,
  target_vocabulary_id,
  target_domain_id,
  target_concept_class_id,
  target_standard_concept,
  target_invalid_reason,
  relationship_id,
  2 AS rank_num,
  '4.01: missing non-Standard combo Drug/Regimen Ingredient to Standard (OMOP crosswalk)' AS rule_applied
FROM joined
GROUP BY
  source_code,
  source_name,
  source_class,
  target_concept_id,
  target_concept_code,
  target_concept_name,
  target_vocabulary_id,
  target_domain_id,
  target_concept_class_id,
  target_standard_concept,
  target_invalid_reason,
  relationship_id; -- (90)
/* ===========================================================
   RANK 2 SAME AS (from non-standard CIEL maps to standard OMOP)
   =========================================================== */
DROP TABLE IF EXISTS ciel_rank_2_same_as;
CREATE TABLE ciel_rank_2_same_as AS
WITH
/* ===========================================================
   Base: unmapped CIEL rows (no rank-1 mappings)
   =========================================================== */
unmapped AS (
    SELECT *
    FROM ciel_mapping_lookup
    WHERE source_code NOT IN (SELECT source_code FROM ciel_rank_1_narrower_than)
      AND source_code NOT IN (SELECT source_code FROM ciel_rank_1_same_as)
      AND source_code NOT IN (SELECT source_code FROM ciel_rank_1_broader_than)
),
/* ===========================================================
   Non-standard SAME-AS rows only
   =========================================================== */
nonstd_sameas AS (
    SELECT *
    FROM unmapped
    WHERE map_type = 'SAME-AS'
      AND target_standard_concept IS NULL
),
sameas_counts AS (
    SELECT
        source_code,
        COUNT(*) AS sameas_cnt
    FROM nonstd_sameas
    GROUP BY source_code
),
/* ===========================================================
   Crosswalk via concept_relationship to Standard concepts
   =========================================================== */
crosswalk_base AS (
    SELECT
        a.source_code,
        a.source_name,
        a.source_class,
        a.map_type,
        a.target_concept_id AS nonstd_target_concept_id,
        r.relationship_id,
        d.concept_id AS target_concept_id,
        d.concept_code AS target_concept_code,
        d.concept_name AS target_concept_name,
        d.vocabulary_id AS target_vocabulary_id,
        d.domain_id AS target_domain_id,
        d.concept_class_id AS target_concept_class_id,
        d.standard_concept AS target_standard_concept,
        d.invalid_reason AS target_invalid_reason
    FROM nonstd_sameas a
    JOIN concept_relationship r
      ON r.concept_id_1 = a.target_concept_id
     AND r.relationship_id IN ('Maps to', 'Maps to value')
     AND r.invalid_reason IS NULL
    JOIN concept d
      ON d.concept_id = r.concept_id_2
     AND d.standard_concept = 'S'
),
base_single AS (
    SELECT cb.*
    FROM crosswalk_base cb
    JOIN sameas_counts c USING (source_code)
    WHERE c.sameas_cnt = 1
),
base_multi AS (
    SELECT cb.*
    FROM crosswalk_base cb
    JOIN sameas_counts c USING (source_code)
    WHERE c.sameas_cnt > 1
),
/* ===========================================================
   5.01: 1 non-Standard SAME-AS to Standard (OMOP crosswalk)
   =========================================================== */
one_non_s_same_as AS (
    SELECT DISTINCT
        source_code,
        source_name,
        source_class,
        map_type,
        target_concept_id,
        target_concept_code,
        target_concept_name,
        target_vocabulary_id,
        target_domain_id,
        target_concept_class_id,
        target_standard_concept,
        target_invalid_reason,
        relationship_id,
        2 AS rank_num,
        '5.01: 1 non-Standard SAME-AS to Standard (OMOP crosswalk)' AS rule_applied
    FROM base_single
),
/* ===========================================================
   5.02: many non-Standard SAME-AS Diagnoses/Findings to Standard
   =========================================================== */
many_non_s_same_as_diagn_find AS (
    SELECT DISTINCT
        b.source_code,
        b.source_name,
        b.source_class,
        b.map_type,
        b.target_concept_id,
        b.target_concept_code,
        b.target_concept_name,
        b.target_vocabulary_id,
        b.target_domain_id,
        b.target_concept_class_id,
        b.target_standard_concept,
        b.target_invalid_reason,
        b.relationship_id,
        2 AS rank_num,
        '5.02: many non-Standard SAME-AS Diagnoses/Findings to Standard (OMOP crosswalk)' AS rule_applied
    FROM base_multi b
    WHERE b.source_class IN ('Diagnosis','Finding','Symptom/Finding')
      AND NOT EXISTS (SELECT 1 FROM one_non_s_same_as x WHERE x.source_code = b.source_code)
),
/* ===========================================================
   5.03: many non-Standard SAME-AS Vaccines to Standard (CVX)
   =========================================================== */
many_non_s_same_as_cvx AS (
    SELECT DISTINCT
        b.source_code,
        b.source_name,
        b.source_class,
        b.map_type,
        b.target_concept_id,
        b.target_concept_code,
        b.target_concept_name,
        b.target_vocabulary_id,
        b.target_domain_id,
        b.target_concept_class_id,
        b.target_standard_concept,
        b.target_invalid_reason,
        b.relationship_id,
        2 AS rank_num,
        '5.03: many non-Standard SAME-AS Vaccines to Standard (OMOP crosswalk)' AS rule_applied
    FROM base_multi b
    WHERE b.target_vocabulary_id = 'CVX'
      AND b.source_class IN ('Drug','Procedure')
      AND b.relationship_id = 'Maps to'
      AND NOT EXISTS (SELECT 1 FROM one_non_s_same_as x WHERE x.source_code = b.source_code)
      AND NOT EXISTS (SELECT 1 FROM many_non_s_same_as_diagn_find x WHERE x.source_code = b.source_code)
),
/* ===========================================================
   5.04: many non-Standard SAME-AS Drugs to Standard (RxNorm/RxE)
   =========================================================== */
many_non_s_same_as_rx AS (
    SELECT DISTINCT
        b.source_code,
        b.source_name,
        b.source_class,
        b.map_type,
        b.target_concept_id,
        b.target_concept_code,
        b.target_concept_name,
        b.target_vocabulary_id,
        b.target_domain_id,
        b.target_concept_class_id,
        b.target_standard_concept,
        b.target_invalid_reason,
        b.relationship_id,
        2 AS rank_num,
        '5.04: many non-Standard SAME-AS Drugs to Standard (OMOP crosswalk)' AS rule_applied
    FROM base_multi b
    WHERE b.target_vocabulary_id IN ('RxNorm','RxNorm Extension')
      AND b.source_class IN ('Drug','Misc','Procedure')
      AND b.relationship_id = 'Maps to'
      AND NOT EXISTS (SELECT 1 FROM one_non_s_same_as x WHERE x.source_code = b.source_code)
      AND NOT EXISTS (SELECT 1 FROM many_non_s_same_as_diagn_find x WHERE x.source_code = b.source_code)
      AND NOT EXISTS (SELECT 1 FROM many_non_s_same_as_cvx x WHERE x.source_code = b.source_code)
),
/* ===========================================================
   5.05: many non-Standard SAME-AS Other classes to Standard
   =========================================================== */
many_non_s_same_as_other AS (
    SELECT DISTINCT
        b.source_code,
        b.source_name,
        b.source_class,
        b.map_type,
        b.target_concept_id,
        b.target_concept_code,
        b.target_concept_name,
        b.target_vocabulary_id,
        b.target_domain_id,
        b.target_concept_class_id,
        b.target_standard_concept,
        b.target_invalid_reason,
        b.relationship_id,
        2 AS rank_num,
        '5.05: many non-Standard SAME-AS Other classes to Standard (OMOP crosswalk)' AS rule_applied
    FROM base_multi b
    WHERE b.source_class NOT IN ('Diagnosis','Drug','Finding','Symptom/Finding')
      AND b.relationship_id IN ('Maps to','Maps to value')
      AND NOT EXISTS (SELECT 1 FROM one_non_s_same_as x WHERE x.source_code = b.source_code)
      AND NOT EXISTS (SELECT 1 FROM many_non_s_same_as_diagn_find x WHERE x.source_code = b.source_code)
      AND NOT EXISTS (SELECT 1 FROM many_non_s_same_as_cvx x WHERE x.source_code = b.source_code)
      AND NOT EXISTS (SELECT 1 FROM many_non_s_same_as_rx x WHERE x.source_code = b.source_code)
)
SELECT * FROM one_non_s_same_as
UNION ALL
SELECT * FROM many_non_s_same_as_diagn_find
UNION ALL
SELECT * FROM many_non_s_same_as_cvx
UNION ALL
SELECT * FROM many_non_s_same_as_rx
UNION ALL
SELECT * FROM many_non_s_same_as_other; -- 6028
/* ===========================================================
   RANK 2 NARROWER-THAN
   =========================================================== */
DROP TABLE IF EXISTS ciel_rank_2_narrower_than;
CREATE TABLE ciel_rank_2_narrower_than AS
WITH
/* ===========================================================
   Base: unmapped CIEL rows not covered by rank-1 or rank-2 SAME-AS
   =========================================================== */
therapeutic_regimens AS (
    SELECT descendant_concept_id
    FROM concept_ancestor
    WHERE ancestor_concept_id = 4045950 -- Therapeutic regimen
),
unmapped AS (
    SELECT l.*
    FROM ciel_mapping_lookup l
    WHERE NOT EXISTS (SELECT 1 FROM ciel_rank_1_narrower_than x WHERE x.source_code = l.source_code AND NOT EXISTS (
                          SELECT 1 FROM therapeutic_regimens tr WHERE tr.descendant_concept_id = x.target_concept_id)) -- safety measure for regimens
      AND source_code NOT IN (SELECT source_code FROM ciel_rank_1_same_as)
      AND source_code NOT IN (SELECT source_code FROM ciel_rank_1_broader_than)
      AND source_code NOT IN (SELECT source_code FROM ciel_rank_2_same_as)
),
/* ===========================================================
   Non-standard NARROWER-THAN rows only
   =========================================================== */
nonstd_narrower AS (
    SELECT *
    FROM unmapped
    WHERE map_type = 'NARROWER-THAN'
      AND target_standard_concept IS NULL
),
narrower_counts AS (
    SELECT
        source_code,
        COUNT(*) AS narrower_cnt
    FROM nonstd_narrower
    GROUP BY source_code
),
/* ===========================================================
   Crosswalk via concept_relationship to Standard concepts
   =========================================================== */
crosswalk_base AS (
    SELECT
        a.source_code,
        a.source_name,
        a.source_class,
        a.map_type,
        a.target_vocabulary_id AS nonstd_target_vocabulary_id,  -- original vocab of non-standard target
        a.target_concept_id AS nonstd_target_concept_id,
        r.relationship_id,
        d.concept_id AS target_concept_id,
        d.concept_code AS target_concept_code,
        d.concept_name AS target_concept_name,
        d.vocabulary_id AS target_vocabulary_id,
        d.domain_id AS target_domain_id,
        d.concept_class_id AS target_concept_class_id,
        d.standard_concept AS target_standard_concept,
        d.invalid_reason AS target_invalid_reason
    FROM nonstd_narrower a
    JOIN concept_relationship r
      ON r.concept_id_1 = a.target_concept_id
     AND r.relationship_id IN ('Maps to','Maps to value')
     AND r.invalid_reason  IS NULL
    JOIN concept d
      ON d.concept_id = r.concept_id_2
     AND d.standard_concept = 'S'
),
base_single AS (
    SELECT cb.*
    FROM crosswalk_base cb
    JOIN narrower_counts c USING (source_code)
    WHERE c.narrower_cnt = 1
),
base_multi AS (
    SELECT cb.*
    FROM crosswalk_base cb
    JOIN narrower_counts c USING (source_code)
    WHERE c.narrower_cnt > 1
),
/* ===========================================================
   6.01: 1 non-Standard NARROWER-THAN to Standard (OMOP crosswalk)
   =========================================================== */
one_non_s_narrower AS (
    SELECT DISTINCT
        source_code,
        source_name,
        source_class,
        map_type,
        target_concept_id,
        target_concept_code,
        target_concept_name,
        target_vocabulary_id,
        target_domain_id,
        target_concept_class_id,
        target_standard_concept,
        target_invalid_reason,
        relationship_id,
        2 AS rank_num,
        '6.01: 1 non-Standard NARROWER-THAN to Standard (OMOP crosswalk)' AS rule_applied
    FROM base_single b
    WHERE NOT EXISTS (SELECT 1 FROM ciel_mapping_lookup x WHERE x.source_code = b.source_code 
    AND x.source_class = 'Test' AND  map_type = 'BROADER-THAN' AND target_vocabulary_id = 'LOINC') -- exclude better LOINC BROADER-THAN maps
),
/* ===========================================================
   6.02: many non-Standard NARROWER-THAN Diagnoses/Findings to Standard
   - original non-standard target vocab = SNOMED
   =========================================================== */
many_non_s_narrower_diagn_find AS (
    SELECT DISTINCT
        b.source_code,
        b.source_name,
        b.source_class,
        b.map_type,
        b.target_concept_id,
        b.target_concept_code,
        b.target_concept_name,
        b.target_vocabulary_id,
        b.target_domain_id,
        b.target_concept_class_id,
        b.target_standard_concept,
        b.target_invalid_reason,
        b.relationship_id,
        2 AS rank_num,
        '6.02: many non-Standard NARROWER-THAN Diagnoses/Findings to Standard (OMOP crosswalk)' AS rule_applied
    FROM base_multi b
    WHERE b.nonstd_target_vocabulary_id = 'SNOMED'
      AND b.source_class IN ('Diagnosis','Finding','Symptom/Finding')
      AND NOT EXISTS (SELECT 1 FROM one_non_s_narrower x WHERE x.source_code = b.source_code)
),
/* ===========================================================
   6.03: many non-Standard NARROWER-THAN CVX to Standard
   - original non-standard target vocab = CVX
   =========================================================== */
many_non_s_narrower_vaccine AS (
    SELECT DISTINCT
        b.source_code,
        b.source_name,
        b.source_class,
        b.map_type,
        b.target_concept_id,
        b.target_concept_code,
        b.target_concept_name,
        b.target_vocabulary_id,
        b.target_domain_id,
        b.target_concept_class_id,
        b.target_standard_concept,
        b.target_invalid_reason,
        b.relationship_id,
        2 AS rank_num,
        '6.03: many non-Standard NARROWER-THAN CVX to Standard (OMOP crosswalk)' AS rule_applied
    FROM base_multi b
    WHERE b.nonstd_target_vocabulary_id = 'CVX'
      AND b.source_class IN ('Drug','Procedure')
      AND NOT EXISTS (SELECT 1 FROM one_non_s_narrower x WHERE x.source_code = b.source_code)
      AND NOT EXISTS (SELECT 1 FROM many_non_s_narrower_diagn_find x WHERE x.source_code = b.source_code)
),
/* ===========================================================
   6.04: many non-Standard NARROWER-THAN Drug/Regimen to Standard
   =========================================================== */
many_non_s_narrower_drug_regimen AS (
    SELECT DISTINCT
        b.source_code,
        b.source_name,
        b.source_class,
        b.map_type,
        b.target_concept_id,
        b.target_concept_code,
        b.target_concept_name,
        b.target_vocabulary_id,
        b.target_domain_id,
        b.target_concept_class_id,
        b.target_standard_concept,
        b.target_invalid_reason,
        'Maps to' as relationship_id,
        2 AS rank_num,
        '6.04: many non-Standard NARROWER-THAN Drug/Regimen to Standard (OMOP crosswalk)' AS rule_applied
    FROM base_multi b
    WHERE b.target_vocabulary_id IN ('RxNorm','RxNorm Extension','CVX')
      AND b.source_class IN ('Drug','Procedure','Misc')
      AND b.relationship_id = 'Maps to'
    AND NOT EXISTS (SELECT 1 FROM one_non_s_narrower x WHERE x.source_code = b.source_code)
    AND NOT EXISTS (SELECT 1 FROM many_non_s_narrower_diagn_find x WHERE x.source_code = b.source_code)
    AND NOT EXISTS (SELECT 1 FROM many_non_s_narrower_vaccine x WHERE x.source_code = b.source_code)
),
/* ===========================================================
   6.05: many non-Standard NARROWER-THAN Others to Standard
   - everything else, excluding specific bad case
   =========================================================== */
many_non_s_narrower_others AS (
    SELECT DISTINCT
        b.source_code,
        b.source_name,
        b.source_class,
        b.map_type,
        b.target_concept_id,
        b.target_concept_code,
        b.target_concept_name,
        b.target_vocabulary_id,
        b.target_domain_id,
        b.target_concept_class_id,
        b.target_standard_concept,
        b.target_invalid_reason,
        b.relationship_id,
        2 AS rank_num,
        '6.05: many non-Standard NARROWER-THAN Others to Standard (OMOP crosswalk)' AS rule_applied
    FROM base_multi b
    WHERE NOT EXISTS (SELECT 1 FROM one_non_s_narrower x WHERE x.source_code = b.source_code )
      AND NOT EXISTS (SELECT 1 FROM many_non_s_narrower_diagn_find x WHERE x.source_code = b.source_code)
      AND NOT EXISTS (SELECT 1 FROM many_non_s_narrower_vaccine x WHERE x.source_code = b.source_code)
      AND NOT EXISTS (SELECT 1 FROM many_non_s_narrower_drug_regimen x WHERE x.source_code = b.source_code)
)
SELECT * FROM one_non_s_narrower
UNION ALL
SELECT * FROM many_non_s_narrower_diagn_find
UNION ALL
SELECT * FROM many_non_s_narrower_vaccine
UNION ALL
SELECT * FROM many_non_s_narrower_drug_regimen
UNION ALL
SELECT * FROM many_non_s_narrower_others; -- 630

DROP TABLE IF EXISTS ciel_rank_2_broader_than;
CREATE TABLE ciel_rank_2_broader_than AS
WITH
/* ===========================================================
   Base: remaining unmapped rows not covered by rank-1 / rank-2 SAME-AS / NARROWER-THAN
   =========================================================== */
unmapped AS (
    SELECT l.*
    FROM ciel_mapping_lookup l
    WHERE NOT EXISTS (
        SELECT 1
        FROM (
            SELECT source_code FROM ciel_rank_1_narrower_than
            UNION
            SELECT source_code FROM ciel_rank_1_same_as
            UNION
            SELECT source_code FROM ciel_rank_1_broader_than
            UNION
            SELECT source_code FROM ciel_rank_2_same_as
        ) x
        WHERE x.source_code = l.source_code
    )
),
/* ===========================================================
   Non-standard BROADER-THAN rows only
   =========================================================== */
nonstd_broader AS (
    SELECT *
    FROM unmapped
    WHERE map_type = 'BROADER-THAN'
      AND target_standard_concept IS NULL
),
broader_counts AS (
    SELECT
        source_code,
        COUNT(*) AS broader_cnt
    FROM nonstd_broader
    GROUP BY source_code
),
/* ===========================================================
   Crosswalk via concept_relationship to Standard concepts
   =========================================================== */
crosswalk_base AS (
    SELECT
        a.source_code,
        a.source_name,
        a.source_class,
        a.map_type,
        a.target_vocabulary_id AS nonstd_target_vocabulary_id,
        a.target_concept_id AS nonstd_target_concept_id,
        r.relationship_id,
        d.concept_id AS target_concept_id,
        d.concept_code AS target_concept_code,
        d.concept_name AS target_concept_name,
        d.vocabulary_id AS target_vocabulary_id,
        d.domain_id AS target_domain_id,
        d.concept_class_id AS target_concept_class_id,
        d.standard_concept AS target_standard_concept,
        d.invalid_reason AS target_invalid_reason
    FROM nonstd_broader a
    JOIN concept_relationship r
      ON r.concept_id_1 = a.target_concept_id
     AND r.relationship_id IN ('Maps to','Maps to value')
     AND r.invalid_reason  IS NULL
    JOIN concept d
      ON d.concept_id = r.concept_id_2
     AND d.standard_concept = 'S'
),
base_single AS (
    SELECT cb.*
    FROM crosswalk_base cb
    JOIN broader_counts c USING (source_code)
    WHERE c.broader_cnt = 1
),
base_multi AS (
    SELECT cb.*
    FROM crosswalk_base cb
    JOIN broader_counts c USING (source_code)
    WHERE c.broader_cnt > 1
),
/* ===========================================================
   7.01: one non-Standard BROADER-THAN to Standard (OMOP crosswalk)
   =========================================================== */
one_non_s_broader AS (
    SELECT DISTINCT
        source_code,
        source_name,
        source_class,
        map_type,
        target_concept_id,
        target_concept_code,
        target_concept_name,
        target_vocabulary_id,
        target_domain_id,
        target_concept_class_id,
        target_standard_concept,
        target_invalid_reason,
        relationship_id,
        2 AS rank_num,
        '7.01: one non-Standard BROADER-THAN to Standard (OMOP crosswalk)' AS rule_applied
    FROM base_single b WHERE NOT EXISTS (SELECT 1 FROM ciel_rank_2_narrower_than x WHERE x.source_code = b.source_code) 
),
/* ===========================================================
   7.02: many non-Standard BROADER-THAN to Standard (OMOP crosswalk)
   =========================================================== */
many_non_s_broader AS (
    SELECT DISTINCT
        b.source_code,
        b.source_name,
        b.source_class,
        b.map_type,
        b.target_concept_id,
        b.target_concept_code,
        b.target_concept_name,
        b.target_vocabulary_id,
        b.target_domain_id,
        b.target_concept_class_id,
        b.target_standard_concept,
        b.target_invalid_reason,
        b.relationship_id,
        2 AS rank_num,
        '7.02: many non-Standard BROADER-THAN to Standard (OMOP crosswalk)' AS rule_applied
    FROM base_multi b
        WHERE NOT EXISTS (SELECT 1 FROM one_non_s_broader x WHERE x.source_code = b.source_code)
)
SELECT * FROM one_non_s_broader
UNION ALL
SELECT * FROM many_non_s_broader;
/* ===========================================================
   TO BE EXCLUDED FROM CONCEPT_RELATIONSHIP_STAGE
   =========================================================== */
DROP TABLE IF EXISTS ciel_unmapped;
CREATE TABLE ciel_unmapped AS
WITH ranked_sources AS (
    SELECT source_code FROM ciel_rank_1_narrower_than
    UNION
    SELECT source_code FROM ciel_rank_1_same_as
    UNION
    SELECT source_code FROM ciel_rank_1_broader_than
    UNION
    SELECT source_code FROM ciel_rank_2_same_as
    UNION
    SELECT source_code FROM ciel_rank_2_narrower_than
    UNION
    SELECT source_code FROM ciel_rank_2_broader_than
),
unmapped AS (
    SELECT l.*
    FROM ciel_mapping_lookup l
    WHERE NOT EXISTS (
        SELECT 1
        FROM ranked_sources x
        WHERE x.source_code = l.source_code
    )
),
has_standard AS (
    SELECT DISTINCT source_code
    FROM unmapped
    WHERE target_standard_concept = 'S'
),
/* 8.02: no Standard OMOP map at all for this source_code */
no_standard AS (
    SELECT
        u.source_code,
        u.source_name,
        u.source_class,
        u.map_type,
        u.target_concept_id,
        u.target_concept_code,
        u.target_concept_name,
        u.target_vocabulary_id,
        u.target_domain_id,
        u.target_concept_class_id,
        u.target_standard_concept,
        u.target_invalid_reason,
        ''::varchar AS relationship_id,
        9 AS rank_num,
        '8.02: Does not have Standard OMOP map' AS rule_applied
    FROM unmapped u
    WHERE NOT EXISTS (SELECT 1 FROM has_standard hs WHERE hs.source_code = u.source_code)
),
/* 8.01: problematic one-to-many Standard mappings that still remain */
problematic_standard AS (
    SELECT
        u.source_code,
        u.source_name,
        u.source_class,
        u.map_type,
        u.target_concept_id,
        u.target_concept_code,
        u.target_concept_name,
        u.target_vocabulary_id,
        u.target_domain_id,
        u.target_concept_class_id,
        u.target_standard_concept,
        u.target_invalid_reason,
        ''::varchar AS relationship_id,
        8 AS rank_num,
        '8.01: Problematic Standard one-to-many. Manual review is needed' AS rule_applied
    FROM unmapped u
    WHERE u.target_standard_concept = 'S'
)
SELECT * FROM no_standard
UNION ALL
SELECT * FROM problematic_standard; -- 1160
/* ===========================================================
   2.15: Missing SNOMED Regimens
   =========================================================== */
INSERT INTO ciel_rank_1_narrower_than
WITH ranked_sources AS (
    SELECT * FROM ciel_rank_1_narrower_than
    UNION ALL
    SELECT * FROM ciel_rank_1_same_as
    UNION ALL
    SELECT * FROM ciel_rank_1_broader_than
    UNION ALL
    SELECT * FROM ciel_rank_2_same_as
    UNION ALL
    SELECT * FROM ciel_rank_2_narrower_than
    UNION ALL
    SELECT * FROM ciel_rank_2_broader_than
),
regimen_descendants AS (
    SELECT descendant_concept_id
    FROM concept_ancestor
    WHERE ancestor_concept_id = 4045950
),
missing_regimens_sn AS (
    SELECT DISTINCT
        n.source_code,
        n.source_name,
        n.source_class,
        'NARROWER-THAN' as map_type,
        c.concept_id AS target_concept_id,
        c.concept_code AS target_concept_code,
        c.concept_name AS target_concept_name,
        c.vocabulary_id AS target_vocabulary_id,
        c.domain_id AS target_domain_id,
        c.concept_class_id AS target_concept_class_id,
        c.standard_concept AS target_standard_concept,
        c.invalid_reason AS target_invalid_reason,
        'Maps to' AS relationship_id,
        1 AS rank_num,
        '2.15: Missing SNOMED Regimens' AS rule_applied
    FROM ranked_sources n
    JOIN concept c
      ON c.concept_id = 4045950  -- Therapeutic regimen
    WHERE n.source_class = 'Misc'
      AND n.source_name ~* ' / |single agent'
      AND EXISTS (SELECT 1 FROM ranked_sources m WHERE m.source_code = n.source_code AND m.target_domain_id = 'Drug')
      AND NOT EXISTS (SELECT 1 FROM ranked_sources m JOIN regimen_descendants rd ON rd.descendant_concept_id = m.target_concept_id WHERE m.source_code = n.source_code)
)
SELECT *
FROM missing_regimens_sn; -- 23
/* ===========================================================
    Mapping output for the load stage
   =========================================================== */
DROP TABLE IF EXISTS maps_for_load_stage;
CREATE TABLE maps_for_load_stage AS
SELECT * FROM ciel_rank_1_same_as
UNION ALL
SELECT * FROM ciel_rank_1_narrower_than
UNION ALL
SELECT * FROM ciel_rank_1_broader_than
UNION ALL
SELECT * FROM ciel_rank_2_same_as
UNION ALL
SELECT * FROM ciel_rank_2_narrower_than
UNION ALL
SELECT * FROM ciel_rank_2_broader_than
UNION ALL
SELECT * FROM missing_drugs_rank_1
UNION ALL
SELECT * FROM ciel_unmapped;
/* ===========================================================
   Remove one map where maps to parents and children exist at the same time
   =========================================================== */
WITH pairs AS (
    SELECT DISTINCT
        m1.source_code,
        m1.target_concept_id AS parent_id,
        m2.target_concept_id AS child_id
    FROM maps_for_load_stage m1
    JOIN maps_for_load_stage m2
      ON m1.source_code = m2.source_code
     AND m1.target_concept_id <> m2.target_concept_id
    JOIN concept_ancestor ca
      ON ca.ancestor_concept_id   = m1.target_concept_id
     AND ca.descendant_concept_id = m2.target_concept_id
),
annotated AS (
    SELECT DISTINCT
        p.source_code,
        mp.source_name,
        mp.map_type,
        p.parent_id AS target_concept_id,
        'parent'::text AS ancestry
    FROM pairs p
    JOIN maps_for_load_stage mp
      ON mp.source_code       = p.source_code
     AND mp.target_concept_id = p.parent_id
    UNION
    SELECT DISTINCT
        p.source_code,
        mc.source_name,
        mc.map_type,
        p.child_id AS target_concept_id,
        'child'::text AS ancestry
    FROM pairs p
    JOIN maps_for_load_stage mc
      ON mc.source_code       = p.source_code
     AND mc.target_concept_id = p.child_id
),
to_delete AS (
    SELECT a.source_code,
        a.target_concept_id
    FROM annotated a
    WHERE
        (
            a.ancestry = 'parent'
            AND (
                a.source_name !~* '\yAND\y|\yAND/OR\y|\yOR\y'
                OR a.source_code IN (
                    '147000','144969','120495','120405','119027','114686',
                    '141945','116666','127739','127738','127737','127736',
                    '127735','127733','124533','117072', '125565'
                )
            )
        )
        OR
        (
            a.ancestry = 'child'
            AND a.source_name ~* '\yAND\y|\yAND/OR\y|\yOR\y'
            AND a.source_code NOT IN (
                '147000','144969','120495','120405','119027','114686',
                '141945','116666','127739','127738','127737','127736',
                '127735','127733','124533','117072', '125565'
            )
        )
)
DELETE FROM maps_for_load_stage m
USING to_delete d
WHERE m.source_code = d.source_code
  AND m.target_concept_id = d.target_concept_id; -- 263
  
-- Remove wrong automated non-S-to-S OMOP crosswalks
DELETE
FROM maps_for_load_stage
WHERE source_code IN ('163068','163063') -- 5FU / Leucovorin
AND   target_concept_id IN (37498183);

DELETE
FROM maps_for_load_stage
WHERE source_code IN ('167458','162201')
AND   target_concept_id IN (19011093); -- 2 (tenofovir vs tenofovir disoproxil)

--- Remove wrong ingredients which came from automated non-S-to-S OMOP crosswalks
-- for multi-ingredient Drug concepts where the number of mapped ingredients
-- does not match the number inferred from the name pattern.
WITH mapping_counts AS (
    SELECT
        source_name,
        COUNT(DISTINCT target_concept_id)   AS mapped_ingredient_count,
        1 +(LENGTH(COALESCE(source_name,'')) -LENGTH(REPLACE(COALESCE(source_name,''),'/',''))) AS expected_ingredient_count
    FROM maps_for_load_stage
    WHERE source_class = 'Drug'
      AND rank_num IN (1, 2)
    GROUP BY source_name
),
problematic_sources AS (
    -- Drug names that look like combinations but whose mapped ingredient
    -- count is inconsistent with the number inferred from the name.
    SELECT
        source_name,
        expected_ingredient_count,
        mapped_ingredient_count
    FROM mapping_counts
    WHERE mapped_ingredient_count >= 2
      AND expected_ingredient_count <> mapped_ingredient_count
),
candidates AS (
    -- Concrete source-target pairs to be removed
    SELECT
        a.source_code,
        a.target_concept_id
    FROM maps_for_load_stage a
    JOIN problematic_sources ps
      ON a.source_name = ps.source_name
    WHERE a.source_class = 'Drug'
      AND a.rank_num IN (1, 2)
      -- Exclude names explicitly using "and" or "+" as part of the regimen pattern
      AND a.source_name !~* '\s+and\s+|\+'
      -- Manually whitelisted exceptions that must be preserved
      AND a.source_code NOT IN (
          '1447','103987','103988','103989','73942','104730',
          '77305','104528','159589','163412','166088'
      )
      -- Only remove known incorrect ingredient targets
      AND a.target_concept_id IN (
          19060837,1712549,1036059,19011093,43014126,914533,933952,
          19126511,950435,1153013,1549786,1400498,19058867,35603384,
          19129648,965748,948515,19086788,1353228,933794,19012565,
          1836241,1717327,19009540
      )
      -- Protect a specific source-target pair that is correct
      AND NOT (a.source_code = '104322' AND a.target_concept_id = 950435)
)
DELETE FROM maps_for_load_stage m
USING candidates c
WHERE m.source_code = c.source_code
AND m.target_concept_id = c.target_concept_id; --27

-- Remove mappings for selected codes that have better manual mappings OR are on hold until the OHDSI Standardized Vocabularies are refreshed with the new SNOMED/RxNorm target concepts for them.
DELETE
FROM maps_for_load_stage
WHERE source_code IN ('78629','104528','166655','140730','11080','112044','159933','145185','144441', '169187', '163435', '163200',
'110826', '111526', '111604', '111634', '112522', '112836', '113339', '115220', '115684', '116870', '117533', '119626', '122497', '125145',
'126554', '126657', '127069', '127253', '127254', '127274', '131944', '131951', '131953', '131955', '132026', '132054', '132106', '133690',
'133928', '135281', '138085', '138540', '139005', '139651', '140241', '141512', '141635', '1422', '142523', '142609', '142746', '142747',
'142755', '142791', '142968', '143791', '144841', '144911', '146687', '1467', '146774', '146785', '146811', '146882', '147515', '147621',
'148962', '150479', '150490', '150739', '152567', '153322', '153645', '153741', '154445', '155493', '155785', '156047', '160078', '160151',
'160152', '160153', '160154', '160161', '160232', '160596', '160654', '160981', '161030', '161031', '161032', '161180', '163036', '163065',
'163066', '163067', '163069', '163072', '1632', '163338', '163738', '163825', '165087', '166007', '166014', '167717', '167785', '168736',
'169533', '170172', '5092', '5272', '5275', '5596', '85471'); -- 165

-- Clean up - remove all interim tables
DROP TABLE ciel_mapping_lookup;
DROP TABLE ciel_rank_1_same_as;
DROP TABLE ciel_rank_1_narrower_than;
DROP TABLE ciel_rank_1_broader_than;
DROP TABLE ciel_rank_2_same_as;
DROP TABLE ciel_rank_2_narrower_than;
DROP TABLE ciel_rank_2_broader_than;
DROP TABLE missing_drugs_rank_1;
DROP TABLE ciel_unmapped;
