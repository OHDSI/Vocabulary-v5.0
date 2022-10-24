--1. Backup concept_relationship_manual table and concept_manual table.
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
/*TRUNCATE TABLE dev_omop.concept_relationship_manual;
INSERT INTO dev_omop.concept_relationship_manual
SELECT * FROM dev_omop.concept_relationship_manual_backup_2022_10_24;*/
--
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
/*TRUNCATE TABLE dev_omop.concept_manual;
INSERT INTO dev_omop.concept_manual
SELECT * FROM dev_omop.concept_manual_backup_2022_10_24;*/

--2. Insert a new concept into the concept_manual table:
-- 2.1 Check the first vacant concept_code among OMOP generated and use it for the new concept:

select 'OMOP'||max(replace(concept_code, 'OMOP','')::int4)+1 from devv5.concept where concept_code like 'OMOP%' and concept_code not like '% %';

-- 2.2 Insert the new concept into the concept_manual table:

INSERT INTO dev_omop.concept_manual (concept_name, domain_id, vocabulary_id, concept_class_id,
                                     standard_concept, concept_code, valid_start_date, valid_end_date)
    VALUES (
            'Patient self-tested',  -- concept_name
            'Type Concept',         -- domain_id
            'Type Concept',         -- vocabulary_id
            'Type Concept',         -- concept_class_id
            'S',                    -- standard_concept
            'OMOP5181828',          -- concept_code
            current_date,           -- current_date as valid_start_date
            '2099-12-31'            -- valid_end_date
           )
;

-- 3. Insert the hierarchical relationships into the concept_relationship_manual table:

INSERT INTO concept_relationship_manual (concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2,
                                         relationship_id, valid_start_date, valid_end_date)
    VALUES ('OMOP5181828',        -- concept_code_1
            'OMOP4976938',        -- concept_code_2
            'Type Concept',       -- vocabulary_id_1
            'Type Concept',       -- vocabulary_id_2
            'Is a',               -- relationship_id
            current_date,         -- current_date as valid_start_date
            '2099-12-31'          -- valid_end_date
          )
;
