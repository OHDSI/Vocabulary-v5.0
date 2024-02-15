--10.1. Backup concept_relationship_manual table and concept_manual table.
DO
$body$
    DECLARE
        update text;
    BEGIN
        SELECT TO_CHAR(CURRENT_DATE, 'YYYY_MM_DD')
        INTO update;
        EXECUTE FORMAT('create table %I as select * from concept_relationship_manual',
                       'concept_relationship_manual_backup_' || update);

    END
$body$;

--restore concept_relationship_manual table (!!!run it only if something went wrong!!!)
/*TRUNCATE TABLE concept_relationship_manual;
INSERT INTO concept_relationship_manual
SELECT * FROM concept_relationship_manual_backup_YYYY_MM_DD;*/

DO
$body$
    DECLARE
        update text;
    BEGIN
        SELECT TO_CHAR(CURRENT_DATE, 'YYYY_MM_DD')
        INTO update;
        EXECUTE FORMAT('create table %I as select * from concept_manual',
                       'concept_manual_backup_' || update);

    END
$body$;

--restore concept_manual table (run it only if something went wrong)
/*TRUNCATE TABLE concept_manual;
INSERT INTO concept_manual
SELECT * FROM concept_manual_backup_YYYY_MM_DD;*/

--10.2. Create icd10pcs_mapped table and pre-populate it with the resulting manual table of the previous icd10pcs refresh.

DROP TABLE dev_icd10pcs.icd10pcs_mapped;
/*CREATE TABLE dev_icd10pcs.icd10pcs_mapped
(
    id SERIAL PRIMARY KEY,
    source_code_description varchar(255),
    source_code varchar(50),
    source_concept_class_id varchar(50),
    source_invalid_reason varchar(20),
    source_domain_id varchar(50),
    source_vocabulary_id varchar(50),
    relationship_id varchar(50),
    cr_invalid_reason varchar(1),
    source varchar(255),
    target_concept_id int,
    target_concept_code varchar(50),
    target_concept_name varchar(255),
    target_concept_class_id varchar(50),
    target_standard_concept varchar(20),
    target_invalid_reason varchar(20),
    target_domain_id varchar(50),
    target_vocabulary_id varchar(50)
); */

--Adding constraints for unique records
ALTER TABLE dev_icd10pcs.icd10pcs_mapped ADD CONSTRAINT idx_pk_mapped UNIQUE (source_code,target_concept_code,source_vocabulary_id,target_vocabulary_id,relationship_id);

--10.3 Truncate the 'icd10pcs_mapped' table. Save the spreadsheet as the 'icd10pcs_mapped table' and upload it into the working schema.
TRUNCATE TABLE dev_icd10pcs.icd10pcs_mapped;

--Format after uploading
UPDATE dev_icd10pcs.icd10pcs_mapped SET cr_invalid_reason = NULL WHERE cr_invalid_reason = '';
UPDATE dev_icd10pcs.icd10pcs_mapped SET source_invalid_reason = NULL WHERE source_invalid_reason = '';

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

--10.5. Create concept_mapped table and populate it with the resulting manual table of the previous hcpcs refresh
--DROP TABLE concept_mapped;
CREATE TABLE concept_mapped
(
       id SERIAL PRIMARY KEY,
       concept_name varchar (255),
       domain_id varchar (50),
       vocabulary_id varchar (50),
       concept_class_id varchar (50),
       standard_concept varchar (1),
       concept_code varchar (50),
       invalid_reason varchar(1)
);

--Adding constraints for unique records
ALTER TABLE dev_icd10pcs.concept_mapped ADD CONSTRAINT idx_pk_manual_concepts UNIQUE (concept_code, vocabulary_id);

--10.6. Truncate the 'concept_mapped' table. Save the spreadsheet as the 'concept_mapped table' and upload it into the working schema.
TRUNCATE TABLE concept_mapped;

--10.7. Format after uploading
UPDATE concept_mapped SET concept_name = NULL WHERE concept_name = '';
UPDATE concept_mapped SET domain_id = NULL WHERE domain_id = '';
UPDATE concept_mapped SET concept_class_id = NULL WHERE concept_class_id = '';
UPDATE concept_mapped SET standard_concept = NULL WHERE standard_concept = '';
UPDATE concept_mapped SET invalid_reason = NULL WHERE invalid_reason = '';

--10.8.Change concept_manual table according to concept_mapped table
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
       NULL as valid_start_date,
       NULL AS valid_end_date,
       invalid_reason
FROM concept_mapped

	ON CONFLICT ON CONSTRAINT unique_manual_concepts
	DO UPDATE
	SET concept_name = excluded.concept_name,
	    domain_id = excluded.domain_id,
	    standard_concept = excluded.standard_concept,
	    valid_start_date = cm.valid_start_date,
	    valid_end_date = cm.valid_end_date,
	    invalid_reason = excluded.invalid_reason
WHERE ROW (cm.concept_name, cm.domain_id, cm.standard_concept, cm.invalid_reason)
	IS DISTINCT FROM
	ROW (excluded.concept_name, excluded.domain_id, excluded.standard_concept, excluded.invalid_reason);
