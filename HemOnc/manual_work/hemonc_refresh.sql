--4.2.1. Create hemonc_mapped table and pre-populate it with the resulting manual table of the previous hemonc refresh.

--DROP TABLE dev_hemonc.hemonc_mapped;
CREATE TABLE dev_hemonc.hemonc_mapped
(
    id SERIAL PRIMARY KEY,
    concept_code_1 varchar(50),
    concept_code_2 varchar(50),
    vocabulary_id_1 varchar(50),
    vocabulary_id_2 varchar(50),
    relationship_id varchar(50),
    valid_start_date date,
    valid_end_date date,
    invalid_reason varchar (10)
);

--Adding constraints for unique records
ALTER TABLE dev_hemonc.hemonc_mapped ADD CONSTRAINT idx_pk_mapped UNIQUE (source_code,target_concept_code,source_vocabulary_id,target_vocabulary_id,relationship_id);

--4.2.2. Truncate the hemonc_mapped table. Save the spreadsheet as the hemonc_mapped table and upload it into the working schema.
TRUNCATE TABLE dev_hemonc.hemonc_mapped;

--4.2.3. Perform any mapping checks you have set.

--4.2.4. Iteratively repeat steps 4.2.2-4.2.4 if found any issues.

--4.2.5 Change concept_relationship_manual table according to hemonc_mapped table.
--Insert new relationships
--Update existing relationships
INSERT INTO dev_hemonc.concept_relationship_manual AS mapped
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
	       relationship_id,
	       valid_start_date,
           valid_end_date,
           invalid_reason
	FROM dev_hemonc.hemonc_mapped m
	--Only related to hemonc vocabulary

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
    FROM hemonc_mapped m
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
