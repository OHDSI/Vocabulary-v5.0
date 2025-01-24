--10.1. Create icd10pcs_mapped table and pre-populate it with the resulting manual table of the previous icd10pcs refresh.

--DROP TABLE dev_icd10pcs.icd10pcs_mapped;
CREATE TABLE dev_icd10pcs.icd10pcs_mapped
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
);

--Adding constraints for unique records
ALTER TABLE dev_icd10pcs.icd10pcs_mapped ADD CONSTRAINT idx_pk_mapped UNIQUE (source_code,target_concept_code,source_vocabulary_id,target_vocabulary_id,relationship_id);

--10.3 Truncate the 'icd10pcs_mapped' table. Save the spreadsheet as the 'icd10pcs_mapped table' and upload it into the working schema.
TRUNCATE TABLE dev_icd10pcs.icd10pcs_mapped;

--Format after uploading
UPDATE dev_icd10pcs.icd10pcs_mapped SET cr_invalid_reason = NULL WHERE cr_invalid_reason = '';
UPDATE dev_icd10pcs.icd10pcs_mapped SET source_invalid_reason = NULL WHERE source_invalid_reason = '';
--UPDATE dev_icd10pcs.icd10pcs_mapped SET mapping_tool = NULL WHERE mapping_tool = '';
--UPDATE dev_icd10pcs.icd10pcs_mapped SET mapping_source = NULL WHERE mapping_source = '';
--UPDATE dev_icd10pcs.icd10pcs_mapped SET confidence = NULL WHERE confidence = '';
--UPDATE dev_icd10pcs.icd10pcs_mapped SET relationship_id_predicate = NULL WHERE relationship_id_predicate = '';
--UPDATE dev_icd10pcs.icd10pcs_mapped SET mapper_id = NULL WHERE mapper_id = '';
--UPDATE dev_icd10pcs.icd10pcs_mapped SET reviewer_id = NULL WHERE reviewer_id = '';

--10.4 Change concept_relationship_manual table according to icd10pcs_mapped table.
--Insert new relationships
--Update existing relationships
INSERT INTO dev_icd10pcs.concept_relationship_manual AS mapped
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
	FROM dev_icd10pcs.icd10pcs_mapped m
	--Only related to icd10pcs vocabulary
	WHERE (source_vocabulary_id = 'ICD10PCS' OR target_vocabulary_id = 'ICD10PCS')
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
FROM icd10pcs_mapped m
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

--5.2.7 Create concept_mapped table and populate it with the resulting manual table of the previous CPT4 refresh
--DROP TABLE dev_icd10pcs.concept_mapped;
CREATE TABLE concept_mapped
(
       id SERIAL PRIMARY KEY,
	   concept_name varchar(255),
	   domain_id varchar(50),
	   vocabulary_id varchar(50),
	   concept_class_id varchar(50),
	   standard_concept varchar(10),
	   valid_start_date date,
	   valid_end_date date,
	   concept_code varchar(50)
  );

--Adding constraints for unique records
ALTER TABLE dev_icd10pcs.concept_mapped ADD CONSTRAINT idx_pk_concept UNIQUE (concept_code, vocabulary_id);

-- 5.2.8 Truncate cm_update table. Save the spreadsheet as 'concept_mapped table' and upload it to the schema:
TRUNCATE TABLE concept_mapped;

--Format after uploading:
UPDATE concept_mapped SET concept_name = NULL WHERE concept_name = '';
UPDATE concept_mapped SET domain_id = NULL WHERE domain_id = '';
UPDATE concept_mapped SET concept_class_id = NULL WHERE concept_class_id = '';
UPDATE concept_mapped SET standard_concept = NULL WHERE standard_concept = '';

-- 5.2.9 Change concept_manual table according to concept_mapped table.
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
       coalesce(valid_start_date, null) as valid_start_date,
       coalesce(valid_end_date, null) as valid_end_date,
       CASE WHEN valid_end_date = '2099-12-31' THEN NULL
	   END AS invalid_reason
FROM dev_icd10pcs.concept_mapped

	ON CONFLICT ON CONSTRAINT unique_manual_concepts
	DO UPDATE
	SET concept_name = excluded.concept_name,
	    domain_id = excluded.domain_id,
	    standard_concept = excluded.standard_concept
WHERE ROW (cm.concept_name, cm.domain_id, cm.standard_concept)
	IS DISTINCT FROM
	ROW (excluded.concept_name, excluded.domain_id, excluded.standard_concept);