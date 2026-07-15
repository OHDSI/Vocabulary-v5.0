--Metadata population via staging
INSERT INTO concept_relationship_metadata (concept_id_1, concept_id_2, relationship_id, relationship_predicate_id,
                                           mapping_source, confidence, mapping_tool, mapper)

SELECT c.concept_id,
       cc.concept_id,
       crmts.relationship_id,
       crmts.relationship_predicate_id,
       crmts.mapping_source,
       crmts.mapping_tool,
       'Thesaurus Health' as mapper
FROM dev_hpo.concept_relationship_metadata_stage crmts
         JOIN concept c
              on (c.concept_code, c.vocabulary_id) = (crmts.concept_code_1, crmts.vocabulary_id_1)
         JOIN concept cc
              on (cc.concept_code, cc.vocabulary_id) = (crmts.concept_code_2, crmts.vocabulary_id_2)
AND EXISTS (
    SELECT 1
    from concept_relationship cr
    where cr.concept_id_1=c.concept_id
    and cr.relationship_id=crmts.relationship_id
    and cr.concept_id_2=cc.concept_id
    and cr.invalid_reason is null
                  )
;
