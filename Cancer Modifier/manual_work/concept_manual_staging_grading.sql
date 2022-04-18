--Manual-work table population
drop table concept_manual_staging;
CREATE TABLE concept_manual_staging
(

     concept_name varchar(255),
       domain_id varchar(20),
       vocabulary_id varchar(20),
       concept_class_id varchar(20),
       standard_concept varchar(1),
       concept_code varchar(50),
       valid_start_date date,
       valid_end_date date,
       invalid_reason varchar(1)
)
;


--SET INVALID as InvalidReasonon and null as StConcepts for these codes
INSERT INTO concept_manual_staging (
                                    concept_name,
                                    domain_id,
                                    vocabulary_id,
                                    concept_class_id,
                                    standard_concept,
                                    concept_code,
                                    valid_start_date,
                                    valid_end_date,
                                    invalid_reason)
SELECT
       concept_name,
       domain_id,
       vocabulary_id,
       concept_class_id,
    null as    standard_concept,
       concept_code,
       valid_start_date,
     CURRENT_DATE as  valid_end_date,
    'D'  as  invalid_reason
FROM concept
where concept_class_id ='Staging/Grading'
AND standard_concept='S'
and invalid_reason  is null
UNION all
SELECT
       concept_name,
       domain_id,
       vocabulary_id,
       concept_class_id,
    null as    standard_concept,
       concept_code,
       valid_start_date,
     CURRENT_DATE as  valid_end_date,
    'D'  as  invalid_reason
FROM concept
where vocabulary_id='NCIt'
and invalid_reason  is null
and standard_concept='S'
;

--Set correct invalid reason for Real concepts
update  concept_manual_staging
SET invalid_reason = null
where length (invalid_reason)=0
;

--To check distinct  codes with several names
SELECT *
FROM concept_manual_staging
where concept_code IN (
 SELECT concept_code
FROM concept_manual_staging
    group by 1 having count(*)>1
    )
;


--To check distinct codes with several codes
SELECT *
FROM concept_manual_staging
where concept_name IN (
 SELECT concept_name
FROM concept_manual_staging
    group by 1 having count(*)>1
    )
;



--CR
DROP TABLE concept_relationship_manual_staging;
CREATE TABLE concept_relationship_manual_staging
(

    concept_code_1   varchar(50),
    concept_name_1   varchar(255),
    vocabulary_id_1  varchar(20),
    valid_start_date date,
    valid_end_date   date,
    invalid_reason   varchar(1),
        relationship_id varchar (20),
    concept_code_2   varchar(50),
    concept_name_2   varchar(255),
        vocabulary_id_2  varchar(20)

)
;

--CHeck all the codes exist in CRMstaging
SELECT distinct *
from concept_relationship_manual_staging
where concept_code_1 not in (
    select concept_code from concept_manual_staging
    )
;

--Check the possible Lose of appropriate multiaxial concepts
select
       left(split_part(concept_code_1,'AJCC/UICC-',2),2),left(split_part(concept_code_2,'AJCC/UICC-',2),2),

       concept_code_1,
       concept_name_1,
       vocabulary_id_1,
       valid_start_date,
       valid_end_date,
       invalid_reason,
       relationship_id,
       concept_code_2,
       concept_name_2,
       reg1,
       reg2
FRom (
                  SELECT concept_code_1,
                         concept_name_1,
                         vocabulary_id_1,
                         valid_start_date,
                         valid_end_date,
                         invalid_reason,
                         relationship_id,
                         concept_code_2,
                         concept_name_2,
                         regexp_replace(split_part(concept_code_1, '_', 2), '\D', '', 'gi') as reg1,
                         regexp_replace(split_part(concept_code_2, '_', 2), '\D', '', 'gi') as reg2
                  FROM concept_relationship_manual_staging
                  where (regexp_replace(split_part(concept_code_1, '_', 2), '\D', '', 'gi') <>
                         regexp_replace(split_part(concept_code_2, '_', 2), '\D', '', 'gi')
                      and regexp_replace(split_part(concept_code_1, '_', 2), '\D', '', 'gi') <>
                          regexp_replace(concept_code_2, '\D', '', 'gi')
                      )
           --        and concept_code_1 ~* '[a-z]\d$' -- or concept_code_1 !~*'[a-z]\d$'
                --    and concept_code_1 ~* '^.*\dth'
              ) as tab
where /*concept_code_1 not ilike concept_code_2 || '%'*/
      -- left(reg1::varchar,1) <> reg2
left(split_part(concept_code_1,'AJCC/UICC-',2),2)<>left(split_part(concept_code_2,'AJCC/UICC-',2),1)
;

-- Manual table population;
--CM
--truncate concept_manual;
INSERT INTO concept_manual ( concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
SELECT distinct concept_name,
       domain_id,
       vocabulary_id,
       concept_class_id,
       standard_concept,
       concept_code,
       valid_start_date,
       valid_end_date,
       invalid_reason
FROM concept_manual_staging
;

--CRM
-- truncate concept_relationship_manual;
INSERT INTO concept_relationship_manual (concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
SELECT distinct concept_code_1,
              concept_code_2,
       vocabulary_id_1,
    'Cancer Modifier'   vocabulary_id_2,
             trim(relationship_id),
              valid_start_date,
       valid_end_date,
      null as invalid_reason
FROM concept_relationship_manual_staging
where length(concept_code_2)>0
;

--CONCEPT RELATIONSHIP MANUAL ENTIRE VOCABULARY (1st iteration)
DROP TABLE concept_manual_staging;
CREATE TABLE concept_manual_staging as
 SELECT distinct concept_name,
                 domain_id,
                 vocabulary_id,
                 concept_class_id,
                 standard_concept,
                 concept_code,
                 valid_start_date,
                 valid_end_date,
                 invalid_reason
 FROM concept_manual
;

--CONCEPT RELATIONSHIP MANUAL ENTIRE VOCABULARY (1st iteration)
DROP TABLE concept_relationship_manual_staging;
CREATE TABLE concept_relationship_manual_staging as
 SELECT distinct
                 concept_code_1,
                 concept_code_2,
                 vocabulary_id_1,
                 vocabulary_id_2,
                 relationship_id,
                 valid_start_date,
                 valid_end_date,
                 invalid_reason
 FROM concept_relationship_manual
;