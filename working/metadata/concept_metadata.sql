-- DDL:
--DROP TABLE concept_metadata;
CREATE TABLE concept_metadata (
    concept_id int NOT NULL,
    concept_category VARCHAR(20),
    reuse_status     VARCHAR(20),
    --CONSTRAINT chk_concept_category CHECK (concept_category IN ('A', 'SA', 'SC', 'M', 'J')),
    FOREIGN KEY (concept_id)
    REFERENCES devv5.concept (concept_id)

);

--Reused codes insertion

--HCPCS
INSERT INTO concept_metadata (concept_id,reuse_status)
SELECT DISTINCT
    c.concept_id,
   'P' as reuse_status
FROM
    dev_test4.reused_concepts rr
    JOIN concept c
        ON rr.concept_id = c.concept_id
;

-- Apparent Junk from various OMOPed terminologies
INSERT INTO concept_metadata (concept_id,concept_category)
WITH JUNK_POOL AS (SELECT DISTINCT c.*
                            FROM devv5.concept_ancestor ca
                                     JOIN devv5.concept c
                                          ON c.concept_id = ca.descendant_concept_id
                                     JOIN devv5.concept cc
                                          ON cc.concept_id = ca.ancestor_concept_id
                                              AND (
                                                 ca.ancestor_concept_id IN (4312372 -- 423901009 Identification code SNOMED
                                                     )
                                                     OR (cc.concept_name ~*
                                                         'serial numb|Social.+security.+(number|identifier)|personal.+telephon|Patient.identif.+numb|patient name|patient surname'
                                                     AND cc.standard_concept IN ( 'S','C')
                                                     )
                                                 ))

,
   junk_via_rel  as (
SELECT DISTINCT 'rel' as flag, cc.concept_id
              , 'J' AS concept_category
              , cc.concept_name
              , cc.vocabulary_id
FROM JUNK_POOL a
         JOIN devv5.concept_relationship cr
              ON cr.concept_id_2 = a.concept_id
                  AND cr.invalid_reason IS NULL
                  AND cr.relationship_id IN ('Maps to', 'Maps to value', 'Concept replaced by')
         JOIN devv5.concept cc
              ON cc.concept_id = cr.concept_id_1
)
,
   junk_direct_rule_based  as (SELECT 'dir' as flag,cx.concept_id
              , 'J' AS concept_category
              , cx.concept_name
              , cx.vocabulary_id
                               FROM devv5.concept cx
                               WHERE cx.concept_name ~*
                                     'serial numb|Social.+security.+(number|identifier)|personal.+telephon|Patient.identif.+numb|patient name|patient surname'
                                 AND cx.standard_concept IS NULL
                               and cx.concept_id NOT IN (SELECT concept_id FROM junk_via_rel))

SELECT DISTINCT concept_id, concept_category
FROM (
SELECT flag, concept_id, concept_category, concept_name, vocabulary_id
FROM junk_via_rel
UNION ALL
SELECT flag, concept_id, concept_category, concept_name, vocabulary_id
FROM junk_direct_rule_based
) as tab
