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
* Authors: Monarch Initiative (authors),  OHDSI Vocabulary Team (Thesaurus Health Content Curation Team- primary ETL; EPAM Ontology Team - final execution)
*
* Date: December 2025
**************************************************************************/


-- Update latest_update field to the new date
DO
$_$
BEGIN
  PERFORM VOCABULARY_PACK.SetLatestUpdate(
      pVocabularyName => 'HPO',
      pVocabularyDate => (SELECT version::date
        as version_date
      FROM dev_hpo.hpo_json
      ORDER BY version DESC
      LIMIT 1),
      pVocabularyVersion => (SELECT 'HPO v' ||
           version::text as version_date
         FROM dev_hpo.hpo_json
         ORDER BY version DESC
         LIMIT 1),
      pVocabularyDevSchema => 'DEV_HPO'
      );
END
$_$;



-- Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

-- 1. HPO_source preparation
-- HPO JSON HPO_source processing
DROP TABLE IF EXISTS  HPO_source; 
CREATE TABLE HPO_source AS
WITH hpo_source AS (
  SELECT
    version,
    edge ->> 'lbl' AS concept_name,

    -- Extract just the ID part from the full URI
    regexp_replace(edge ->> 'id', 'http://purl.obolibrary.org/obo/', '', 'gi') AS concept_code,
    edge ->> 'type' AS concept_class_id,
    edge ->> 'meta' AS meta
  FROM dev_hpo.hpo_json,
  LATERAL jsonb_array_elements(source_json -> 'graphs') AS graph,
  LATERAL jsonb_array_elements(graph -> 'nodes') AS edge
  -- WHERE left(replace(edge->>'id', 'http://purl.obolibrary.org/obo/', ''),2)= 'HP'

  UNION ALL

  SELECT
    version,
    graph ->> 'lbl' AS concept_name,

    -- Extract just the ID part from the full URI
    regexp_replace(graph ->> 'id', 'http://purl.obolibrary.org/obo/', '', 'gi') AS concept_code,
    graph ->> 'type' AS concept_class_id,
    graph ->> 'meta' AS meta
  FROM dev_hpo.hpo_json,
  LATERAL jsonb_array_elements(source_json -> 'graphs') AS graph
  -- WHERE left(replace(edge->>'id', 'http://purl.obolibrary.org/obo/', ''),2)= 'HP'
),
synonym_enh_hpo_source AS (
  SELECT
    concept_name,
    concept_code,
    concept_class_id,
    jsonb_pretty(meta::jsonb) AS metadata,
    synonym ->> 'val' AS synonym_name,
    synonym ->> 'pred' AS synonym_type,
    COALESCE((meta::jsonb) ->> 'deprecated', 'false')::boolean AS deprecation,
    version
  FROM hpo_source,
  LATERAL jsonb_array_elements((meta::jsonb) -> 'synonyms') AS synonym
),
definition_enh_hpo_source AS (
  SELECT
    concept_name,
    concept_code,
    concept_class_id,
    jsonb_pretty(meta::jsonb) AS metadata,
    xref ->> 'val' AS refrence,
    (meta::jsonb) -> 'definition' ->> 'val' AS definition,
    COALESCE((meta::jsonb) ->> 'deprecated', 'false')::boolean AS deprecation,
    version
  FROM hpo_source,
  LATERAL jsonb_array_elements((meta::jsonb) -> 'xrefs') AS xref
),
property_enh_hpo_source AS (
  SELECT
    concept_name,
    concept_code,
    concept_class_id,
    jsonb_pretty(meta::jsonb) AS metadata,
    basicPropertyValues ->> 'val' AS bpv_refrence,
    basicPropertyValues ->> 'pred' AS bpv_predicate,
    COALESCE((meta::jsonb) ->> 'deprecated', 'false')::boolean AS deprecation,
    version
  FROM hpo_source,
  LATERAL jsonb_array_elements((meta::jsonb) -> 'basicPropertyValues') AS basicPropertyValues
),
combined_hpo_source AS (
  SELECT
    version,
    concept_name,
    concept_code,
    concept_class_id,
    metadata,
    deprecation,
    refrence,
    definition,
    NULL AS synonym_name,
    NULL AS synonym_type,
    NULL AS bpv_refrence,
    NULL AS bpv_predicate
  FROM definition_enh_hpo_source

  UNION ALL

  SELECT
    version,
    concept_name,
    concept_code,
    concept_class_id,
    metadata,
    deprecation,
    NULL AS refrence,
    NULL AS definition,
    synonym_name,
    synonym_type,
    NULL AS bpv_refrence,
    NULL AS bpv_predicate
  FROM synonym_enh_hpo_source

  UNION ALL

  SELECT
    version,
    concept_name,
    concept_code,
    concept_class_id,
    metadata,
    deprecation,
    NULL AS refrence,
    NULL AS definition,
    NULL AS synonym_name,
    NULL AS synonym_type,
    bpv_refrence,
    bpv_predicate
  FROM property_enh_hpo_source

  UNION ALL

  SELECT
    a.version,
    a.concept_name,
    a.concept_code,
    a.concept_class_id,
    a.meta AS metadata,
    COALESCE(
      b.deprecation,
      CASE WHEN a.meta::jsonb->>'deprecated'='true' THEN true ELSE NULL END,
      false
    ) AS deprecation,
    NULL AS refrence,
    NULL AS definition,
    NULL AS synonym_name,
    NULL AS synonym_type,
    NULL AS bpv_refrence,
    NULL AS bpv_predicate
  FROM hpo_source a
  LEFT JOIN property_enh_hpo_source b
    ON a.concept_code = b.concept_code
)
SELECT DISTINCT
  version,
  concept_name,
  concept_code,
  concept_class_id,
  metadata,
  deprecation,
  refrence,
  definition,
  synonym_name,
  synonym_type,
  bpv_refrence,
  bpv_predicate
FROM combined_hpo_source
;


-- 2. concept_stage table population
INSERT INTO concept_stage (
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
WITH staging_source AS (
  SELECT DISTINCT
    concept_name,
    domain_id,
    vocabulary_id,
    concept_class_id,
    standard_concept,
    concept_code,
    valid_start_date,
    valid_end_date,
    invalid_reason,
    dense_rank_id
  FROM (
    SELECT DISTINCT
      s.concept_name,
      s.concept_code,
      s.concept_class_id,
      CASE
        WHEN s.deprecation IS true AND sss.concept_code IS NULL THEN 'D'
        WHEN s.deprecation IS true AND sss.concept_code IS NOT NULL THEN 'U'
        ELSE NULL
      END AS invalid_reason,
      CASE
        WHEN s.deprecation IS true THEN to_date((a.latest_update - 1)::varchar, 'YYYY-MM-DD')
        ELSE to_date('2099-12-31', 'YYYY-MM-DD')
      END AS valid_end_date,
      CASE
        WHEN ss.concept_code IS NULL THEN to_date('2008-11-17', 'YYYY-MM-DD') -- Publication date of 1st article about HPO
        ELSE ss.bpv_refrence::date
      END AS valid_start_date,
      'Observation' AS domain_id,
      NULL AS standard_concept,
      vocabulary_id,
      dense_rank() OVER (
        PARTITION BY s.concept_code
        ORDER BY
          CASE
            WHEN s.deprecation IS true THEN to_date((a.latest_update - 1)::varchar, 'YYYY-MM-DD')
            ELSE to_date('2099-12-31', 'YYYY-MM-DD')
          END ASC
      ) AS dense_rank_id
    FROM dev_hpo.HPO_source s
    JOIN (
      SELECT latest_update, vocabulary_id
      FROM vocabulary
      WHERE vocabulary_id = 'HPO'
    ) a ON 1 = 1
    -- valid_start_date set
    LEFT JOIN dev_hpo.HPO_source ss
      ON ss.concept_code = s.concept_code
      AND ss.bpv_predicate = 'http://purl.org/dc/elements/1.1/date'
    LEFT JOIN HPO_source sss
      ON sss.concept_code = s.concept_code
      AND sss.bpv_predicate = 'http://purl.obolibrary.org/obo/IAO_0100001'
    WHERE left(s.concept_code, 3) = 'HP_'
      AND s.version IN (
        SELECT substring(vocabulary_version FROM '\d{4}-\d{2}-\d{2}')::date AS date_string
        FROM vocabulary
        WHERE vocabulary.vocabulary_id = 'HPO'
        LIMIT 1
      )
  ) AS tab_source
)
SELECT DISTINCT
  concept_name,
  domain_id,
  vocabulary_id,
  concept_class_id,
  standard_concept,
  concept_code,
  valid_start_date,
  valid_end_date,
  invalid_reason
FROM staging_source
WHERE dense_rank_id = 1
ORDER BY concept_code
;


-- 3. Process manual concepts (concept_manual)
DO $_$
BEGIN
  PERFORM VOCABULARY_PACK.ProcessManualConcepts();
END $_$;


-- 4. Populate concept_synonym_stage
INSERT INTO concept_synonym_stage (
  synonym_concept_code,
  synonym_name,
  synonym_vocabulary_id,
  language_concept_id
)
SELECT
  concept_code AS concept_code,
  synonym_name AS synonym_name,
  'HPO' AS vocabulary_id,
  4180186 AS language_concept_id -- English
FROM HPO_source s
WHERE s.synonym_name IS NOT NULL
  AND s.version IN (
    SELECT substring(vocabulary_version FROM '\d{4}-\d{2}-\d{2}')::date AS date_string
    FROM vocabulary
    WHERE vocabulary.vocabulary_id = 'HPO'
    LIMIT 1
  )
  AND left(s.concept_code, 3) = 'HP_'
  AND synonym_type = 'hasExactSynonym' -- Only exact synonyms are considered reliable
;


-- 5. Populate concept_relationship_stage
-- 5.1. Internal replacements integration
INSERT INTO concept_relationship_stage (
  concept_code_1,
  concept_code_2,
  relationship_id,
  vocabulary_id_1,
  vocabulary_id_2,
  valid_start_date,
  valid_end_date
)
SELECT DISTINCT
  concept_code AS concept_code_1,
  concept_code_2 AS concept_code_2,
  'Concept replaced by' AS relationship_id,
  vocabulary_id AS vocabulary_id_1,
  vocabulary_id AS vocabulary_id_2,
  valid_start_date,
  to_date('2099-12-31', 'YYYY-MM-DD') AS valid_end_date
FROM (
  SELECT DISTINCT
    s.concept_name,
    s.concept_code,
    s.concept_class_id,
    CASE
      WHEN s.deprecation IS true AND sss.concept_code IS NULL THEN 'D'
      WHEN s.deprecation IS true AND sss.concept_code IS NOT NULL THEN 'U'
      ELSE NULL
    END AS invalid_reason,
    CASE
      WHEN s.deprecation IS true THEN to_date((a.latest_update - 1)::varchar, 'YYYY-MM-DD')
      ELSE to_date('2099-12-31', 'YYYY-MM-DD')
    END AS valid_end_date,
    CASE
      WHEN ssss.concept_code IS NULL THEN to_date('2008-11-17', 'YYYY-MM-DD') -- Publication date of 1st article about HPO
      ELSE ssss.bpv_refrence::date
    END AS valid_start_date,
    'Observation' AS domain_id,
    NULL AS standard_concept,
    vocabulary_id,
    regexp_replace(split_part(sss.bpv_refrence, '/', -1), ':', '_') AS concept_code_2
  FROM HPO_source s
  JOIN (
    SELECT latest_update, vocabulary_id
    FROM vocabulary
    WHERE vocabulary_id = 'HPO'
  ) a ON 1 = 1
  -- valid_start_date set
  LEFT JOIN HPO_source ss
    ON ss.concept_code = s.concept_code
    AND ss.bpv_predicate = 'http://purl.org/dc/elements/1.1/date'
  JOIN HPO_source sss
    ON sss.concept_code = s.concept_code
    AND sss.bpv_predicate = 'http://purl.obolibrary.org/obo/IAO_0100001'
  LEFT JOIN HPO_source ssss
    ON regexp_replace(split_part(sss.bpv_refrence, '/', -1), ':', '_') = ssss.concept_code
    AND ssss.bpv_predicate = 'http://purl.org/dc/elements/1.1/date'
  WHERE left(s.concept_code, 3) = 'HP_'
    AND s.version IN (
      SELECT substring(vocabulary_version FROM '\d{4}-\d{2}-\d{2}')::date AS date_string
      FROM vocabulary
      WHERE vocabulary.vocabulary_id = 'HPO'
      LIMIT 1
    )
) AS tab_source
ORDER BY concept_code
;

--5.2 HPO hierarchy integration
INSERT INTO concept_relationship_stage (
  concept_code_1,
  concept_code_2,
  relationship_id,
  vocabulary_id_1,
  vocabulary_id_2,
  valid_start_date,
  valid_end_date
)
SELECT DISTINCT
  concept_code_1,
  concept_code_2,
  relationship_id,
  vocabulary_id_1,
  vocabulary_id_2,
  valid_start_date,
  valid_end_date
FROM (
  WITH crs AS (
    SELECT
      split_part(edge ->> 'sub', '/', -1) AS concept_code_1,
      split_part(edge ->> 'obj', '/', -1) AS concept_code_2,
      'HPO' AS vocabulary_id_1,
      'HPO' AS vocabulary_id_2,
      edge ->> 'pred' AS predicate
    FROM dev_hpo.hpo_json,
    LATERAL jsonb_array_elements(source_json -> 'graphs') AS graph,
    LATERAL jsonb_array_elements(graph -> 'edges') AS edge
    WHERE (left(split_part(edge ->> 'sub', '/', -1), 3) = 'HP_'
       AND left(split_part(edge ->> 'obj', '/', -1), 3) = 'HP_')
      AND version IN (
        SELECT substring(vocabulary_version FROM '\d{4}-\d{2}-\d{2}')::date AS date_string
        FROM vocabulary
        WHERE vocabulary.vocabulary_id = 'HPO'
        LIMIT 1
      )
    ORDER BY split_part(edge ->> 'sub', '/', -1)
  )
  SELECT DISTINCT
    concept_code_1,
    concept_code_2,
    COALESCE(relationship_id, predicate) AS relationship_id,
    crs.vocabulary_id_1,
    crs.vocabulary_id_2,
    to_date('2008-11-17', 'YYYY-MM-DD') AS valid_start_date, -- Publication date of 1st article about HPO
    to_date('2099-12-31', 'YYYY-MM-DD') AS valid_end_date
  FROM crs
  JOIN relationship r
    ON lower(regexp_replace(predicate, '[[:punct:]]|\s', '', 'gi')) =
       lower(regexp_replace(r.relationship_id, '[[:punct:]]|\s', '', 'gi'))
   AND predicate = 'is_a'
) AS tab_source
;

-- 5.3 Recursive table used to adjust classes and domains
DROP TABLE IF EXISTS hpo_hierarchy;
CREATE TABLE hpo_hierarchy AS
WITH RECURSIVE concept_hierarchy AS (
  SELECT
    concept_code_1,
    concept_code_1 AS concept_code_2,
    vocabulary_id_1,
    vocabulary_id_1 AS vocabulary_id_2,
    relationship_id,
    0 AS level,
    concept_code_1 AS root_concept,
    ARRAY[concept_code_1]::varchar[] AS path
  FROM concept_relationship_stage
  WHERE relationship_id = 'Is a'

  UNION ALL

  SELECT
    ch.concept_code_1,
    crs.concept_code_2,
    ch.vocabulary_id_1,
    crs.vocabulary_id_2,
    crs.relationship_id,
    ch.level + 1,
    ch.root_concept,
    ch.path || crs.concept_code_2::varchar
  FROM concept_hierarchy ch
  JOIN concept_relationship_stage crs
    ON ch.concept_code_2 = crs.concept_code_1
  WHERE crs.relationship_id = 'Is a'
    AND crs.concept_code_2 != ALL(ch.path)
)
SELECT
  ch.concept_code_1 AS descendant_concept_code,
  cs1.concept_name AS descendant_concept_name,
  ch.concept_code_2 AS ancestor_concept_code,
  cs2.concept_name AS ancestor_concept_name,
  ch.vocabulary_id_1 AS descendant_vocabulary_id,
  ch.vocabulary_id_2 AS ancestor_vocabulary_id,
  ch.level,
  cs_root.concept_name AS root_concept_name,
  ch.path AS concept_code_path,
  ARRAY(
    SELECT cs.concept_name
    FROM unnest(ch.path) AS p(concept_code)
    JOIN concept_stage cs
      ON cs.concept_code = p.concept_code
  ) AS concept_name_path,
  array_to_string(
    ARRAY(
      SELECT cs.concept_name
      FROM unnest(ch.path) AS p(concept_code)
      JOIN concept_stage cs
        ON cs.concept_code = p.concept_code
    ),
    '|'
  ) AS concept_name_agg
FROM concept_hierarchy ch
JOIN concept_stage cs1
  ON cs1.concept_code = ch.concept_code_1
JOIN concept_stage cs2
  ON cs2.concept_code = ch.concept_code_2
JOIN concept_stage cs_root
  ON cs_root.concept_code = ch.root_concept
ORDER BY concept_code_1, level
;

/* These links are excluded from the scope until a relevant use case exists
-- 5.4 Gene-to-phenotype integration
-- specific genes (translated to OMOP Genomic) to HPO phenotypes connection
INSERT INTO concept_relationship_stage (
  concept_code_1,
  concept_code_2,
  relationship_id,
  vocabulary_id_1,
  vocabulary_id_2,
  valid_start_date,
  valid_end_date
)
SELECT DISTINCT
  concept_code_1 AS concept_code_1,
  concept_code_2 AS concept_code_2,
  relationship_id AS relationship_id,
  vocabulary_id_1 AS vocabulary_id_1,
  vocabulary_id_2 AS vocabulary_id_2,
  valid_start_date,
  to_date('2099-12-31', 'YYYY-MM-DD') AS valid_end_date
FROM (
  WITH gene_to_hpo AS (
    /*
       Map genes to HPO terms.
       Exclude descendants of HP_0000005 (Mode of inheritance),
       because they are not phenotype-specific.
    */
    SELECT DISTINCT
      gene_symbol,
      replace(hpo_id, ':', '_') AS concept_code
    FROM genes_to_hpo_phenotype a
    WHERE replace(hpo_id, ':', '_') NOT IN (
      SELECT descendant_concept_code
      FROM hpo_hierarchy
      WHERE ancestor_concept_code = 'HP_0000005'
    )
    and frequency IN ('HP:0040280',--Obligate
                       'HP:0040281' --Very frequent
        )
  ),

  gene_to_omop_map AS (
    /*
       Link gene symbols to OMOP Genomic concepts
       using exact synonym match.
       Only standard OMOP Genomic concepts are allowed.
    */
    SELECT DISTINCT
      a.gene_symbol,
      c.*
    FROM gene_to_hpo a
    JOIN concept_synonym cs
      ON cs.concept_synonym_name = a.gene_symbol
    JOIN concept c
      ON c.concept_id = cs.concept_id
      AND c.vocabulary_id = 'OMOP Genomic'
      AND c.standard_concept = 'S'
      AND c.concept_class_id = 'Genetic Variation'
  ),

  strict_candidates AS (
    /*
       Keep ONLY canonical name matches.
       The concept name must start with the gene symbol
       and be followed by a valid delimiter,
       or be exactly equal to the gene symbol.
       This removes fuzzy or descriptive matches.
    */
    SELECT g.*
    FROM gene_to_omop_map g
    WHERE
         upper(g.concept_name) = upper(g.gene_symbol)
      OR upper(g.concept_name) LIKE upper(g.gene_symbol) || ' %'
      OR upper(g.concept_name) LIKE upper(g.gene_symbol) || '(%'
      OR upper(g.concept_name) LIKE upper(g.gene_symbol) || '-%'
      OR upper(g.concept_name) LIKE upper(g.gene_symbol) || '_%'
      OR upper(g.concept_name) LIKE upper(g.gene_symbol) || ':%'
  ),

  strict_one AS (
    /*
       Enforce a strict 1:1 mapping:
       - If exactly ONE canonical OMOP concept exists for a gene_symbol,
         keep it.
       - If ZERO or MORE THAN ONE exist, drop the gene_symbol completely.
       This guarantees zero ambiguous mappings.
    */
    SELECT *
    FROM (
      SELECT
        sc.*,
        COUNT(*) OVER (PARTITION BY sc.gene_symbol) AS cnt,
        ROW_NUMBER() OVER (
          PARTITION BY sc.gene_symbol
          ORDER BY sc.concept_id
        ) AS rn
      FROM strict_candidates sc
    ) x
    WHERE x.cnt = 1
      AND x.rn = 1
  )

  /*
     Final mapping:
     - HPO concept  → OMOP Genomic concept
     - One OMOP concept per gene_symbol
     - Potentially multiple HPO terms per gene
  */
  SELECT DISTINCT
    h.concept_code AS concept_code_1,
    cs2.vocabulary_id AS vocabulary_id_1,
    'Has variant' AS relationship_id,
    current_date AS valid_start_date,
    NULL AS invalid_reason,
    so.concept_code AS concept_code_2,
    so.vocabulary_id AS vocabulary_id_2
  FROM strict_one so
  JOIN gene_to_hpo h
    ON h.gene_symbol = so.gene_symbol
  JOIN concept_stage cs2
    ON cs2.concept_code = h.concept_code
) AS tab_genes_to_ph
;
*/

-- 6. Hierarchy-based domain/class correction
UPDATE concept_stage
SET domain_id = x.default_domain
FROM (
  WITH hpo_filtered AS (
    SELECT *
    FROM hpo_hierarchy
    WHERE concept_code_path[array_length(concept_code_path, 1)] = 'HP_0000001'
  )
  SELECT DISTINCT
    descendant_concept_code,
    descendant_concept_name,
    CASE
      WHEN EXISTS (
        SELECT 1
        FROM hpo_filtered h2
        WHERE h2.descendant_concept_code = h1.descendant_concept_code
          AND h2.concept_code_path && ARRAY['HP_0012823', 'HP_0000005', 'HP_0040279']::varchar[]
      ) THEN 'Meas Value'
      WHEN EXISTS (
        SELECT 1
        FROM hpo_filtered h2
        WHERE h2.descendant_concept_code = h1.descendant_concept_code
          AND h2.concept_code_path && ARRAY['HP_0020228']::varchar[]
      ) THEN 'Measurement'
      ELSE 'Observation'
    END AS default_domain
  FROM hpo_filtered h1
) AS x
WHERE x.descendant_concept_code = concept_code
;


-- 6.1. Precise domain update: isolate measurement concepts
UPDATE concept_stage
SET domain_id = x.default_domain
FROM (
  WITH hpo_longest AS (
    SELECT
      descendant_concept_code,
      descendant_concept_name,
      string_agg(DISTINCT concept_name_agg, '|') AS concept_name_agg
    FROM (
      SELECT *
      FROM hpo_hierarchy s
      WHERE concept_code_path[array_length(concept_code_path, 1)] = 'HP_0000001'
    ) AS tabx
    GROUP BY descendant_concept_code, descendant_concept_name
  )
  SELECT
    descendant_concept_code,
    descendant_concept_name,
    concept_name_agg,
    'Measurement' AS default_domain
  FROM hpo_longest
  WHERE (
    (
      (concept_name_agg ~* 'concentration|( test| level| ratio| activity)$|( test | level | ratio | activity )|^(test |level |ratio |activity )')
      OR descendant_concept_name ~* 'concentration|( test| level| ratio| activity)$|( test | level | ratio | activity )|^(test |level |ratio |activity )'
    )
    AND concept_name_agg !~* 'morphology'
  )
  OR (
    concept_name_agg ~* 'physiology'
    AND (
      (concept_name_agg ~* 'concentration|( test| level| ratio| activity)$|( test | level | ratio | activity )|^(test |level |ratio |activity )')
      AND descendant_concept_name ~* 'concentration|( test| level| ratio| activity)$|( test | level | ratio | activity )|^(test |level |ratio |activity )'
    )
  )
) AS x
WHERE x.descendant_concept_code = concept_code;


-- 6.2. Assign default concept_class_id by domain
UPDATE concept_stage a
SET concept_class_id = x.default_class
FROM (
  SELECT 'Measurement' AS domain_id, 'Observable Entity' AS default_class
  UNION ALL
  SELECT 'Observation' AS domain_id, 'Clinical Finding' AS default_class
  UNION ALL
  SELECT 'Meas Value' AS domain_id, 'Qualifier Value' AS default_class
  UNION ALL
  SELECT 'Condition' AS domain_id, 'Clinical Finding' AS default_class
  UNION ALL
  SELECT 'Procedure' AS domain_id, 'Procedure' AS default_class
  UNION ALL
  SELECT 'Drug' AS domain_id, 'Drug Product' AS default_class
  UNION ALL
  SELECT 'Device' AS domain_id, 'Device' AS default_class
) AS x
WHERE a.domain_id = x.domain_id;
;


-- 6.3. Precise domain/class assignment: isolate morphological abnormalities
UPDATE concept_stage
SET domain_id = x.default_domain,
    concept_class_id = x.default_class
FROM (
  WITH hpo_longest AS (
    SELECT
      descendant_concept_code,
      descendant_concept_name,
      string_agg(DISTINCT concept_name_agg, '|') AS concept_name_agg
    FROM (
      SELECT *
      FROM hpo_hierarchy s
    ) AS tabx
    GROUP BY descendant_concept_code, descendant_concept_name
  )
  SELECT
    descendant_concept_code,
    descendant_concept_name,
    concept_name_agg,
    'Observation' AS default_domain,
    'Morph Abnormality' AS default_class
  FROM hpo_longest
  WHERE concept_name_agg ~* 'morpholog'
     OR concept_name_agg ~* 'morpholog'
) AS x
WHERE x.descendant_concept_code = concept_code;


-- 6.4. Neoplasms are considered Conditions
UPDATE concept_stage
SET domain_id = x.default_domain,
    concept_class_id = x.default_class
FROM (
  WITH hpo_longest AS (
    SELECT
      descendant_concept_code,
      descendant_concept_name
    FROM (
      SELECT *
      FROM hpo_hierarchy s
      WHERE ancestor_concept_code = 'HP_0002664' -- Neoplasm
    ) AS tabx
    GROUP BY descendant_concept_code, descendant_concept_name
  )
  SELECT
    descendant_concept_code,
    descendant_concept_name,
    'Condition' AS default_domain,
    'Disorder' AS default_class
  FROM hpo_longest
) AS x
WHERE x.descendant_concept_code = concept_code
;

-- 7.0 Deterministic mappings insertion


-- 7.1  Process manual relationships (concept_relationship_manual)
DO $_$
BEGIN
  PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;


-- 8. Check replacement mappings
DO $_$
BEGIN
  PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

-- 9. Add mappings from deprecated to current concepts
DO $_$
BEGIN
  PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

-- 10. Deprecate 'Maps to' mappings that point to deprecated/upgraded concepts
DO $_$
BEGIN
  PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

-- 11. Add mappings from deprecated to current concepts for 'Maps to value'
DO $_$
BEGIN
  PERFORM VOCABULARY_PACK.AddFreshMapsToValue();
END $_$;


-- 12. Clean up
DROP TABLE  HPO_source; 
DROP TABLE hpo_hierarchy;


-- At the end, concept_stage, concept_relationship_stage, and concept_synonym_stage
-- should be ready to be fed into the generic_update.sql script.




