--concept_manual_backup
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

INSERT INTO concept_manual (SELECT * FROM concept_manual_backup_2022_11_12);

-- concept_relationship_manual backup
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

INSERT INTO concept_relationship_manual (SELECT * FROM concept_relationship_manual_backup_2022_11_12);

--SELECT * FROM concept_manual_backup_2022_11_12
--SELECT * FROM concept_relationship_manual_backup_2022_11_12

--'Self-reported' concept and relationships insertion
TRUNCATE concept_manual;
INSERT INTO concept_manual
VALUES ('Self reported measurement', 'Observation', 'PPI', 'Qualifier Value', 'S', 'Self-reported', '2022-11-12', '2099-12-31', null);

TRUNCATE concept_relationship_manual;
INSERT INTO concept_relationship_manual
VALUES ('Self-reported', 'Self-reported', 'PPI', 'PPI', 'Maps to', '2022-11-12', '2099-12-31', null);

-- 'Life Functioning Survey' insertion
INSERT INTO concept_manual
VALUES ('Life Functioning Survey', 'Observation', 'PPI', 'Module', 'S', 'lfs', '2022-11-12', '2099-12-31', null);

INSERT INTO concept_relationship_manual
VALUES ('lfs', 'TheBasics_Disability', 'PPI', 'PPI', 'Subsumes', '2022-11-12', '2099-12-31', null);





