--DOwnload manua tables as csv https://drive.google.com/drive/u/0/folders/1giqnH9bLsEtVQj_DcI16DXJZd1Xetv4c
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
       invalid_reason varchar(1),
       concept_synonym_name varchar(255)
)
;



--Update of invalid reason
UPDATE concept_manual_staging SET invalid_reason= null where length(invalid_reason)=0
;

--To check distinct  codes with several names
SELECT  distinct *
FROM concept_manual_staging
where concept_code IN (
 SELECT concept_code
FROM concept_manual_staging
    group by 1 having count(*)>1
    )
;

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
                                           standard_concept,
                                           concept_code,
                                           valid_start_date,
                                           valid_end_date,
                                           invalid_reason
FROM
(SELECT
       concept_name,
       domain_id,
       vocabulary_id,
       concept_class_id,
    null as    standard_concept,
       concept_code,
       valid_start_date,
     CURRENT_DATE as  valid_end_date,
    'D'  as  invalid_reason
FROM devv5.concept
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
FROM devv5.concept
where vocabulary_id='NCIt'
and invalid_reason  is null
and standard_concept='S' ) as tab



--CR
--mapt to ony + is a for responses
--Only for one to one hierarchy
--Punt the csv before script run
DROP TABLE concept_relationship_manual_staging;
CREATE TABLE concept_relationship_manual_staging
(

    concept_code_1   varchar(50),
    vocabulary_id_1  varchar(20),
    valid_start_date date,
    valid_end_date   date,
    invalid_reason   varchar(1),
        relationship_id varchar (20),
    concept_code_2   varchar(50),
        vocabulary_id_2  varchar(20)

)
;

--automap
--autoIsa
-- Mapping of FIGO
with figo_map as (
    select distinct a.concept_code as concept_code_1,
                    a.vocabulary_id as vocabulary_id_1,
                    a.concept_name as concept_name_1,
                    'Concept replaced by'    as relationship_id,
                    null         as invalid_reason,
                    '2022-04-18'::date as valid_start_date,
                    '2099-12-31'::date as valid_end_date,
                    c.concept_code as concept_code_2,
                    c.vocabulary_id as vocabulary_id_2,
                    c.concept_name as concept_name_2
    FROM concept_manual_staging a
             JOIN concept_manual_staging b
                  ON regexp_replace(a.concept_name,'\(|\)','','gi') ilike '%' || regexp_replace(b.concept_name,'\(|\)','','gi')
                      and a.invalid_reason is not null
                      and a.concept_name ilike '%2015 FIGO%'
                      and b.invalid_reason is null
                      and b.concept_name ilike '%FIGO%'
             JOIN concept_manual_staging c
                  on c.concept_code = '2015_' || b.concept_code

    UNION ALL

    select distinct a.concept_code,
                    a.vocabulary_id,
                    a.concept_name,
                    'Concept replaced by'    as relationship_id,
                    null         as invalid_reason,
                    '2022-04-18'::date as valid_start_date,
                    '2099-12-31'::date as valid_end_date,
                    c.concept_code,
                    c.vocabulary_id,
                    c.concept_name
    FROM concept_manual_staging a
             JOIN concept_manual_staging b
                  ON regexp_replace(a.concept_name,'\(|\)','','gi') ilike '%' || regexp_replace(b.concept_name,'\(|\)','','gi')
                      and a.invalid_reason is not null
                      and a.concept_name ilike '%2018 FIGO%'
                      and b.invalid_reason is null
                      and b.concept_name ilike '%FIGO%'
             JOIN concept_manual_staging c
                  on c.concept_code = '2018_' || b.concept_code


        UNION ALL

    select distinct a.concept_code,
                    a.vocabulary_id,
                    a.concept_name,
                    'Concept replaced by'    as relationship_id,
                    null         as invalid_reason,
                    '2022-04-18'::date as valid_start_date,
                    '2099-12-31'::date as valid_end_date,
                    c.concept_code,
                    c.vocabulary_id,
                    c.concept_name
    FROM concept_manual_staging a
             JOIN concept_manual_staging b
                  ON regexp_replace(a.concept_name,'\(|\)','','gi') ilike '%' || regexp_replace(b.concept_name,'\(|\)','','gi')
                      and a.invalid_reason is not null
                      and a.concept_name not ilike '%2018 FIGO%'
                                               and a.concept_name not ilike '%2015 FIGO%'
                                               and a.concept_name  ilike '%FIGO%'
                      and b.invalid_reason is null
                      and b.concept_name ilike '%FIGO%'
             JOIN concept_manual_staging c
                  on c.concept_code = b.concept_code

)
INSERT INTO concept_relationship_manual_staging  (concept_code_1,
                vocabulary_id_1,
                relationship_id,
                invalid_reason,
                valid_start_date,
                valid_end_date,
                concept_code_2,
                vocabulary_id_2)

SELECT distinct concept_code_1,
                vocabulary_id_1,
                relationship_id,
                invalid_reason,
                valid_start_date,
                valid_end_date,
                concept_code_2,
                vocabulary_id_2
FROM  figo_map
where concept_code_1 IN (SELECT distinct concept_code_1 from figo_map group by 1 having count(*)=1)
and  (concept_code_1,concept_code_2) NOT IN (select concept_code_1,concept_code_2 from concept_relationship_manual_staging )

order by concept_code_1,relationship_id,concept_code_2
;
--NCIt mappings
INSERT INTO concept_relationship_manual_staging  (concept_code_1,
                vocabulary_id_1,
                relationship_id,
                invalid_reason,
                valid_start_date,
                valid_end_date,
                concept_code_2,
                vocabulary_id_2)
SELECT distinct concept_code_1,
                vocabulary_id_1,
                relationship_id,
                invalid_reason,
                valid_start_date::date,
                valid_end_date::date,
                concept_code_2,
                vocabulary_id_2
FROM
    (
    WITH TABs as (SELECT distinct s.concept_code as concept_code_1,
    s.vocabulary_id as vocabulary_id_1,
    s.concept_name as concept_name_1,
    'Concept replaced by' as relationship_id,
    null as invalid_reason,
    '2022-04-18' as valid_start_date,
    '2099-12-31' as valid_end_date,
    m.concept_code as concept_code_2,
    m.vocabulary_id as vocabulary_id_2,
    m.concept_name as concept_name_2
    FROM concept_manual_staging s
    JOIN concept_manual_staging m
    ON split_part(s.concept_code, '-', 1) ilike '%'||split_part(m.concept_code, '-', 3)
    where s.invalid_reason is not null
    and s.concept_class_id='AJCC Category'
    and s.concept_code like 'c%'
    and m.concept_code like 'c-8th%'
    union all
    SELECT distinct s.concept_code,
    s.vocabulary_id,
    s.concept_name,
    'Concept replaced by' as relationship_id,
    null as invalid_reason,
    '2022-04-18' as valid_start_date,
    '2099-12-31' as valid_end_date,
    m.concept_code,
    m.vocabulary_id,
    m.concept_name
    FROM concept_manual_staging s
    JOIN concept_manual_staging m
    ON split_part(s.concept_code, '-', 1) ilike '%'||split_part(m.concept_code, '-', 3)
    where s.invalid_reason is not null
    and s.concept_class_id='AJCC Category'
    and s.concept_code like 'p%'
    and m.concept_code like 'p-8th%')
        SELECT * FROM tabs where concept_code_1 in (SELECT concept_code_1 from tabs group by 1 having count (*)=1)
    ) as tab
where (concept_code_1,relationship_id,concept_code_2) NOT IN (select concept_code_1,relationship_id,concept_code_2 from concept_relationship_manual_staging )

;

--NCIt mappings
INSERT INTO concept_relationship_manual_staging  (concept_code_1,
                vocabulary_id_1,
                relationship_id,
                invalid_reason,
                valid_start_date,
                valid_end_date,
                concept_code_2,
                vocabulary_id_2)
SELECT distinct concept_code_1,
                vocabulary_id_1,
                relationship_id,
                invalid_reason,
                valid_start_date::date,
                valid_end_date::date,
                concept_code_2,
                vocabulary_id_2
FROM (
         WITH TABs as (SELECT distinct s.concept_code  as concept_code_1,
                                       s.vocabulary_id as vocabulary_id_1,
                                       s.concept_name  as concept_name_1,
                                      'Concept replaced by' as relationship_id,
    null as invalid_reason,
    '2022-04-18' as valid_start_date,
    '2099-12-31' as valid_end_date,
    m.concept_code as concept_code_2,
    m.vocabulary_id as vocabulary_id_2,
    m.concept_name as concept_name_2
                       FROM concept_manual_staging s
                           JOIN concept_manual_staging m
                       ON split_part(regexp_replace(s.concept_code,'\(\d+\)','','gi'), '-', 1) ilike '%'||split_part(m.concept_code, '-', 3)
                       where s.invalid_reason is not null
                         and s.concept_class_id='AJCC Category'
                         and s.concept_code like 'c%'
                         and m.concept_code like 'c-8th%'
                       union all
                       SELECT distinct s.concept_code,
                           s.vocabulary_id,
                           s.concept_name,
                           'Concept replaced by' as relationship_id,
                           null as invalid_reason,
                           '2022-04-18' as valid_start_date,
                           '2099-12-31' as valid_end_date,
                           m.concept_code,
                           m.vocabulary_id,
                           m.concept_name
                       FROM concept_manual_staging s
                           JOIN concept_manual_staging m
                       ON split_part(regexp_replace(s.concept_code,'\(\d+\)','','gi'), '-', 1) ilike '%'||split_part(m.concept_code, '-', 3)
                       where s.invalid_reason is not null
                         and s.concept_class_id='AJCC Category'
                         and s.concept_code like 'p%'
                         and m.concept_code like 'p-8th%')
         SELECT *
         FROM tabs
         where concept_code_1 in (SELECT concept_code_1 from tabs group by 1 having count(*) = 1)
     ) as tab
where (concept_code_1,relationship_id,concept_code_2) NOT IN (select concept_code_1,relationship_id,concept_code_2 from concept_relationship_manual_staging )
;

--NCIt
--Mapping of grades
INSERT INTO concept_relationship_manual_staging  (concept_code_1,
                vocabulary_id_1,
                relationship_id,
                invalid_reason,
                valid_start_date,
                valid_end_date,
                concept_code_2,
                vocabulary_id_2)
                SELECT distinct concept_code_1,
                vocabulary_id_1,
                relationship_id,
                invalid_reason,
                valid_start_date::date,
                valid_end_date::date,
                concept_code_2,
                vocabulary_id_2
FROM (
         SELECT distinct s.concept_code as concept_code_1 ,
                         s.vocabulary_id as vocabulary_id_1,
                         s.concept_name,
                         'Concept replaced by'    as relationship_id,
                         null         as invalid_reason,
                         '2022-04-18' as valid_start_date,
                         '2099-12-31' as valid_end_date,
                         m.concept_code concept_code_2,
                         m.vocabulary_id as vocabulary_id_2,
                         m.concept_name
         FROM concept_manual_staging s
                  JOIN concept_manual_staging m
                       ON split_part(regexp_replace(s.concept_code, '^G', '', 'g'), '-', 1) ilike
                          '%' || split_part(m.concept_code, '-', 2)
         where s.invalid_reason is not null
           and s.concept_class_id = 'AJCC Category'
           and s.concept_code like 'G%'
           and m.concept_code like 'Grade%'
     ) as tab
where (concept_code_1,relationship_id,concept_code_2) NOT IN (select concept_code_1,relationship_id,concept_code_2 from concept_relationship_manual_staging )
;

--DELETE UPDATED CONCEPTS
DELETE
FROM concept_manual_staging
where concept_code  IN (select concept_code_1 from concept_relationship_manual_staging where relationship_id ilike 'Concept replaced by%')
and invalid_reason is not null;


----Hierarchy creation for most attributes
INSERT INTO concept_relationship_manual_staging  (concept_code_1,  vocabulary_id_1, valid_start_date, valid_end_date, invalid_reason, relationship_id, concept_code_2, vocabulary_id_2)
SELECT  distinct
                 concept_code_1,
                 vocabulary_id_1,
                 valid_start_date,
                 valid_end_date,
                 invalid_reason,
                 relationship_id,
                 concept_code_2,
                 vocabulary_id_2
FROM (
    SELECT concept_code                                   as concept_code_1,
                         vocabulary_id                                  as vocabulary_id_1,
                         valid_start_date,
                         valid_end_date,
                         invalid_reason,
                         'Is a'                                         as relationship_id,
                         regexp_replace(concept_code, '^yc-', '', 'gi') as concept_code_2,
                         vocabulary_id                                  as vocabulary_id_2
                  FROM concept_manual_staging
                  WHERE concept_code ilike 'yc-AJCC/UICC%'

                  UNION ALL
                  SELECT concept_code                                  as concept_code_1,
                         vocabulary_id                                 as vocabulary_id_1,
                         valid_start_date,
                         valid_end_date,
                         invalid_reason,
                         'Is a'                                        as relationship_id,
                         regexp_replace(concept_code, '^c-', '', 'gi') as concept_code_2,
                         vocabulary_id                                 as vocabulary_id_2
                  FROM concept_manual_staging
                  WHERE concept_code ilike 'c-AJCC/UICC%'
    UNION ALL
      SELECT concept_code                                   as concept_code_1,
                         vocabulary_id                                  as vocabulary_id_1,
                         valid_start_date,
                         valid_end_date,
                         invalid_reason,
                         'Is a'                                         as relationship_id,
                         regexp_replace(concept_code, '^yp-', '', 'gi') as concept_code_2,
                         vocabulary_id                                  as vocabulary_id_2
                  FROM concept_manual_staging
                  WHERE concept_code ilike 'yp-AJCC/UICC%'

                  UNION ALL
                  SELECT concept_code                                  as concept_code_1,
                         vocabulary_id                                 as vocabulary_id_1,
                         valid_start_date,
                         valid_end_date,
                         invalid_reason,
                         'Is a'                                        as relationship_id,
                         regexp_replace(concept_code, '^p-', '', 'gi') as concept_code_2,
                         vocabulary_id                                 as vocabulary_id_2
                  FROM concept_manual_staging
                  WHERE concept_code ilike 'p-AJCC/UICC%'

UNION ALL
                  SELECT concept_code                                   as concept_code_1,
                         vocabulary_id                                  as vocabulary_id_1,
                         valid_start_date,
                         valid_end_date,
                         invalid_reason,
                         'Is a'                                         as relationship_id,
                         regexp_replace(concept_code, '6th_', '', 'gi') as concept_code_2,
                         vocabulary_id                                  as vocabulary_id_2
                  FROM concept_manual_staging
                  WHERE concept_code ilike 'c-6th_AJCC/UICC%'

                  UNION ALL
                  SELECT concept_code                                  as concept_code_1,
                         vocabulary_id                                 as vocabulary_id_1,
                         valid_start_date,
                         valid_end_date,
                         invalid_reason,
                         'Is a'                                        as relationship_id,
                         regexp_replace(concept_code, '^c-', '', 'gi') as concept_code_2,
                         vocabulary_id                                 as vocabulary_id_2
                  FROM concept_manual_staging
                  WHERE concept_code ilike 'c-6th_AJCC/UICC%'
                  UNION ALL
                  SELECT concept_code                                   as concept_code_1,
                         vocabulary_id                                  as vocabulary_id_1,
                         valid_start_date,
                         valid_end_date,
                         invalid_reason,
                         'Is a'                                         as relationship_id,
                         regexp_replace(concept_code, '6th_', '', 'gi') as concept_code_2,
                         vocabulary_id                                  as vocabulary_id_2
                  FROM concept_manual_staging
                  WHERE concept_code ilike 'yc-6th_AJCC/UICC%'

                  UNION ALL
                  SELECT concept_code                                   as concept_code_1,
                         vocabulary_id                                  as vocabulary_id_1,
                         valid_start_date,
                         valid_end_date,
                         invalid_reason,
                         'Is a'                                         as relationship_id,
                         regexp_replace(concept_code, '^yc-', '', 'gi') as concept_code_2,
                         vocabulary_id                                  as vocabulary_id_2
                  FROM concept_manual_staging
                  WHERE concept_code ilike 'yc-6th_AJCC/UICC%'
                  UNION ALL
                  SELECT concept_code                                   as concept_code_1,
                         vocabulary_id                                  as vocabulary_id_1,
                         valid_start_date,
                         valid_end_date,
                         invalid_reason,
                         'Is a'                                         as relationship_id,
                         regexp_replace(concept_code, '7th_', '', 'gi') as concept_code_2,
                         vocabulary_id                                  as vocabulary_id_2
                  FROM concept_manual_staging
                  WHERE concept_code ilike 'yc-7th_AJCC/UICC%'

                  UNION ALL
                  SELECT concept_code                                   as concept_code_1,
                         vocabulary_id                                  as vocabulary_id_1,
                         valid_start_date,
                         valid_end_date,
                         invalid_reason,
                         'Is a'                                         as relationship_id,
                         regexp_replace(concept_code, '^yc-', '', 'gi') as concept_code_2,
                         vocabulary_id                                  as vocabulary_id_2
                  FROM concept_manual_staging
                  WHERE concept_code ilike 'yc-7th_AJCC/UICC%'
                  UNION ALL
                  SELECT concept_code                                   as concept_code_1,
                         vocabulary_id                                  as vocabulary_id_1,
                         valid_start_date,
                         valid_end_date,
                         invalid_reason,
                         'Is a'                                         as relationship_id,
                         regexp_replace(concept_code, '7th_', '', 'gi') as concept_code_2,
                         vocabulary_id                                  as vocabulary_id_2
                  FROM concept_manual_staging
                  WHERE concept_code ilike 'c-7th_AJCC/UICC%'

                  UNION ALL
                  SELECT concept_code                                  as concept_code_1,
                         vocabulary_id                                 as vocabulary_id_1,
                         valid_start_date,
                         valid_end_date,
                         invalid_reason,
                         'Is a'                                        as relationship_id,
                         regexp_replace(concept_code, '^c-', '', 'gi') as concept_code_2,
                         vocabulary_id                                 as vocabulary_id_2
                  FROM concept_manual_staging
                  WHERE concept_code ilike 'c-7th_AJCC/UICC%'
                  UNION ALL
                  SELECT concept_code                                   as concept_code_1,
                         vocabulary_id                                  as vocabulary_id_1,
                         valid_start_date,
                         valid_end_date,
                         invalid_reason,
                         'Is a'                                         as relationship_id,
                         regexp_replace(concept_code, '8th_', '', 'gi') as concept_code_2,
                         vocabulary_id                                  as vocabulary_id_2
                  FROM concept_manual_staging
                  WHERE concept_code ilike 'c-8th_AJCC/UICC%'

                  UNION ALL
                  SELECT concept_code                                  as concept_code_1,
                         vocabulary_id                                 as vocabulary_id_1,
                         valid_start_date,
                         valid_end_date,
                         invalid_reason,
                         'Is a'                                        as relationship_id,
                         regexp_replace(concept_code, '^c-', '', 'gi') as concept_code_2,
                         vocabulary_id                                 as vocabulary_id_2
                  FROM concept_manual_staging
                  WHERE concept_code ilike 'c-8th_AJCC/UICC%'
                  UNION ALL
                  SELECT concept_code                                   as concept_code_1,
                         vocabulary_id                                  as vocabulary_id_1,
                         valid_start_date,
                         valid_end_date,
                         invalid_reason,
                         'Is a'                                         as relationship_id,
                         regexp_replace(concept_code, '8th_', '', 'gi') as concept_code_2,
                         vocabulary_id                                  as vocabulary_id_2
                  FROM concept_manual_staging
                  WHERE concept_code ilike 'yc-8th_AJCC/UICC%'

                  UNION ALL
                  SELECT concept_code                                   as concept_code_1,
                         vocabulary_id                                  as vocabulary_id_1,
                         valid_start_date,
                         valid_end_date,
                         invalid_reason,
                         'Is a'                                         as relationship_id,
                         regexp_replace(concept_code, '^yc-', '', 'gi') as concept_code_2,
                         vocabulary_id                                  as vocabulary_id_2
                  FROM concept_manual_staging
                  WHERE concept_code ilike 'yc-8th_AJCC/UICC%'

                  UNION ALL

                  SELECT concept_code                                   as concept_code_1,
                         vocabulary_id                                  as vocabulary_id_1,
                         valid_start_date,
                         valid_end_date,
                         invalid_reason,
                         'Is a'                                         as relationship_id,
                         regexp_replace(concept_code, '6th_', '', 'gi') as concept_code_2,
                         vocabulary_id                                  as vocabulary_id_2
                  FROM concept_manual_staging
                  WHERE concept_code ilike 'p-6th_AJCC/UICC%'

                  UNION ALL
                  SELECT concept_code                                  as concept_code_1,
                         vocabulary_id                                 as vocabulary_id_1,
                         valid_start_date,
                         valid_end_date,
                         invalid_reason,
                         'Is a'                                        as relationship_id,
                         regexp_replace(concept_code, '^p-', '', 'gi') as concept_code_2,
                         vocabulary_id                                 as vocabulary_id_2
                  FROM concept_manual_staging
                  WHERE concept_code ilike 'p-6th_AJCC/UICC%'
                  UNION ALL
                  SELECT concept_code                                   as concept_code_1,
                         vocabulary_id                                  as vocabulary_id_1,
                         valid_start_date,
                         valid_end_date,
                         invalid_reason,
                         'Is a'                                         as relationship_id,
                         regexp_replace(concept_code, '6th_', '', 'gi') as concept_code_2,
                         vocabulary_id                                  as vocabulary_id_2
                  FROM concept_manual_staging
                  WHERE concept_code ilike 'yp-6th_AJCC/UICC%'

                  UNION ALL
                  SELECT concept_code                                   as concept_code_1,
                         vocabulary_id                                  as vocabulary_id_1,
                         valid_start_date,
                         valid_end_date,
                         invalid_reason,
                         'Is a'                                         as relationship_id,
                         regexp_replace(concept_code, '^yp-', '', 'gi') as concept_code_2,
                         vocabulary_id                                  as vocabulary_id_2
                  FROM concept_manual_staging
                  WHERE concept_code ilike 'yp-6th_AJCC/UICC%'
                  UNION ALL
                  SELECT concept_code                                   as concept_code_1,
                         vocabulary_id                                  as vocabulary_id_1,
                         valid_start_date,
                         valid_end_date,
                         invalid_reason,
                         'Is a'                                         as relationship_id,
                         regexp_replace(concept_code, '7th_', '', 'gi') as concept_code_2,
                         vocabulary_id                                  as vocabulary_id_2
                  FROM concept_manual_staging
                  WHERE concept_code ilike 'yp-7th_AJCC/UICC%'

                  UNION ALL
                  SELECT concept_code                                   as concept_code_1,
                         vocabulary_id                                  as vocabulary_id_1,
                         valid_start_date,
                         valid_end_date,
                         invalid_reason,
                         'Is a'                                         as relationship_id,
                         regexp_replace(concept_code, '^yp-', '', 'gi') as concept_code_2,
                         vocabulary_id                                  as vocabulary_id_2
                  FROM concept_manual_staging
                  WHERE concept_code ilike 'yp-7th_AJCC/UICC%'
                  UNION ALL
                  SELECT concept_code                                   as concept_code_1,
                         vocabulary_id                                  as vocabulary_id_1,
                         valid_start_date,
                         valid_end_date,
                         invalid_reason,
                         'Is a'                                         as relationship_id,
                         regexp_replace(concept_code, '7th_', '', 'gi') as concept_code_2,
                         vocabulary_id                                  as vocabulary_id_2
                  FROM concept_manual_staging
                  WHERE concept_code ilike 'p-7th_AJCC/UICC%'

                  UNION ALL
                  SELECT concept_code                                  as concept_code_1,
                         vocabulary_id                                 as vocabulary_id_1,
                         valid_start_date,
                         valid_end_date,
                         invalid_reason,
                         'Is a'                                        as relationship_id,
                         regexp_replace(concept_code, '^p-', '', 'gi') as concept_code_2,
                         vocabulary_id                                 as vocabulary_id_2
                  FROM concept_manual_staging
                  WHERE concept_code ilike 'p-7th_AJCC/UICC%'
                  UNION ALL
                  SELECT concept_code                                   as concept_code_1,
                         vocabulary_id                                  as vocabulary_id_1,
                         valid_start_date,
                         valid_end_date,
                         invalid_reason,
                         'Is a'                                         as relationship_id,
                         regexp_replace(concept_code, '8th_', '', 'gi') as concept_code_2,
                         vocabulary_id                                  as vocabulary_id_2
                  FROM concept_manual_staging
                  WHERE concept_code ilike 'p-8th_AJCC/UICC%'

                  UNION ALL
                  SELECT concept_code                                  as concept_code_1,
                         vocabulary_id                                 as vocabulary_id_1,
                         valid_start_date,
                         valid_end_date,
                         invalid_reason,
                         'Is a'                                        as relationship_id,
                         regexp_replace(concept_code, '^p-', '', 'gi') as concept_code_2,
                         vocabulary_id                                 as vocabulary_id_2
                  FROM concept_manual_staging
                  WHERE concept_code ilike 'p-8th_AJCC/UICC%'
                  UNION ALL
                  SELECT concept_code                                   as concept_code_1,
                         vocabulary_id                                  as vocabulary_id_1,
                         valid_start_date,
                         valid_end_date,
                         invalid_reason,
                         'Is a'                                         as relationship_id,
                         regexp_replace(concept_code, '8th_', '', 'gi') as concept_code_2,
                         vocabulary_id                                  as vocabulary_id_2
                  FROM concept_manual_staging
                  WHERE concept_code ilike 'yp-8th_AJCC/UICC%'

                  UNION ALL
                  SELECT concept_code                                   as concept_code_1,
                         vocabulary_id                                  as vocabulary_id_1,
                         valid_start_date,
                         valid_end_date,
                         invalid_reason,
                         'Is a'                                         as relationship_id,
                         regexp_replace(concept_code, '^yp-', '', 'gi') as concept_code_2,
                         vocabulary_id                                  as vocabulary_id_2
                  FROM concept_manual_staging
                  WHERE concept_code ilike 'yp-8th_AJCC/UICC%'
       UNION ALL
                  SELECT concept_code                                   as concept_code_1,
                         vocabulary_id                                  as vocabulary_id_1,
                         valid_start_date,
                         valid_end_date,
                         invalid_reason,
                         'Is a'                                         as relationship_id,
                         regexp_replace(concept_code, '^2015_', '', 'gi') as concept_code_2,
                         vocabulary_id                                  as vocabulary_id_2
                  FROM concept_manual_staging
                  WHERE concept_code ilike '2015_FIGO%'
        UNION ALL
                  SELECT concept_code                                   as concept_code_1,
                         vocabulary_id                                  as vocabulary_id_1,
                         valid_start_date,
                         valid_end_date,
                         invalid_reason,
                         'Is a'                                         as relationship_id,
                         regexp_replace(concept_code, '^2018_', '', 'gi') as concept_code_2,
                         vocabulary_id                                  as vocabulary_id_2
                  FROM concept_manual_staging
                  WHERE concept_code ilike '2018_FIGO%'
            UNION ALL
                  SELECT concept_code                                   as concept_code_1,
                         vocabulary_id                                  as vocabulary_id_1,
                         valid_start_date,
                         valid_end_date,
                         invalid_reason,
                         'Is a'                                         as relationship_id,
                         regexp_replace(concept_code, '^\dth_', '', 'gi') as concept_code_2,
                         vocabulary_id                                  as vocabulary_id_2
                  FROM concept_manual_staging
                  WHERE concept_code ~*'^\dth_'
    and concept_code not IN (
'6th_AJCC/UICC',
'7th_AJCC/UICC',
'8th_AJCC/UICC'
)


              ) as hier_tab
where (concept_code_1,relationship_id,concept_code_2) NOT IN (select concept_code_1,relationship_id,concept_code_2 from concept_relationship_manual_staging )
and concept_code_2!=concept_code_1
;
--To version 'is a'
INSERT INTO concept_relationship_manual_staging  (concept_code_1,  vocabulary_id_1, valid_start_date, valid_end_date, invalid_reason, relationship_id, concept_code_2, vocabulary_id_2)
SELECT
       concept_code as concept_code_1,
       vocabulary_id as vocabulary_id_1,
       valid_start_date,
       valid_end_date,
       invalid_reason,
       'Is a' relationship_id,
       '8th_AJCC/UICC' as concept_code_2,
            vocabulary_id as vocabulary_id_2
FROM concept_manual_staging
            WHERE concept_code ilike '%8th%'
UNION ALL
SELECT    concept_code as concept_code_1,
       vocabulary_id as vocabulary_id_1,
       valid_start_date,
       valid_end_date,
       invalid_reason,
       'Is a' relationship_id,
       '7th_AJCC/UICC' as concept_code_2,
            vocabulary_id as vocabulary_id_2
FROM concept_manual_staging
            WHERE concept_code ilike '%7th%'

UNION ALL
SELECT    concept_code as concept_code_1,
       vocabulary_id as vocabulary_id_1,
       valid_start_date,
       valid_end_date,
       invalid_reason,
       'Is a' relationship_id,
       '6th_AJCC/UICC' as concept_code_2,
            vocabulary_id as vocabulary_id_2
FROM concept_manual_staging
            WHERE concept_code ilike '%6th%'
;
--onetoOne hierarchy reconstruction
INSERT INTO concept_relationship_manual_staging  (concept_code_1,  vocabulary_id_1, valid_start_date, valid_end_date, invalid_reason, relationship_id, concept_code_2, vocabulary_id_2)
SELECT distinct concept_code_1,
                'Cancer Modifier' as vocabulary_id_1,
                         '2022-04-18'::date as valid_start_date,
                         '2099-12-31'::date as valid_end_date,
                                         null         as invalid_reason,
                                'Is a'    as relationship_id,
                             concept_code_2,
                'Cancer Modifier' as vocabulary_id_2
FROM (
select c.concept_code as concept_code_1,cc.concept_code as concept_code_2,row_number() OVER (PARTITION BY c.concept_code ORDER BY length(cc.concept_code) DESC)  AS rating_in_section
FROM concept_manual_staging c
join concept_manual_staging cc
on c.concept_code ilike cc.concept_code ||'%'
and c.concept_code<>cc.concept_code
    and c.standard_concept='S'
    and cc.standard_concept='S')
    as tablescd
where rating_in_section=1
and (concept_code_1,'Is a',concept_code_2) NOT IN (select concept_code_1,relationship_id,concept_code_2 from concept_relationship_manual_staging  where concept_relationship_manual_staging .concept_code_1=concept_relationship_manual_staging .concept_code_2)
;

-- normalisation of rel name
Update concept_relationship_manual_staging  set relationship_id= trim(relationship_id);
;
-- normalisation of invalidreason
Update concept_relationship_manual_staging  set invalid_reason= null where length(invalid_reason)=0;

--Generic Stage  Is a
with tab as (
SELECT s.concept_code as concept_code_1,ss.concept_code as concept_code_2,row_number() OVER (PARTITION BY s.concept_code ORDER BY length(ss.concept_code) DESC) as rating
FROM concept_manual_staging s
JOIN concept_manual_staging ss
ON split_part(s.concept_code,'-',array_length(regexp_split_to_array(s.concept_code,'-'),1)) ~* split_part(ss.concept_code,'-',array_length(regexp_split_to_array(ss.concept_code,'-'),1))
and  s.concept_name ilike '%stage%'
and s.concept_code !~*'^Stage-\d'
       and s.standard_concept='S'
and ss.concept_code ~*'^Stage-\d')

INSERT INTO concept_relationship_manual_staging  (concept_code_1,  vocabulary_id_1, valid_start_date, valid_end_date, invalid_reason, relationship_id, concept_code_2, vocabulary_id_2)

SELECT
       concept_code_1,
          'Cancer Modifier' as vocabulary_id_1,
                         '2022-04-18'::date as valid_start_date,
                         '2099-12-31'::date as valid_end_date,
                            null         as invalid_reason,
                                'Is a'    as relationship_id,
                             concept_code_2,
                'Cancer Modifier' as vocabulary_id_2
FROM tab
where rating=1
;
--Generic Grade  Is a
with tab as (
SELECT s.concept_code as concept_code_1,ss.concept_code as concept_code_2,row_number() OVER (PARTITION BY s.concept_code ORDER BY length(ss.concept_code) DESC) as rating
FROM concept_manual_staging s
JOIN concept_manual_staging ss
ON split_part(s.concept_code,'-',array_length(regexp_split_to_array(s.concept_code,'-'),1)) ~* split_part(ss.concept_code,'-',array_length(regexp_split_to_array(ss.concept_code,'-'),1))
and  s.concept_name ilike '%Grade%'
and s.concept_code !~*'^Grade-\d'
       and s.standard_concept='S'
and ss.concept_code ~*'^Grade-\d')

INSERT INTO concept_relationship_manual_staging  (concept_code_1,  vocabulary_id_1, valid_start_date, valid_end_date, invalid_reason, relationship_id, concept_code_2, vocabulary_id_2)

SELECT
       concept_code_1,
          'Cancer Modifier' as vocabulary_id_1,
                         '2022-04-18'::date as valid_start_date,
                         '2099-12-31'::date as valid_end_date,
                            null         as invalid_reason,
                                'Is a'    as relationship_id,
                             concept_code_2,
                'Cancer Modifier' as vocabulary_id_2
FROM tab
where rating=1
;


--CHeck all the codes exist in CRMstaging
SELECT distinct *
from concept_relationship_manual_staging 
where concept_code_1 not in (
    select concept_code from concept_manual_staging
    )
;

--CHeck all the codes exist in CRMstaging
SELECT distinct concept_code_2
from concept_relationship_manual_staging 
where concept_code_2 not in (
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
and relationship_id<>'Concept replaced by'
;

-- Manual table population;
--CM
truncate concept_manual;
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
 truncate concept_relationship_manual;
INSERT INTO concept_relationship_manual (concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
SELECT distinct concept_code_1,
              concept_code_2,
       vocabulary_id_1,
         'Cancer Modifier'   vocabulary_id_2,
             relationship_id,
              valid_start_date,
       valid_end_date,
      null as invalid_reason
FROM concept_relationship_manual_staging
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


---Attributes
--Postfix if not NULL is  allways with suffix
--Version if not NULL is always with system
CREATE TABLE concept_attribute_manual_staging
    (
prefix varchar(55),
version varchar(55),
system varchar(55),
category varchar(55),
suffix varchar(55),
postfix varchar(55)
    )
    ;

SELECT devv5.FastRecreateSchema(main_schema_name=>'devv5', include_concept_ancestor=>true, include_deprecated_rels=>true, include_synonyms=>true);

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

DO
$body$
    DECLARE
        update text;
    BEGIN
        SELECT TO_CHAR(CURRENT_DATE, 'YYYY_MM_DD')
        INTO update;
        EXECUTE format('create table %I as select * from concept_synonym_manual',
                       'concept_synonym_manual_backup_' || update);

    END
$body$;

SELECT * FROM qa_tests.check_stage_tables ();

DO $_$
BEGIN
	PERFORM devv5.GenericUpdate();
END $_$;

select * from QA_TESTS.GET_CHECKS();


--12.1. first clean cache
select * from qa_tests.purge_cache();

--12.2. summary (table to check, schema to compare)
select * from qa_tests.get_summary (table_name=>'concept',pCompareWith=>'devv5');

--12.3. summary (table to check, schema to compare)
select * from qa_tests.get_summary (table_name=>'concept_relationship',pCompareWith=>'devv5');

--12.4. summary (table to check, schema to compare)
select * from qa_tests.get_summary (table_name=>'concept_ancestor',pCompareWith=>'devv5');



--13. Statistics QA checks
--changes in tables between dev-schema (current) and devv5/prodv5/any other schema

--13.1. Domain changes
select * from qa_tests.get_domain_changes(pCompareWith=>'devv5');

--13.2. Newly added concepts grouped by vocabulary_id and domain
select * from qa_tests.get_newly_concepts(pCompareWith=>'devv5');

--13.3. Standard concept changes
select * from qa_tests.get_standard_concept_changes(pCompareWith=>'devv5');

--13.4. Newly added concepts and their standard concept status
select * from qa_tests.get_newly_concepts_standard_concept_status(pCompareWith=>'devv5');

--13.5. Changes of concept mapping status grouped by target domain
select * from qa_tests.get_changes_concept_mapping(pCompareWith=>'devv5');