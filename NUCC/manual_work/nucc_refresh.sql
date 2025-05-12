--5.2.1. Create nucc_mapped table and pre-populate it with the resulting manual table of the previous nucc refresh.
/*
DROP TABLE dev_nucc.nucc_mapped;
CREATE TABLE dev_nucc.nucc_mapped
(
    id SERIAL PRIMARY KEY,
    source_code_description varchar(255),
    source_code varchar(50),
    source_concept_class_id varchar(50),
    source_invalid_reason varchar(20),
    source_domain_id varchar(50),
    source_vocabulary_id varchar(50),
	cr_invalid_reason varchar(1),
	mapping_tool varchar(255),
	mapping_source varchar(255),
	confidence varchar(5),
    relationship_id varchar(50),
    relationship_id_predicate varchar(10),
    source varchar(255),
	comments varchar(255),
    target_concept_id int,
    target_concept_code varchar(50),
    target_concept_name varchar(255),
    target_concept_class_id varchar(50),
    target_standard_concept varchar(20),
    target_invalid_reason varchar(20),
    target_domain_id varchar(50),
    target_vocabulary_id varchar(50),
	mapper_id varchar(10),
	reviewer_id varchar(10)
);*/

--Adding constraints for unique records
ALTER TABLE dev_nucc.nucc_mapped ADD CONSTRAINT idx_pk_mapped UNIQUE (source_code,target_concept_code,source_vocabulary_id,target_vocabulary_id,relationship_id);

--5.2.2. Review the previous mapping and map new concepts. If previous mapping should be changed or deprecated, use cr_invalid_reason field.

--5.2.3. Select concepts to map and add them to the manual file in the spreadsheet editor.

--5.2.4. Truncate the nucc_mapped table. Save the spreadsheet as the nucc_mapped table and upload it into the working schema.
TRUNCATE TABLE dev_nucc.nucc_mapped;

--Format after uploading
UPDATE dev_nucc.nucc_mapped SET mapping_tool = NULL WHERE mapping_tool = '';
UPDATE dev_nucc.nucc_mapped SET mapping_source = NULL WHERE mapping_source = '';
UPDATE dev_nucc.nucc_mapped SET confidence = NULL WHERE confidence = '';
UPDATE dev_nucc.nucc_mapped SET relationship_id_predicate = NULL WHERE relationship_id_predicate = '';
UPDATE dev_nucc.nucc_mapped SET cr_invalid_reason = NULL WHERE cr_invalid_reason = '';
UPDATE dev_nucc.nucc_mapped SET source_invalid_reason = NULL WHERE source_invalid_reason = '';
UPDATE dev_nucc.nucc_mapped SET mapper_id = NULL WHERE mapper_id = '';
UPDATE dev_nucc.nucc_mapped SET reviewer_id = NULL WHERE reviewer_id = '';

--5.2.5. Perform any mapping checks you have set.

--5.2.6. Iteratively repeat steps 5.2.2-5.2.5 if found any issues.

--5.2.7 Change concept_relationship_manual table according to nucc_mapped table.
--Insert new relationships
--Update existing relationships
INSERT INTO dev_nucc.concept_relationship_manual AS mapped
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
	FROM dev_nucc.nucc_mapped m
	--Only related to nucc vocabulary
	WHERE (source_vocabulary_id = 'nucc' OR target_vocabulary_id = 'nucc')
	    AND (target_concept_id != 0 OR target_concept_id IS NULL)

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
FROM nucc_mapped m
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

-- 5.2.8 Create table concept_mapped table and pre-populate it with the resulting manual table of the previous nucc refresh.
/*drop table concept_mapped;
CREATE TABLE concept_mapped
(
       id SERIAL PRIMARY KEY,
	   concept_name varchar(255),
	   domain_id varchar(50),
	   vocabulary_id varchar(50),
	   concept_class_id varchar(50),
	   standard_concept varchar(10),
	   concept_code varchar(50),
       valid_start_date date,
       valid_end_date date,
       invalid_reason varchar(10)
  );*/

-- 5.2.9 Truncate concept_mapped table. Save the spreadsheet as 'concept_mapped table' and upload it to the schema:
TRUNCATE TABLE concept_mapped;

--Format after uploading:
UPDATE concept_mapped SET concept_name = NULL WHERE concept_name = '';
UPDATE concept_mapped SET domain_id = NULL WHERE domain_id = '';
UPDATE concept_mapped SET concept_class_id = NULL WHERE concept_class_id = '';
UPDATE concept_mapped SET standard_concept = NULL WHERE standard_concept = '';
UPDATE concept_mapped SET valid_start_date = NULL WHERE standard_concept = '';

--5.2.10 Change concept_manual table according to concept_mapped table.
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
       'X'
FROM dev_nucc.concept_mapped

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
	ROW (excluded.concept_name, excluded.domain_id, excluded.standard_concept, excluded.valid_start_date, excluded.valid_end_date, excluded.invalid_reason);