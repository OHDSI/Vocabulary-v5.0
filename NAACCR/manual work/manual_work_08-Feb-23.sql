--concept_relationship_manual_backup_2023_02_08;
DO
$body$
    DECLARE
        update text;
    BEGIN
        SELECT TO_CHAR(CURRENT_DATE, 'YYYY_MM_DD')
        INTO update;
        EXECUTE format('create table %I as select * from concept_relationship_manual',
                       'concept_relationship_manual_backup_' || update);

    END
$body$;

SELECT count(*) FROM concept_relationship_manual_backup_2023_02_08;

--concept_manual_backup_2023_02_08;
DO
$body$
    DECLARE
        update text;
    BEGIN
        SELECT TO_CHAR(CURRENT_DATE, 'YYYY_MM_DD')
        INTO update;
        EXECUTE format('create table %I as select * from concept_manual',
                       'concept_manual_backup_' || update);

    END
$body$;

--Perform backup checks in checks. sql
--the counts in backups and _manuals should be identical

--Manual table population

--concept_manual population steps
-- In the vast majority of cases we don not expect to have any new NAACCR codes to be ingested. However some of lost codes may become a part of future releases
--When NEW codes to be ingested design the DDL for concept_manual_refresh (on demand development)

--CM Table truncation
TRUNCATE concept_manual;

--Insertion of the very last version of concept manual (in 90% of cases no changes here compared to previous release)
INSERT INTO concept_manual (concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code,
                            valid_start_date, valid_end_date, invalid_reason)
SELECT
       distinct
       concept_name,
       domain_id,
       vocabulary_id,
       concept_class_id,
       standard_concept,
       concept_code,
       valid_start_date,
       valid_end_date,
       invalid_reason
FROM concept_manual_backup_2023_02_08
;

--concept_relationship_manual population steps

--DDL for concept_relationship_manual_refresh (the pre-manual table with relationships to be implemented)
--Upload the proper file
--Upload https://docs.google.com/spreadsheets/d/1OLvyc4cSKHKNAo6jJy6EGIJUSOhaIRY4M1faG4y_bCY/edit#gid=0
--It is slightly modified version of https://github.com/OHDSI/Vocabulary-v5.0/issues/740
TRUNCATE concept_relationship_manual_refresh;
CREATE TABLE concept_relationship_manual_refresh
(
    concept_code_1   varchar(50),
    concept_code_2   varchar(50),
    vocabulary_id_1  varchar(20),
    vocabulary_id_2  varchar(20),
    relationship_id  varchar(20),
    valid_start_date DATE,
    valid_end_date   DATE,
    invalid_reason   varchar(1)
)
;

--Set proper Valid tart date for new relationships
UPDATE concept_relationship_manual_refresh
SET valid_start_date= CURRENT_DATE-1;



--Perform integrity checks to ensure that we will not create extra irrelevant relationships .Refer to checks. sql

--CRM process
TRUNCATE concept_relationship_manual;
INSERT INTO concept_relationship_manual (concept_code_1, vocabulary_id_1, relationship_id, valid_start_date,
                                         valid_end_date, invalid_reason, concept_code_2, vocabulary_id_2)
SELECT DISTINCT
       concept_code_1,
       vocabulary_id_1,
       relationship_id,
       valid_start_date,
       valid_end_date,
       invalid_reason,
       concept_code_2,
       vocabulary_id_2
FROM concept_relationship_manual_backup_2023_02_08
;

--Mapping insertion
INSERT INTO concept_relationship_manual (concept_code_1, vocabulary_id_1, relationship_id, valid_start_date,
                                         valid_end_date, invalid_reason, concept_code_2, vocabulary_id_2)
SELECT concept_code_1,
       vocabulary_id_1,
       relationship_id,
       CURRENT_DATE AS valid_start_date,
       valid_end_date,
       invalid_reason,
       concept_code_2,
       vocabulary_id_2
FROM concept_relationship_manual_refresh
WHERE (concept_code_1, relationship_id, concept_code_2) NOT IN (SELECT concept_code_1, relationship_id, concept_code_2
                                                                FROM concept_relationship_manual
                                                                WHERE invalid_reason IS NULL);
;

--Set Non-standard concept class
UPDATE concept_manual cm
SET standard_concept = NULL
/*SELECT *
FROM concept_manual cm*/
where exists (select 1
    from concept_relationship_manual crm
   JOIN concept_manual c on c.concept_code=crm.concept_code_1
    and crm.relationship_id ='Maps to'
    and crm.vocabulary_id_2='Cancer Modifier'
     where crm.concept_code_1=cm.concept_code
    and crm.vocabulary_id_1=cm.vocabulary_id)
and cm.standard_concept is not null
;


-- deprecate previous inaccurate mapping
UPDATE concept_relationship_manual crm
SET invalid_reason = 'D',
    valid_end_date = current_date-1
;

