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
SELECT * FROM dev_ops.concept_relationship_manual_backup_YYYY_MM_DD;*/

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
SELECT * FROM dev_ops.concept_manual_backup_YYYY_MM_DD;*/

-- 7.3.2. Create table ops_delta_translated.
CREATE TABLE dev_ops.ops_delta_translated
(
    concept_name_en varchar (255),
    concept_code varchar (50)
);

-- 7.3.3. Truncate the ops_delta_translated table. Save the spreadsheet as the ops_delta_translated table and upload it into the working schema.
-- /*TRUNCATE TABLE dev_ops.ops_delta_translated;*/

-- 7.3.4. Insert the translation into the concept__manual table.

INSERT INTO dev_ops.concept_manual (concept_name, vocabulary_id, concept_code)
    (SELECT concept_name_en as concept_name,
            'OPS' as vocabulary_id,
            t.concept_code as concept_code
     FROM dev_ops.ops_delta_translated t
        WHERE concept_code
                  NOT IN (SELECT concept_code FROM dev_ops.concept_manual)
    )
;

--8.2.2. Create ops_mapped table and pre-populate it with the resulting manual table of the previous OPS refresh.
--DROP TABLE dev_ops.ops_mapped;
/* CREATE TABLE dev_ops.ops_mapped
(
    id SERIAL PRIMARY KEY,
    source_code_description varchar(255),
    source_code varchar(50),
    source_concept_class_id varchar(50),
    source_invalid_reason varchar(20),
    source_domain_id varchar(50),
    to_value varchar(50),
    source varchar(50),
    target_concept_id int,
    target_concept_code varchar(50),
    target_concept_name varchar(255),
    target_concept_class_id varchar(50),
    target_standard_concept varchar(20),
    target_invalid_reason varchar(20),
    target_domain_id varchar(50),
    target_vocabulary_id varchar(50)
);*/