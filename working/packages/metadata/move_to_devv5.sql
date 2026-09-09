/*
    Move metadata to the devv5 metadata tables
*/

-- UPSERT for concept_metadata
INSERT INTO devv5.concept_metadata (concept_id, concept_category, reuse_status)
SELECT concept_id, concept_category, reuse_status
FROM dev_voc_metadata.concept_metadata
ON CONFLICT (concept_id) DO UPDATE
SET 
    concept_category = EXCLUDED.concept_category,
    reuse_status = EXCLUDED.reuse_status;

-- UPSERT for concept_relationship_metadata
INSERT INTO devv5.concept_relationship_metadata (
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
FROM dev_voc_metadata.concept_relationship_metadata
ON CONFLICT (concept_id_1, concept_id_2, relationship_id) DO UPDATE
SET 
    relationship_predicate_id = EXCLUDED.relationship_predicate_id,
    relationship_group = EXCLUDED.relationship_group,
    mapping_source = EXCLUDED.mapping_source,
    confidence = EXCLUDED.confidence,
    mapping_tool = EXCLUDED.mapping_tool,
    mapper = EXCLUDED.mapper,
    reviewer = EXCLUDED.reviewer;

-- reverse links for concept_relationship_metadata
INSERT INTO devv5.concept_relationship_metadata
SELECT 
    rm.concept_id_2, 
    rm.concept_id_1, 
    r.reverse_relationship_id, 
    rm.relationship_predicate_id,
    rm.relationship_group,
    rm.mapping_source,
    rm.confidence,
    rm.mapping_tool,
    rm.mapper,
    rm.reviewer
FROM dev_voc_metadata.concept_relationship_metadata rm
JOIN relationship r ON rm.relationship_id = r.relationship_id;