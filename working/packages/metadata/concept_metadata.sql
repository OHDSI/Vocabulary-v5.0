-- DDL:
--DROP TABLE concept_metadata;
TRUNCATE TABLE concept_metadata;
CREATE TABLE concept_metadata
(
    concept_id       int NOT NULL,
    concept_category varchar(20),
    reuse_status     varchar(20),
    CONSTRAINT chk_concept_category CHECK (concept_category IN ('A', 'SA', 'SC', 'M', 'V')),
    CONSTRAINT chk_reuse_status CHECK (reuse_status IS NULL OR reuse_status IN ('RF', 'RP', 'R')),
    FOREIGN KEY (concept_id)
    REFERENCES concept (concept_id),
    CONSTRAINT xpk_concept_metadata
    UNIQUE (concept_id)
);

--Reused codes insertion
INSERT INTO concept_metadata (concept_id,reuse_status)
SELECT DISTINCT
    c.concept_id,
    CASE WHEN rr.old_concept_name = (SELECT concept_name FROM devv5.concept c1 WHERE c1.concept_id = rr.concept_id)
        THEN 'RF'
        WHEN rr.new_concept_name = (SELECT concept_name FROM devv5.concept c1 WHERE c1.concept_id = rr.concept_id)
        THEN 'RP' END AS reuse_status
FROM dev_voc_metadata.reused_concepts rr
    JOIN concept c
        ON rr.concept_id = c.concept_id
where not exists(SELECT 1
                 from dev_voc_metadata.concept_metadata cm
                 where (cm.concept_id)=rr.concept_id)
and exists (SELECT 1
                 from dev_voc_metadata.concept  с
                 where (c.concept_id)=rr.concept_id)
;

-- Apparent Void from various OMOPed terminologies
INSERT INTO concept_metadata (concept_id,concept_category)
WITH void_pool AS (SELECT DISTINCT c.*
                            FROM devv5.concept_ancestor ca
                                     JOIN devv5.concept c
                                          ON c.concept_id = ca.descendant_concept_id
                                     JOIN devv5.concept cc
                                          ON cc.concept_id = ca.ancestor_concept_id
                                              AND (
                                                 ca.ancestor_concept_id IN (4312372 -- 423901009 Identification code SNOMED
                                                     )
                                                     OR (cc.concept_name ~*
                                                         'Pers.+identifier|serial numb|Social.+security.+(number|identifier)|personal.+telephon|Patient.identif.+numb|patient name|patient surname'
                                                     AND cc.standard_concept IN ( 'S','C')
                                                     )
                                                 ))

,
   void_via_rel  as (
SELECT DISTINCT 'rel' as flag, cc.concept_id
              , 'V' AS concept_category
              , cc.concept_name
              , cc.vocabulary_id
FROM void_pool a
         JOIN devv5.concept_relationship cr
              ON cr.concept_id_2 = a.concept_id
                  AND cr.invalid_reason IS NULL
                  AND cr.relationship_id IN ('Maps to', 'Maps to value', 'Concept replaced by')
         JOIN devv5.concept cc
              ON cc.concept_id = cr.concept_id_1
)
,
   void_direct_rule_based  as (SELECT 'dir' as flag,cx.concept_id
              , 'V' AS concept_category
              , cx.concept_name
              , cx.vocabulary_id
                               FROM devv5.concept cx
                               WHERE cx.concept_name ~*
                                     'serial numb|Social.+security.+(number|identifier)|personal.+telephon|Patient.identif.+numb|patient name|patient surname'
                                 AND cx.standard_concept IS NULL
                               and cx.concept_id NOT IN (SELECT concept_id FROM void_via_rel))

SELECT DISTINCT concept_id, concept_category
FROM (
SELECT flag, concept_id, concept_category, concept_name, vocabulary_id
FROM void_via_rel
UNION ALL
SELECT flag, concept_id, concept_category, concept_name, vocabulary_id
FROM void_direct_rule_based
) as tab
where not exists(SELECT 1
                 from dev_voc_metadata.concept_metadata cm
                 where (cm.concept_id)=tab.concept_id)
and exists (SELECT 1
                 from dev_voc_metadata.concept xx
                 where xx.concept_id=tab.concept_id)
;

-- Metadata attribute
-- Apparent metadata
INSERT INTO concept_metadata (concept_id, concept_category)
SELECT DISTINCT concept_id, 'M' AS concept_category
FROM devv5.concept
WHERE domain_id = 'Metadata'
ON CONFLICT ON CONSTRAINT xpk_concept_metadata
DO UPDATE SET concept_category = concept_metadata.concept_category
WHERE ROW (concept_metadata.concept_category) IS DISTINCT FROM ROW (excluded.concept_category);

-- Attributes attribute
-- Drug attributes
INSERT INTO concept_metadata (concept_id, concept_category)
SELECT DISTINCT concept_id, 'A' AS concept_category
FROM devv5.concept
WHERE (
    concept_class_id IN (
        'AU Qualifier',
        'Supplier',
        'Trade Product',
        'Brand Name',
        'Dose Form',
        'Drug form',
        'Form',
        'Chemical Structure',
        'Pharmacokinetics',
        'Supplier'
    )
    AND domain_id = 'Drug'
)
-- Attributes from other domains
OR (
    concept_class_id IN (
        'LOINC Component',
        'LOINC Method',
        'LOINC Property',
        'LOINC Scale',
        'LOINC System',
        'LOINC Time'
    )
)
OR (
    vocabulary_id IN ('SNOMED', 'SNOMED Veterinary', 'Nebraska Lexicon', 'OMOP Extension')
    AND concept_class_id IN ('Qualifier Value', 'Attribute')
)
ON CONFLICT ON CONSTRAINT xpk_concept_metadata
DO UPDATE SET concept_category = concept_metadata.concept_category
WHERE ROW (concept_metadata.concept_category) IS DISTINCT FROM ROW (excluded.concept_category);
