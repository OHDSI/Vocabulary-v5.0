--- Исследование MedDRA 240123
/*

Распределение по классам (всего - имеют маппинг - %):

SOC - 27 - 0
HLGT - 337 - 2 (0,6%)
HLT - 1737 - 5 (0,3%)
PT - 25412 - 4806 уникальных (18,9%), из них 215 - maps to many (214 - на 2 концепта, 1 - на 3 концепта), не имеют маппинга 20605
LLT - 50375 - 7939 уникальных (15,8%), из них 347 - maps to many (345 - на 2 концепта, 2 - на 3 концепта), не имеют маппинга 42434


 */

-- Распределение концептов по доменам

SELECT domain_id, COUNT(*) AS count
FROM devv5.concept
WHERE vocabulary_id='MedDRA' AND invalid_reason IS NULL
GROUP BY domain_id
ORDER BY count DESC;

-- Распределение концептов по классам

SELECT concept_class_id, COUNT(*) AS count
FROM devv5.concept
WHERE vocabulary_id='MedDRA' AND invalid_reason IS NULL
GROUP BY concept_class_id
ORDER BY count;


-- Распределение концептов по классам с актуальным маппингом на SNOMED

SELECT c.concept_class_id, COUNT(*) AS count
FROM devv5.concept AS c
INNER JOIN devv5.concept_relationship AS cr
ON c.concept_id = cr.concept_id_1 AND cr.relationship_id='Maps to' AND cr.invalid_reason is NULL
INNER JOIN devv5.concept AS cc
ON cr.concept_id_2 = cc.concept_id
WHERE c.vocabulary_id='MedDRA'
  --AND c.invalid_reason IS NULL
  AND cc.invalid_reason IS NULL and cc.standard_concept='S' AND cc.vocabulary_id='SNOMED'
GROUP BY c.concept_class_id
ORDER BY count DESC;


-- Сколько валидных концептов определенного класса имеют maps to связи на SNOMED, в том числе to many

SELECT *, row_number() over (partition by c.concept_id) AS number
FROM devv5.concept AS c
INNER JOIN devv5.concept_relationship AS cr
ON c.concept_id = cr.concept_id_1 AND cr.relationship_id='Maps to' AND cr.invalid_reason is NULL
    AND c.concept_class_id='LLT'
INNER JOIN devv5.concept AS cc
ON cr.concept_id_2 = cc.concept_id
WHERE c.vocabulary_id='MedDRA' AND c.invalid_reason IS NULL AND cc.invalid_reason IS NULL and cc.standard_concept='S' AND cc.vocabulary_id='SNOMED'
ORDER BY number DESC, c.concept_id;


-- Вывести все валидные PT концепты и соответствующие им (subsumes) LLT

SELECT c.concept_id, c.concept_name, c.concept_class_id, cc.concept_id, cc.concept_name, cc.concept_class_id
FROM devv5.concept AS c
INNER JOIN
devv5.concept_relationship AS cr
ON c.concept_id = cr.concept_id_1 AND cr.relationship_id='Subsumes' AND cr.invalid_reason IS NULL
INNER JOIN
devv5.concept AS cc
ON cr.concept_id_2=cc.concept_id
WHERE c.vocabulary_id='MedDRA' AND c.invalid_reason IS NULL AND c.concept_class_id='PT'
      AND cc.vocabulary_id='MedDRA' AND cc.invalid_reason IS NULL AND cc.concept_class_id='LLT'
ORDER BY c.concept_id;


-- Концепты PT с маппингом на SNOMED и их LLT с или без мапинга

WITH tab AS
(SELECT c.concept_id
FROM devv5.concept AS c
INNER JOIN devv5.concept_relationship AS cr
ON c.concept_id=cr.concept_id_1 AND c.vocabulary_id='MedDRA' AND c.invalid_reason IS NULL and cr.relationship_id='Maps to' AND cr.invalid_reason IS NULL
INNER JOIN devv5.concept AS cc
ON cr.concept_id_2=cc.concept_id AND cc.vocabulary_id='SNOMED' AND cc.invalid_reason IS NULL
)

SELECT c.concept_id, c.concept_name, c.concept_class_id, cr2.relationship_id, ccc.concept_id, ccc.concept_name, ccc.vocabulary_id,
cr.relationship_id, cc.concept_id, cc.concept_name, cc.concept_class_id, cr3.relationship_id, cccc.concept_id, cccc.concept_name, cccc.vocabulary_id,
row_number() over (partition by c.concept_name) AS number_LLT
FROM devv5.concept AS c
INNER JOIN devv5.concept_relationship AS cr
ON c.concept_id=cr.concept_id_1 AND c.vocabulary_id='MedDRA' and c.concept_class_id='PT' and c.invalid_reason IS NULL AND cr.relationship_id='Subsumes'
AND cr.invalid_reason IS NULL
AND c.concept_id IN (SELECT concept_id FROM tab)
INNER JOIN devv5.concept AS cc
ON cr.concept_id_2=cc.concept_id AND cc.vocabulary_id='MedDRA' AND cc.invalid_reason IS NULL
LEFT JOIN devv5.concept_relationship AS cr2
ON c.concept_id=cr2.concept_id_1 AND cr2.relationship_id='Maps to' AND cr2.invalid_reason IS NULL
LEFT JOIN devv5.concept AS ccc
ON cr2.concept_id_2=ccc.concept_id AND ccc.vocabulary_id='SNOMED' AND ccc.invalid_reason IS NULL
LEFT JOIN devv5.concept_relationship AS cr3
ON cc.concept_id=cr3.concept_id_1 AND cr3.relationship_id='Maps to' AND cr3.invalid_reason IS NULL
LEFT JOIN devv5.concept AS cccc
ON cr3.concept_id_2=cccc.concept_id AND cccc.vocabulary_id='SNOMED' AND cccc.invalid_reason IS NULL;


-- Концепты LLT с маппингом на SNOMED и соответствующие им PT c или без маппинга на SNOMED

WITH tab AS
(SELECT c.concept_id
FROM devv5.concept AS c
INNER JOIN devv5.concept_relationship AS cr
ON c.concept_id=cr.concept_id_1 AND c.vocabulary_id='MedDRA' AND c.invalid_reason IS NULL and cr.relationship_id='Maps to' AND cr.invalid_reason IS NULL
INNER JOIN devv5.concept AS cc
ON cr.concept_id_2=cc.concept_id AND cc.vocabulary_id='SNOMED' AND cc.invalid_reason IS NULL
)

SELECT c.concept_id, c.concept_name, c.concept_class_id, cr2.relationship_id, ccc.concept_id, ccc.concept_name, ccc.vocabulary_id,
cr.relationship_id, cc.concept_id, cc.concept_name, cc.concept_class_id, cr3.relationship_id, cccc.concept_id, cccc.concept_name, cccc.vocabulary_id,
row_number() over (partition by cc.concept_name) AS number_LLT
FROM devv5.concept AS c
INNER JOIN devv5.concept_relationship AS cr
ON c.concept_id=cr.concept_id_1 AND c.vocabulary_id='MedDRA' and c.concept_class_id='LLT' and c.invalid_reason IS NULL AND cr.relationship_id='Is a'
AND cr.invalid_reason IS NULL
AND c.concept_id IN (SELECT concept_id FROM tab)
INNER JOIN devv5.concept AS cc
ON cr.concept_id_2=cc.concept_id AND cc.vocabulary_id='MedDRA' AND cc.invalid_reason IS NULL
LEFT JOIN devv5.concept_relationship AS cr2
ON c.concept_id=cr2.concept_id_1 AND cr2.relationship_id='Maps to' AND cr2.invalid_reason IS NULL
LEFT JOIN devv5.concept AS ccc
ON cr2.concept_id_2=ccc.concept_id AND ccc.vocabulary_id='SNOMED' AND ccc.invalid_reason IS NULL
LEFT JOIN devv5.concept_relationship AS cr3
ON cc.concept_id=cr3.concept_id_1 AND cr3.relationship_id='Maps to' AND cr3.invalid_reason IS NULL
LEFT JOIN devv5.concept AS cccc
ON cr3.concept_id_2=cccc.concept_id AND cccc.vocabulary_id='SNOMED' AND cccc.invalid_reason IS NULL;

-- Вывести PT, не имеющие маппинга

SELECT *
FROM devv5.concept
WHERE vocabulary_id='MedDRA' and concept_class_id='PT' and invalid_reason IS NULL AND
      concept_id NOT IN (
        SELECT c.concept_id
        FROM devv5.concept AS c
        INNER JOIN devv5.concept_relationship AS cr
        ON c.concept_id = cr.concept_id_1 AND cr.relationship_id='Maps to' AND cr.invalid_reason is NULL
        INNER JOIN devv5.concept AS cc
        ON cr.concept_id_2 = cc.concept_id
        WHERE c.vocabulary_id='MedDRA' AND c.invalid_reason IS NULL AND cc.invalid_reason IS NULL and cc.standard_concept='S' AND cc.vocabulary_id='SNOMED' AND cc.invalid_reason IS NULL
        )
  -- AND concept_code NOT IN (SELECT source_code FROM dev_msalavei.meddra_pt_umls_mapped)
   ;
-- Вывести LLT, не имеющие маппинга

SELECT *
FROM devv5.concept
WHERE vocabulary_id='MedDRA' and concept_class_id='LLT' and invalid_reason IS NULL AND
      concept_id NOT IN (
        SELECT c.concept_id
        FROM devv5.concept AS c
        INNER JOIN devv5.concept_relationship AS cr
        ON c.concept_id = cr.concept_id_1 AND cr.relationship_id='Maps to' AND cr.invalid_reason is NULL
        INNER JOIN devv5.concept AS cc
        ON cr.concept_id_2 = cc.concept_id
        WHERE c.vocabulary_id='MedDRA' AND c.invalid_reason IS NULL AND cc.invalid_reason IS NULL and cc.standard_concept='S' AND cc.vocabulary_id='SNOMED' AND cc.invalid_reason IS NULL
        );


-- Забор готового маппинга из UMLS

WITH tab AS (

SELECT concept_code
FROM devv5.concept
WHERE vocabulary_id='MedDRA' and concept_class_id='LLT' and invalid_reason IS NULL AND
      concept_id NOT IN (
        SELECT c.concept_id
        FROM devv5.concept AS c
        INNER JOIN devv5.concept_relationship AS cr
        ON c.concept_id = cr.concept_id_1 AND cr.relationship_id='Maps to' AND cr.invalid_reason is NULL
        INNER JOIN devv5.concept AS cc
        ON cr.concept_id_2 = cc.concept_id
        WHERE c.vocabulary_id='MedDRA' AND c.invalid_reason IS NULL AND cc.invalid_reason IS NULL and cc.standard_concept='S' AND cc.vocabulary_id='SNOMED' AND cc.invalid_reason IS NULL
        )
)

SELECT t1.cui, t1.vocabulary_id AS MedDRA, t1.concept_code AS source_code, t1.concept_name AS MedDRA_concept_name, t2.vocabulary_id AS SNOMED, t2.concept_code AS targed_code, t2.concept_name AS SNOMED_concept_name,
       row_number() over (partition by t1.concept_code ||' '||t2.concept_code) AS sort
--INTO dev_msalavei.meddra_LLT_UMLS_mapped
FROM dev_msalavei.umls_2023 AS t1
             INNER JOIN dev_msalavei.umls_2023 AS t2
                        ON t1.cui = t2.cui
    WHERE t1.concept_code IN (SELECT concept_code FROM tab)
        AND t1.vocabulary_id ='MDR'
    AND t2.vocabulary_id = 'SNOMEDCT_US'
    AND t2.concept_code IN (SELECT concept_code FROM devv5.concept WHERE vocabulary_id='SNOMED' AND invalid_reason IS NULL AND standard_concept='S')
    ORDER BY sort;

-- Using UMLS we create 2 temporary tables with MedDRA-to-SNOMED mapping: meddra_llt_umls_mapped and meddra_pt_umls_mapped

--Check the parents of MedDRA code (including itselt)
SELECT cc.concept_name, cc.concept_class_id, ca.max_levels_of_separation, cc.concept_code
FROM devv5.concept c

JOIN devv5.concept_ancestor ca
    ON c.concept_id = ca.descendant_concept_id
JOIN devv5.concept cc
    ON ca.ancestor_concept_id = cc.concept_id
        -- c.concept_code - code, for which we want to construct hierarchy
WHERE     c.concept_code = '10037810' AND c.vocabulary_id = 'MedDRA' AND cc.vocabulary_id = 'MedDRA'
ORDER BY ca.max_levels_of_separation DESC;


--Check the children of MedDRA code (including itselt)
SELECT cc.concept_name, cc.concept_class_id, ca.max_levels_of_separation, cc.concept_code
FROM devv5.concept c

JOIN devv5.concept_ancestor ca
    ON c.concept_id = ca.ancestor_concept_id
JOIN devv5.concept cc
    ON ca.descendant_concept_id = cc.concept_id

WHERE c.concept_code = '10013722' AND
      c.vocabulary_id = 'MedDRA' AND cc.vocabulary_id = 'MedDRA'
ORDER BY ca.max_levels_of_separation;


