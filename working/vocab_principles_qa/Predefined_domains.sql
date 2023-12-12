--Check how domain_ids are consistent with concept_class_ids
--current selection of domains and concept_classes is based on a current state of OHDSI vocabs
SELECT c.domain_id, c.concept_class_id, count(c.concept_id)
FROM devv5.concept c

WHERE (c.domain_id = 'Unit' AND c.concept_class_id NOT IN ('Canonical Unit', 'Unit'))
        OR (c.domain_id = 'Visit' AND c.concept_class_id NOT IN ('Visit'))
        OR (c.domain_id = 'Type Concept' AND c.concept_class_id NOT IN ('Type Concept'))
        OR (c.domain_id = 'Sponsor' AND c.concept_class_id NOT IN ('Sponsor'))
        OR (c.domain_id = 'Specimen' AND c.concept_class_id NOT IN ('Specimen'))
        OR (c.domain_id = 'Spec Disease Status' AND c.concept_class_id NOT IN ('Qualifier Value'))
        OR (c.domain_id = 'Spec Anatomic Site' AND c.concept_class_id NOT IN ('Body Structure', 'CPT4 Modifier', 'ICDO Topography'))
        OR (c.domain_id = 'Route' AND c.concept_class_id NOT IN ('Qualifier Value'))
        OR (c.domain_id = 'Revenue Code' AND c.concept_class_id NOT IN ('Revenue Code'))
        OR (c.domain_id = 'Relationship' AND c.concept_class_id NOT IN ('Social Context'))
        OR (c.domain_id = 'Regimen' AND c.concept_class_id NOT IN ('Regimen', 'Modality'))
        OR (c.domain_id = 'Race' AND c.concept_class_id NOT IN ('Race'))
        OR (c.domain_id = 'Provider' AND c.concept_class_id NOT IN ('Physician Specialty', 'Provider'))
        OR (c.domain_id = 'Procedure' AND c.concept_class_id NOT IN ('ICD10PCS Hierarchy', 'ICD10PCS', 'Procedure', 'CPT4', 'Clinical Observation',
                                                                    'NAACCR Procedure', 'HCPCS', 'CPT4 Hierarchy', 'CPT4 Modifier', 'NAACCR Value', 'Context',
                                                                    'HCPCS Modifier'))
        OR (c.domain_id = 'Plan Stop Reason' AND c.concept_class_id NOT IN ('Plan Stop Reason'))
        OR (c.domain_id = 'Payer' AND c.concept_class_id NOT IN ('Payer'))
        OR (c.domain_id = 'Plan' AND c.concept_class_id NOT IN ('Plan'))

--TODO: proceed with other domains

GROUP BY domain_id, concept_class_id;



--Check if new domains in standard concepts appear outside of these vocabularies
SELECT c.vocabulary_id, c.domain_id, count(c.concept_id) AS counts
FROM devv5.concept c

WHERE c.standard_concept = 'S'
GROUP BY vocabulary_id, domain_id
ORDER BY vocabulary_id, counts DESC
;


--Text matching if measurements are assigned Measurement domain
--1203
SELECT count(*)
FROM devv5.concept c
WHERE standard_concept ='S'
AND domain_id != 'Measurement'
AND concept_name ILIKE '%measurement%';


--Number of Standard procedures that have a Measurement (not necessarily Standard) with a same name and not mapped to them
--160
SELECT COUNT(DISTINCT c1.concept_id)
FROM devv5.concept c1
INNER JOIN devv5.concept c2 ON c1.concept_name = c2.concept_name
    AND c1.standard_concept = 'S'
    AND c1.domain_id = 'Procedure'
    AND c2.domain_id = 'Measurement'
WHERE NOT EXISTS (SELECT 1
    FROM (SELECT c.concept_id AS id_1, cr.relationship_id, cc.concept_id AS id_2, cc.domain_id
          FROM devv5.concept c
          INNER JOIN devv5.concept_relationship cr ON c.concept_id = cr.concept_id_1
          INNER JOIN devv5.concept cc ON cr.concept_id_2 = cc.concept_id) sub
    WHERE sub.id_1 = c2.concept_id
    AND sub.relationship_id = 'Maps to'
    AND sub.domain_id = 'Procedure')
;


--Number of Standard Measurements that have a Procedure with a same name and not mapped to them
--345
SELECT COUNT(DISTINCT c2.concept_id)
FROM devv5.concept c1
INNER JOIN devv5.concept c2 ON c1.concept_name = c2.concept_name
    AND c1.standard_concept = 'S'
    AND c1.domain_id = 'Measurement'
    AND c2.domain_id = 'Procedure'
WHERE NOT EXISTS (SELECT 1
    FROM (SELECT c.concept_id AS id_1, cr.relationship_id, cc.concept_id AS id_2, cc.domain_id
          FROM devv5.concept c
          INNER JOIN devv5.concept_relationship cr ON c.concept_id = cr.concept_id_1
          INNER JOIN devv5.concept cc ON cr.concept_id_2 = cc.concept_id) sub
    WHERE sub.id_1 = c2.concept_id
    AND sub.relationship_id = 'Maps to'
    AND sub.domain_id = 'Measurement')
;


-- Presumably, concepts that represent ingredients of drugs should be drugs (SNOMED check)
SELECT c.*
FROM concept c
JOIN concept_relationship cr
    ON cr.concept_id_1 = c.concept_id
JOIN concept cc
    ON cc.concept_id = cr.concept_id_2
WHERE cr.relationship_id = 'Prec ingredient of' AND cr.invalid_reason IS NULL
AND cc.domain_id = 'Drug'
AND c.domain_id != 'Drug';


--Presumably, all concepts that have ingredient name in their concept_name, are drugs:
--! Very heavy query
WITH ingredients AS (
       SELECT DISTINCT concept_name
       FROM concept
       WHERE concept_class_id = 'Ingredient'
       AND standard_concept = 'S'
       and concept_name !~* '[0-9]'
),

ing_regexp AS (
SELECT string_agg(concept_name, '|') AS ing_regexp
       FROM ingredients
       where concept_name ~* '[0-9]'),

exclusion AS (SELECT 'adverse|spf|antiseptic|dressing|plaster' AS exclusion)

SELECT *
FROM concept c
WHERE c.concept_name ~* (SELECT ('||ing_regexp||') FROM ing_regexp)
AND c.concept_name !~* (SELECT exclusion FROM exclusion)
AND c.concept_class_id != 'Ingredient'
AND c.domain_id not in ('Drug', 'Provider')
AND vocabulary_id != 'AMIS' -- in German
ORDER BY vocabulary_id, domain_id, standard_concept, concept_name
;


--concept is present in drug_strength but has not Drug domain
SELECT * FROM concept c
JOIN drug_strength ds
    ON ds.drug_concept_id =c.concept_id
WHERE c.domain_id != 'Drug'
;

--Standard drugs are either in drug_strength or in pack_content
SELECT *
FROM concept c
LEFT JOIN drug_strength ds
    ON ds.drug_concept_id = c.concept_id
LEFT JOIN pack_content
    ON pack_concept_id = c.concept_id
WHERE c.domain_id = 'Drug' AND c.standard_concept = 'S'
AND coalesce (ds.drug_concept_id, pack_concept_id) IS NULL
;