--Metadata population via staging
INSERT INTO concept_relationship_metadata (concept_id_1, concept_id_2, relationship_id, relationship_predicate_id,
                                           mapping_source, confidence, mapping_tool, mapper,reviewer)

SELECT c.concept_id,
       cc.concept_id,
       crmts.relationship_id,
       crmts.relationship_id_predicate as relationship_predicate_id,
       crmts.mapping_source,
       crmts.confidence,
       crmts.mapping_tool,
       crmts.mapper_id as  mapper,
       crmts.reviewer_id as reviewer
FROM dev_hpo.hpo_mapped crmts
         JOIN concept c
              on (c.concept_code, c.vocabulary_id) = (crmts.source_code, crmts.source_vocabulary_id)
         JOIN concept cc
              on (cc.concept_code, cc.vocabulary_id) = (crmts.target_concept_code, crmts.target_vocabulary_id)
AND EXISTS (
    SELECT 1
    from concept_relationship cr
    where cr.concept_id_1=c.concept_id
    and cr.relationship_id=crmts.relationship_id
    and cr.concept_id_2=cc.concept_id
    and cr.invalid_reason is null
                  )
;
