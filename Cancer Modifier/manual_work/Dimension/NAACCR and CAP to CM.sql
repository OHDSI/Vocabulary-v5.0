DROP TABLE dev_mnerovnya.naaccr_to_cm;
CREATE TABLE dev_mnerovnya.naaccr_to_cm
(
    vl_name          varchar,
    concept_name     varchar,
    concept_class_id varchar,
    vr_name          varchar,
    schema_name      varchar
);
TRUNCATE TABLE dev_mnerovnya.cm_old_new;
CREATE TABLE dev_mnerovnya.cm_old_new
(
    concept_id       int,
    concept_name_old varchar,
    comment          text,
    concept_name_new varchar,
    site             varchar,
    meas             varchar
);
SELECT *
FROM dev_mnerovnya.cm_old_new;

SELECT DISTINCT *
FROM dev_mnerovnya.naaccr_to_cm
WHERE concept_class_id = 'Dimension';

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
FROM devv5.concept
WHERE vocabulary_id = 'CAP';
SELECT *
FROM devv5.concept
WHERE vocabulary_id = 'Cancer Modifier'
  AND concept_class_id = 'Dimension';
SELECT *
FROM dev_mnerovnya.cap_to_cm
WHERE concept_class_id = 'Dimension';

SELECT *
FROM devv5.concept
WHERE concept_id IN (SELECT concept_id_2
                     FROM devv5.concept_relationship
                     WHERE concept_id_1 = 37198752
                       AND relationship_id = 'Has CAP protocol');

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
--where ;
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

SELECT DISTINCT concept_name
FROM devv5.concept
WHERE vocabulary_id = 'CAP'
  AND concept_name LIKE LOWER('%dimension%');

SELECT DISTINCT concept_name
FROM devv5.concept
WHERE vocabulary_id = 'NAACCR'
  AND concept_name LIKE LOWER('%dimension%');

SELECT *
FROM devv5.concept
WHERE vocabulary_id = 'Cancer Modifier'
  AND concept_class_id = 'Margin';

-- Topography of distance to margin
SELECT DISTINCT SUBSTR(concept_name, instr(LOWER(concept_name), ' to ') + 4) AS b
FROM devv5.concept
WHERE vocabulary_id = 'Cancer Modifier'
  AND LOWER(concept_name) LIKE '%istance%to%margin%'
UNION
DISTINCT
SELECT DISTINCT SUBSTR(concept_name, instr(LOWER(concept_name), ' from ') + 6) AS b
FROM devv5.concept
WHERE vocabulary_id = 'Cancer Modifier'
  AND LOWER(concept_name) LIKE '%istance%from%margin%'
ORDER BY 1
LIMIT 1000;

-- Histologies within margins
SELECT DISTINCT SUBSTR(concept_name, instr(concept_name, ' by ') + 4)
FROM concept
WHERE vocabulary_id = 'Cancer Modifier'
  AND LOWER(concept_name) LIKE '% by %'
ORDER BY 1
LIMIT 1000;

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

--mapping
SELECT *
FROM devv5.concept
WHERE vocabulary_id = 'NAACCR'
  AND concept_name ILIKE '%dimension%'
  AND concept_class_id = 'NAACCR Variable'
;
SELECT *
FROM devv5.concept
WHERE vocabulary_id = 'NAACCR'
  AND concept_name ILIKE '%size%'
  AND concept_class_id = 'NAACCR Variable'
;

SELECT c.concept_name_old, c.concept_name_new, n.vr_name, n.vl_name, n.schema_name
FROM dev_mnerovnya.naaccr_to_cm n
left JOIN dev_mnerovnya.cm_old_new c on n.concept_name = c.concept_name_old
where n.concept_class_id = 'Dimension'
;

SELECT c.concept_name_old, c.concept_name_new, n.vr_name, n.vl_name
FROM dev_mnerovnya.cap_to_cm n
left JOIN dev_mnerovnya.cm_old_new c on n.concept_name = c.concept_name_old
where n.concept_class_id = 'Dimension'
;


--CAP mapping
SELECT  n.vr_name, n.vl_name ,c.concept_name_old, c.concept_name_new
FROM dev_mnerovnya.cap_to_cm n
left JOIN dev_mnerovnya.cm_old_new c on n.concept_name = c.concept_name_old
where n.concept_class_id = 'Dimension'
;
--NAACCR mapping
with a as (SELECT DISTINCT  n.vr_name as naaccr_name, c.comment as comment, c.concept_name_old as concept_name_cm, c.concept_name_new
FROM dev_mnerovnya.naaccr_to_cm n
left JOIN dev_mnerovnya.cm_old_new c on n.concept_name = c.concept_name_old
where n.concept_class_id = 'Dimension')

SELECT DISTINCT c1.concept_id, c1.concept_code, a.naaccr_name, c1.vocabulary_id, 'Maps to' as relationship, a.comment, c2.concept_id, c2.concept_code, a.concept_name_new as new_cm_name,c2.vocabulary_id
FROM a
LEFT JOIN devv5.concept c1 on a.naaccr_name = c1.concept_name
LEFT JOIN devv5.concept c2 on a.concept_name_cm = c2.concept_name
where c1.vocabulary_id =  'NAACCR' and c2.vocabulary_id = 'Cancer Modifier'
ORDER BY a.naaccr_name
;
SELECT *
FROM devv5.concept
WHERE vocabulary_id = 'NAACCR'
  AND lower(concept_name) ILIKE '%size%'
  AND concept_class_id = 'NAACCR Variable'
and concept_name not in (SELECT vr_name from naaccr_to_cm);