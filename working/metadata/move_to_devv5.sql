/*
    Move metadata to the devv5 metadata tables
*/

-- concept_metadata
INSERT INTO devv5.concept_metadata 
SELECT * FROM dev_test4.concept_metadata;

-- concept_relationship_metadata
INSERT INTO devv5.concept_relationship_metadata 
SELECT * FROM dev_test4.concept_relationship_metadata;

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
FROM dev_test4.concept_relationship_metadata rm
JOIN relationship r ON rm.relationship_id = r.relationship_id;