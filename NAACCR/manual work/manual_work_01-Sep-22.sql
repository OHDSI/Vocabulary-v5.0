--concept_relationship_manual_backup_2022_09_01;
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

SELECT count(*) FROM concept_relationship_manual_backup_2022_09_01;

--concept_manual_backup_2022_09_01;
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

SELECT count(*) FROM concept_manual_backup_2022_09_01;

--Upload https://docs.google.com/spreadsheets/d/1BKRlhXAWq-UB5cN6JeiCg_6JRt19s8rAH6ogXUmv5Co/edit#gid=196015655
--It is slightly modified version of https://github.com/OHDSI/Vocabulary-v5.0/issues/668
CREATE TABLE concept_relationship_manual_refresh as
SELECT *
FROM concept_relationship_manual;

UPDATE concept_relationship_manual_refresh SET valid_start_date= CURRENT_DATE-1;


--CM population
TRUNCATE concept_manual;
--CM population
INSERT INTO concept_manual (concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
SELECT concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
FROM concept_manual_backup_2022_09_01
;

--CRM process
TRUNCATE concept_relationship_manual;
INSERT INTO concept_relationship_manual (concept_code_1, vocabulary_id_1,  relationship_id, valid_start_date, valid_end_date, invalid_reason,concept_code_2,vocabulary_id_2)
SELECT concept_code_1, vocabulary_id_1,  relationship_id, valid_start_date, valid_end_date, invalid_reason,concept_code_2,vocabulary_id_2
FROM concept_relationship_manual_backup_2022_09_01;


--Detect codes not existing as naaccrr values
SELECT *
FROM concept_relationship_manual_refresh
WHERE concept_code_1 not in (SELECT concept_code from concept where concept_class_id='NAACCR Value')
;

--CHeck thant NAACCR Values are not target for other codes
SELECT *
FROM concept_relationship_manual_refresh a
JOIN concept b
on a.concept_code_1=b.concept_code and concept_class_id='NAACCR Value'
JOIN concept_relationship r
on b.concept_id=r.concept_id_2
and r.relationship_id='Maps to'
and r.invalid_reason is null
and r.concept_id_2<>r.concept_id_1;




--Mapping insertion
INSERT INTO concept_relationship_manual (concept_code_1, vocabulary_id_1,  relationship_id, valid_start_date, valid_end_date, invalid_reason,concept_code_2,vocabulary_id_2)
SELECT concept_code_1, vocabulary_id_1,  relationship_id, valid_start_date, valid_end_date, invalid_reason,concept_code_2,vocabulary_id_2
FROM concept_relationship_manual_refresh
where (concept_code_1,relationship_id,concept_code_2) NOT IN (SELECT concept_code_1,relationship_id,concept_code_2 from concept_relationship_manual);
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

--SELECT * FROM concept_relationship_manual crm --use this SELECT for QA
WHERE invalid_reason IS NULL --deprecate only what's not yet deprecated in order to preserve the original deprecation date

    AND concept_code_1 IN (SELECT concept_code_1 FROM concept_relationship_manual_refresh where relationship_id='Maps to') --work only with the codes presented in the manual file of the current vocabulary refresh

    AND NOT EXISTS (SELECT 1 --don't deprecate mapping if the same exists in the current manual file
                    FROM concept_relationship_manual_refresh rl
                    WHERE rl.concept_code_1 = crm.concept_code_1 --the same source_code is mapped
                        AND rl.concept_code_2 = crm.concept_code_2 --to the same concept_code
                        AND rl.vocabulary_id_2 = crm.vocabulary_id_2 --of the same vocabulary
                        AND rl.relationship_id = crm.relationship_id --with the same relationship
        )
and crm.relationship_id IN ('Maps to', 'Maps to value')
;