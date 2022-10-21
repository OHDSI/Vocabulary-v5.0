--7.3.1. Backup concept_relationship_manual table and concept_manual table.
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
/*TRUNCATE TABLE dev_ops.concept_relationship_manual;
INSERT INTO dev_ops.concept_relationship_manual
SELECT * FROM dev_ops.concept_relationship_manual_backup_2022_09_09;*/

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
/*TRUNCATE TABLE dev_ops.concept_manual;
INSERT INTO dev_ops.concept_manual
SELECT * FROM dev_ops.concept_manual_backup_2022_09_09;*/

-- 7.3.2. Create table ops_delta_translated
--DROP TABLE dev_ops.ops_delta_translated;
/*CREATE TABLE dev_ops.ops_delta_translated
(
    concept_name_en varchar (255),
    concept_code varchar (50)
);*/

-- 7.3.3. Truncate the ops_delta_translated table. Save the spreadsheet as the ops_delta_translated table and upload it into the working schema.
-- /*TRUNCATE TABLE dev_ops.ops_delta_translated;*/

-- 7.3.4. Insert the manual translation into the concept_manual table.
INSERT INTO dev_ops.concept_manual (concept_name, vocabulary_id, concept_code, invalid_reason)
    (SELECT concept_name_en as concept_name,
            'OPS' as vocabulary_id,
            t.concept_code as concept_code,
            'X' as invalid_reason
     FROM dev_ops.ops_delta_translated t
        WHERE concept_code
                  NOT IN (SELECT concept_code FROM dev_ops.concept_manual)
    )
;

-- 7.3.5. Insert the automated translation in concept_manual table (2022 temporary solution for translation of the new codes, missing from delta)
/*DROP TABLE IF EXISTS ops_translation_auto;

CREATE TABLE ops_translation_auto AS
SELECT synonym_concept_code AS concept_code,
    synonym_name AS german_term,
	NULL::TEXT AS english_term
FROM dev_ops.concept_synonym_stage
WHERE language_concept_id = 4182504
  and synonym_concept_code in (select concept_code from dev_ops.concept_stage where concept_name like 'Placeholder%');

SELECT * FROM ops_translation_auto;

DO $_$
BEGIN
	PERFORM devv5.GTranslate(
		pInputTable    =>'ops_translation_auto',
		pInputField    =>'german_term',
		pOutputField   =>'english_term',
		pDestLang      =>'en'
	);
END $_$;*/

INSERT INTO dev_ops.concept_manual (concept_name, vocabulary_id, concept_code, invalid_reason)
    (SELECT vocabulary_pack.CutConceptName(english_term) as concept_name,
            'OPS' as vocabulary_id,
            t.concept_code as concept_code,
            'X' as invalid_reason
     FROM dev_ops.ops_translation_auto t
        WHERE concept_code
                  NOT IN (SELECT concept_code FROM dev_ops.concept_manual)
    )
;

--7.3.6. Create ops_mapped table and pre-populate it with the resulting manual table of the previous OPS refresh.
--DROP TABLE dev_ops.ops_mapped;
/*CREATE TABLE dev_ops.ops_mapped
(
    id SERIAL PRIMARY KEY,
    source_code_description varchar(255),
    source_code varchar(255),
    source_concept_class_id varchar(255),
    source_invalid_reason varchar(20),
    source_domain_id varchar(255),
    to_value varchar(255),
    target_concept_id int,
    target_concept_code varchar(255),
    target_concept_name varchar(255),
    target_concept_class_id varchar(255),
    target_standard_concept varchar(20),
    target_invalid_reason varchar(20),
    target_domain_id varchar(255),
    target_vocabulary_id varchar(255)
);*/

--7.3.9 Truncate the ops_mapped table. Save the spreadsheet as the ops_mapped table and upload it into the working schema.
--TRUNCATE TABLE dev_ops.ops_mapped;

--7.3.10 Deprecate updated relationships in CRM

--7.3.13 Insert new and corrected mappings into the concept_relationship_manual table.
with mapping AS
    (
        SELECT DISTINCT source_code AS concept_code_1,
               target_concept_code AS concept_code_2,
               'ops' AS vocabulary_id_1,
               target_vocabulary_id AS vocabulary_id_2,
               CASE WHEN to_value ~* 'value' THEN 'Maps to value'
                    WHEN to_value ~* 'Is a' THEN 'Is a'
                    WHEN to_value ~* 'Subsumes' THEN 'Subsumes'
                   ELSE 'Maps to' END AS relationship_id,
               current_date AS valid_start_date,
               to_date('20991231','yyyymmdd') AS valid_end_date,
               NULL AS invalid_reason
        FROM dev_ops.ops_mapped
        WHERE target_concept_id != 0
    )

INSERT INTO dev_ops.concept_relationship_manual(concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
    (SELECT concept_code_1,
            concept_code_2,
            vocabulary_id_1,
            vocabulary_id_2,
            relationship_id,
            valid_start_date,
            valid_end_date,
            invalid_reason
     FROM mapping m
        WHERE (concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id)
                  NOT IN (SELECT concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id FROM dev_ops.concept_relationship_manual)
    )
;

--7.3.14 Activate mapping, that became valid again
UPDATE concept_relationship_manual crm
SET invalid_reason = null,
    valid_end_date = to_date('20991231','yyyymmdd'),
    valid_start_date =current_date

--SELECT * FROM concept_relationship_manual crm --use this SELECT for QA
WHERE invalid_reason = 'D' -- activate only deprecated mappings
AND EXISTS(SELECT 1 -- activate mapping if the same exists in the current manual file
           FROM dev_ops.ops_mapped crm_new
           WHERE crm_new.source_code = crm.concept_code_1           --the same source_code is mapped
             AND crm_new.target_concept_code = crm.concept_code_2   --to the same concept_code
             AND crm_new.target_vocabulary_id = crm.vocabulary_id_2 --of the same vocabulary
             AND crm_new.to_value = crm.relationship_id --with the same relationship
            )
;