/*
================================================================================
build_initial_oncology_seed_scope.sql
================================================================================

Purpose
-------
Build dev_cancer_modifier.seeding_table: the initial local oncology concept scope.

This step expands root oncology seed concepts using:

1. concept_ancestor descendants within the same vocabulary as the root seed.
2. selected non-mapping concept_relationship edges pointing to the root seed.



Created objects
---------------
- dev_cancer_modifier.seeding_table

Inputs
------
- concept
- concept_ancestor
- concept_relationship
- dev_cancer_modifier.onco_seed_roots
================================================================================
*/

-- -----------------------------------------------------------------------------
-- Section 03.01: Recreate initial seed-scope table
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS dev_cancer_modifier.seeding_table;

CREATE UNLOGGED TABLE dev_cancer_modifier.seeding_table AS
WITH root_seed AS (
    -- -------------------------------------------------------------------------
    --  Load root seed concept metadata and text-normalization forms
    -- -------------------------------------------------------------------------
    SELECT
        c.concept_id AS root_seed_concept_id,
        c.concept_name AS root_seed_name,
        to_tsvector(c.concept_name) AS root_ts_vector_seed_name,
        c.vocabulary_id AS root_seed_vocabulary_id,
        c.domain_id AS root_seed_domain_id
    FROM concept c
    JOIN dev_cancer_modifier.onco_seed_roots r
        ON r.seed_concept_id = c.concept_id
),

scope AS (
    -- -------------------------------------------------------------------------
    -- Section 03.03: Expand by concept_ancestor descendants
    -- -------------------------------------------------------------------------
    SELECT DISTINCT
        'anc'::text AS provenance_source,
        st.root_seed_concept_id,
        st.root_seed_name AS ancestor_name,
        cc.*
    FROM root_seed st
    JOIN concept_ancestor ca
        ON ca.ancestor_concept_id = st.root_seed_concept_id
    JOIN concept cc
        ON cc.concept_id = ca.descendant_concept_id
       AND cc.vocabulary_id = st.root_seed_vocabulary_id

    UNION

    -- -------------------------------------------------------------------------
    --  Expand by selected concept_relationship edges
    -- -------------------------------------------------------------------------
    SELECT DISTINCT
        ('rel:' || cr.relationship_id)::text AS provenance_source,
        st.root_seed_concept_id,
        st.root_seed_name AS ancestor_name,
        cc.*
    FROM root_seed st
    JOIN concept_relationship cr
        ON cr.concept_id_2 = st.root_seed_concept_id
       AND cr.invalid_reason IS NULL
       AND cr.relationship_id NOT IN ('Maps to', 'Maps to value', 'Subsumes', 'Is a','Concept repaced by','Asso morph of','Interprets of')
    JOIN concept cc
        ON cc.concept_id = cr.concept_id_1
       AND cc.vocabulary_id = st.root_seed_vocabulary_id
    WHERE cc.concept_id <> st.root_seed_concept_id
      AND cc.standard_concept IS NOT NULL
      AND (
            cc.domain_id = st.root_seed_domain_id
            OR cc.domain_id IN ('Observation', 'Meas Value', 'Measurement', 'Procedure','Condition')
          )

    UNION

    -- -------------------------------------------------------------------------
    --  Expand by selected name-match edges
    -- -------------------------------------------------------------------------
    SELECT DISTINCT
        ('name_match')::text AS provenance_source,
        st.root_seed_concept_id,
        st.root_seed_name AS ancestor_name,
        cc.*
    FROM root_seed st
    JOIN concept  cc
        ON cc.concept_name = st.root_seed_name
       AND (
           cc.vocabulary_id =st.root_seed_vocabulary_id
               OR cc.vocabulary_id IN ('SNOMED','NAACCR','LOINC'))
        and cc.standard_concept='S'
    where cc.concept_id<>st.root_seed_concept_id


    UNION

    -- -------------------------------------------------------------------------
    --  Expand by selected synonym-name-match edges
    -- -------------------------------------------------------------------------
    SELECT DISTINCT
        ('synonym-name_match')::text AS provenance_source,
        st.root_seed_concept_id,
        st.root_seed_name AS ancestor_name,
        cc.*
    FROM root_seed st
    JOIN concept_synonym  cs
        ON cs.concept_synonym_name = st.root_seed_name
    JOIN concept cc
        ON cc.concept_id = cs.concept_id
     AND (
           cc.vocabulary_id =st.root_seed_vocabulary_id
               OR cc.vocabulary_id IN ('SNOMED','NAACCR','LOINC'))
        and cc.standard_concept='S'
    where cc.concept_id<>st.root_seed_concept_id

     UNION

    -- -------------------------------------------------------------------------
    --  Expand by selected synonym-name-match edges
    -- -------------------------------------------------------------------------
    SELECT DISTINCT
        ('MultiAncestor')::text AS provenance_source,
        ca.ancestor_concept_id,
        c.concept_name AS ancestor_name,
        cc.*
    FROM concept_ancestor ca
    JOIN concept  c
        ON  ca.ancestor_concept_id  =  c.concept_id
        and ca.ancestor_concept_id=443392 -- Malignant neoplastic disease
    JOIN concept cc
        ON cc.concept_id = ca.descendant_concept_id

     AND EXISTS (SELECT 1
                 from concept_ancestor ca1
                 where ca1.descendant_concept_id=ca.descendant_concept_id
                 and ca1.ancestor_concept_id IN (37204336, -- Genetic disease
                                                35622958,--Disorder in remission
                                                37165277 -- Relapsing malignant neoplastic disease

                     ))
       WHERE    cc.vocabulary_id =c.vocabulary_id
              AND c.vocabulary_id IN ('SNOMED','NAACCR','LOINC')
    AND cc.concept_id<>ca.ancestor_concept_id

    UNION

    -- -------------------------------------------------------------------------
    --  Expand by selected synonym-name-match edges
    -- -------------------------------------------------------------------------
    SELECT DISTINCT
        ('DueToMalignant')::text AS provenance_source,
        ca.ancestor_concept_id,
        c.concept_name AS ancestor_name,
        cc.*
    FROM concept_ancestor ca
    JOIN concept  c
        ON  ca.ancestor_concept_id  =  c.concept_id
        and ca.ancestor_concept_id=443392 -- Malignant neoplastic disease
         JOIN concept_relationship cr
        ON cr.concept_id_2 = ca.descendant_concept_id
    JOIN concept cc
        ON cc.concept_id = cr.concept_id_1
               and cr.relationship_id='Has due to'
               and cr.invalid_reason is null
       WHERE    cc.vocabulary_id =c.vocabulary_id
              AND c.vocabulary_id IN ('SNOMED','NAACCR','LOINC')
    AND cc.concept_id<>ca.ancestor_concept_id
),

scope_seed AS (
    -- -------------------------------------------------------------------------
    -- Section 03.05: Collapse provenance and prepare seed text features
    -- -------------------------------------------------------------------------
    SELECT
        array_agg(DISTINCT provenance_source ORDER BY provenance_source) AS prov,
        array_agg(DISTINCT ancestor_name ORDER BY ancestor_name) AS anc_name,
        array_agg(DISTINCT root_seed_concept_id ORDER BY root_seed_concept_id) AS root_seed_concept_ids,
        to_tsvector(concept_name) AS ts_vector_seed_name,

        concept_id,
        concept_name,
        domain_id,
        vocabulary_id,
        concept_class_id,
        standard_concept,
        concept_code,
        valid_start_date,
        valid_end_date,
        invalid_reason
    FROM scope s
    GROUP BY
        concept_id,
        concept_name,
        domain_id,
        vocabulary_id,
        concept_class_id,
        standard_concept,
        concept_code,
        valid_start_date,
        valid_end_date,
        invalid_reason
)

-- -----------------------------------------------------------------------------
-- Final seed-scope output shape
-- -----------------------------------------------------------------------------
SELECT
    prov,
    anc_name,
    root_seed_concept_ids,
    ts_vector_seed_name,

    concept_id AS concept_id,
    concept_name AS seed_name,
    domain_id AS seed_domain_id,
    vocabulary_id AS seed_vocabulary_id,
    concept_class_id AS seed_concept_class_id,
    standard_concept AS seed_standard_concept,
    concept_code AS seed_concept_code,
    valid_start_date AS seed_valid_start_date,
    valid_end_date AS seed_valid_end_date,
    invalid_reason AS seed_invalid_reason
FROM scope_seed;

-- -----------------------------------------------------------------------------
-- Index seed-scope table
-- -----------------------------------------------------------------------------
CREATE UNIQUE INDEX seeding_table_seed_uidx
    ON dev_cancer_modifier.seeding_table(concept_id);

CREATE INDEX seeding_table_vocab_domain_idx
    ON dev_cancer_modifier.seeding_table(seed_vocabulary_id, seed_domain_id);

CREATE INDEX seeding_table_name_idx
    ON dev_cancer_modifier.seeding_table(seed_name);

CREATE INDEX seeding_table_tsv_gin_idx
    ON dev_cancer_modifier.seeding_table
    USING gin(ts_vector_seed_name);

ANALYZE dev_cancer_modifier.seeding_table;
