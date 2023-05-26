--TODO: Make backup of concept_manual and concept_relationship_manual a part of load_stage
--TODO: Insert content into manual tables and publish the respective CSVs. CSVs then should be uploaded to manual tables
--TODO: Manual tables must be organized as full set, not delta

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



-- Update 3 concepts and set different concept_class_id for 2 concepts

--Deprecating existing mappings and making two question concepts standard
INSERT INTO concept_manual(concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
VALUES ('How often are you treated with less courtesy than other people when you go to a doctor''s office or other health care provider?', 'Observation', 'PPI', 'Question', 'S', 'sdoh_dms_1', '2021-11-03', '2099-12-31', null);

INSERT INTO concept_relationship_manual(concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
VALUES ('sdoh_dms_1', '67586-8', 'PPI', 'LOINC', 'Maps to', '2011-07-25', '2023-05-18', 'D');


INSERT INTO concept_manual(concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
VALUES ('How often are you treated with less respect than other people when you go to a doctor''s office or other health care provider?', 'Observation', 'PPI', 'Question', 'S', 'sdoh_dms_2', '2021-11-03', '2099-12-31', null);

INSERT INTO concept_relationship_manual(concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
VALUES ('sdoh_dms_2', '67587-6', 'PPI', 'LOINC', 'Maps to', '2011-07-25', '2023-05-18', 'D');

--Question -> Answer concept_class_id transition
INSERT INTO concept_manual(concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
VALUES ('Prefer not to answer', 'Observation', 'PPI', 'Answer', NULL, 'AttemptQuitSmoking_CompletelyQuitAgePreferNotToAns', '2017-05-26', '2017-09-14', 'D');

INSERT INTO concept_manual(concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
VALUES ('Prefer not to answer', 'Observation', 'PPI', 'Answer', NULL, 'Smoking_AverageDailyCigaretteNumberPreferNotToAnsw', '2017-05-26', '2017-09-14', 'D');

--Deprecating existing mapping and making one answer concept standard
INSERT INTO concept_manual(concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
VALUES ('Sex At Birth: Sex At Birth None Of These', 'Observation', 'PPI', 'Answer', 'S', 'SexAtBirth_SexAtBirthNoneOfThese', '2017-05-26', '2099-12-31', null);

INSERT INTO concept_relationship_manual(concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
VALUES ('SexAtBirth_SexAtBirthNoneOfThese', 'BiologicalSexAtBirth_SexAtBirth', 'PPI', 'PPI', 'Maps to', '2019-04-21', '2023-05-18', 'D');

INSERT INTO concept_relationship_manual(concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
VALUES ('SexAtBirth_SexAtBirthNoneOfThese', '260413007', 'PPI', 'SNOMED', 'Maps to value', '2019-04-21', '2023-05-18', 'D');

INSERT INTO concept_synonym_manual(synonym_name, synonym_concept_code, synonym_vocabulary_id, language_concept_id)
VALUES ('None of these describe me', 'SexAtBirth_SexAtBirthNoneOfThese', 'PPI', 4180186);