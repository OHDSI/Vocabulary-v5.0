--NAACCR
DROP TABLE dev_mnerovnya.naaccr_to_cm;
CREATE TABLE dev_mnerovnya.naaccr_to_cm
(
    vl_name          varchar,
    concept_name     varchar,
    concept_class_id varchar,
    vr_name          varchar,
    schema_name      varchar
);

SELECT DISTINCT *
FROM dev_mnerovnya.naaccr_to_cm
WHERE concept_class_id = 'Dimension';

--CM_concept
CREATE TABLE dev_mnerovnya.cm_concept_dimension
(
    old_concept_code varchar,
    old_concept_name varchar,
    new_concept_name varchar,
    status           varchar,
    remap_to         varchar,
    changed_class    varchar
);

SELECT *
FROM dev_mnerovnya.cm_concept_dimension;


WITH tab AS (SELECT DISTINCT cvr.concept_id   AS vr_concept_id,
                             cvr.concept_code AS vr_concept_code,
                             s.vr_name,
                             cvl.concept_id   AS vl_concept_id,
                             cvl.concept_code AS vl_concept_code,
                             s.vl_name,
                             cm.concept_id    AS cm_concept_id,
                             cm.concept_code  AS cm_concept_code,
                             s.concept_name,
                             cm.concept_class_id
             FROM dev_mnerovnya.naaccr_to_cm s
                      LEFT JOIN (SELECT * FROM devv5.concept WHERE vocabulary_id = 'NAACCR') cvr
                                ON s.vr_name = cvr.concept_name
                      LEFT JOIN (SELECT * FROM devv5.concept WHERE vocabulary_id = 'NAACCR') cvl
                                ON s.vl_name = cvl.concept_name
                      LEFT JOIN (SELECT * FROM devv5.concept WHERE vocabulary_id = 'Cancer Modifier') cm
                                ON s.concept_name = cm.concept_name
             WHERE SPLIT_PART(cvr.concept_code, '@', 1) = SPLIT_PART(cvl.concept_code, '@', 1)
               AND cm.concept_class_id = 'Dimension'
             ORDER BY vr_concept_code, vr_name, vl_concept_code, vl_name, concept_name
)
SELECT *
FROM tab
WHERE vl_concept_id IN (SELECT vl_concept_id FROM tab GROUP BY 1 HAVING COUNT(DISTINCT cm_concept_id) > 1)
;


TRUNCATE TABLE dev_mnerovnya.cancer_mod_dimension;
CREATE TABLE dev_mnerovnya.cancer_mod_dimension
(
    concept_name varchar,
    site         varchar,
    meas         varchar

);
SELECT *
FROM dev_mnerovnya.cancer_mod_dimension;

CREATE TABLE dev_mnerovnya.cancer_mod_dimension_atr
(
    anc_atr  varchar,
    desc_atr varchar

);
SELECT *
FROM dev_mnerovnya.cancer_mod_dimension_atr;

WITH a AS (SELECT a.concept_name AS parent_name, d.concept_name AS child_name
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
SELECT *
FROM a
         LEFT JOIN devv5.concept b ON a.parent_name = b.concept_name;



--source_mapping_dimension
TRUNCATE TABLE dev_mnerovnya.source_mapping_dimension;
CREATE TABLE dev_mnerovnya.source_mapping_dimension
(
    source_vocabulary_id varchar,
    source_code          varchar,
    source_name          varchar,
    target_concept_name  varchar,
    target_concept_code  varchar,
    target_vocabulary_id varchar
);

SELECT *
FROM dev_mnerovnya.source_mapping_dimension;

--inserting to source_mapping
WITH a AS (SELECT DISTINCT n.vr_name          AS naaccr_name,
                           c.status          AS status,
                           c.old_concept_name AS concept_name_cm,
                           c.new_concept_name
           FROM dev_mnerovnya.cm_concept_dimension c
                    LEFT JOIN dev_mnerovnya.naaccr_to_cm n ON n.concept_name = c.old_concept_name
           WHERE n.concept_class_id = 'Dimension'
             AND c.new_concept_name != ''
    )
INSERT INTO dev_mnerovnya.source_mapping_dimension
(
 source_vocabulary_id,
source_code         ,
source_name         ,
target_concept_name ,
target_concept_code ,
target_vocabulary_id
)


SELECT DISTINCT c1.vocabulary_id   AS source_vocabulary_id,
                c1.concept_code    AS source_code,

                a.naaccr_name      AS source_name,
                a.new_concept_name AS target_concept_name,

                c2.concept_code    AS target_concept_code,
                c2.vocabulary_id   AS target_vocabulary_id


FROM a
         LEFT JOIN devv5.concept c1 ON a.naaccr_name = c1.concept_name
         LEFT JOIN devv5.concept c2 ON a.concept_name_cm = c2.concept_name
WHERE c1.vocabulary_id = 'NAACCR'
  AND c2.vocabulary_id = 'Cancer Modifier'
ORDER BY target_concept_name
;

SELECT *
FROM dev_cancer_modifier.concept_relationship_manual;






--CAP
DROP TABLE dev_mnerovnya.cap_to_cm;
CREATE TABLE dev_mnerovnya.cap_to_cm
(
    protocol_name    varchar,
    vr_name          varchar,
    vl_name          varchar,
    concept_name     varchar,
    concept_class_id varchar
);
SELECT *
FROM dev_mnerovnya.cap_to_cm;


--CAP mapping
SELECT n.vr_name, n.vl_name, c.concept_name_old, c.concept_name_new
FROM dev_mnerovnya.cap_to_cm n
         LEFT JOIN dev_mnerovnya.cm_old_new c ON n.concept_name = c.concept_name_old
WHERE n.concept_class_id = 'Dimension'
;

--vr
WITH a AS (SELECT DISTINCT cvr.concept_id   AS vr_concept_id,
                           cvr.concept_code AS vr_concept_code,
                           s.vr_name,
               /*    cvl.concept_id   AS vl_concept_id,
                   cvl.concept_code AS vl_concept_code,
                   s.vl_name,*/
                           cm.concept_id    AS cm_concept_id,
                           cm.concept_code  AS cm_concept_code,
                           s.concept_name,
                           cm.concept_class_id
           FROM dev_mnerovnya.cap_to_cm s
                    LEFT JOIN (SELECT * FROM devv5.concept WHERE vocabulary_id = 'CAP') cvr
                              ON s.vr_name = cvr.concept_name
               /*LEFT JOIN (SELECT * FROM devv5.concept WHERE vocabulary_id = 'CAP') cvl
                         ON s.vl_name = cvl.concept_name*/
                    LEFT JOIN (SELECT * FROM devv5.concept WHERE vocabulary_id = 'Cancer Modifier') cm
                              ON s.concept_name = cm.concept_name
           WHERE cm.concept_class_id = 'Dimension'
           ORDER BY vr_concept_code, vr_name/*, vl_concept_code, vl_name*/, concept_name
)
SELECT DISTINCT --vr_concept_code,
                vr_name,
                concept_name
FROM a
;

--vl
WITH a AS (SELECT DISTINCT cvl.concept_id   AS vl_concept_id,
                           cvl.concept_code AS vl_concept_code,
                           s.vl_name,

                           cm.concept_id    AS cm_concept_id,
                           cm.concept_code  AS cm_concept_code,
                           s.concept_name,
                           cm.concept_class_id
           FROM dev_mnerovnya.cap_to_cm s
                    LEFT JOIN (SELECT * FROM devv5.concept WHERE vocabulary_id = 'CAP') cvl
                              ON s.vl_name = cvl.concept_name

                    LEFT JOIN (SELECT * FROM devv5.concept WHERE vocabulary_id = 'Cancer Modifier') cm
                              ON s.concept_name = cm.concept_name
           WHERE cm.concept_class_id = 'Dimension'
           ORDER BY vl_concept_code, vl_name, concept_name
)
SELECT DISTINCT --vl_concept_code,
                vl_name,
                concept_name
FROM a
;

