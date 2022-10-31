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
/*TRUNCATE TABLE dev_cpt4.concept_relationship_manual;
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
/*TRUNCATE TABLE dev_cpt4.concept_manual;
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
    null,
    null,
    'X'
 from cm_input);

select * from concept_manual where concept_code = '0124A';
-- 3. insert new relationship into concept_relationship_manual:
select * from concept_relationship_manual
where concept_code_1 = '0072A';

-- 4. insert new synonyms into concept_synonym_manual:

select * from concept_synonym_manual;

select * from concept_manual;
