--Semantic mapping update
TRUNCATE dev_hpo.hpo_cde;

--  Run InitiateMappingPipeline script
DO $_$
BEGIN
    PERFORM dev_hpo.InitiateHPOMappingPipeline();
END $_$;


-- PUT HERE SOME HEURISTIC TO ISOLATE MAPPING CANDIDATES CAPABLE TO BE INSERTED w/o review
-- Should be OMOP-compliant and ratified by HPO-author/steward
with tab as (SELECT DISTINCT hpo_code           as source_code,
                             hpo_name           as source_code_desription,
                             hpo_omop_domain_id as source_domain_id,
                             lexical_similarity,
                             lex_match_range,
                             sem_match_range,
                             source_concensus_category,
                             semantic_similarity,
                             source_consensus,
                             source_consensus_nar,
                             predicate_id,
                             relationship_id,
                             NULL               AS not_omop_compliant,
                             NULL               AS require_attribute_parsing,
                             NULL               AS final_decision_is_made,
                             NULL               AS automap_id_is_changed,
                             c.concept_id       as target_concept_id,
                             target_concept_code,
                             target_concept_name,
                             target_concept_class_id,
                             c.standard_concept as target_standard_concept,
                             c.invalid_reason   as target_invalid_reason,
                             target_domain_id,
                             target_vocabulary_id
             FROM dev_hpo.hpo_to_omop_mapped hm --table that contains one to one candidates
                      JOIN concept c
                           on split_part(object_id, ':', 2):: int = c.concept_id
             and hm.rate_of_target=1

WHERE NOT exists (SELECT 1
    from concept_relationship_manual crm
    where (crm.concept_code_1
    , crm.vocabulary_id_1)=(hm.hpo_code
    , 'HPO')
  and crm.relationship_id='Maps to'
    )

  AND NOT exists (SELECT 1
    from concept_relationship_stage crs
    where (crs.concept_code_1
    , crs.vocabulary_id_1)=(hm.hpo_code
    , 'HPO')
  and crs.relationship_id='Maps to'
    )
  AND hm.predicate_id IS NOT NULL
  and hm.lexical_similarity>=0.7
  and hm.semantic_similarity>=0.9
  and hm.source_consensus:: int >=50
order by hpo_omop_domain_id, lex_match_range DESC,
    sem_match_range DESC
    )

INSERT INTO hpo_mapped (source_code, source_domain_id, source_vocabulary_id,
                  mapping_tool, mapping_source, confidence, relationship_id,
                 relationship_id_predicate,   target_concept_id, target_concept_code,
                 target_concept_name, target_concept_class_id, target_standard_concept, target_invalid_reason,
                 target_domain_id, target_vocabulary_id, mapper_id, reviewer_id)


SELECT distinct source_code,
                source_domain_id,
                'HPO'                                                       as source_vocabulary_id,
                'AM-tool_U'                                                 as mapping_tool,
                'Machine-produced mappings with spot-curation'              as mapping_source,
                round(coalesce(semantic_similarity::numeric, lexical_similarity::numeric)::numeric, 2) as confidence,
                relationship_id,
                predicate_id,
                target_concept_id,
                target_concept_code,
                target_concept_name,
                target_concept_class_id,
                target_standard_concept,
                target_invalid_reason,
                target_domain_id,
                target_vocabulary_id,
                'Thesaurus Health',
                'Thesaurus Health'


from tab t
WHERE NOT EXISTS (SELECT 1
                  from concept_relationship_manual crmx
                  where crmx.concept_code_1=t.source_code
                  and crmx.relationship_id IN ('Maps to','Maps to value')
                  and crmx.vocabulary_id_1='HPO'
                  and crmx.invalid_reason is null
                  )
and NOT EXISTS (SELECT 1
                  from concept_relationship  crmx
                  JOIN concept  cx
                  on cx.concept_id=crmx.concept_id_1
                   and cx.vocabulary_id='HPO'
                  where cx.concept_code=t.source_code
                  and crmx.relationship_id IN ('Maps to','Maps to value')
                   and cx.vocabulary_id='HPO'
                   and crmx.invalid_reason is null
                  )

AND NOT EXISTS (SELECT 1
                  from concept_relationship_stage crmx
                  where crmx.concept_code_1=t.source_code
                  and crmx.relationship_id IN ('Maps to','Maps to value')
                  and crmx.vocabulary_id_1='HPO'
                  and crmx.invalid_reason is null
                  )
;