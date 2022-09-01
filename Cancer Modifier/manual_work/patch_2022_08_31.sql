--concept_relationship_manual_backup_2022_08_31;
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

--concept_manual_backup_2022_08_31;
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

TRUNCATE concept_manual;
TRUNCATE concept_relationship_manual;

-- Per WG request
 INSERT INTO concept_manual (concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
 SELECT
        'Initial Diagnosis'  as concept_name,
        'Measurement'        as domain_id,
        'Cancer Modifier'    as vocabulary_id,
        'Extension/Invasion' as concept_class_id,
        'S'                     standard_concept,
        'init_diag'          as concept_code,
        CURRENT_DATE         as valid_start_date,
        '2099-12-31'::date   as valid_end_date,
        NULL                 as invalid_reason
;

--Update of distant lymph nodes
INSERT  INTO concept_manual (concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
SELECT
    'Distant spread to lymph node'   as concept_name,
       domain_id,
       vocabulary_id,
       concept_class_id,
       standard_concept,
       concept_code,
       valid_start_date,
       valid_end_date,
       invalid_reason
FROM concept
where concept_id =36769243 --  Distant Lymph Nodes
;

--Update of  lymph nodes
INSERT  INTO concept_manual (concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
SELECT
    'Spread to lymph node'   as concept_name,
       domain_id,
       vocabulary_id,
       concept_class_id,
       standard_concept,
       concept_code,
       valid_start_date,
       valid_end_date,
       invalid_reason
FROM concept
where concept_id =36768587	--	Lymph Nodes
;
INSERT  INTO concept_manual (concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
SELECT
    'Regional spread to lymph node'   as concept_name,
       domain_id,
       vocabulary_id,
       concept_class_id,
       standard_concept,
       concept_code,
       valid_start_date,
       valid_end_date,
       invalid_reason
FROM concept
where concept_id =36769269	--	Regional Lymph Nodes
;

--Relationship Creation
INSERT INTO concept_relationship_manual (concept_code_1, vocabulary_id_1,  relationship_id, valid_start_date, valid_end_date, invalid_reason,concept_code_2,vocabulary_id_2)
SELECT c.concept_code as concept_code_1,
       c.vocabulary_id as vocabulary_id_1,
       'Is a' as reationship_id,
       CURRENT_DATE         as valid_start_date,
        '2099-12-31'::date   as valid_end_date,
        NULL                 as invalid_reason,
       c2.concept_code as concept_code_2,
       c2.vocabulary_id as vocabulary_id_2
FROM concept_manual c
JOIN concept_manual c2
on c.concept_name ilike '%' || c2.concept_name
and c.concept_name<>c2.concept_name
UNION ALL
SELECT c.concept_code as concept_code_1,c.vocabulary_id as vocabulary_id_1,
       'Is a' as reationship_id,
       CURRENT_DATE         as valid_start_date,
        '2099-12-31'::date   as valid_end_date,
        NULL                 as invalid_reason,
       c2.concept_code as concept_code_2,c2.vocabulary_id as vocabulary_id_2
FROM concept_manual c
JOIN concept c2
on c2.concept_id= 36769180	--	Metastasis
and c.concept_code = 	'OMOP4998920'	-- Distant Lymph Nodes
;

--Classifiers
WITH classifiers as (
    SELECT 'FIGO finding'     as concept_name,
           'Measurement'      as domain_id,
           'Cancer Modifier'  as vocabulary_id,
           'Staging/Grading'  as concept_class_id,
           'C'                   standard_concept,
           'FIGO'             as concept_code,
           CURRENT_DATE       as valid_start_date,
           '2099-12-31'::date as valid_end_date,
           NULL               as invalid_reason

    UNION ALL

    SELECT 'RECIST finding'   as concept_name,
           'Measurement'      as domain_id,
           'Cancer Modifier'  as vocabulary_id,
           'Staging/Grading'  as concept_class_id,
           'C'                   standard_concept,
           'RECIST'           as concept_code,
           CURRENT_DATE       as valid_start_date,
           '2099-12-31'::date as valid_end_date,
           NULL               as invalid_reason

    UNION ALL

    SELECT 'iRECIST finding'  as concept_name,
           'Measurement'      as domain_id,
           'Cancer Modifier'  as vocabulary_id,
           'Staging/Grading'  as concept_class_id,
           'C'                   standard_concept,
           'iRECIST'          as concept_code,
           CURRENT_DATE       as valid_start_date,
           '2099-12-31'::date as valid_end_date,
           NULL               as invalid_reason

    UNION ALL

    SELECT 'irRECIST finding' as concept_name,
           'Measurement'      as domain_id,
           'Cancer Modifier'  as vocabulary_id,
           'Staging/Grading'  as concept_class_id,
           'C'                   standard_concept,
           'irRECIST'         as concept_code,
           CURRENT_DATE       as valid_start_date,
           '2099-12-31'::date as valid_end_date,
           NULL               as invalid_reason

    UNION ALL

    SELECT 'AJCC/UICC finding' as concept_name,
           'Measurement'       as domain_id,
           'Cancer Modifier'   as vocabulary_id,
           'Staging/Grading'   as concept_class_id,
           'C'                    standard_concept,
           'AJCC/UICC'         as concept_code,
           CURRENT_DATE        as valid_start_date,
           '2099-12-31'::date  as valid_end_date,
           NULL                as invalid_reason

    UNION ALL

    SELECT 'AJCC finding'     as concept_name,
           'Measurement'      as domain_id,
           'Cancer Modifier'  as vocabulary_id,
           'Staging/Grading'  as concept_class_id,
           'C'                   standard_concept,
           'AJCC'             as concept_code,
           CURRENT_DATE       as valid_start_date,
           '2099-12-31'::date as valid_end_date,
           NULL               as invalid_reason

    UNION ALL

    SELECT 'Ann Arbor finding' as concept_name,
           'Measurement'       as domain_id,
           'Cancer Modifier'   as vocabulary_id,
           'Staging/Grading'   as concept_class_id,
           'C'                    standard_concept,
           'Ann_Arbor'         as concept_code,
           CURRENT_DATE        as valid_start_date,
           '2099-12-31'::date  as valid_end_date,
           NULL                as invalid_reason

    UNION ALL

    SELECT 'Binet finding'    as concept_name,
           'Measurement'      as domain_id,
           'Cancer Modifier'  as vocabulary_id,
           'Staging/Grading'  as concept_class_id,
           'C'                   standard_concept,
           'Binet'            as concept_code,
           CURRENT_DATE       as valid_start_date,
           '2099-12-31'::date as valid_end_date,
           NULL               as invalid_reason

    UNION ALL

    SELECT 'CHOI finding'     as concept_name,
           'Measurement'      as domain_id,
           'Cancer Modifier'  as vocabulary_id,
           'Staging/Grading'  as concept_class_id,
           'C'                   standard_concept,
           'CHOI'             as concept_code,
           CURRENT_DATE       as valid_start_date,
           '2099-12-31'::date as valid_end_date,
           NULL               as invalid_reason

    UNION ALL

    SELECT 'Clark finding'    as concept_name,
           'Measurement'      as domain_id,
           'Cancer Modifier'  as vocabulary_id,
           'Staging/Grading'  as concept_class_id,
           'C'                   standard_concept,
           'Clark'            as concept_code,
           CURRENT_DATE       as valid_start_date,
           '2099-12-31'::date as valid_end_date,
           NULL               as invalid_reason

    UNION ALL

    SELECT 'COG finding'      as concept_name,
           'Measurement'      as domain_id,
           'Cancer Modifier'  as vocabulary_id,
           'Staging/Grading'  as concept_class_id,
           'C'                   standard_concept,
           'COG'              as concept_code,
           CURRENT_DATE       as valid_start_date,
           '2099-12-31'::date as valid_end_date,
           NULL               as invalid_reason

    UNION ALL

    SELECT 'Deauville finding' as concept_name,
           'Measurement'       as domain_id,
           'Cancer Modifier'   as vocabulary_id,
           'Staging/Grading'   as concept_class_id,
           'C'                    standard_concept,
           'Deauville'         as concept_code,
           CURRENT_DATE        as valid_start_date,
           '2099-12-31'::date  as valid_end_date,
           NULL                as invalid_reason

    UNION ALL

    SELECT 'Dukes finding'    as concept_name,
           'Measurement'      as domain_id,
           'Cancer Modifier'  as vocabulary_id,
           'Staging/Grading'  as concept_class_id,
           'C'                   standard_concept,
           'Dukes'            as concept_code,
           CURRENT_DATE       as valid_start_date,
           '2099-12-31'::date as valid_end_date,
           NULL               as invalid_reason

    UNION ALL

    SELECT 'Enneking finding' as concept_name,
           'Measurement'      as domain_id,
           'Cancer Modifier'  as vocabulary_id,
           'Staging/Grading'  as concept_class_id,
           'C'                   standard_concept,
           'Enneking'         as concept_code,
           CURRENT_DATE       as valid_start_date,
           '2099-12-31'::date as valid_end_date,
           NULL               as invalid_reason

    UNION ALL

    SELECT 'ENSAT finding'    as concept_name,
           'Measurement'      as domain_id,
           'Cancer Modifier'  as vocabulary_id,
           'Staging/Grading'  as concept_class_id,
           'C'                   standard_concept,
           'ENSAT'            as concept_code,
           CURRENT_DATE       as valid_start_date,
           '2099-12-31'::date as valid_end_date,
           NULL               as invalid_reason
    UNION ALL

    SELECT 'Evans finding'    as concept_name,
           'Measurement'      as domain_id,
           'Cancer Modifier'  as vocabulary_id,
           'Staging/Grading'  as concept_class_id,
           'C'                   standard_concept,
           'Evans'            as concept_code,
           CURRENT_DATE       as valid_start_date,
           '2099-12-31'::date as valid_end_date,
           NULL               as invalid_reason

    UNION ALL

    SELECT 'Gleason finding'  as concept_name,
           'Measurement'      as domain_id,
           'Cancer Modifier'  as vocabulary_id,
           'Staging/Grading'  as concept_class_id,
           'C'                   standard_concept,
           'Gleason'          as concept_code,
           CURRENT_DATE       as valid_start_date,
           '2099-12-31'::date as valid_end_date,
           NULL               as invalid_reason

    UNION ALL

    SELECT 'INRG finding'     as concept_name,
           'Measurement'      as domain_id,
           'Cancer Modifier'  as vocabulary_id,
           'Staging/Grading'  as concept_class_id,
           'C'                   standard_concept,
           'INRG'             as concept_code,
           CURRENT_DATE       as valid_start_date,
           '2099-12-31'::date as valid_end_date,
           NULL               as invalid_reason

    UNION ALL

    SELECT 'IRSG finding'     as concept_name,
           'Measurement'      as domain_id,
           'Cancer Modifier'  as vocabulary_id,
           'Staging/Grading'  as concept_class_id,
           'C'                   standard_concept,
           'IRSG'             as concept_code,
           CURRENT_DATE       as valid_start_date,
           '2099-12-31'::date as valid_end_date,
           NULL               as invalid_reason

    UNION ALL

    SELECT 'INSS finding'     as concept_name,
           'Measurement'      as domain_id,
           'Cancer Modifier'  as vocabulary_id,
           'Staging/Grading'  as concept_class_id,
           'C'                   standard_concept,
           'INSS'             as concept_code,
           CURRENT_DATE       as valid_start_date,
           '2099-12-31'::date as valid_end_date,
           NULL               as invalid_reason

    UNION ALL

    SELECT 'IRS-modified finding' as concept_name,
           'Measurement'          as domain_id,
           'Cancer Modifier'      as vocabulary_id,
           'Staging/Grading'      as concept_class_id,
           'C'                       standard_concept,
           'IRSm'                 as concept_code,
           CURRENT_DATE           as valid_start_date,
           '2099-12-31'::date     as valid_end_date,
           NULL                   as invalid_reason

    UNION ALL

    SELECT 'ISS finding'      as concept_name,
           'Measurement'      as domain_id,
           'Cancer Modifier'  as vocabulary_id,
           'Staging/Grading'  as concept_class_id,
           'C'                   standard_concept,
           'ISS'              as concept_code,
           CURRENT_DATE       as valid_start_date,
           '2099-12-31'::date as valid_end_date,
           NULL               as invalid_reason

    UNION ALL

    SELECT 'Lugano finding'   as concept_name,
           'Measurement'      as domain_id,
           'Cancer Modifier'  as vocabulary_id,
           'Staging/Grading'  as concept_class_id,
           'C'                   standard_concept,
           'Lugano'           as concept_code,
           CURRENT_DATE       as valid_start_date,
           '2099-12-31'::date as valid_end_date,
           NULL               as invalid_reason

    UNION ALL

    SELECT 'Mandard finding'  as concept_name,
           'Measurement'      as domain_id,
           'Cancer Modifier'  as vocabulary_id,
           'Staging/Grading'  as concept_class_id,
           'C'                   standard_concept,
           'Mandard'          as concept_code,
           CURRENT_DATE       as valid_start_date,
           '2099-12-31'::date as valid_end_date,
           NULL               as invalid_reason

    UNION ALL

    SELECT 'Masaoka-Koga finding' as concept_name,
           'Measurement'          as domain_id,
           'Cancer Modifier'      as vocabulary_id,
           'Staging/Grading'      as concept_class_id,
           'C'                       standard_concept,
           'Masaoka_Koga'         as concept_code,
           CURRENT_DATE           as valid_start_date,
           '2099-12-31'::date     as valid_end_date,
           NULL                   as invalid_reason

    UNION ALL

    SELECT 'Nottingham finding' as concept_name,
           'Measurement'        as domain_id,
           'Cancer Modifier'    as vocabulary_id,
           'Staging/Grading'    as concept_class_id,
           'C'                     standard_concept,
           'Nottingham'         as concept_code,
           CURRENT_DATE         as valid_start_date,
           '2099-12-31'::date   as valid_end_date,
           NULL                 as invalid_reason
    UNION ALL

    SELECT 'PERCIST finding'  as concept_name,
           'Measurement'      as domain_id,
           'Cancer Modifier'  as vocabulary_id,
           'Staging/Grading'  as concept_class_id,
           'C'                   standard_concept,
           'PERCIST'          as concept_code,
           CURRENT_DATE       as valid_start_date,
           '2099-12-31'::date as valid_end_date,
           NULL               as invalid_reason
    UNION ALL

    SELECT 'POG finding'      as concept_name,
           'Measurement'      as domain_id,
           'Cancer Modifier'  as vocabulary_id,
           'Staging/Grading'  as concept_class_id,
           'C'                   standard_concept,
           'POG'              as concept_code,
           CURRENT_DATE       as valid_start_date,
           '2099-12-31'::date as valid_end_date,
           NULL               as invalid_reason

    UNION ALL

    SELECT 'PRETEXT finding'  as concept_name,
           'Measurement'      as domain_id,
           'Cancer Modifier'  as vocabulary_id,
           'Staging/Grading'  as concept_class_id,
           'C'                   standard_concept,
           'PRETEXT'          as concept_code,
           CURRENT_DATE       as valid_start_date,
           '2099-12-31'::date as valid_end_date,
           NULL               as invalid_reason

    UNION ALL

    SELECT 'RANO finding'     as concept_name,
           'Measurement'      as domain_id,
           'Cancer Modifier'  as vocabulary_id,
           'Staging/Grading'  as concept_class_id,
           'C'                   standard_concept,
           'RANO'             as concept_code,
           CURRENT_DATE       as valid_start_date,
           '2099-12-31'::date as valid_end_date,
           NULL               as invalid_reason
    UNION ALL

    SELECT 'RISS finding'     as concept_name,
           'Measurement'      as domain_id,
           'Cancer Modifier'  as vocabulary_id,
           'Staging/Grading'  as concept_class_id,
           'C'                   standard_concept,
           'RISS'             as concept_code,
           CURRENT_DATE       as valid_start_date,
           '2099-12-31'::date as valid_end_date,
           NULL               as invalid_reason
    UNION ALL

    SELECT 'Rai finding'      as concept_name,
           'Measurement'      as domain_id,
           'Cancer Modifier'  as vocabulary_id,
           'Staging/Grading'  as concept_class_id,
           'C'                   standard_concept,
           'Rai'              as concept_code,
           CURRENT_DATE       as valid_start_date,
           '2099-12-31'::date as valid_end_date,
           NULL               as invalid_reason
    UNION ALL

    SELECT 'Reese-Ellsworth finding' as concept_name,
           'Measurement'             as domain_id,
           'Cancer Modifier'         as vocabulary_id,
           'Staging/Grading'         as concept_class_id,
           'C'                          standard_concept,
           'Reese_Ellsworth'         as concept_code,
           CURRENT_DATE              as valid_start_date,
           '2099-12-31'::date        as valid_end_date,
           NULL                      as invalid_reason

    UNION ALL

    SELECT 'SIOP/COG/NWTSG finding' as concept_name,
           'Measurement'            as domain_id,
           'Cancer Modifier'        as vocabulary_id,
           'Staging/Grading'        as concept_class_id,
           'C'                         standard_concept,
           'SIOP/COG/NWTSG'         as concept_code,
           CURRENT_DATE             as valid_start_date,
           '2099-12-31'::date       as valid_end_date,
           NULL                     as invalid_reason
    UNION ALL

    SELECT 'WHO finding'      as concept_name,
           'Measurement'      as domain_id,
           'Cancer Modifier'  as vocabulary_id,
           'Staging/Grading'  as concept_class_id,
           'C'                   standard_concept,
           'WHO'              as concept_code,
           CURRENT_DATE       as valid_start_date,
           '2099-12-31'::date as valid_end_date,
           NULL               as invalid_reason
    UNION ALL

    SELECT 'mRai finding'     as concept_name,
           'Measurement'      as domain_id,
           'Cancer Modifier'  as vocabulary_id,
           'Staging/Grading'  as concept_class_id,
           'C'                   standard_concept,
           'mRai'             as concept_code,
           CURRENT_DATE       as valid_start_date,
           '2099-12-31'::date as valid_end_date,
           NULL               as invalid_reason

        UNION ALL

    SELECT 'BCLC finding'     as concept_name,
           'Measurement'      as domain_id,
           'Cancer Modifier'  as vocabulary_id,
           'Staging/Grading'  as concept_class_id,
           'C'                   standard_concept,
           'BCLC'             as concept_code,
           CURRENT_DATE       as valid_start_date,
           '2099-12-31'::date as valid_end_date,
           NULL               as invalid_reason

            UNION ALL

    SELECT 'Durie/Salmon finding'     as concept_name,
           'Measurement'      as domain_id,
           'Cancer Modifier'  as vocabulary_id,
           'Staging/Grading'  as concept_class_id,
           'C'                   standard_concept,
           'DS'             as concept_code,
           CURRENT_DATE       as valid_start_date,
           '2099-12-31'::date as valid_end_date,
           NULL               as invalid_reason
)

INSERT  INTO concept_manual (concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)

SELECT concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason
FROM classifiers
;

--CR relationships for Classifiers
WITH
     relationships as (
         SELECT
                c.concept_id,
                c.concept_code                                                                       as concept_code_1,
                c.vocabulary_id                                                                      as vocabulary_id_1,
                'Is a'                                                                         as relationship_id,
                CURRENT_DATE                                                                         as valid_start_date,
                '2099-12-31'::date                                                                   as valid_end_date,
                NULL                                                                                 as invalid_reason,
                a.concept_code                                                                       as concept_code_2,
                a.vocabulary_id                                                                      as vocabulary_id_2,
                row_number()
                OVER (PARTITION BY c.concept_code ORDER BY length(a.concept_code) DESC)              AS rating_in_section

         FROM concept c
         left JOIN concept_manual a
                    ON c.concept_code ilike '%' || a.concept_code || '%'
         where c.concept_class_id = 'Staging/Grading'
           and c.standard_concept = 'S'
           and a.concept_code is NOT null
         and c.concept_code <>'Stage-DS'
     )
, tab as (
         SELECT r.concept_id,
                concept_code_1,
                vocabulary_id_1,
                relationship_id,
                r.valid_start_date,
                r.valid_end_date,
                r.invalid_reason,
                concept_code_2,
                vocabulary_id_2,
                rating_in_section,
                cc.concept_name,
                cc.concept_code,
                cc.vocabulary_id,
            row_number()    OVER (PARTITION BY r.concept_id ORDER BY min_levels_of_separation DESC)              AS ancest
FROM relationships r
JOIN devv5.concept_ancestor ca
on r.concept_id=descendant_concept_id
JOIN devv5.concept cc
on ancestor_concept_id=cc.concept_id
where rating_in_section=1
    and cc.concept_code ilike '%' || r.concept_code_2 || '%')
INSERT INTO concept_relationship_manual (concept_code_1, vocabulary_id_1,  relationship_id, valid_start_date, valid_end_date, invalid_reason,concept_code_2,vocabulary_id_2)

SELECT distinct
               concept_code                                                                       as concept_code_1,
                vocabulary_id                                                                      as vocabulary_id_1,
                'Is a'                                                                         as relationship_id,
                CURRENT_DATE                                                                         as valid_start_date,
                '2099-12-31'::date                                                                   as valid_end_date,
                NULL                                                                                 as invalid_reason,
                concept_code_2,
                vocabulary_id_2
FROM tab
where ancest=1
;



