--1. Create NDC_manual_mapped table and pre-populate it with the resulting manual table of the previous NDC refresh
--DROP TABLE dev_ndc.NDC_manual_mapped;
CREATE TABLE dev_ndc.NDC_manual_mapped (
    id SERIAL PRIMARY KEY,
    source_concept_id int,
    source_code varchar(255),
    source_code_description varchar(1000),
    source_concept_class_id varchar(50),
    source_invalid_reason varchar(20),
    source_domain_id varchar(50),
    source_vocabulary_id varchar(50),
    relationship_id varchar(50),
    cr_invalid_reason varchar(1),
    --flag varchar,
    target_concept_id int,
    target_concept_code varchar(255),
    target_concept_name varchar(255),
    target_concept_class_id varchar(255),
    target_standard_concept varchar(255),
    target_invalid_reason varchar(255),
    target_domain_id varchar(255),
    target_vocabulary_id varchar(255)
);

--Format after uploading
UPDATE dev_ndc.NDC_manual_mapped SET cr_invalid_reason = NULL WHERE cr_invalid_reason = '';
UPDATE dev_ndc.NDC_manual_mapped SET source_invalid_reason = NULL WHERE source_invalid_reason = '';

--Adding constraints for unique records
ALTER TABLE dev_ndc.NDC_manual_mapped ADD CONSTRAINT idx_pk_mapped UNIQUE (source_code,target_concept_code,source_vocabulary_id,target_vocabulary_id,relationship_id);

--2.1. Review the previous mappings and manually add new to the NDC_manual_mapped table.

--2.2. Truncate the NDC_manual_mapped table. Save the spreadsheet as the NDC_manual_mapped table and upload it into the working schema.
TRUNCATE TABLE dev_ndc.NDC_manual_mapped;

--2.3. Perform any mapping checks you have set.

--2.4. Iteratively repeat steps 2.2-2.4 if found any issues.

--2.5. Insert new and update existing relationships according to _mapped table.
INSERT INTO dev_ndc.concept_relationship_manual AS mapped
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
           to_date('20991231','yyyymmdd') AS valid_end_date,
           m.cr_invalid_reason
	FROM dev_ndc.NDC_manual_mapped m
	--Only related to NDC vocabulary
	WHERE (source_vocabulary_id = 'NDC' OR target_vocabulary_id = 'NDC')
	    AND target_concept_id NOT IN (0, 17)

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


--2.6. Correction of valid_start_dates and valid_end_dates for deprecation of existing mappings, existing in base, but not manual tables.
UPDATE concept_relationship_manual crm
SET valid_start_date = cr.valid_start_date,
    valid_end_date = current_date
FROM NDC_manual_mapped m
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