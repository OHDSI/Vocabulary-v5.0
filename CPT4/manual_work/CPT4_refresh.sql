--1. Backup concept_relationship_manual, concept_synonym_manual table and concept_manual table.
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


--restore concept_relationship_manual table (run it only if something went wrong)
TRUNCATE TABLE dev_cpt4.concept_relationship_manual;
INSERT INTO dev_cpt4.concept_relationship_manual
SELECT * FROM dev_cpt4.concept_relationship_manual_backup_2022_08_12;*/

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
TRUNCATE TABLE dev_cpt4.concept_manual;
INSERT INTO dev_cpt4.concept_manual
SELECT * FROM dev_cpt4.concept_manual_backup_2022_08_12;*/

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

-- 2. insert new concepts into concept_manual table
create table cm_input (concept_name text,domain_id varchar(50), vocabulary_id varchar(50),
                      concept_class_id varchar(50), standard_concept varchar (2), concept_code varchar(50), valid_start_date date, valid_end_date date);
--drop table cm_input;
truncate table cm_input;

insert into concept_manual (concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
(select vocabulary_pack.cutconceptname(concept_name),
    domain_id,
    vocabulary_id,
    concept_class_id,
    null,
    concept_code,
    valid_start_date,
    '2099-12-31',
    null
 from cm_input);

select * from concept_manual where concept_code = '90611';
-- 3. insert new relationship into concept_relationship_manual:
create table crm_input (concept_code_1 varchar(50), concept_code_2 varchar(50),
                        vocabulary_id_1 varchar(50), vocabulary_id_2 varchar(50), relationship_id varchar(10));

insert into concept_relationship_manual (concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
(select concept_code_1,
        concept_code_2,
        vocabulary_id_1,
        vocabulary_id_2,
        relationship_id,
        current_date,
        '2099-12-31',
        null
 from crm_input);

-- 4. insert new synonyms into concept_synonym_manual:
create table synonym_input (synonym_name text, synonym_concept_code varchar(50), synonym_vocabulary_id varchar(50));
--truncate table synonym_input;

select * from concept_synonym_manual;
