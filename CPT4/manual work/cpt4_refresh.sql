--9.2.1. Backup concept_manual table and concept_synonym_manual to save any implemented changes.

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
/*TRUNCATE TABLE dev_cpt4.concept_manual;
INSERT INTO dev_cpt4.concept_manual
SELECT * FROM dev_cpt4.concept_manual_backup_YYYY_MM_DD;*/

DO
$body$
    DECLARE
        update text;
    BEGIN
        SELECT TO_CHAR(CURRENT_DATE, 'YYYY_MM_DD')
        INTO update;
        EXECUTE FORMAT('create table %I as select * from concept_synonym_manual',
                       'concept_synonym_manual_backup_' || update);

    END
$body$;

--restore concept_synonym_manual table (run it only if something went wrong)
/*TRUNCATE TABLE dev_cpt4.concept_synonym_manual;
INSERT INTO dev_cpt4.concept_synonym_manual
SELECT * FROM dev_cpt4.concept_synonym_manual_backup_YYYY_MM_DD;*/

--9.2.2 Create cpt4_mapped table and pre-populate it with the resulting manual table of the previous CPT4 refresh.

/*DROP TABLE dev_cpt4.cpt4_mapped;
CREATE TABLE dev_cpt4.cpt4_mapped
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
ALTER TABLE dev_cpt4.cpt4_mapped ADD CONSTRAINT idx_pk_mapped UNIQUE (source_code,target_concept_code,source_vocabulary_id,target_vocabulary_id,relationship_id);

--9.2.3 Truncate the 'cpt4_mapped' table. Save the spreadsheet as the 'cpt4_mapped table' and upload it into the working schema.
TRUNCATE TABLE dev_cpt4.cpt4_mapped;

--Format after uploading
UPDATE dev_cpt4.cpt4_mapped SET cr_invalid_reason = NULL WHERE cr_invalid_reason = '';
UPDATE dev_cpt4.cpt4_mapped SET source_invalid_reason = NULL WHERE source_invalid_reason = '';

--9.2.4 Change concept_relationship_manual table according to cpt4_mapped table.
--Insert new relationships
--Update existing relationships
INSERT INTO dev_cpt4.concept_relationship_manual AS mapped
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
	FROM dev_cpt4.cpt4_mapped m
	--Only related to cpt4 vocabulary
	WHERE (source_vocabulary_id = 'CPT4' OR target_vocabulary_id = 'CPT4')
	    AND target_concept_id != 0

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
FROM cpt4_mapped m
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