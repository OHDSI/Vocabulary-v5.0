/*
================================================================================
5 - table assembling.sql
================================================================================

Purpose
-------
Assemble the candidate review table from Hecate output, seed concepts and the
rule-based mining table, then assign review priorities.

Inputs
------
- dev_cancer_modifier.hecate_mined_snomed
- dev_cancer_modifier.hecate_mined_LOINC
- dev_cancer_modifier.hecate_mined_NAACCR
- dev_cancer_modifier.seeding_table
- oncology_concepts_mined_with_rules

Created objects
---------------
- oncology_concept_mined_for_review
- oncology_concept_mined_for_review_prioritized
================================================================================
*/

-- -----------------------------------------------------------------------------
-- Section 05.01: Combine Hecate hits and seed concepts into review rows
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS dev_cancer_modifier.oncology_concept_mined_for_review;
CREATE TABLE   dev_cancer_modifier.oncology_concept_mined_for_review AS
with scope AS
         (select *
          from (SELECT distinct 'hecate@NAACCR'                                                   as origin,
                                id                                                         AS source_concept_id,
                                code as source_concept_code,
                                loaded_at,
                                name                                                       as source_concept_name,
                                to_tsvector(name)                                          as source_concept_name_ts_vector,
                                class                                                      as source_concept_class_id,
                                domain                                                     as source_domain_id,
                                vocabulary                                                 as source_vocabulary_id,
                                records,
                                score,
                                seed_concept_id,
                                c.concept_name                                             as seed_concept_name,
                                CASE WHEN lower(validity) = 'valid' then null else 'D' end as source_invalid_reason
                FROM dev_cancer_modifier."hecate_mined_NAACCR" a
                         JOIN concept c
                              on a.seed_concept_id = c.concept_id
                   -- where id NOT IN (SELECT concept_id from dev_cancer_modifier.mined_scope_full_with_ancestor_and_vector)
               ) "hsN*"
          UNION ALL

          SELECT distinct 'hecate@LOINC' as origin,   id                                                     AS source_concept_id,
                            code as source_concept_code,
                                loaded_at,
                                name                                                       as source_concept_name,
                                to_tsvector(name)                                          as source_concept_name_ts_vector,
                                class                                                      as source_concept_class_id,
                                domain                                                     as source_domain_id,
                                vocabulary                                                 as source_vocabulary_id,
                                records,
                                score,
                                seed_concept_id,
                                c.concept_name                                             as seed_concept_name,
                                CASE WHEN lower(validity) = 'valid' then null else 'D' end as source_invalid_reason
                FROM dev_cancer_modifier."hecate_mined_LOINC" a
                         JOIN concept c
                              on a.seed_concept_id = c.concept_id
          --where id NOT IN (SELECT concept_id from dev_cancer_modifier.mined_scope_full_with_ancestor_and_vector)

          UNION ALL

          SELECT distinct 'hecate@SNOMED' as origin, id                                                     AS source_concept_id,
                            code as source_concept_code,
                          loaded_at,
                                name                                                       as source_concept_name,
                                to_tsvector(name)                                          as source_concept_name_ts_vector,
                                class                                                      as source_concept_class_id,
                                domain                                                     as source_domain_id,
                                vocabulary                                                 as source_vocabulary_id,
                                records,
                                score,
                                seed_concept_id,
                                c.concept_name                                             as seed_concept_name,
                                CASE WHEN lower(validity) = 'valid' then null else 'D' end as source_invalid_reason
                FROM dev_cancer_modifier."hecate_mined_snomed" a
                         JOIN concept c
                              on a.seed_concept_id = c.concept_id

          UNION ALL

          SELECT distinct 'seeds' || '@' || prov[1] as origin,
                 st.concept_id,
                 seed_concept_code,
                 NULL::date as loaded_at,
                 seed_name,
                 to_tsvector(seed_name),
                 seed_concept_class_id,
                 seed_domain_id,
                 seed_vocabulary_id,
                 -1,
                 -1,
                  c.concept_id as seed_concept_id,
                  c.concept_name,
                  seed_invalid_reason

          from seeding_table st
          CROSS JOIN LATERAL unnest(st.root_seed_concept_ids) AS r(seed_concept_id)
JOIN concept c
    ON c.concept_id = r.seed_concept_id
)

    SELECT
    s.origin,
    s.source_concept_id,
    s.source_concept_code,
    s.loaded_at,
    s.source_concept_name,
    s.source_concept_name_ts_vector,
    s.source_concept_class_id,
    s.source_domain_id,
    s.source_vocabulary_id,
    s.records,
    s.score,
    s.seed_concept_id,
    s.seed_concept_name,
    s.source_invalid_reason,
    COALESCE(rc.related_concept_context, '[]'::jsonb) AS related_concept_context
FROM scope s
LEFT JOIN LATERAL (
    SELECT
        jsonb_agg(
            DISTINCT jsonb_build_object(
                'relationship', cr.relationship_id,
                'related_concept_info', jsonb_build_object(
                    'concept_id', c.concept_id,
                    'domain_id', c.domain_id,
                    'concept_name', c.concept_name
                )
            )
        ) AS related_concept_context
    FROM concept_relationship cr
    JOIN concept c
        ON c.concept_id = cr.concept_id_2
       AND c.vocabulary_id = s.source_vocabulary_id
    WHERE cr.concept_id_1 = s.source_concept_id
      AND cr.invalid_reason IS NULL
      AND cr.relationship_id NOT IN (
          'Maps to',
          'Mapped from',
          'Maps to value',
          'Value mapped from',
          'Concept replaced by',
          'Concept replaces'
      )
    AND c.vocabulary_id IN ('NAACCR','SNOMED','LOINC')
        and c.invalid_reason is null
    and c.standard_concept='S'
) rc
   ON TRUE;

-- -----------------------------------------------------------------------------
-- Section 05.02: Add exact concept-name matches across target vocabularies
-- -----------------------------------------------------------------------------
INSERT INTO oncology_concept_mined_for_review (origin, source_concept_id,source_concept_code, loaded_at, source_concept_name, source_concept_name_ts_vector, source_concept_class_id, source_domain_id, source_vocabulary_id, records, score, seed_concept_id, seed_concept_name, source_invalid_reason,related_concept_context)
with scope as ( SELECT distinct 'full-name-match' as origin,
       c.concept_id source_concept_id,
       c.concept_code as source_concept_code,
       current_timestamp as loaded_at,
       c.concept_name as source_concept_name,
       to_tsvector(c.concept_name ) as source_concept_name_ts_vector,
       c.concept_class_id as source_concept_class_id,
       c.domain_id as source_domain_id,
       c.vocabulary_id as source_vocabulary_id,
      -1 as records,
      -1 as score,
       a.source_concept_id as seed_concept_id,
         a.source_concept_name as seed_concept_name,
       c.invalid_reason as source_invalid_reason
FROM oncology_concept_mined_for_review a
JOIN concept c
on c.concept_name=a.source_concept_name
and c.concept_id<>a.source_concept_id
and c.vocabulary_id IN ('SNOMED','NAACCR','LOINC')
and c.domain_id=a.source_domain_id
and length(trim(a.source_concept_name))>1
WHERE c.standard_concept='S')
SELECT origin,
       source_concept_id,
       source_concept_code,
       loaded_at,
       source_concept_name,
       source_concept_name_ts_vector,
       source_concept_class_id,
       source_domain_id,
       source_vocabulary_id,
       records,
       score,
       seed_concept_id,
       seed_concept_name,
       source_invalid_reason,
       COALESCE(rc.related_concept_context, '[]'::jsonb) AS related_concept_context
from scope s
LEFT JOIN LATERAL (
    SELECT c.concept_id,
        jsonb_agg(
            DISTINCT jsonb_build_object(
                'relationship', cr.relationship_id,
                'related_concept_info', jsonb_build_object(
                    'concept_id', c.concept_id,
                    'domain_id', c.domain_id,
                    'concept_name', c.concept_name
                )
            )
        ) AS related_concept_context
    FROM concept_relationship cr
    JOIN concept c
        ON c.concept_id = cr.concept_id_2
       AND c.vocabulary_id = s.source_vocabulary_id
    WHERE cr.concept_id_1 = s.source_concept_id
      AND cr.invalid_reason IS NULL
      AND cr.relationship_id NOT IN (
          'Maps to',
          'Mapped from',
          'Maps to value',
          'Value mapped from',
          'Concept replaced by',
          'Concept replaces'
      )
    AND c.vocabulary_id IN ('NAACCR','SNOMED','LOINC')
        and c.invalid_reason is null
    and c.standard_concept='S'
    group by c.concept_id
) rc
    ON TRUE

;

-- -----------------------------------------------------------------------------
-- Section 05.03: Add exact synonym-name matches across target vocabularies
-- -----------------------------------------------------------------------------
INSERT INTO oncology_concept_mined_for_review (origin, source_concept_id,source_concept_code, loaded_at, source_concept_name, source_concept_name_ts_vector, source_concept_class_id, source_domain_id, source_vocabulary_id, records, score, seed_concept_id, seed_concept_name, source_invalid_reason,related_concept_context)
with scope as (SELECT distinct 'full-synonym-name-match' as origin,
       c.concept_id source_concept_id,
       c.concept_code as source_concept_code,
       current_timestamp as loaded_at,
       c.concept_name as source_concept_name,
       to_tsvector(c.concept_name ) as source_concept_name_ts_vector,
       c.concept_class_id as source_concept_class_id,
       c.domain_id as source_domain_id,
       c.vocabulary_id as source_vocabulary_id,
      -1 as records,
      -1 as score,
       a.source_concept_id as seed_concept_id,
         a.source_concept_name as seed_concept_name,
       c.invalid_reason as source_invalid_reason
FROM oncology_concept_mined_for_review a
JOIN devv5.concept_synonym cs
on cs.concept_synonym_name=a.source_concept_name
and cs.concept_id<>a.source_concept_id
and length(trim(a.source_concept_name))>1
JOIN concept c
on c.concept_id=cs.concept_id
and c.vocabulary_id IN ('SNOMED','NAACCR','LOINC')
and c.domain_id=a.source_domain_id
WHERE c.standard_concept='S')
SELECT origin,
       source_concept_id,
       source_concept_code,
       loaded_at,
       source_concept_name,
       source_concept_name_ts_vector,
       source_concept_class_id,
       source_domain_id,
       source_vocabulary_id,
       records,
       score,
       seed_concept_id,
       seed_concept_name,
       source_invalid_reason,
       COALESCE(rc.related_concept_context, '[]'::jsonb) AS related_concept_context
from scope s
LEFT JOIN LATERAL (
    SELECT
        jsonb_agg(
            DISTINCT jsonb_build_object(
                'relationship', cr.relationship_id,
                'related_concept_info', jsonb_build_object(
                    'concept_id', c.concept_id,
                    'domain_id', c.domain_id,
                    'concept_name', c.concept_name
                )
            )
        ) AS related_concept_context
    FROM concept_relationship cr
    JOIN concept c
        ON c.concept_id = cr.concept_id_2
       AND c.vocabulary_id = s.source_vocabulary_id
    WHERE cr.concept_id_1 = s.source_concept_id
      AND cr.invalid_reason IS NULL
      AND cr.relationship_id NOT IN (
          'Maps to',
          'Mapped from',
          'Maps to value',
          'Value mapped from',
          'Concept replaced by',
          'Concept replaces'
      )
    AND c.vocabulary_id IN ('NAACCR','SNOMED','LOINC')
        and c.invalid_reason is null
    and c.standard_concept='S'
) rc
    ON TRUE
;

-- -----------------------------------------------------------------------------
-- Section 05.04: Replace duplicate rule-based rows and append rule-only hits
-- -----------------------------------------------------------------------------
DELETE FROM oncology_concept_mined_for_review
    where origin='Rule-based-mine';
-- Insert standard rule-mined candidates not already represented by Hecate or seeds.
INSERT INTO oncology_concept_mined_for_review (origin, source_concept_id,source_concept_code, loaded_at, source_concept_name, source_concept_name_ts_vector, source_concept_class_id, source_domain_id, source_vocabulary_id, records, score, seed_concept_id, seed_concept_name, source_invalid_reason,related_concept_context)
SELECT origin,
       concept_id as source_concept_id,
      concept_code as source_concept_code,
       current_timestamp as loaded_at,
      concept_name as source_concept_name,
       to_tsvector(concept_name) as source_concept_name_ts_vector,
       concept_class_id as source_concept_class_id,
       domain_id as source_domain_id,
       vocabulary_id as source_vocabulary_id,
       NULL::int as records,
       NULL::float as score,
       NULL::int as seed_concept_id,
       NULL::varchar as seed_concept_name,
       invalid_reason as source_invalid_reason,
       COALESCE(rc.related_concept_context, '[]'::jsonb) AS related_concept_context
FROM oncology_concepts_mined_with_rules s
LEFT JOIN LATERAL (
    SELECT
        jsonb_agg(
            DISTINCT jsonb_build_object(
                'relationship', cr.relationship_id,
                'related_concept_info', jsonb_build_object(
                    'concept_id', c.concept_id,
                    'domain_id', c.domain_id,
                    'concept_name', c.concept_name
                )
            )
        ) AS related_concept_context
    FROM concept_relationship cr
    JOIN concept c
        ON c.concept_id = cr.concept_id_2
       AND c.vocabulary_id = s.vocabulary_id
    WHERE cr.concept_id_1 = s.concept_id
      AND cr.invalid_reason IS NULL
      AND cr.relationship_id NOT IN (
          'Maps to',
          'Mapped from',
          'Maps to value',
          'Value mapped from',
          'Concept replaced by',
          'Concept replaces'
      )
    AND c.vocabulary_id IN ('NAACCR','SNOMED','LOINC')
        and c.invalid_reason is null
    and c.standard_concept='S'
) rc
    ON TRUE
where concept_id NOT IN (SELECT source_concept_id from oncology_concept_mined_for_review)
and standard_concept='S'
;

-- Insert non-standard rule-mined candidates for potential destandardization review.
INSERT INTO oncology_concept_mined_for_review (origin, source_concept_id,source_concept_code, loaded_at, source_concept_name, source_concept_name_ts_vector, source_concept_class_id, source_domain_id, source_vocabulary_id, records, score, seed_concept_id, seed_concept_name, source_invalid_reason,related_concept_context)
SELECT origin || ':' || 'non-Standard' as origin,
       concept_id as source_concept_id,
      concept_code as source_concept_code,
       current_timestamp as loaded_at,
      concept_name as source_concept_name,
       to_tsvector(concept_name) as source_concept_name_ts_vector,
       concept_class_id as source_concept_class_id,
       domain_id as source_domain_id,
       vocabulary_id as source_vocabulary_id,
       NULL::int as records,
       NULL::float as score,
       NULL::int as seed_concept_id,
       NULL::varchar as seed_concept_name,
       invalid_reason as source_invalid_reason,
       COALESCE(rc.related_concept_context, '[]'::jsonb) AS related_concept_context
FROM oncology_concepts_mined_with_rules s
LEFT JOIN LATERAL (
    SELECT
        jsonb_agg(
            DISTINCT jsonb_build_object(
                'relationship', cr.relationship_id,
                'related_concept_info', jsonb_build_object(
                    'concept_id', c.concept_id,
                    'domain_id', c.domain_id,
                    'concept_name', c.concept_name
                )
            )
        ) AS related_concept_context
    FROM concept_relationship cr
    JOIN concept c
        ON c.concept_id = cr.concept_id_2
       AND c.vocabulary_id = s.vocabulary_id
    WHERE cr.concept_id_1 = s.concept_id
      AND cr.invalid_reason IS NULL
      AND cr.relationship_id NOT IN (
          'Maps to',
          'Mapped from',
          'Maps to value',
          'Value mapped from',
          'Concept replaced by',
          'Concept replaces'
      )
    AND c.vocabulary_id IN ('NAACCR','SNOMED','LOINC')
    and c.invalid_reason is null
    and c.standard_concept='S'
) rc
    ON TRUE
where concept_id NOT IN (SELECT source_concept_id from oncology_concept_mined_for_review)
and standard_concept IS NULL;


--Precoordinated pairs insertion
DROP TABLE IF EXISTS dev_cancer_modifier.precoord_pairs_from_cde;

CREATE TABLE dev_cancer_modifier.precoord_pairs_from_cde AS
WITH vocab_precoord_cde AS (
    SELECT DISTINCT
        cde.source_concept_id
    FROM dev_cancer_modifier.oncology_concept_mined_for_review cde
    JOIN concept c
        ON c.concept_id = cde.source_concept_id
       AND c.vocabulary_id IN ( 'LOINC' ) -- adjust
       AND c.invalid_reason IS NULL
),

question_answer_pairs AS (
    -- Source CDE concept is a valid LOINC question: collect valid allowed answers.
    SELECT DISTINCT
        question.concept_id AS question_concept_id,
        question.concept_code AS question_concept_code,
        question.concept_name AS question_concept_name,
        question.domain_id AS question_domain_id,
        answer.concept_id AS answer_concept_id,
        answer.concept_code AS answer_concept_code,
        answer.concept_name AS answer_concept_name,
        answer.domain_id AS answer_domain_id,
        'source_is_question' AS cde_source_role
    FROM vocab_precoord_cde cde
    JOIN concept question
        ON question.concept_id = cde.source_concept_id
       AND question.vocabulary_id IN ( 'LOINC' ) -- adjust
       AND question.invalid_reason IS NULL
    JOIN concept_relationship answer_of
        ON answer_of.concept_id_2 = question.concept_id
       AND answer_of.relationship_id = 'Answer of'
       AND answer_of.invalid_reason IS NULL
    JOIN concept answer
        ON answer.concept_id = answer_of.concept_id_1
       AND answer.vocabulary_id IN ( 'LOINC' ) -- adjust  
       AND answer.invalid_reason IS NULL

    UNION

    -- Source CDE concept is a valid LOINC answer: collect valid question context.
    SELECT DISTINCT
        question.concept_id AS question_concept_id,
        question.concept_code AS question_concept_code,
        question.concept_name AS question_concept_name,
        question.domain_id AS question_domain_id,
        answer.concept_id AS answer_concept_id,
        answer.concept_code AS answer_concept_code,
        answer.concept_name AS answer_concept_name,
        answer.domain_id AS answer_domain_id,
        'source_is_answer' AS cde_source_role
    FROM vocab_precoord_cde cde
    JOIN concept answer
        ON answer.concept_id = cde.source_concept_id
       AND answer.vocabulary_id IN ( 'LOINC' ) -- adjust
       AND answer.invalid_reason IS NULL
    JOIN concept_relationship answer_of
        ON answer_of.concept_id_1 = answer.concept_id
       AND answer_of.relationship_id = 'Answer of'
       AND answer_of.invalid_reason IS NULL
    JOIN concept question
        ON question.concept_id = answer_of.concept_id_2
       AND question.vocabulary_id IN ( 'LOINC' ) -- adjust
       AND question.invalid_reason IS NULL
)

SELECT DISTINCT
    LEFT(TRIM(question_concept_name) || ': ' || TRIM(answer_concept_name), 255) AS concept_name,
    COALESCE(NULLIF(question_domain_id, ''), 'Observation') AS domain_id,
    'LOINC' AS vocabulary_id,
    'Precoordinated pair' AS concept_class_id,
    NULL::text AS standard_concept,
    question_concept_code || '|' || answer_concept_code AS concept_code,
    CURRENT_DATE AS valid_start_date,
    TO_DATE('2099-12-31','YYYY-MM-DD') AS valid_end_date,
    NULL::text AS invalid_reason,
    question_concept_id,
    question_concept_code,
    question_concept_name,
    answer_concept_id,
    answer_concept_code,
    answer_concept_name,
    cde_source_role
FROM question_answer_pairs
ORDER BY
    question_concept_code,
    answer_concept_code
;

--

-- Insert pre-coordinated pairs for manual mapping and review +
INSERT INTO oncology_concept_mined_for_review (origin, source_concept_id,source_concept_code, loaded_at, source_concept_name, source_concept_name_ts_vector, source_concept_class_id, source_domain_id, source_vocabulary_id, records, score, seed_concept_id, seed_concept_name, source_invalid_reason,related_concept_context)
SELECT origin,
        NULL::int as source_concept_id,
      source_concept_code,
       current_timestamp as loaded_at,
      source_concept_name as source_concept_name,
       to_tsvector(source_concept_name) as source_concept_name_ts_vector,
       source_concept_class_id as source_concept_class_id,
       source_domain_id as source_domain_id,
       source_vocabulary_id as source_vocabulary_id,
       NULL::int as records,
       NULL::float as score,
       NULL::int as seed_concept_id,
       NULL::varchar as seed_concept_name,
       source_invalid_reason,
       related_concept_context AS related_concept_context
FROM (SELECT distinct on (a.concept_code) a.concept_name     as source_concept_name,

                                          b.origin           as origin,
                                          a.domain_id        as source_domain_id,
                                          a.vocabulary_id    as source_vocabulary_id,
                                          a.concept_class_id as source_concept_class_id,
                                          a.standard_concept as source_standard_concept,
                                          a.concept_code     as source_concept_code,
                                          a.invalid_reason   as source_invalid_reason,
                                          COALESCE(rc.related_concept_context, '[]'::jsonb) AS related_concept_context
      FROM dev_cancer_modifier.precoord_pairs_from_cde a
               JOIN dev_cancer_modifier.oncology_concept_mined_for_review b
                    on a.question_concept_id = b.source_concept_id
                        and b.origin NOT IN ('full-name-match')
               LEFT JOIN LATERAL (
          SELECT jsonb_agg(
                         DISTINCT jsonb_build_object(
                          'relationship', cr.relationship_id,
                          'related_concept_info', jsonb_build_object(
                                  'concept_id', c.concept_id,
                                  'domain_id', c.domain_id,
                                  'concept_name', c.concept_name
                                                  )
                                  )
                 ) AS related_concept_context
          FROM concept_relationship cr
                   JOIN concept c
                        ON c.concept_id = cr.concept_id_2
                            AND c.vocabulary_id = a.vocabulary_id
          WHERE cr.concept_id_1 = a.answer_concept_id
            AND cr.invalid_reason IS NULL
            AND cr.relationship_id NOT IN (
                                           'Maps to',
                                           'Mapped from',
                                           'Maps to value',
                                           'Value mapped from',
                                           'Concept replaced by',
                                           'Concept replaces'
              )
            AND c.vocabulary_id IN ('LOINC')
            and c.invalid_reason is null
          ) rc
                         ON TRUE
      where a.concept_code NOT IN (SELECT source_concept_code from oncology_concept_mined_for_review)
        and standard_concept IS NULL) as prec_tab_res
    ;

DROP TABLE IF EXISTS dev_cancer_modifier.precoord_pairs_from_cde;
-- -----------------------------------------------------------------------------
-- Section 05.05: Prioritize candidates for curator review
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS dev_cancer_modifier.oncology_concept_mined_for_review_prioritized;
CREATE TABLE dev_cancer_modifier.oncology_concept_mined_for_review_prioritized AS
-- Tier-1: candidates found by Hecate, seed expansion or name/synonym matching.
SELECT distinct 'Tier-1' as priority,
                array_agg(distinct origin) as origin,
                source_concept_id,
                source_concept_code,
                source_concept_name,
              source_concept_class_id,
                source_domain_id,
                source_vocabulary_id,
                  jsonb_agg(distinct jsonb_build_object('seed_concept_id',seed_concept_id,'seed_concept_name',
                seed_concept_name)) as seed_info_agg,
               count(distinct seed_concept_id) as seed_id_cnt,
                jsonb_agg(distinct related_concept_context) as related_concept_context,
                max(records) as max_record,max(score) as max_score
FROM oncology_concept_mined_for_review
where origin NOT IN ('Rule-based-mine','Rule-based-mine:non-Standard')
group by source_concept_id,
                source_concept_code,
                source_concept_name,
                source_concept_class_id,
                source_domain_id,
                source_vocabulary_id

UNION ALL

-- Tier-2: rule-based candidates under already selected candidate ancestors.
SELECT distinct 'Tier-2' as priority,
                array_agg(distinct origin) as origin,
                source_concept_id,
                source_concept_code,
                source_concept_name,
              source_concept_class_id,
                source_domain_id,
                source_vocabulary_id,
                  jsonb_agg(distinct jsonb_build_object('seed_concept_id',seed_concept_id,'seed_concept_name',
                seed_concept_name)) as seed_info_agg,
               count(distinct seed_concept_id) as seed_id_cnt,
                jsonb_agg(distinct related_concept_context) as related_concept_context,
                max(records) as max_record,max(score) as max_score
FROM oncology_concept_mined_for_review s
where s.origin ='Rule-based-mine'
and ( (s.source_concept_id IN  (
    SELECT descendant_concept_id
    FROM devv5.concept_ancestor ca
    JOIN oncology_concept_mined_for_review s2
    on s2.source_concept_id=ca.ancestor_concept_id
    where s2.origin NOT IN ('Rule-based-mine','Rule-based-mine:non-Standard')
    ))
OR s.source_concept_id is null) -- to permit precoordinated pairs integration
group by source_concept_id,
                source_concept_code,
                source_concept_name,
                source_concept_class_id,
                source_domain_id,
                source_vocabulary_id

UNION ALL

-- Tier-3: rule-based candidates connected by active non-manual relationships.
SELECT distinct 'Tier-3' as priority,
                array_agg(distinct origin) as origin,
                source_concept_id,
                source_concept_code,
                source_concept_name,
              source_concept_class_id,
                source_domain_id,
                source_vocabulary_id,
                  jsonb_agg(distinct jsonb_build_object('seed_concept_id',seed_concept_id,'seed_concept_name',
                seed_concept_name)) as seed_info_agg,
               count(distinct seed_concept_id) as seed_id_cnt,
                jsonb_agg(distinct related_concept_context) as related_concept_context,
                max(records) as max_record,max(score) as max_score
FROM oncology_concept_mined_for_review s
where s.origin ='Rule-based-mine'
and (

    ( s.source_concept_id IN  (
    SELECT concept_id_2
    FROM concept_relationship cr
    JOIN oncology_concept_mined_for_review s2
    on s2.source_concept_id=cr.concept_id_1
    and cr.invalid_reason IS NULL
    where s2.origin NOT IN ('Rule-based-mine','Rule-based-mine:non-Standard')
    ))
OR s.source_concept_id is null) -- to permit precoordinated pairs integration

group by source_concept_id,
                source_concept_code,
                source_concept_name,
                source_concept_class_id,
                source_domain_id,
                source_vocabulary_id

UNION ALL

-- Tier-4: non-standard rule-based candidates connected to selected candidates.
SELECT distinct 'Tier-4' as priority,
                array_agg(distinct origin) as origin,
                source_concept_id,
                source_concept_code,
                source_concept_name,
              source_concept_class_id,
                source_domain_id,
                source_vocabulary_id,
                  jsonb_agg(distinct jsonb_build_object('seed_concept_id',seed_concept_id,'seed_concept_name',
                seed_concept_name)) as seed_info_agg,
               count(distinct seed_concept_id) as seed_id_cnt,
                jsonb_agg(distinct related_concept_context) as related_concept_context,
                max(records) as max_record,max(score) as max_score
FROM oncology_concept_mined_for_review s
where s.origin ='Rule-based-mine:non-Standard'
and   (
       (s.source_concept_id IN  (
    SELECT concept_id_2
    FROM concept_relationship cr
    JOIN oncology_concept_mined_for_review s2
    on s2.source_concept_id=cr.concept_id_1
    and cr.invalid_reason IS NULL
    where s2.origin NOT IN ('Rule-based-mine')
    ))
or s.seed_concept_id is null)
group by source_concept_id,
                source_concept_code,
                source_concept_name,
                source_concept_class_id,
                source_domain_id,
                source_vocabulary_id
;
