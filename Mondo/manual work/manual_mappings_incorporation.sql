-- CDE table prepration
TRUNCATE TABLE dev_mondo.mondo_cde;

-- Run the MONDO mapping pipeline
DO $_$
BEGIN
    PERFORM dev_mondo.InitiateMONDOMappingPipeline();
END $_$;

-- Heuristic preview for mapping candidates that may be eligible for insertion after review.
-- Candidates must be OMOP-compliant and ratified by a MONDO author or steward before insertion.
with tab as (SELECT DISTINCT hm.mondo_code           as source_code,
                             hm.mondo_name           as source_code_description,
                             hm.mondo_omop_domain_id as source_domain_id,
                             hm.lexical_similarity,
                             hm.lex_match_range,
                             hm.sem_match_range,
                             hm.source_consensus_category,
                             hm.semantic_similarity,
                             hm.source_consensus,
                             hm.source_consensus_count,
                             hm.predicate_id,
                             hm.relationship_id,
                             hm.mapping_source,
                             hm.mapping_path,
                             hm.mapping_path_key,
                             hm.maps_to_rn_final,
                             NULL               AS not_omop_compliant,
                             NULL               AS require_attribute_parsing,
                             NULL               AS final_decision_is_made,
                             NULL               AS automap_id_is_changed,
                             c.concept_id       as target_concept_id,
                             hm.target_concept_code,
                             hm.target_concept_name,
                             hm.target_concept_class_id,
                             c.standard_concept as target_standard_concept,
                             c.invalid_reason   as target_invalid_reason,
                             hm.target_domain_id,
                             hm.target_vocabulary_id
             FROM dev_mondo.MONDO_to_omop_mapped hm --table that contains one to one candidates
                      JOIN concept c
                           on split_part(hm.object_id, ':', 2):: int = c.concept_id
             and hm.rate_of_target=1

WHERE NOT exists (SELECT 1
    from concept_relationship_manual crm
    where (crm.concept_code_1
    , crm.vocabulary_id_1)=(hm.mondo_code
    , 'MONDO')
  and crm.relationship_id='Maps to'
    )

  AND NOT exists (SELECT 1
    from concept_relationship_stage crs
    where (crs.concept_code_1
    , crs.vocabulary_id_1)=(hm.mondo_code
    , 'MONDO')
  and crs.relationship_id='Maps to'
    )
 -- AND hm.predicate_id IS NOT NULL
  AND (
    hm.semantic_similarity >= 0.94
    OR (
      hm.lexical_similarity >= 0.7
      AND hm.semantic_similarity >= 0.9
      AND hm.source_consensus::int >= 50
    )
  )
order by  hm.mondo_omop_domain_id, hm.lex_match_range DESC,
    hm.sem_match_range DESC
    )

INSERT INTO concept_relationship_manual (concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)

SELECT distinct source_code as concept_code_1,
       target_concept_code as       concept_code_2,
       'Mondo' as vocabulary_id_1,
       target_vocabulary_id as  vocabulary_id_2,
       relationship_id,
       current_date as valid_start_date,
       to_date('2099-12-31','YYYY-MM-DD') as valid_end_date,
       NULL AS invalid_reason
from tab
;