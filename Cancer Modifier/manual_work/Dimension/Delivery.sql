-- Create sequence that starts after existing OMOPxxx-style concept codes
DO
$$
    DECLARE
        ex INTEGER;
    BEGIN
        SELECT MAX(REPLACE(concept_code, 'OMOP', '')::int4) + 1
        INTO ex
        FROM (
                 SELECT concept_code
                 FROM devv5.concept
                 WHERE concept_code LIKE 'OMOP%'
                   AND concept_code NOT LIKE '% %' -- Last valid value of the OMOP123-type codes
             ) AS s0;
        DROP SEQUENCE IF EXISTS omop_seq;
        EXECUTE 'CREATE SEQUENCE omop_seq INCREMENT BY 1 START WITH ' || ex || ' NO CYCLE CACHE 20';
    END
$$;

--CONCEPT_MANUAL
SELECT *
FROM concept_manual;

TRUNCATE concept_manual
;
--rename
INSERT INTO concept_manual (concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code,
                            valid_start_date, valid_end_date, invalid_reason)
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
--changed class
INSERT INTO concept_manual (concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code,
                            valid_start_date, valid_end_date, invalid_reason)
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
         JOIN devv5.concept c ON c.concept_code = a.old_concept_code AND c.vocabulary_id = 'Cancer Modifier'
WHERE status = 'Change_class'
;
--depracate
INSERT INTO concept_manual (concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code,
                            valid_start_date, valid_end_date, invalid_reason)
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
WHERE status = 'deprecate'
;
--Remap
INSERT INTO concept_manual (concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code,
                            valid_start_date, valid_end_date, invalid_reason)
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
--new
INSERT INTO concept_manual (concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code,
                            valid_start_date, valid_end_date, invalid_reason)
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


INSERT INTO concept_manual (concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code,
                            valid_start_date, valid_end_date, invalid_reason)
SELECT DISTINCT site,
                'Measurement',
                'Cancer Modifier',
                'Morph Abnormality',
                NULL,
                'OMOP' || NEXTVAL('omop_seq') AS concept_code,
                CURRENT_DATE,
                TO_DATE('20991231', 'yyyyMMdd'),
                NULL
FROM (SELECT DISTINCT site FROM cancer_mod_dimension) a
;
INSERT INTO concept_manual (concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code,
                            valid_start_date, valid_end_date, invalid_reason)
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
SELECT *
FROM concept_manual
;

--add naaccr to concept_manual
INSERT INTO concept_manual (concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code,
                            valid_start_date, valid_end_date, invalid_reason)
SELECT DISTINCT c.concept_name,
       c.domain_id,
       c.vocabulary_id,
       c.concept_class_id,
       null as standard_concept,
       c.concept_code,
       c.valid_start_date,
       c.valid_end_date,
       c.invalid_reason
FROM dev_mnerovnya.concept_relationship_manual m
         JOIN devv5.concept c ON m.concept_code_1 = c.concept_code
WHERE m.vocabulary_id_1 = 'NAACCR'
and c.vocabulary_id = 'NAACCR';

--

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
;
SELECT *
FROM concept_relationship
LIMIT 50;

SELECT c.concept_code  AS cocnept_code_1,
       c1.concept_code AS cocnept_code_2,
       c.concept_name  AS concept_name_1,
       c1.concept_name AS concept_name_2,
       'Inheres in'    AS relationship_id
FROM cancer_mod_dimension cm
         JOIN concept_manual c ON cm.concept_name = c.concept_name
         JOIN concept_manual c1 ON cm.site = c1.concept_name
    AND c.concept_name != c1.concept_name

UNION

SELECT c.concept_code  AS cocnept_code_1,
       c.concept_name  AS concept_name_1,
       c1.concept_code AS cocnept_code_2,
       c1.concept_name AS concept_name_2,
       'Has property'  AS relationship_id
FROM cancer_mod_dimension cm
         JOIN concept_manual c ON cm.concept_name = c.concept_name
         JOIN concept_manual c1 ON cm.meas = c1.concept_name
    AND c.concept_name != c1.concept_name
;


--CONCEPT_RELATIONSHIP_MANUAL
SELECT *
FROM concept_relationship_manual;

TRUNCATE TABLE concept_relationship_manual;

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
       target_concept_code             AS cocnept_code_2,
       source_vocabulary_id            AS vocabulary_id_1,
       target_vocabulary_id            AS vocabulary_id_2,
       'Maps to'                       AS relationship_id,
       c.valid_start_date,
       TO_DATE('20991231', 'yyyyMMdd') AS valid_end_date,
       c.invalid_reason

FROM source_mapping_dimension smd
         JOIN concept_manual c ON smd.target_concept_code = c.concept_code

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
INSERT INTO concept_relationship_manual (concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2,
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
FROM dev_mnerovnya.cancer_mod_dimension_atr atr
         JOIN dev_mnerovnya.concept_manual a
              ON a.concept_name = atr.anc_atr
         JOIN dev_mnerovnya.concept_manual b ON b.concept_name = atr.desc_atr
WHERE a.concept_code != b.concept_code;

SELECT *
FROM dev_mnerovnya.concept_relationship_manual;


SELECT *
FROM cm_concept_dimension;

SELECT a.concept_code,
       a.concept_name,
       a.standard_concept,
       a.invalid_reason,
       relationship_id,
       b.concept_code,
       b.concept_name,
       b.standard_concept,
       b.invalid_reason
FROM concept_manual a
         JOIN concept_relationship_manual r ON a.concept_code = r.concept_code_1
         JOIN concept_manual b ON b.concept_code = r.concept_code_2
;

SELECT DISTINCT relationship_id
FROM dev_cancer_modifier.concept_relationship_manual;

SELECT *
FROM dev_mnerovnya.concept_relationship_manual;

SELECT *
FROM dev_mnerovnya.concept_manual;

SELECT *
FROM source_mapping_dimension;
