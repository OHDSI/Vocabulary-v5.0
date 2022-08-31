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
 SELECT
        'FIGO finding'  as concept_name,
        'Measurement'        as domain_id,
        'Cancer Modifier'    as vocabulary_id,
        'Staging/Grading' as concept_class_id,
        'C'                     standard_concept,
        'FIGO'          as concept_code,
        CURRENT_DATE         as valid_start_date,
        '2099-12-31'::date   as valid_end_date,
        NULL                 as invalid_reason

UNION ALL

 SELECT
        'RECIST finding'  as concept_name,
        'Measurement'        as domain_id,
        'Cancer Modifier'    as vocabulary_id,
        'Staging/Grading' as concept_class_id,
        'C'                     standard_concept,
        'RECIST'          as concept_code,
        CURRENT_DATE         as valid_start_date,
        '2099-12-31'::date   as valid_end_date,
        NULL                 as invalid_reason

UNION ALL

 SELECT
        'iRECIST finding'  as concept_name,
        'Measurement'        as domain_id,
        'Cancer Modifier'    as vocabulary_id,
        'Staging/Grading' as concept_class_id,
        'C'                     standard_concept,
        'iRECIST'          as concept_code,
        CURRENT_DATE         as valid_start_date,
        '2099-12-31'::date   as valid_end_date,
        NULL                 as invalid_reason

 UNION ALL

 SELECT
        'irRECIST finding'  as concept_name,
        'Measurement'        as domain_id,
        'Cancer Modifier'    as vocabulary_id,
        'Staging/Grading' as concept_class_id,
        'C'                     standard_concept,
        'irRECIST'          as concept_code,
        CURRENT_DATE         as valid_start_date,
        '2099-12-31'::date   as valid_end_date,
        NULL                 as invalid_reason

 UNION ALL

 SELECT
        'AJCC/UICC finding'  as concept_name,
        'Measurement'        as domain_id,
        'Cancer Modifier'    as vocabulary_id,
        'Staging/Grading' as concept_class_id,
        'C'                     standard_concept,
        'AJCC/UICC'          as concept_code,
        CURRENT_DATE         as valid_start_date,
        '2099-12-31'::date   as valid_end_date,
        NULL                 as invalid_reason

 UNION ALL

 SELECT
        'AJCC finding'  as concept_name,
        'Measurement'        as domain_id,
        'Cancer Modifier'    as vocabulary_id,
        'Staging/Grading' as concept_class_id,
        'C'                     standard_concept,
        'AJCC'          as concept_code,
        CURRENT_DATE         as valid_start_date,
        '2099-12-31'::date   as valid_end_date,
        NULL                 as invalid_reason

 UNION ALL

 SELECT
        'Ann Arbor finding'  as concept_name,
        'Measurement'        as domain_id,
        'Cancer Modifier'    as vocabulary_id,
        'Staging/Grading' as concept_class_id,
        'C'                     standard_concept,
        'Ann_Arbor'          as concept_code,
        CURRENT_DATE         as valid_start_date,
        '2099-12-31'::date   as valid_end_date,
        NULL                 as invalid_reason

 UNION ALL

 SELECT
        'Binet finding'  as concept_name,
        'Measurement'        as domain_id,
        'Cancer Modifier'    as vocabulary_id,
        'Staging/Grading' as concept_class_id,
        'C'                     standard_concept,
        'Binet'          as concept_code,
        CURRENT_DATE         as valid_start_date,
        '2099-12-31'::date   as valid_end_date,
        NULL                 as invalid_reason

 UNION ALL

 SELECT
        'CHOI finding'  as concept_name,
        'Measurement'        as domain_id,
        'Cancer Modifier'    as vocabulary_id,
        'Staging/Grading' as concept_class_id,
        'C'                     standard_concept,
        'CHOI'          as concept_code,
        CURRENT_DATE         as valid_start_date,
        '2099-12-31'::date   as valid_end_date,
        NULL                 as invalid_reason

 UNION ALL

 SELECT
        'Clark finding'  as concept_name,
        'Measurement'        as domain_id,
        'Cancer Modifier'    as vocabulary_id,
        'Staging/Grading' as concept_class_id,
        'C'                     standard_concept,
        'Clark'          as concept_code,
        CURRENT_DATE         as valid_start_date,
        '2099-12-31'::date   as valid_end_date,
        NULL                 as invalid_reason

 UNION ALL

 SELECT
        'COG finding'  as concept_name,
        'Measurement'        as domain_id,
        'Cancer Modifier'    as vocabulary_id,
        'Staging/Grading' as concept_class_id,
        'C'                     standard_concept,
        'COG'          as concept_code,
        CURRENT_DATE         as valid_start_date,
        '2099-12-31'::date   as valid_end_date,
        NULL                 as invalid_reason

 UNION ALL

 SELECT
        'Deauville finding'  as concept_name,
        'Measurement'        as domain_id,
        'Cancer Modifier'    as vocabulary_id,
        'Staging/Grading' as concept_class_id,
        'C'                     standard_concept,
        'Deauville'          as concept_code,
        CURRENT_DATE         as valid_start_date,
        '2099-12-31'::date   as valid_end_date,
        NULL                 as invalid_reason

 UNION ALL

 SELECT
        'Dukes finding'  as concept_name,
        'Measurement'        as domain_id,
        'Cancer Modifier'    as vocabulary_id,
        'Staging/Grading' as concept_class_id,
        'C'                     standard_concept,
        'Dukes'          as concept_code,
        CURRENT_DATE         as valid_start_date,
        '2099-12-31'::date   as valid_end_date,
        NULL                 as invalid_reason

 UNION ALL

 SELECT
        'Enneking finding'  as concept_name,
        'Measurement'        as domain_id,
        'Cancer Modifier'    as vocabulary_id,
        'Staging/Grading' as concept_class_id,
        'C'                     standard_concept,
        'Enneking'          as concept_code,
        CURRENT_DATE         as valid_start_date,
        '2099-12-31'::date   as valid_end_date,
        NULL                 as invalid_reason

 UNION ALL

 SELECT
        'ENSAT finding'  as concept_name,
        'Measurement'        as domain_id,
        'Cancer Modifier'    as vocabulary_id,
        'Staging/Grading' as concept_class_id,
        'C'                     standard_concept,
        'ENSAT'          as concept_code,
        CURRENT_DATE         as valid_start_date,
        '2099-12-31'::date   as valid_end_date,
        NULL                 as invalid_reason
 UNION ALL

 SELECT
        'Evans finding'  as concept_name,
        'Measurement'        as domain_id,
        'Cancer Modifier'    as vocabulary_id,
        'Staging/Grading' as concept_class_id,
        'C'                     standard_concept,
        'Evans'          as concept_code,
        CURRENT_DATE         as valid_start_date,
        '2099-12-31'::date   as valid_end_date,
        NULL                 as invalid_reason

 UNION ALL

 SELECT
        'Gleason finding'  as concept_name,
        'Measurement'        as domain_id,
        'Cancer Modifier'    as vocabulary_id,
        'Staging/Grading' as concept_class_id,
        'C'                     standard_concept,
        'Gleason'          as concept_code,
        CURRENT_DATE         as valid_start_date,
        '2099-12-31'::date   as valid_end_date,
        NULL                 as invalid_reason

 UNION ALL

 SELECT
        'INRG finding'  as concept_name,
        'Measurement'        as domain_id,
        'Cancer Modifier'    as vocabulary_id,
        'Staging/Grading' as concept_class_id,
        'C'                     standard_concept,
        'INRG'          as concept_code,
        CURRENT_DATE         as valid_start_date,
        '2099-12-31'::date   as valid_end_date,
        NULL                 as invalid_reason

 UNION ALL

 SELECT
        'INSS finding'  as concept_name,
        'Measurement'        as domain_id,
        'Cancer Modifier'    as vocabulary_id,
        'Staging/Grading' as concept_class_id,
        'C'                     standard_concept,
        'INSS'          as concept_code,
        CURRENT_DATE         as valid_start_date,
        '2099-12-31'::date   as valid_end_date,
        NULL                 as invalid_reason

 UNION ALL

 SELECT
        'IRSG finding'  as concept_name,
        'Measurement'        as domain_id,
        'Cancer Modifier'    as vocabulary_id,
        'Staging/Grading' as concept_class_id,
        'C'                     standard_concept,
        'IRSG'          as concept_code,
        CURRENT_DATE         as valid_start_date,
        '2099-12-31'::date   as valid_end_date,
        NULL                 as invalid_reason

 UNION ALL

 SELECT
        'INSS finding'  as concept_name,
        'Measurement'        as domain_id,
        'Cancer Modifier'    as vocabulary_id,
        'Staging/Grading' as concept_class_id,
        'C'                     standard_concept,
        'INSS'          as concept_code,
        CURRENT_DATE         as valid_start_date,
        '2099-12-31'::date   as valid_end_date,
        NULL                 as invalid_reason

 UNION ALL

 SELECT
        'IRS-modified finding'  as concept_name,
        'Measurement'        as domain_id,
        'Cancer Modifier'    as vocabulary_id,
        'Staging/Grading' as concept_class_id,
        'C'                     standard_concept,
        'IRSm'          as concept_code,
        CURRENT_DATE         as valid_start_date,
        '2099-12-31'::date   as valid_end_date,
        NULL                 as invalid_reason

 UNION ALL

 SELECT
        'ISS finding'  as concept_name,
        'Measurement'        as domain_id,
        'Cancer Modifier'    as vocabulary_id,
        'Staging/Grading' as concept_class_id,
        'C'                     standard_concept,
        'ISS'          as concept_code,
        CURRENT_DATE         as valid_start_date,
        '2099-12-31'::date   as valid_end_date,
        NULL                 as invalid_reason

 UNION ALL

 SELECT
        'Lugano finding'  as concept_name,
        'Measurement'        as domain_id,
        'Cancer Modifier'    as vocabulary_id,
        'Staging/Grading' as concept_class_id,
        'C'                     standard_concept,
        'Lugano'          as concept_code,
        CURRENT_DATE         as valid_start_date,
        '2099-12-31'::date   as valid_end_date,
        NULL                 as invalid_reason

 UNION ALL

 SELECT
        'Mandard finding'  as concept_name,
        'Measurement'        as domain_id,
        'Cancer Modifier'    as vocabulary_id,
        'Staging/Grading' as concept_class_id,
        'C'                     standard_concept,
        'Mandard'          as concept_code,
        CURRENT_DATE         as valid_start_date,
        '2099-12-31'::date   as valid_end_date,
        NULL                 as invalid_reason

 UNION ALL

 SELECT
        'Masaoka-Koga finding'  as concept_name,
        'Measurement'        as domain_id,
        'Cancer Modifier'    as vocabulary_id,
        'Staging/Grading' as concept_class_id,
        'C'                     standard_concept,
        'Masaoka_Koga'          as concept_code,
        CURRENT_DATE         as valid_start_date,
        '2099-12-31'::date   as valid_end_date,
        NULL                 as invalid_reason
;