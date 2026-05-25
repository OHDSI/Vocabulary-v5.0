-- 1. Populate concept_relationship_manual table from a manual lookup (edi_mapped) table
/*CREATE TABLE edi_mapped(
source_concept_code varchar,
source_domain_id varchar,
source_concept_name varchar,
target_concept_id int,
target_concept_code varchar,
target_concept_name varchar,
target_concept_class varchar,
target_domain_id varchar,
target_vocabulary_id varchar,
target_standard_concept varchar,
target_invalid_reason varchar,
valid_start_date date,
valid_end_date date);*/

-- 2. Truncate edi_mapped table and populate with the fresh data:
TRUNCATE TABLE dev_edi.edi_mapped;

-- 3. Add mappings into concept_relationship_manual
INSERT INTO dev_edi.concept_relationship_manual AS mapped
    (concept_code_1,
    concept_code_2,
    vocabulary_id_1,
    vocabulary_id_2,
    relationship_id,
    valid_start_date,
    valid_end_date,
    invalid_reason)

	SELECT source_code,
	       target_concept_code,
	       source_vocabulary_id,
	       target_vocabulary_id,
	       m.relationship_id,
	       current_date AS valid_start_date,
           CASE WHEN m.cr_invalid_reason IS NULL
                  THEN to_date('20991231','yyyymmdd')
                  ELSE current_date END AS valid_end_date,
           m.cr_invalid_reason
	FROM dev_edi.edi_mapped m

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

-- 4. Correction of valid_start_dates and valid_end_dates for deprecation of existing mappings, existing in base, but not manual tables
UPDATE concept_relationship_manual crm
SET valid_start_date = cr.valid_start_date,
    valid_end_date = current_date
FROM edi_mapped m
JOIN concept c
ON c.concept_code = m.source_code AND m.source_vocabulary_id = c.vocabulary_id
JOIN concept_relationship cr
ON cr.concept_id_1 = c.concept_id AND cr.relationship_id = m.relationship_id
JOIN concept c1
ON c1.concept_id = cr.concept_id_2 AND c1.concept_code = m.target_concept_code AND c1.vocabulary_id = m.target_vocabulary_id
WHERE m.cr_invalid_reason IS NOT NULL
AND crm.concept_code_1 = m.source_code AND crm.vocabulary_id_1 = m.source_vocabulary_id
AND crm.concept_code_2 = m.target_concept_code AND crm.vocabulary_id_2 = m.target_vocabulary_id
AND crm.relationship_id = m.relationship_id
AND crm.invalid_reason IS NOT NULL
;
