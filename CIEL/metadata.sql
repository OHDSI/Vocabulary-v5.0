INSERT INTO concept_metadata (
    concept_id,
    concept_category,
    reuse_status)
SELECT DISTINCT 
    concept_id,
    NULL,
    NULL
FROM concept WHERE vocabulary_id = 'CIEL'; -- 58349

INSERT INTO concept_relationship_metadata (
    concept_id_1,
    concept_id_2,
    relationship_id,
    relationship_predicate_id,
    relationship_group,
    mapping_source,
    confidence,
    mapping_tool,
    mapper,
    reviewer
) 
SELECT 
    c.concept_id AS concept_id_1,
    target_concept_id AS concept_id_2,
    relationship_id as relationship_id,
    -- SSSOM Predicates based on Mapping Direction
    CASE 
        -- EQ: Equivalent [exactMatch]
        WHEN rule_applied ~* '^1\.01' THEN 'eq'        
        -- UP: Uphill [broadMatch] 
        WHEN rule_applied ~* '^1\.02|^2\.06|^2\.10|^2\.12|^2\.14|^2\.15'
           THEN 'up'             
    END AS relationship_predicate_id, -- returns "violates check constraint "chk_relationship_predicate_id"" but relationship_predicate_id are 'eq' and 'up'
  NULL AS relationship_group,
    'CIEL' AS mapping_source,
    1 AS confidence,
    'AM-lib_C' AS mapping_tool,
    'Andrew S. Kanter' AS mapper,
    NULL AS reviewer
FROM maps_for_load_stage a
JOIN concept c
  ON a.source_code = c.concept_code
WHERE c.vocabulary_id = 'CIEL'
AND rule_applied ~* '^1\.01|^1\.02|^2\.06|^2\.10|^2\.12|^2\.14|^2\.15' 
; -- 41522

-- Clean-up
DROP TABLE maps_for_load_stage;
