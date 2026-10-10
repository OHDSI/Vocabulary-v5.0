/*
================================================================================
1- prepare tables for Cancer Modifier Univeral Load Stage-style process (manual tables part)
================================================================================
================================================================================
*/


--change concept_manual table according to concept_mapped table.
INSERT INTO concept_manual AS cm
(concept_name,
 domain_id,
 vocabulary_id,
 concept_class_id,
 standard_concept,
 concept_code,
 valid_start_date,
 valid_end_date,
 invalid_reason)
SELECT concept_name,
       domain_id,
       vocabulary_id,
       concept_class_id,
       standard_concept,
       concept_code,
       valid_start_date,
       valid_end_date,
       invalid_reason
FROM dev_cancer_modifier.concept_manual_refresh

	ON CONFLICT ON CONSTRAINT unique_manual_concepts
	DO UPDATE
	SET concept_name = excluded.concept_name,
	    domain_id = excluded.domain_id,
	    standard_concept = excluded.standard_concept,
		valid_start_date = CASE WHEN excluded.valid_start_date IS NOT NULL THEN excluded.valid_start_date ELSE cm.valid_start_date END,
		valid_end_date = CASE WHEN excluded.valid_end_date IS NOT NULL THEN excluded.valid_end_date ELSE cm.valid_end_date END,
		invalid_reason = excluded.invalid_reason
WHERE ROW (cm.concept_name, cm.domain_id, cm.standard_concept, cm.valid_start_date, cm.valid_end_date, cm.invalid_reason)
	IS DISTINCT FROM
	ROW (excluded.concept_name, excluded.domain_id, excluded.standard_concept, excluded.valid_start_date, excluded.valid_end_date, excluded.invalid_reason)
;






--Synonyms manual population
INSERT INTO concept_synonym_manual (synonym_name, synonym_concept_code, synonym_vocabulary_id, language_concept_id)
SELECT synonym_name, synonym_concept_code, synonym_vocabulary_id, language_concept_id
FROM concept_synonym_manual_refresh csmr
;


--Insert new relationships
--Update existing relationships
INSERT INTO dev_cancer_modifier.concept_relationship_manual AS mapped
    (concept_code_1,
    concept_code_2,
    vocabulary_id_1,
    vocabulary_id_2,
    relationship_id,
    valid_start_date,
    valid_end_date,
    invalid_reason)

	SELECT concept_code_1,
	       concept_code_2,
	       vocabulary_id_1,
	       vocabulary_id_2,
	       m.relationship_id,
	       current_date-1 AS valid_start_date,
           CASE WHEN m.invalid_reason IS NULL
                  THEN to_date('20991231','yyyymmdd')
                  ELSE current_date END AS valid_end_date,
           m.invalid_reason
	FROM dev_cancer_modifier.concept_relationship_manual_refresh m
	--Only related to Cancer-Modifier orchestrated vocabularies vocabulary
	WHERE (vocabulary_id_1 IN ('Cancer Modifier','OMOP Genomic') OR vocabulary_id_2 IN ('Cancer Modifier','OMOP Genomic'))

	ON CONFLICT ON CONSTRAINT unique_manual_relationships
	DO UPDATE
	    --In case of mapping 'resuscitation' use current_date as valid_start_date; in case of mapping deprecation use previous valid_start_date
	SET valid_start_date = CASE WHEN excluded.invalid_reason IS NULL THEN excluded.valid_start_date ELSE mapped.valid_start_date END,
	    --In case of mapping 'resuscitation' use 2099-12-31 as valid_end_date; in case of mapping deprecation use current_date
		valid_end_date = CASE WHEN excluded.invalid_reason IS NULL THEN excluded.valid_end_date ELSE current_date END,
		invalid_reason = excluded.invalid_reason
	WHERE ROW (mapped.invalid_reason)
	IS DISTINCT FROM
	ROW (excluded.invalid_reason);

--Correction of valid_start_dates and valid_end_dates for deprecation of existing mappings, existing in base, but not manual tables
UPDATE concept_relationship_manual crm
SET valid_start_date = cr.valid_start_date,
    valid_end_date = current_date
FROM dev_cancer_modifier.concept_relationship_manual_refresh m
JOIN concept c
ON c.concept_code = m.concept_code_1 AND m.vocabulary_id_1 = c.vocabulary_id
JOIN concept_relationship cr
ON cr.concept_id_1 = c.concept_id AND cr.relationship_id = m.relationship_id
JOIN concept c1
ON c1.concept_id = cr.concept_id_2 AND c1.concept_code = m.concept_code_2 AND c1.vocabulary_id = m.vocabulary_id_2
WHERE m.invalid_reason IS NOT NULL
AND crm.concept_code_1 = m.concept_code_1 AND crm.vocabulary_id_1 = m.vocabulary_id_1
AND crm.concept_code_2 = m.concept_code_2 AND crm.vocabulary_id_2 = m.vocabulary_id_2
AND crm.relationship_id = m.relationship_id
AND crm.invalid_reason IS NOT NULL
;

