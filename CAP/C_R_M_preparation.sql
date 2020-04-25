
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
                  );

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

--Mapping to 0
SELECT *
FROM cap_breast_mapping
WHERE concept_code is null
;

-- Not perfect mapping of CAP Variables
SELECT *
FROM cap_breast_mapping
WHERE s_concept_class_id='CAP Variable'
AND (domain_id NOT IN ('Observation', 'Measurement')
OR domain_id is NULL)
;

-- Var_val vocabularies inconsistency
SELECT m.s_concept_name,m.s_concept_code,m.concept_code, m.concept_name,m.target_vocabulary_id,
       m2.s_concept_code,m2.s_alternative_concept_name,m2.concept_code,m2.concept_name,m2.target_vocabulary_id
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
order by m2.concept_code
;


-- Variables mapped to 0 with mapped values
SELECT m.s_concept_name,m.s_concept_code,m.concept_code, m.concept_name,m.target_vocabulary_id,
       m2.s_concept_code,m2.s_alternative_concept_name,m2.concept_code,m2.concept_name,m2.target_vocabulary_id
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

-- for DCIS we in general use  'tumour'/ when for invasive carcinoma we prefere malignant neoplasm as target

-- Semantic check
SELECT *
FROM cap_breast_mapping m
WHERE m.s_concept_name ~*'involved(!?un*)|positive'
AND m.concept_name !~*'involved|positive'
AND s_domain_id <>'Meas Value'
AND s_concept_name ~* 'dist'
ORDER BY s_concept_name
;

-- todo
--  compare quantity and quality of NL and snomed attributes for same codes.
SELECT distinct c.concept_name,c.concept_class_id, relationship_id,cc.concept_class_id, count(*)
FROM devv5.concept c
JOIN   devv5.concept_relationship cr
ON c.concept_id=cr.concept_id_1
AND c.vocabulary_id='Nebraska Lexicon'
JOIN   devv5.concept  cc
ON cc.concept_id=cr.concept_id_2
AND cc.vocabulary_id ='Nebraska Lexicon'
WHERE c.concept_code IN (SELECT concept_code FROM cap_breast_mapping WHERE target_vocabulary_id ='Nebraska Lexicon')
GROUP BY  c.concept_name,c.concept_class_id, relationship_id,cc.concept_class_id
ORDER BY c.concept_name
;

SELECT distinct c.concept_name,c.concept_class_id, relationship_id,cc.concept_class_id, count(*)
FROM devv5.concept c
JOIN   devv5.concept_relationship cr
ON c.concept_id=cr.concept_id_1
AND c.vocabulary_id='SNOMED'
JOIN   devv5.concept  cc
ON cc.concept_id=cr.concept_id_2
AND cc.vocabulary_id ='SNOMED'
WHERE c.concept_code IN (SELECT concept_code FROM cap_breast_mapping WHERE target_vocabulary_id ='Nebraska Lexicon')
AND cr.relationship_id !~* 'map'
GROUP BY  c.concept_name,c.concept_class_id, relationship_id,cc.concept_class_id
ORDER BY c.concept_name
;

SELECT distinct standard_concept from cap_breast_mapping


-- CRM preparation
SELECT m.s_concept_code,
       m.concept_code,
       m.s_vocabulary_id,
       m.target_vocabulary_id,
       CASE WHEN  (m.target_vocabulary_id = 'SNOMED'  or (m.target_vocabulary_id = 'Nebraska Lexicon' AND m.standard_concept  in ('S','Standard') ) )then 'Maps to'
            ELSE concat('CAP', ' to ', coalesce(m.target_vocabulary_id,'NULL'),  ' equivalent')
             END AS relationship_id,
       TO_DATE('20200418', 'yyyymmdd') AS valid_start_date ,
       TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
      NULL as invalid_reason
FROM cap_breast_mapping m
JOIN devv5.concept c
ON m.s_concept_code=c.concept_code
ANd c.vocabulary_id='CAP'
WHERE m.target_concept_id <>0 -- to exlude to 0 mappings
;