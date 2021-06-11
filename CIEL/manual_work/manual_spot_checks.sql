--  After full QA and generic update do some spot check tests for a quick manual plausibility check:
-- assumes that the schema "dev_ciel" is used
-- check validity of mappings (per domain, uncomment the respective one in question)
SELECT c.concept_id, c.concept_code, c.concept_name, c.invalid_reason, cr.relationship_id, c2.concept_id, c2.vocabulary_id, c2.concept_name, c2.invalid_reason 
   FROM dev_ciel.CONCEPT c 
   inner join dev_ciel.concept_relationship cr
    ON c.concept_id = cr.concept_id_1
   left join  dev_ciel.concept c2
    ON c2.concept_id = cr.concept_id_2
    WHERE c.vocabulary_id = 'CIEL'
    -- AND c.domain_id = 'Condition'
    -- AND c.domain_id = 'Device'
    -- AND c.domain_id = 'Drug'
    -- AND c.domain_id = 'Measurement'
     AND c.domain_id = 'Observation' 
    -- AND c.domain_id = 'Procedure'
    -- AND c.domain_id = 'Spec Anatomic Site'
    -- AND c.domain_id = 'Specimen'
    -- AND c.domain_id = 'Unit'
     LIMIT 200 ;
	 
-- Check Synonyms
SELECT c.concept_code, c.concept_name AS Name, cs.concept_synonym_name AS SynName, c2.concept_name AS Lang
   FROM dev_ciel.CONCEPT c 
   inner join dev_ciel.concept_synonym cs
    ON c.concept_id = cs.concept_id
   left join  dev_ciel.concept c2
    ON c2.concept_id = cs.language_concept_id
    WHERE c.vocabulary_id = 'CIEL'
    -- AND c.domain_id = 'Condition'
    -- AND c.domain_id = 'Device'
    -- AND c.domain_id = 'Drug'
    -- AND c.domain_id = 'Measurement'
     AND c.domain_id = 'Observation' 
    -- AND c.domain_id = 'Procedure'
    -- AND c.domain_id = 'Spec Anatomic Site'
    -- AND c.domain_id = 'Specimen'
    -- AND c.domain_id = 'Unit'
     LIMIT 200 ;
	 
-- find relationships involving different domains (sample of 200)
SELECT c.concept_id, c.concept_code, c.domain_id, c.concept_class_id, c.concept_name, c.invalid_reason, cr.relationship_id, c2.concept_id, c2.vocabulary_id, c2.domain_id, c2.concept_class_id, c2.concept_name, c2.invalid_reason 
   FROM dev_ciel.CONCEPT c 
   inner join dev_ciel.concept_relationship cr
    ON c.concept_id = cr.concept_id_1
   left join  dev_ciel.concept c2
    ON c2.concept_id = cr.concept_id_2
    WHERE c.vocabulary_id = 'CIEL'
     AND c.domain_id <> c2.domain_id
     LIMIT 200 ;