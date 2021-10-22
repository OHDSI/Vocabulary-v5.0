--The file emulates stage tables creation only and used to populate the Manual tables
--Table Preparation
--cm_concept_dimension the manual File  https://docs.google.com/spreadsheets/d/10INTlC8XeoAFRzkSbOc3rS37ilJn979qlvpkEHOaOYU/edit#gid=0
DROP TABLE IF EXISTS cm_concept_dimension;
CREATE TABLE cm_concept_dimension
(
    old_concept_code	varchar(50),
    old_concept_name varchar(255),
    new_concept_name	 varchar(255),
    status	varchar(50),
    remap_to varchar(50),
    changed_class varchar(20)
)
;
--Table Preparation
--source_mapping_dimension the manual File  https://docs.google.com/spreadsheets/d/1vUD_vgTCVtCFkE_IM9hIBAOaOsf9AyBQN0HMoobfjcQ/edit#gid=0
DROP TABLE IF EXISTS source_mapping_dimension;
CREATE TABLE source_mapping_dimension
(
    source_vocabulary_id varchar(20),
        source_code varchar(50),
        source_name varchar(255),
        target_concept_name varchar(255),
        target_concept_code varchar(50),
        target_vocabulary_id varchar(20)
)
;

--cancer_mod_dimension the manual File  https://docs.google.com/spreadsheets/d/1K7jeNwAy8b-L6RGFq_mte94jp3R8yza8G2LZZgicszg/edit#gid=0
DROP TABLE IF EXISTS cancer_mod_dimension;
CREATE TABLE cancer_mod_dimension
(
    concept_name varchar(255),
    site	varchar(255),
    meas varchar(255)
)
;

--FROM source_mapping_dimension smd the manual File  https://docs.google.com/spreadsheets/d/1K7jeNwAy8b-L6RGFq_mte94jp3R8yza8G2LZZgicszg/edit
DROP TABLE IF EXISTS  cancer_mod_dimension_atr ;
CREATE TABLE  cancer_mod_dimension_atr
(
    anc_atr varchar(255),
    desc_Atr	varchar(255)
)
;

--Codes to be Renamed Insert
INSERT INTO concept_manual (
                            concept_name,
                            domain_id,
                            vocabulary_id,
                            concept_class_id,
                            standard_concept,
                            concept_code,
                            valid_start_date,
                            valid_end_date,
                            invalid_reason)
SELECT new_concept_name,
       'Measurement',
       'Cancer Modifier',
       'Dimension',
       'S',
       old_concept_code,
       c.valid_start_date,
       c.valid_end_date,
       NULL
FROM cm_concept_dimension a
JOIN devv5.concept c ON c.concept_code = a.old_concept_code AND c.vocabulary_id = 'Cancer Modifier'
WHERE status = 'Rename'
;

--Concept Class Switch
INSERT INTO concept_manual ( concept_name,
                            domain_id,
                            vocabulary_id,
                            concept_class_id,
                            standard_concept,
                            concept_code,
                            valid_start_date,
                            valid_end_date,
                            invalid_reason)
SELECT old_concept_name,
       'Measurement',
       'Cancer Modifier',
       changed_class,
       'S',
       old_concept_code,
       c.valid_start_date,
       c.valid_end_date,
       NULL
FROM cm_concept_dimension a
         JOIN devv5.concept c
             ON c.concept_code = a.old_concept_code
                    AND c.vocabulary_id = 'Cancer Modifier'
WHERE status = 'Change_class'
;


-- Concepts to be Deprecated
INSERT INTO concept_manual (concept_name,
                            domain_id,
                            vocabulary_id,
                            concept_class_id,
                            standard_concept,
                            concept_code,
                            valid_start_date,
                            valid_end_date,
                            invalid_reason)
SELECT old_concept_name,
       'Measurement',
       'Cancer Modifier',
       'Dimension',
       NULL,
       old_concept_code,
       c.valid_start_date,
       CURRENT_DATE,
       'D'
FROM cm_concept_dimension a
         JOIN devv5.concept c ON c.concept_code = a.old_concept_code AND c.vocabulary_id = 'Cancer Modifier'
WHERE status = 'Deprecate'
;

-- Concepts to be Updatated Remapped
INSERT INTO concept_manual (concept_name,
                            domain_id,
                            vocabulary_id,
                            concept_class_id,
                            standard_concept,
                            concept_code,
                            valid_start_date,
                            valid_end_date,
                            invalid_reason)
SELECT old_concept_name,
       'Measurement',
       'Cancer Modifier',
       'Dimension',
       NULL,
       old_concept_code,
       c.valid_start_date,
       CURRENT_DATE,
       'U'
FROM cm_concept_dimension a
         JOIN devv5.concept c ON c.concept_code = a.old_concept_code AND c.vocabulary_id = 'Cancer Modifier'
WHERE status = 'Remap'
;

--New concepts from Dimension Class to be added
INSERT INTO concept_manual (concept_name,
                            domain_id,
                            vocabulary_id,
                            concept_class_id,
                            standard_concept,
                            concept_code,
                            valid_start_date,
                            valid_end_date,
                            invalid_reason)
SELECT new_concept_name,
       'Measurement',
       'Cancer Modifier',
       'Dimension',
       'S',
       'OMOP' || NEXTVAL('omop_seq') AS concept_code,
       CURRENT_DATE,
       TO_DATE('20991231', 'yyyyMMdd'),
       NULL
FROM cm_concept_dimension
WHERE status = 'Add_new'
;

--New concepts with Attributive Chars to be added
-- Morph Abnormality that was exactly measured
INSERT INTO concept_manual (
                            concept_name,
                            domain_id,
                            vocabulary_id,
                            concept_class_id,
                            standard_concept,
                            concept_code,
                            valid_start_date,
                            valid_end_date,
                            invalid_reason)
SELECT DISTINCT site,
                'Observation',
                'Cancer Modifier',
                'Morph Abnormality',
                NULL,
                'OMOP' || NEXTVAL('omop_seq') AS concept_code,
                CURRENT_DATE,
                TO_DATE('20991231', 'yyyyMMdd'),
                NULL
FROM (SELECT DISTINCT site FROM cancer_mod_dimension) a
;

--New concepts with Attributive Chars to be added
-- Type of Measurement performed
INSERT INTO concept_manual (
                            concept_name,
                            domain_id,
                            vocabulary_id,
                            concept_class_id,
                            standard_concept,
                            concept_code,
                            valid_start_date,
                            valid_end_date,
                            invalid_reason
                            )
SELECT DISTINCT meas,
                'Measurement',
                'Cancer Modifier',
                'Qualifier Value',
                NULL,
                'OMOP' || NEXTVAL('omop_seq') AS concept_code,
                CURRENT_DATE,
                TO_DATE('20991231', 'yyyyMMdd'),
                NULL
FROM (SELECT DISTINCT meas FROM cancer_mod_dimension) a
;

-- To make NAACCR concepts Non-Standard
INSERT INTO concept_manual (concept_name,
                            domain_id,
                            vocabulary_id,
                            concept_class_id,
                            standard_concept,
                            concept_code,
                            valid_start_date,
                            valid_end_date,
                            invalid_reason)
SELECT DISTINCT c.concept_name,
       c.domain_id,
       c.vocabulary_id,
       c.concept_class_id,
       null as standard_concept,
       c.concept_code,
       c.valid_start_date,
       c.valid_end_date,
       c.invalid_reason
FROM source_mapping_dimension m
         JOIN concept c ON m.source_code = c.concept_code
WHERE m.source_vocabulary_id = c.vocabulary_id
and c.vocabulary_id = 'NAACCR';


--CRM Population
INSERT INTO concept_relationship_manual (concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2,
                                         relationship_id, valid_start_date, valid_end_date, invalid_reason)
SELECT c.concept_code                  AS cocnept_code_1,
       c1.concept_code                 AS cocnept_code_2,
       'Cancer Modifier'               AS vocabulary_id_1,
       'Cancer Modifier'               AS vocabulary_id_2,
       'Inheres in'                    AS relationship_id,
       c1.valid_start_date,
       TO_DATE('20991231', 'yyyyMMdd') AS valid_end_date,
       c1.invalid_reason
FROM cancer_mod_dimension cm
         JOIN concept_manual c ON cm.concept_name = c.concept_name
         JOIN concept_manual c1 ON cm.site = c1.concept_name
    AND c.concept_name != c1.concept_name

UNION

SELECT c.concept_code                  AS cocnept_code_1,
       c1.concept_code                 AS cocnept_code_2,
       'Cancer Modifier'               AS vocabulary_id_1,
       'Cancer Modifier'               AS vocabulary_id_2,
       'Has property'                  AS relationship_id,
       c1.valid_start_date,
       TO_DATE('20991231', 'yyyyMMdd') AS valid_end_date,
       c1.invalid_reason
FROM cancer_mod_dimension cm
         JOIN concept_manual c ON cm.concept_name = c.concept_name
         JOIN concept_manual c1 ON cm.meas = c1.concept_name
    AND c.concept_name != c1.concept_name

UNION

SELECT source_code                     AS cocnept_code_1,
     c.concept_code             AS cocnept_code_2,
       source_vocabulary_id            AS vocabulary_id_1,
       target_vocabulary_id            AS vocabulary_id_2,
       'Maps to'                       AS relationship_id,
       c.valid_start_date,
       TO_DATE('20991231', 'yyyyMMdd') AS valid_end_date,
       c.invalid_reason

FROM source_mapping_dimension smd
         JOIN concept_manual c ON smd.target_concept_name = c.concept_name
and CASE WHEN  target_concept_name='Thickness of Tumor' then c.concept_code else smd.target_concept_code end = c.concept_code



UNION

SELECT old_concept_code                AS cocnept_code_1,
       remap_to                        AS cocnept_code_2,
       'Cancer Modifier'               AS vocabulary_id_1,
       'Cancer Modifier'               AS vocabulary_id_2,
       'Maps to'                       AS relationship_id,
       CURRENT_DATE                    AS valid_start_date,
       TO_DATE('20991231', 'yyyyMMdd') AS valid_end_date,
       NULL                            AS invalid_reason
FROM cm_concept_dimension
WHERE status = 'Remap'

UNION

SELECT old_concept_code                AS cocnept_code_1,
       remap_to                        AS cocnept_code_2,
       'Cancer Modifier'               AS vocabulary_id_1,
       'Cancer Modifier'               AS vocabulary_id_2,
       'Concept replaced by'           AS relationship_id,
       CURRENT_DATE                    AS valid_start_date,
       TO_DATE('20991231', 'yyyyMMdd') AS valid_end_date,
       NULL                            AS invalid_reason
FROM cm_concept_dimension
WHERE status = 'Remap'
;

--Hierarchy of Attributes construction
WITH a AS (
    SELECT a.concept_name AS parent_name, d.concept_name AS child_name
    FROM cancer_mod_dimension a
             JOIN cancer_mod_dimension_atr b ON a.site = b.anc_atr
--join cancer_mod_dimension_atr c  on a.meas = c.anc_atr
             JOIN cancer_mod_dimension d ON d.site = b.desc_atr AND d.meas = a.meas
        AND a.concept_name != d.concept_name
    UNION
    SELECT a.concept_name AS parent_name, d.concept_name AS child_name
    FROM cancer_mod_dimension a
--join cancer_mod_dimension_atr b  on a.site = b.anc_atr
             JOIN cancer_mod_dimension_atr c ON a.meas = c.anc_atr
             JOIN cancer_mod_dimension d ON d.site = a.site AND d.meas = c.desc_atr
        AND a.concept_name != d.concept_name
)

INSERT
INTO concept_relationship_manual (concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2,
                                  relationship_id, valid_start_date, valid_end_date, invalid_reason)
SELECT cm2.concept_code                AS cocnept_code_1,
       cm1.concept_code                AS cocnept_code_2,
/*       cm2.concept_name  AS cocnept_name_1,
       cm1.concept_name          AS cocnept_name_2,*/
       cm2.vocabulary_id               AS vocabulary_id_1,
       cm1.vocabulary_id               AS vocabulary_id_2,
       'Is a'                          AS relationship_id,
       CURRENT_DATE                    AS valid_start_date,
       TO_DATE('20991231', 'yyyyMMdd') AS valid_end_date,
       NULL                            AS invalid_reason
FROM a
         JOIN concept_manual cm1 ON cm1.concept_name = a.parent_name
         JOIN concept_manual cm2 ON cm2.concept_name = a.child_name;
;


--attributes inserting
insert INTO concept_relationship_manual (concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2,
                                  relationship_id, valid_start_date, valid_end_date, invalid_reason)
SELECT --b.concept_name                  AS name_1,
       b.concept_code                  AS cocnept_code_1,
        --a.concept_name                  AS name_2,
       a.concept_code                  AS cocnept_code_2,
       b.vocabulary_id                 AS vocabulary_id_1,
       a.vocabulary_id                 AS vocabulary_id_2,
       'Is a'                          AS relationship_id,
       CURRENT_DATE                    AS valid_start_date,
       TO_DATE('20991231', 'yyyyMMdd') AS valid_end_date,
       NULL                            AS invalid_reason
FROM cancer_mod_dimension_atr atr
         JOIN concept_manual a
              ON a.concept_name = atr.anc_atr
         JOIN concept_manual b ON b.concept_name = atr.desc_atr
where a.concept_code != b.concept_code
;



--CONCEPT MANUAL (Dimension)
INSERT INTO concept_stage
(concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
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
FROM concept_manual
    ;

--CONCEPT MANUAL backup
DROP TABLE concept_manual_dimension;
CREATE TABLE concept_manual_dimension as
 SELECT distinct
                 concept_name,
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

--CONCEPT RELATIONSHIP MANUAL backup
DROP TABLE concept_relationship_manual_dimension;
CREATE TABLE concept_relationship_manual_dimension as
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

--Manual Table Preparation
TRUNCATE TABLE concept_relationship_manual;

INSERT INTO concept_relationship_manual
(concept_code_1,
 concept_code_2,
 vocabulary_id_1,
 vocabulary_id_2,
 relationship_id,
 valid_start_date,
 valid_end_date,
 invalid_reason)
SELECT
       concept_code_1,
       concept_code_2,
       vocabulary_id_1,
       vocabulary_id_2,
       relationship_id,
       valid_start_date,
       valid_end_date,
       invalid_reason
FROM concept_relationship_manual_dimension
 ;

