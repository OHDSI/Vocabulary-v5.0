/*
================================================================================
6 - curation output metadata backlog.sql
================================================================================

Purpose
-------
Prepare a dependency-light CDE review output that combines:

1. mined oncology candidates from oncology_concept_mined_for_review_prioritized;
2. existing devv5 concept_relationship_metadata rows from mined vocabularies to
   Cancer Modifier where relationship_predicate_id is not exactMatch.

This variant intentionally avoids dependencies on dev_nemesis_release and
splitting_snomed_conditions_oncology_wg. It is useful when the goal is to review
mined concepts together with the previous non-exact Cancer Modifier mapping
backlog.

Inputs
------
- dev_cancer_modifier.oncology_concept_mined_for_review_prioritized
- devv5.concept
- devv5.concept_relationship
- devv5.concept_relationship_metadata

Notes
-----
- Review grain is one row per proposed review decision or mapping target. A
  single source_concept_id can appear in multiple rows when it has multiple
  proposed targets. Keep curator flags row-level to preserve 1-to-many mappings.
- Existing exactMatch mappings to Cancer Modifier are not emitted by the metadata
  backlog section.
- Existing metadata rows are pulled from devv5 so previous backlog can be
  reviewed even if it is not present in the current mining output.
================================================================================
*/

-- -----------------------------------------------------------------------------
-- Section 06M.01: Build CDE-ready output from mined candidates and metadata backlog
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS dev_cancer_modifier.oncology_concept_mined_for_review_metadata_backlog;

CREATE TABLE dev_cancer_modifier.oncology_concept_mined_for_review_metadata_backlog AS
WITH mining_vocabularies(vocabulary_id) AS (
    VALUES
        ('SNOMED'),
        ('LOINC'),
        ('NAACCR')
),

mined_candidates AS (
    SELECT DISTINCT
        p.source_concept_id,
        p.source_concept_code::text AS source_concept_code,
        p.source_concept_name,
        p.source_domain_id,
        p.source_vocabulary_id,
        p.max_record,
        p.priority,
        p.max_score
    FROM dev_cancer_modifier.oncology_concept_mined_for_review_prioritized p
    JOIN mining_vocabularies mv
        ON mv.vocabulary_id = p.source_vocabulary_id
),

metadata_backlog AS (
    SELECT DISTINCT
        source.concept_id AS source_concept_id,
        source.concept_code::text AS source_concept_code,
        source.concept_name AS source_concept_name,
        source.domain_id AS source_domain_id,
        source.vocabulary_id AS source_vocabulary_id,
        NULL::integer AS max_record,
        cr.relationship_id,
        crm.relationship_predicate_id,
        crm.relationship_group,
        crm.mapping_source,
        crm.confidence,
        crm.mapping_tool,
        crm.mapper,
        crm.reviewer,
        target.concept_id AS target_concept_id,
        target.concept_code AS target_concept_code,
        target.concept_name AS target_concept_name,
        target.concept_class_id AS target_concept_class_id,
        target.standard_concept AS target_standard_concept,
        target.invalid_reason AS target_invalid_reason,
        target.domain_id AS target_domain_id,
        target.vocabulary_id AS target_vocabulary_id
    FROM devv5.concept_relationship_metadata crm
    JOIN devv5.concept_relationship cr
        ON cr.concept_id_1 = crm.concept_id_1
       AND cr.concept_id_2 = crm.concept_id_2
       AND cr.relationship_id = crm.relationship_id
       AND cr.invalid_reason IS NULL
    JOIN devv5.concept source
        ON source.concept_id = crm.concept_id_1
    JOIN mining_vocabularies mv
        ON mv.vocabulary_id = source.vocabulary_id
    JOIN devv5.concept target
        ON target.concept_id = crm.concept_id_2
       AND target.vocabulary_id = 'Cancer Modifier'
    WHERE crm.relationship_predicate_id IS DISTINCT FROM 'exactMatch'
),

metadata_rows AS (
    SELECT
        mb.source_concept_code,
        mb.source_concept_id,
        COALESCE(mc.max_record, mb.max_record) AS max_record,
        mb.source_concept_name,
        mb.source_domain_id,
        CONCAT_WS(
            '; ',
            'Review existing non-exact Cancer Modifier metadata mapping',
            'predicate=' || COALESCE(mb.relationship_predicate_id, 'NULL'),
            'mapping_source=' || NULLIF(mb.mapping_source, ''),
            'confidence=' || mb.confidence::text,
            CASE WHEN mc.source_concept_id IS NOT NULL THEN 'also_found_by_current_mining' END
        ) AS action_req,
        mb.source_vocabulary_id,
        mb.relationship_id,
        mb.relationship_predicate_id AS relationship_id_predicate,
        NULL::boolean AS decision,
        NULL::boolean AS to_destandardize,
        NULL::boolean AS create_standard,
        NULL::text AS comment,
        mb.target_concept_id,
        mb.target_concept_code,
        mb.target_concept_name,
        mb.target_concept_class_id,
        mb.target_standard_concept,
        mb.target_invalid_reason,
        mb.target_domain_id,
        mb.target_vocabulary_id
    FROM metadata_backlog mb
    LEFT JOIN mined_candidates mc
        ON mc.source_concept_id = mb.source_concept_id
),

mined_open_rows AS (
    SELECT
        mc.source_concept_code,
        mc.source_concept_id,
        mc.max_record,
        mc.source_concept_name,
        mc.source_domain_id,
        CONCAT_WS(
            '; ',
            'Review mined candidate for Cancer Modifier mapping',
            'priority=' || mc.priority,
            'max_score=' || mc.max_score::text
        ) AS action_req,
        mc.source_vocabulary_id,
        NULL::text AS relationship_id,
        NULL::text AS relationship_id_predicate,
        NULL::boolean AS decision,
        NULL::boolean AS to_destandardize,
        NULL::boolean AS create_standard,
        NULL::text AS comment,
        NULL::integer AS target_concept_id,
        NULL::text AS target_concept_code,
        NULL::text AS target_concept_name,
        NULL::text AS target_concept_class_id,
        NULL::text AS target_standard_concept,
        NULL::text AS target_invalid_reason,
        NULL::text AS target_domain_id,
        NULL::text AS target_vocabulary_id
    FROM mined_candidates mc
    WHERE NOT EXISTS (
        SELECT 1
        FROM metadata_backlog mb
        WHERE mb.source_concept_id = mc.source_concept_id
    )
),

cde_rows AS (
    SELECT * FROM metadata_rows
    UNION ALL
    SELECT * FROM mined_open_rows
)

SELECT *
FROM (
    SELECT DISTINCT
        source_concept_code,
        source_concept_id,
        max_record,
        source_concept_name,
        source_domain_id,
        action_req,
        source_vocabulary_id,
        relationship_id,
        relationship_id_predicate,
        decision,
        to_destandardize,
        create_standard,
        comment,
        target_concept_id,
        target_concept_code,
        target_concept_name,
        target_concept_class_id,
        target_standard_concept,
        target_invalid_reason,
        target_domain_id,
        target_vocabulary_id
    FROM cde_rows
) cde_export
ORDER BY
    source_vocabulary_id,
    to_tsvector(regexp_replace(source_concept_name, '\(.+\)', '', 'gi')),
    source_concept_name,
    source_concept_code,
    relationship_id,
    relationship_id_predicate,
    target_concept_id;


-- -----------------------------------------------------------------------------
-- Section Quick backlog summary
-- -----------------------------------------------------------------------------
SELECT
    source_vocabulary_id,
    relationship_id_predicate,
    (regexp_match(action_req,'Tier-\d'))[1] as priority_tier,
    COUNT(*) AS row_count,
    COUNT(DISTINCT source_concept_id) AS source_concept_count,
    COUNT(DISTINCT target_concept_id) AS target_concept_count
FROM dev_cancer_modifier.oncology_concept_mined_for_review_metadata_backlog
GROUP BY
    source_vocabulary_id,
    relationship_id_predicate, (regexp_match(action_req,'Tier-\d'))[1]
ORDER BY
    source_vocabulary_id,
    relationship_id_predicate,
     (regexp_match(action_req,'Tier-\d'))[1];


-- -----------------------------------------------------------------------------
--  Create for review to be uploaded to OHDSI Vocabulary Google drive
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS dev_cancer_modifier.oncology_concept_mined_for_review_metadata_backlog_tier_1;
CREATE TABLE dev_cancer_modifier.oncology_concept_mined_for_review_metadata_backlog_tier_1 AS
SELECT source_concept_code,
       source_concept_id,
       max_record,
       source_concept_name,
       source_domain_id,
       action_req,
       source_vocabulary_id,
       relationship_id,
       relationship_id_predicate,
       decision,
       to_destandardize,
       create_standard,
       comment,
       target_concept_id,
       target_concept_code,
       target_concept_name,
       target_concept_class_id,
       target_standard_concept,
       target_invalid_reason,
       target_domain_id,
       target_vocabulary_id
FROM dev_cancer_modifier.oncology_concept_mined_for_review_metadata_backlog
WHERE (source_vocabulary_id IN ( 'SNOMED') --adjust as needed
and
     action_req ~*'Tier-1' --adjust as needed)
    )
   OR
    (source_vocabulary_id IN ( 'LOINC') --adjust as needed
         AND source_concept_code ~* '\|' and source_concept_id IS NULL )  -- proxy for precoordinated pairs
ORDER BY
    source_vocabulary_id,
    to_tsvector(regexp_replace(source_concept_name, '\(.+\)', '', 'gi')),
    source_concept_name,
    source_concept_code,
    relationship_id,
    relationship_id_predicate,
    target_concept_id
;

SELECT *
FROM oncology_concept_mined_for_review_metadata_backlog_tier_1
ORDER BY
    source_vocabulary_id,
    to_tsvector(regexp_replace(source_concept_name, '\(.+\)', '', 'gi')),
    source_concept_name,
    source_concept_code,
    relationship_id,
    relationship_id_predicate,
    target_concept_id
;


