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
* Date: July 2026
**************************************************************************/


-- Update latest_update field to the new date
DO
$_$
BEGIN
  PERFORM VOCABULARY_PACK.SetLatestUpdate(
      pVocabularyName => 'Mondo',
      pVocabularyDate => (SELECT version::date
        as version_date
      FROM dev_mondo.mondo_json
      ORDER BY version DESC
      LIMIT 1),
      pVocabularyVersion => (SELECT 'Mondo v' ||
           version::text as version_date
         FROM dev_mondo.mondo_json
         ORDER BY version DESC
         LIMIT 1),
      pVocabularyDevSchema => 'DEV_MONDO'
      );
END
$_$;



-- Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

-- 1. mondo_source preparation
-- MONDO JSON source processing
DROP TABLE IF EXISTS  mondo_source;
CREATE TABLE mondo_source AS
WITH mondo_source AS (
  SELECT
    version,
    edge ->> 'lbl' AS concept_name,

    -- Extract just the ID part from the full URI
    regexp_replace(edge ->> 'id', 'http://purl.obolibrary.org/obo/', '', 'gi') AS concept_code,
    edge ->> 'type' AS concept_class_id,
    edge ->> 'meta' AS meta
  FROM dev_mondo.mondo_json,
  LATERAL jsonb_array_elements(source_json -> 'graphs') AS graph,
  LATERAL jsonb_array_elements(graph -> 'nodes') AS edge

  UNION ALL

  SELECT
    version,
    graph ->> 'lbl' AS concept_name,

    -- Extract just the ID part from the full URI
    regexp_replace(graph ->> 'id', 'http://purl.obolibrary.org/obo/', '', 'gi') AS concept_code,
    graph ->> 'type' AS concept_class_id,
    graph ->> 'meta' AS meta
  FROM dev_mondo.mondo_json,
  LATERAL jsonb_array_elements(source_json -> 'graphs') AS graph
),
synonym_enh_mondo_source AS (
  SELECT
    concept_name,
    concept_code,
    concept_class_id,
    jsonb_pretty(meta::jsonb) AS metadata,
    synonym ->> 'val' AS synonym_name,
    synonym ->> 'pred' AS synonym_type,
    COALESCE((meta::jsonb) ->> 'deprecated', 'false')::boolean AS deprecation,
    version
  FROM mondo_source,
  LATERAL jsonb_array_elements((meta::jsonb) -> 'synonyms') AS synonym
),
definition_enh_mondo_source AS (
  SELECT
    concept_name,
    concept_code,
    concept_class_id,
    jsonb_pretty(meta::jsonb) AS metadata,
    xref ->> 'val' AS refrence,
    (meta::jsonb) -> 'definition' ->> 'val' AS definition,
    COALESCE((meta::jsonb) ->> 'deprecated', 'false')::boolean AS deprecation,
    version
  FROM mondo_source,
  LATERAL jsonb_array_elements((meta::jsonb) -> 'xrefs') AS xref
),
property_enh_mondo_source AS (
  SELECT
    concept_name,
    concept_code,
    concept_class_id,
    jsonb_pretty(meta::jsonb) AS metadata,
    basicPropertyValues ->> 'val' AS bpv_refrence,
    basicPropertyValues ->> 'pred' AS bpv_predicate,
    COALESCE((meta::jsonb) ->> 'deprecated', 'false')::boolean AS deprecation,
    version
  FROM mondo_source,
  LATERAL jsonb_array_elements((meta::jsonb) -> 'basicPropertyValues') AS basicPropertyValues
),
combined_mondo_source AS (
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
  FROM definition_enh_mondo_source

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
  FROM synonym_enh_mondo_source

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
  FROM property_enh_mondo_source

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
  FROM mondo_source a
  LEFT JOIN property_enh_mondo_source b
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
FROM combined_mondo_source
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
        WHEN ss.concept_code IS NULL THEN to_date('2008-11-17', 'YYYY-MM-DD') -- Initial MONDO valid start date; review against release metadata before final PR
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
    FROM mondo_source s
    JOIN (
      SELECT latest_update, vocabulary_id
      FROM vocabulary
      WHERE vocabulary_id = 'Mondo')
        a ON 1 = 1
    -- valid_start_date set
    LEFT JOIN mondo_source ss
      ON ss.concept_code = s.concept_code
      AND ss.bpv_predicate = 'http://purl.org/dc/elements/1.1/date'
    LEFT JOIN mondo_source sss
      ON sss.concept_code = s.concept_code
      AND sss.bpv_predicate = 'http://purl.obolibrary.org/obo/IAO_0100001'
    WHERE split_part(s.concept_code, '_',1) = 'MONDO'
      AND s.version IN (
        SELECT substring(vocabulary_version FROM '\d{4}-\d{2}-\d{2}')::date AS date_string
        FROM vocabulary
        WHERE vocabulary.vocabulary_id = 'Mondo'
        LIMIT 1
      )
  ) AS tab_source
)
SELECT DISTINCT
  case when length(coalesce(concept_name,''))=0 then 'obsolete term ' || concept_code else concept_name end as concept_name,
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
  'Mondo' AS vocabulary_id,
  4180186 AS language_concept_id -- English
FROM mondo_source s
WHERE s.synonym_name IS NOT NULL
  AND s.version IN (
    SELECT substring(vocabulary_version FROM '\d{4}-\d{2}-\d{2}')::date AS date_string
    FROM vocabulary
    WHERE vocabulary.vocabulary_id = 'Mondo'
    LIMIT 1
  )
  AND split_part(s.concept_code, '_',1) = 'MONDO'
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
      WHEN ssss.concept_code IS NULL THEN to_date('2008-11-17', 'YYYY-MM-DD') -- Initial MONDO valid start date; review against release metadata before final PR
      ELSE ssss.bpv_refrence::date
    END AS valid_start_date,
    'Observation' AS domain_id,
    NULL AS standard_concept,
    vocabulary_id,
    regexp_replace(split_part(sss.bpv_refrence, '/', -1), ':', '_') AS concept_code_2
  FROM mondo_source s
  JOIN (
    SELECT latest_update, vocabulary_id
    FROM vocabulary
    WHERE vocabulary_id = 'Mondo') a
      ON 1 = 1
  -- valid_start_date set
  LEFT JOIN mondo_source ss
    ON ss.concept_code = s.concept_code
    AND ss.bpv_predicate = 'http://purl.org/dc/elements/1.1/date'
  JOIN mondo_source sss
    ON sss.concept_code = s.concept_code
    AND sss.bpv_predicate = 'http://purl.obolibrary.org/obo/IAO_0100001'
  LEFT JOIN mondo_source ssss
    ON regexp_replace(split_part(sss.bpv_refrence, '/', -1), ':', '_') = ssss.concept_code
    AND ssss.bpv_predicate = 'http://purl.org/dc/elements/1.1/date'
  WHERE split_part(s.concept_code, '_',1) = 'MONDO'
    AND s.version IN (
      SELECT substring(vocabulary_version FROM '\d{4}-\d{2}-\d{2}')::date AS date_string
      FROM vocabulary
      WHERE vocabulary.vocabulary_id = 'Mondo'
      LIMIT 1
    )
) AS tab_source
where split_part(concept_code, '_',1) = 'MONDO'
and split_part(concept_code_2, '_',1) = 'MONDO'
ORDER BY concept_code
;

-- 5.2 MONDO hierarchy integration
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
      'Mondo' AS vocabulary_id_1,
      'Mondo' AS vocabulary_id_2,
      edge ->> 'pred' AS predicate
    FROM dev_mondo.mondo_json,
    LATERAL jsonb_array_elements(source_json -> 'graphs') AS graph,
    LATERAL jsonb_array_elements(graph -> 'edges') AS edge
    WHERE split_part(split_part(edge ->> 'sub', '/', -1), '_',1) = 'MONDO'
       AND split_part(split_part(edge ->> 'obj', '/', -1), '_',1) = 'MONDO'
      AND version IN (
        SELECT substring(vocabulary_version FROM '\d{4}-\d{2}-\d{2}')::date AS date_string
        FROM vocabulary
        WHERE vocabulary.vocabulary_id = 'Mondo'
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
    to_date('2008-11-17', 'YYYY-MM-DD') AS valid_start_date, -- Initial MONDO valid start date; review against release metadata before final PR
    to_date('2099-12-31', 'YYYY-MM-DD') AS valid_end_date
  FROM crs
  JOIN relationship r
    ON lower(regexp_replace(predicate, '[[:punct:]]|\s', '', 'gi')) =
       lower(regexp_replace(r.relationship_id, '[[:punct:]]|\s', '', 'gi'))
   AND predicate = 'is_a'
) AS tab_source
;

-- 5.3 Recursive table used to adjust classes and domains
DROP TABLE IF EXISTS mondo_hierarchy;
CREATE TABLE mondo_hierarchy AS
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


-- 6. Hierarchy-based domain/class correction
UPDATE concept_stage
SET domain_id = x.default_domain
FROM (
  WITH mondo_filtered AS (
    SELECT *
    FROM mondo_hierarchy
    WHERE concept_code_path[array_length(concept_code_path, 1)] = 'MONDO_0000001'
  )
  SELECT DISTINCT
    descendant_concept_code,
    descendant_concept_name,
    CASE
      WHEN EXISTS (
        SELECT 1
        FROM mondo_filtered h2
        WHERE h2.descendant_concept_code = h1.descendant_concept_code
          AND h2.concept_code_path && ARRAY['MONDO_XXX', 'MONDO_YYYY', 'MONDO_ZZZZ']::varchar[]
      ) THEN 'Meas Value'
      WHEN EXISTS (
        SELECT 1
        FROM mondo_filtered h2
        WHERE h2.descendant_concept_code = h1.descendant_concept_code
          AND h2.concept_code_path && ARRAY['MONDO_XYZ']::varchar[] -- measurement archetypical
      ) THEN 'Measurement'
      ELSE 'Observation'
    END AS default_domain
  FROM mondo_filtered h1
) AS x
WHERE x.descendant_concept_code = concept_code
;


-- 6.1. Precise domain update: isolate measurement concepts
UPDATE concept_stage
SET domain_id = x.default_domain
FROM (
  WITH mondo_longest AS (
    SELECT
      descendant_concept_code,
      descendant_concept_name,
      string_agg(DISTINCT concept_name_agg, '|') AS concept_name_agg
    FROM (
      SELECT *
      FROM mondo_hierarchy s
      WHERE concept_code_path[array_length(concept_code_path, 1)] = 'MONDO_0000001'
    ) AS tabx
    GROUP BY descendant_concept_code, descendant_concept_name
  )
  SELECT
    descendant_concept_code,
    descendant_concept_name,
    concept_name_agg,
    'Measurement' AS default_domain
  FROM mondo_longest
  WHERE (
    (
      (concept_name_agg ~* 'concentration|( test| level| ratio)$|( test | level | ratio )|^(test |level |ratio )')
      OR descendant_concept_name ~* 'concentration|( test| level| ratio)$|( test | level | ratio | activity )|^(test |level |ratio )'
    )
    AND concept_name_agg !~* 'morphology'
  )
  OR (
    concept_name_agg ~* 'physiology'
    AND (
      (concept_name_agg ~* 'concentration|( test| level| ratio)$|( test | level | ratio )|^(test |level |ratio )')
      AND descendant_concept_name ~* 'concentration|( test| level| ratio)$|( test | level | ratio  )|^(test |level |ratio )'
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
  WITH mondo_longest AS (
    SELECT
      descendant_concept_code,
      descendant_concept_name,
      string_agg(DISTINCT concept_name_agg, '|') AS concept_name_agg
    FROM (
      SELECT *
      FROM mondo_hierarchy s
    ) AS tabx
    GROUP BY descendant_concept_code, descendant_concept_name
  )
  SELECT
    descendant_concept_code,
    descendant_concept_name,
    concept_name_agg,
    'Observation' AS default_domain,
    'Morph Abnormality' AS default_class
  FROM mondo_longest
  WHERE concept_name_agg ~* 'morpholog'
     OR concept_name_agg ~* 'morpholog'
) AS x
WHERE x.descendant_concept_code = concept_code;


-- 6.4. Neoplasms are considered Conditions
UPDATE concept_stage
SET domain_id = x.default_domain,
    concept_class_id = x.default_class
FROM (
  WITH mondo_longest AS (
    SELECT
      descendant_concept_code,
      descendant_concept_name
    FROM (
      SELECT *
      FROM mondo_hierarchy s
      WHERE ancestor_concept_code = 'MONDO_0045024' -- Neoplasm
    ) AS tabx
    GROUP BY descendant_concept_code, descendant_concept_name
  )
  SELECT
    descendant_concept_code,
    descendant_concept_name,
    'Condition' AS default_domain,
    'Disorder' AS default_class
  FROM mondo_longest
) AS x
WHERE x.descendant_concept_code = concept_code
;

--7.0 Mapping integration using mapping-helper function
-- Run the Manul Work Function in order to populate the manual tables


-- 7.1 Process manual relationships (concept_relationship_manual)
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
DROP TABLE  mondo_source;
DROP TABLE mondo_hierarchy;

-- At the end, concept_stage, concept_relationship_stage, and concept_synonym_stage
-- should be ready to be fed into the generic_update.sql script.
-- Authenticate outside this script when required; do not store credentials in vocabulary SQL.

