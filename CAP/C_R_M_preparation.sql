-- table with mappigs to Histology code provided by CAP
DROP TABLE cap_to_icd03_snomed_mappings;
CREATE UNLOGGED TABLE cap_to_icd03_snomed_mappings
(
   Template_Name  varchar(1256),
       Item_Ckey  varchar(1256),
       Item_Title  varchar(1256),
       ICDO3Morph  varchar(1256),
       ICDO3FullTerm  varchar(1256),
       ICDO3_Match  varchar(1256),
       FSN  varchar(1256),
       ConceptID  varchar(1256),
       SNOMED_Match  varchar(1256),
       Status varchar(1256)

)
;

SELECT fsn,ConceptID, split_part(b.Item_Ckey,'.',1),s_concept_name,exploration_path
FROM cap_breast_mapping a
JOIN cap_to_icd03_snomed_mappings b
on a.s_concept_code=split_part(b.Item_Ckey,'.',1)
AND a.concept_code != b.ConceptID
;
--Table with mappings
-- for DCIS  in general we use  'tumour'/ when for invasive carcinoma we prefer malignant neoplasm as target
-- DROP TABLE cap_breast_mapping;
CREATE UNLOGGED TABLE cap_breast_mapping
(
    s_concept_name             varchar(1256),
    s_concept_code             varchar(1256),
    s_domain_id                varchar(1256),
    s_vocabulary_id            varchar(1256),
    s_concept_class_id         varchar(1256),
    s_alternative_concept_name varchar(1256),
    exploration_path           varchar(1256),
    comments                   varchar(1256),
    issue_type                 varchar(1256),
    target_concept_id          int,
    concept_code               varchar(1256),
    concept_name               varchar(1256),
    target_vocabulary_id       varchar(1256),
    concept_class_id           varchar(1256),
    standard_concept           varchar(1256),
    invalid_reason             varchar(1256),
    domain_id                  varchar(1256)
)
;

SELECT * FROM cap_breast_mapping
;

--check if any source code/description are lost
SELECT *
FROM devv5.concept s
WHERE NOT EXISTS(SELECT 1
                 FROM cap_breast_mapping m
                 WHERE s.concept_code = m.s_concept_code
                   AND s.concept_name = m.S_ALTERNATIVE_CONCEPT_NAME
    )
AND  s.vocabulary_id='CAP';

--check if any source code/description are modified
SELECT *
FROM cap_breast_mapping m
WHERE NOT EXISTS(SELECT 1
                 FROM devv5.concept s
                 WHERE s.concept_code = m.s_concept_code
                   AND s.concept_name = m.S_ALTERNATIVE_CONCEPT_NAME
                   AND  s.vocabulary_id='CAP'
    );

--check if target concepts exist in the concept table
--round 1
SELECT distinct *
FROM cap_breast_mapping j1
JOIN devv5.concept c
ON j1.target_concept_id=c.concept_id
WHERE j1.concept_name=c.concept_name
AND target_vocabulary_id=vocabulary_id
AND j1.concept_code=c.concept_code
AND target_concept_id!=0
;

-- round 2 shows all 0 mappings + non standards
SELECT *
FROM cap_breast_mapping j1
WHERE NOT EXISTS (  SELECT *
                    FROM cap_breast_mapping j2
                    JOIN devv5.concept c
                        ON j2.target_concept_id = c.concept_id
                            AND c.concept_name = j2.concept_name
                            AND c.vocabulary_id = j2.target_vocabulary_id
                            AND c.domain_id = j2.domain_id
                            AND c.standard_concept = 'S'
                            AND c.invalid_reason is NULL
    WHERE j2.s_concept_code=j1.s_concept_code
                  )
;

--Mapping to 0
SELECT *
FROM cap_breast_mapping
WHERE concept_code is null
;
--NL non-standards
SELECT *
FROM cap_breast_mapping
WHERE standard_concept is NULL
AND concept_code is NOT null

--'Maps to' mapping to abnormal domains
with tab as (
    SELECT DISTINCT s.*
    FROM cap_breast_mapping s
)

SELECT *
FROM tab
WHERE s_concept_code in (
    SELECT s_concept_code
    FROM tab a
    WHERE EXISTS(   SELECT 1
                    FROM tab b
                    WHERE a.s_concept_code = b.s_concept_code
                        AND b.domain_id not in ('Observation', 'Procedure', 'Condition', 'Drug', 'Measurement')--, 'Device') --add Device if needed
                        AND a.s_concept_class_id <> 'CAP Value'
                )
    )
ORDER BY  s_concept_name
;
-- Not perfect mapping of CAP Variables
--round 1
SELECT *
FROM cap_breast_mapping
WHERE s_concept_class_id='CAP Variable'
AND (domain_id NOT IN ('Observation', 'Measurement')
OR domain_id is NULL)
;
-- Not perfect mapping of CAP Variables
--round 2
SELECT *
FROM cap_breast_mapping
WHERE s_concept_class_id='CAP Variable'
AND domain_id NOT IN ('Observation', 'Measurement')
ORDER BY  s_concept_name
;

--1-to-many mapping
with tab as (
    SELECT DISTINCT s.*
    FROM cap_breast_mapping s
)

SELECT *
FROM tab
WHERE s_concept_code in (

    SELECT s_concept_code
    FROM cap_breast_mapping
    GROUP BY s_concept_code
    HAVING count (*) > 1)
ORDER BY s_concept_code
;

-- Var_val vocabularies inconsistency
SELECT m.s_concept_name as var_name,m.s_concept_code as var_code,m.concept_code as var_target_code, m.concept_name as  var_target_name,m.target_vocabulary_id as var_target_vocabulary,
      m2.s_concept_name as val_name,m2.s_concept_code as val_code,m2.concept_code as val_target_code, m2.concept_name as  val_target_name,m2.target_vocabulary_id as val_target_vocabulary
FROM cap_breast_mapping m
JOIN devv5.concept c
ON m.s_concept_code=c.concept_code
AND m.s_concept_class_id='CAP Variable'
AND c.vocabulary_id='CAP'
JOIN devv5.concept_relationship cr
ON c.concept_id=cr.concept_id_1
AND cr.relationship_id='Has CAP value'
JOIN devv5.concept c2
ON cr.concept_id_2=c2.concept_id
JOIN cap_breast_mapping m2
ON c2.concept_code=m2.s_concept_code
AND  m2.target_vocabulary_id<>m.target_vocabulary_id
AND (m2.target_vocabulary_id not in ('SNOMED','Nebraska Lexicon')
 OR m.target_vocabulary_id not in ('SNOMED','Nebraska Lexicon') )
order by m.s_concept_name,m2.concept_code
;


-- Variables mapped to 0 with mapped values
SELECT m.s_concept_name as var_name,m.s_concept_code as var_code,m.concept_code as var_target_code, m.concept_name as  var_target_name,m.target_vocabulary_id as var_target_vocabulary,
      m2.s_concept_name as val_name,m2.s_concept_code as val_code,m2.concept_code as val_target_code, m2.concept_name as  val_target_name,m2.target_vocabulary_id as val_target_vocabulary
FROM cap_breast_mapping m
JOIN devv5.concept c
ON m.s_concept_code=c.concept_code
AND m.s_concept_class_id='CAP Variable'
AND c.vocabulary_id='CAP'
JOIN devv5.concept_relationship cr
ON c.concept_id=cr.concept_id_1
AND cr.relationship_id='Has CAP value'
JOIN devv5.concept c2
ON cr.concept_id_2=c2.concept_id
JOIN cap_breast_mapping m2
ON c2.concept_code=m2.s_concept_code
AND  m.target_concept_id=0
AND  m2.target_concept_id<>0
order by m.s_concept_name,m2.concept_code
;

-- Semantic check
SELECT *
FROM cap_breast_mapping m
WHERE m.s_concept_name ~*'involved(!?un*)|positive'
AND m.concept_name !~*'involved|positive'
AND s_domain_id <>'Meas Value'
AND s_concept_name ~* 'dist'
ORDER BY s_concept_name
;


-- CRM preparation
DROP TABLE CRM_breast;
CREATE UNLOGGED TABLE CRM_breast AS
    (
        with nebraska_eq AS (
            SELECT c.concept_code                   AS concept_code_1,
                   cc.concept_code                  AS concept_code_2,
                   c.vocabulary_id                  AS vocabulary_id_1,
                   cc.vocabulary_id                 AS vocabulary_id_2,
                   CASE
                       WHEN (m.issue_type in ('loss of hierarchical context',
                                              'loss of context',
                                              'poor data modeling')
                           AND cc.vocabulary_id = 'Nebraska Lexicon')
                           THEN 'CAP-Nebraska cat' -- issues with potential loss of source info
                       ELSE 'CAP-Nebraska eq' END AS relationship_id, -- Equivalent is more appropriate targets the Category
                   TO_DATE('20200427', 'yyyymmdd')  AS valid_start_date,
                   TO_DATE('20991231', 'yyyymmdd')  AS valid_end_date,
                   NULL                             as invalid_reason
            FROM cap_breast_mapping m
                     JOIN devv5.concept c
                          ON m.s_concept_code = c.concept_code
                              AND c.vocabulary_id = 'CAP'
                     JOIN devv5.concept cc
                          ON m.target_concept_id = cc.concept_id
                              AND cc.vocabulary_id = m.target_vocabulary_id

            WHERE m.target_concept_id <> 0 -- to exclude to 0 mappings
              AND cc.vocabulary_id = 'Nebraska Lexicon'
        )
           , standard AS (
            SELECT c.concept_code                  AS concept_code_1,
                   cc.concept_code                 AS concept_code_2,
                   c.vocabulary_id                 AS vocabulary_id_1,
                   cc.vocabulary_id                AS vocabulary_id_2,
                   'Maps to'                       AS relationship_id,
                   TO_DATE('20200427', 'yyyymmdd') AS valid_start_date,
                   TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
                   NULL                            as invalid_reason
            FROM cap_breast_mapping m
                     JOIN devv5.concept c
                          ON m.s_concept_code = c.concept_code
                              AND c.vocabulary_id = 'CAP'
                     JOIN devv5.concept cc
                          ON m.target_concept_id = cc.concept_id
                              AND cc.vocabulary_id = m.target_vocabulary_id

            WHERE m.target_concept_id <> 0 -- to exclude to 0 mappings
              AND cc.standard_concept = 'S'
        )
           , CR_map AS (SELECT c.concept_code                  AS concept_code_1,
                               cc.concept_code                 AS concept_code_2,
                               c.vocabulary_id                 AS vocabulary_id_1,
                               cc.vocabulary_id                AS vocabulary_id_2,
                               cr.relationship_id,
                               TO_DATE('20200427', 'yyyymmdd') AS valid_start_date,
                               TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
                               NULL                            as invalid_reason
                        FROM cap_breast_mapping m
                                 JOIN devv5.concept c
                                      ON m.s_concept_code = c.concept_code
                                          AND c.vocabulary_id = 'CAP'
                                 JOIN devv5.concept_relationship cr
                                      ON m.target_concept_id = cr.concept_id_1
                                          AND cr.relationship_id = 'Maps to'
                                          AND cr.concept_id_2 <> m.target_concept_id
                                 JOIN devv5.concept cc
                                      ON cr.concept_id_2 = cc.concept_id
                        WHERE m.target_concept_id <> 0-- to exclude to 0 mappings
                          AND m.standard_concept IS NULL
                          AND m.target_vocabulary_id = 'Nebraska Lexicon'
        )
           , resulting_tab AS
            (
                SELECT *
                FROM standard
                UNION ALL
                SELECT *
                FROM nebraska_eq
                UNION ALL
                SELECT *
                FROM CR_map)

        SELECT distinct *
        from resulting_tab
        ORDER BY concept_code_1
    )
;
-- insert into concept_relationship_manual
--TRUNCATE concept_relationship_manual;
INSERT INTO concept_relationship_manual (concept_code_1,
                                         concept_code_2,
                                         vocabulary_id_1,
                                         vocabulary_id_2,
                                         relationship_id,
                                         valid_start_date,
                                         valid_end_date,
                                         invalid_reason)
SELECT concept_code_1,
       concept_code_2,
       vocabulary_id_1,
       vocabulary_id_2,
       relationship_id,
       valid_start_date,
       valid_end_date,
       invalid_reason
FROM CRM_breast;

-- todo
--  compare quantity and quality of NL and snomed attributes for same codes
-- resolved with D. Dymshyts
WITH tabN AS (
    SELECT distinct c.concept_code, c.concept_name, c.concept_class_id, relationship_id, cc.concept_class_id, count(*)
    FROM devv5.concept c
             JOIN devv5.concept_relationship cr
                  ON c.concept_id = cr.concept_id_1
                      AND c.vocabulary_id = 'Nebraska Lexicon'
             JOIN devv5.concept cc
                  ON cc.concept_id = cr.concept_id_2
                      AND cc.vocabulary_id = 'Nebraska Lexicon'
    WHERE c.concept_code IN
          (SELECT concept_code FROM cap_breast_mapping WHERE target_vocabulary_id = 'Nebraska Lexicon')
      AND cr.relationship_id !~* 'map'
    GROUP BY c.concept_code, c.concept_name, c.concept_class_id, relationship_id, cc.concept_class_id
    ORDER BY c.concept_name
)
, tabS AS (
    SELECT distinct c.concept_code, c.concept_name, c.concept_class_id, relationship_id, cc.concept_class_id, count(*)
    FROM devv5.concept c
             JOIN devv5.concept_relationship cr
                  ON c.concept_id = cr.concept_id_1
                      AND c.vocabulary_id = 'SNOMED'
             JOIN devv5.concept cc
                  ON cc.concept_id = cr.concept_id_2
                      AND cc.vocabulary_id = 'SNOMED'
    WHERE c.concept_code IN
          (SELECT concept_code FROM cap_breast_mapping WHERE target_vocabulary_id = 'Nebraska Lexicon')
      AND cr.relationship_id !~* 'map'
    GROUP BY c.concept_code, c.concept_name, c.concept_class_id, relationship_id, cc.concept_class_id
    ORDER BY c.concept_name
)
;


