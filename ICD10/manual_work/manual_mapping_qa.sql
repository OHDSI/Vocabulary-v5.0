-- 1 -- create table for checks
DROP TABLE icd10_manual_checks;

CREATE TABLE icd10_manual_checks 
AS
SELECT b.concept_id,
       b.concept_code,
       b.concept_name,
       a.relationship_id,
       c.concept_id AS sno_id,
       c.concept_code AS sno_code,
       c.concept_name AS sno_name
FROM dev_icd10.concept_manual_relationship a
  JOIN concept b
    ON b.concept_code = a.concept_code_1
   AND b.vocabulary_id = 'ICD10'
  JOIN concept c
    ON c.concept_code = a.concept_code_2
   AND c.vocabulary_id = 'SNOMED'
WHERE a.invalid_reason IS NULL;

-- 2 --count different rows number and relationship_ids. The difference between total number of (distinct) rows in mapping and in the devv5.concept should be 600 rows.
SELECT 'row number - total in mapping' AS issue_desc,
       COUNT(concept_code)
FROM icd10_manual_checks
UNION
SELECT 'row number - total distinct in mapping' AS issue_desc,
       COUNT(DISTINCT concept_code)
FROM icd10_manual_checks
UNION
SELECT 'row number - total ICD10 concepts in concept' AS issue_desc,
       COUNT(concept_code)
FROM concept c
WHERE c.vocabulary_id = 'ICD10'
UNION
SELECT 'relationship_id - Maps to + Maps to value' AS issue_desc,
       COUNT(DISTINCT concept_code)
FROM icd10_manual_checks
WHERE concept_code IN (SELECT concept_code
                       FROM icd10_manual_checks
                       WHERE relationship_id = 'Maps to value')
AND   concept_code IN (SELECT concept_code
                       FROM icd10_manual_checks
                       WHERE relationship_id = 'Maps to')
UNION
SELECT 'relationship_id - Maps to  only' AS issue_desc,
       COUNT(DISTINCT concept_code)
FROM icd10_manual_checks
WHERE concept_code IN (SELECT concept_code
                       FROM icd10_manual_checks
                       WHERE relationship_id = 'Maps to')
AND   concept_code NOT IN (SELECT concept_code
                           FROM icd10_manual_checks
                           WHERE relationship_id = 'Maps to value')
UNION
SELECT 'relationship_id - to more then one Is a ' AS issue_desc,
       COUNT(DISTINCT concept_code)
FROM icd10_manual_checks
WHERE relationship_id = 'Is a'
AND   concept_code IN (SELECT concept_code
                       FROM icd10_manual_checks
                       GROUP BY concept_code
                       HAVING COUNT(1) >= 2)
UNION
SELECT 'relationship_id - to one Is a' AS issue_desc,
       COUNT(DISTINCT concept_code)
FROM icd10_manual_checks
WHERE relationship_id = 'Is a'
AND   concept_code IN (SELECT concept_code
                       FROM icd10_manual_checks
                       GROUP BY concept_code
                       HAVING COUNT(1) = 1)
ORDER BY issue_desc;

--3--check presence of problems in ICD10 manual mapping - all queries should return null 
WITH icd10_proc_and_cond
AS
(SELECT a.*,
       c.concept_class_id,
       c.domain_id
FROM icd10_manual_checks a
  JOIN concept c ON a.sno_id = c.concept_id
WHERE a.concept_code IN (SELECT concept_code
                         FROM icd10_manual_checks
                         GROUP BY concept_code
                         HAVING COUNT(1) > 1)
AND   a.concept_code IN (SELECT a.concept_code
                         FROM icd10_manual_checks a
                           JOIN concept c
                             ON a.sno_id = c.concept_id
                            AND c.domain_id IN ('Procedure'))
AND   domain_id NOT IN ('Measurement')
AND   a.concept_code NOT IN (SELECT concept_code
                             FROM icd10_manual_checks
                             WHERE relationship_id = 'Maps to value')) SELECT 'mapping issue - Condition + Procedure' AS issue_desc,COUNT(DISTINCT concept_code) FROM icd10_manual_checks WHERE concept_code IN (SELECT concept_code
                                                                                                                                                                                                                 FROM (SELECT *,
                                                                                                                                                                                                                              LAST_VALUE(domain_id) OVER (PARTITION BY concept_code) = 'Procedure' AS last_domain,
                                                                                                                                                                                                                              FIRST_VALUE(domain_id) OVER (PARTITION BY concept_code) = 'Procedure' AS first_domain
                                                                                                                                                                                                                       FROM icd10_proc_and_cond) n
                                                                                                                                                                                                                 WHERE last_domain <> first_domain
                                                                                                                                                                                                                 ORDER BY concept_code)
UNION
SELECT 'mapping issue - non-standard concepts' AS issue_desc,
       COUNT(sno_id)
FROM icd10_manual_checks
WHERE concept_id IN (SELECT icd.concept_id
                     FROM icd10_manual_checks icd
                       LEFT JOIN concept c
                              ON icd.sno_id = c.concept_id
                             AND c.standard_concept = 'S'
                     WHERE c.concept_id IS NULL)
UNION
SELECT 'empty concept_id' AS issue_desc,
       COUNT(concept_id)
FROM icd10_manual_checks
WHERE concept_id IS NULL
UNION
SELECT 'empty concept_code' AS issue_desc,
       COUNT(concept_id)
FROM icd10_manual_checks
WHERE concept_code = ''
UNION
SELECT 'empty concept_name' AS issue_desc,
       COUNT(concept_id)
FROM icd10_manual_checks
WHERE concept_name = ''
UNION
SELECT 'empty sno_id' AS issue_desc,
       COUNT(concept_id)
FROM icd10_manual_checks
WHERE sno_id IS NULL
UNION
SELECT 'empty sno_code' AS issue_desc,
       COUNT(concept_id)
FROM icd10_manual_checks
WHERE sno_code = ''
UNION
SELECT 'empty sno_name' AS issue_desc,
       COUNT(concept_id)
FROM icd10_manual_checks
WHERE sno_name = ''
UNION
SELECT 'incorrect ICD10 concept_code' AS issue_desc,
       COUNT(concept_code)
FROM icd10_manual_checks
WHERE concept_code NOT IN (SELECT concept_code FROM concept WHERE vocabulary_id = 'ICD10')
UNION
SELECT 'incorrect ICD10 concept_id' AS issue_desc,
       COUNT(concept_id)
FROM icd10_manual_checks
WHERE concept_id NOT IN (SELECT concept_id FROM concept WHERE vocabulary_id = 'ICD10')
UNION
SELECT 'incorrect ICD10 concept_name' AS issue_desc,
       COUNT(concept_name)
FROM icd10_manual_checks
WHERE concept_name NOT IN (SELECT concept_name FROM concept WHERE vocabulary_id = 'ICD10')
-- in this case these classes are ok: 'Location','Observable Entity', 'Physical Force', 'Qualifier Value'
UNION
SELECT 'incorrect relationship_id' AS issue_desc,
       COUNT(relationship_id)
FROM icd10_manual_checks
WHERE relationship_id NOT IN ('Maps to','Maps to value','Is a')
UNION
SELECT 'incorrect SNOMED concept_id' AS issue_desc,
       COUNT(sno_id)
FROM icd10_manual_checks
WHERE sno_id NOT IN (SELECT concept_id FROM concept WHERE vocabulary_id = 'SNOMED')
UNION
SELECT 'incorrect SNOMED concept_code' AS issue_desc,
       COUNT(sno_code)
FROM icd10_manual_checks
WHERE sno_code NOT IN (SELECT concept_code
                       FROM concept
                       WHERE vocabulary_id = 'SNOMED'
                       AND   standard_concept = 'S')
UNION
SELECT 'incorrect SNOMED concept_name' AS issue_desc,
       COUNT(sno_name)
FROM icd10_manual_checks
WHERE sno_name NOT IN (SELECT concept_name
                       FROM concept
                       WHERE vocabulary_id = 'SNOMED'
                       AND   standard_concept = 'S')
UNION
SELECT 'incorrect SNOMED concept_class_id' AS issue_desc,
       COUNT(a.sno_id)
FROM icd10_manual_checks a
  JOIN concept c ON a.sno_id = c.concept_id
WHERE c.vocabulary_id = 'SNOMED'
AND   c.standard_concept = 'S'
AND   c.concept_class_id IN ('Body Structure','Morph Abnormality','Organism','Physical Object','Substance','Qualifier Value')
--  in this case these classes are ok: 'Location','Observable Entity', 'Physical Force', 
AND   a.relationship_id != 'Maps to value'
UNION
SELECT 'relationship id - doubled Maps to' AS issue_desc,
       COUNT(DISTINCT concept_code)
FROM icd10_manual_checks
WHERE concept_code IN (SELECT concept_code
                       FROM icd10_manual_checks
                       WHERE relationship_id = 'Maps to'
                       GROUP BY concept_code,
                                relationship_id
                       HAVING COUNT(1) >= 2)
UNION
SELECT 'duplicates' AS issue_desc,
       COUNT(DISTINCT concept_code)
FROM icd10_manual_checks
WHERE concept_code IN (SELECT concept_code
                       FROM icd10_manual_checks
                       GROUP BY concept_code,
                                sno_id
                       HAVING COUNT(1) >= 2)
UNION
SELECT 'relationship_id - Maps to value with incorrect pair of relationship_id' AS issue_desc,
       COUNT(concept_code)
FROM icd10_manual_checks
WHERE concept_code IN (SELECT concept_code
                       FROM icd10_manual_checks
                       WHERE relationship_id = 'Maps to value')
AND   concept_code NOT IN (SELECT concept_code
                           FROM icd10_manual_checks
                           WHERE relationship_id = 'Maps to')
UNION
SELECT 'relationship_id - Maps to value without Maps to ' AS issue_desc,
       COUNT(concept_code)
FROM icd10_manual_checks
WHERE concept_code IN (SELECT concept_code
                       FROM icd10_manual_checks
                       GROUP BY concept_code
                       HAVING COUNT(1) = 1)
AND   concept_code IN (SELECT concept_code
                       FROM icd10_manual_checks
                       WHERE relationship_id = 'Maps to value')
UNION
SELECT 'missed ICD10 concepts from concept' AS issue_desc,
       COUNT(concept_code)
FROM concept
WHERE concept_code NOT IN (SELECT concept_code FROM icd10_manual_checks)
AND   vocabulary_id = 'ICD10'
AND   concept_code !~ '^\d+'
-- 0  -- take a notice that navigational concepts in ICD10 have totally numeric concept_code, so they are excluded;  
UNION
SELECT 'mapping issue - incorrect History of' AS issue_desc,
       COUNT(DISTINCT concept_code)
FROM icd10_manual_checks
WHERE concept_name ~* 'histor'
AND   concept_code IN (SELECT concept_code
                       FROM icd10_manual_checks
                       GROUP BY concept_code
                       HAVING COUNT(1) > 1)
AND   concept_code NOT IN (SELECT concept_code
                           FROM icd10_manual_checks
                           WHERE sno_id IN (4167217,4214956,4215685))
AND   concept_code !~* 'Z35'
UNION
SELECT 'mapping issue - lost Finding related to pregnancy' AS issue_desc,
       COUNT(DISTINCT k.concept_code)
FROM icd10_manual_checks k
  JOIN concept c ON k.sno_id = c.concept_id
WHERE k.concept_id NOT IN (SELECT a.concept_id
                           FROM icd10_manual_checks a
                             JOIN concept_ancestor b
                               ON sno_id = b.descendant_concept_id
                              AND ancestor_concept_id = 444094)
AND   k.concept_id IN (SELECT concept_id
                       FROM icd10_manual_checks
                       WHERE concept_code ~ '^O')
AND   c.domain_id != 'Procedure'
UNION
SELECT 'relationship_id - Maps to instead of Is a' AS issue_desc,
       COUNT(concept_code)
FROM icd10_manual_checks
WHERE concept_name ~* 'other\s+|\s+other|classified\s+elsewhere|not\s+elsewhere\s+classified'
AND   concept_name !~* 'other and unspecified|not otherwise specified|other than'
AND   relationship_id != 'Is a'
AND   concept_code NOT IN (SELECT concept_code
                           FROM icd10_manual_checks
                           WHERE relationship_id = 'Maps to value')
AND   sno_name !~* 's+other|other\s+'
UNION
SELECT 'relationship_id -  hierarchical concept (^\w.\d+$) and the last concept in the chapter (^\w.\d+\.9%) should have equal rel_id, but not' AS issue_desc,
       COUNT(DISTINCT a1.concept_code)
FROM (SELECT concept_code,
             concept_name,
             relationship_id,
             sno_id,
             sno_name
      FROM icd10_manual_checks
      WHERE concept_code IN (SELECT concept_code
                             FROM icd10_manual_checks
                             WHERE concept_code ~ '^\w.\d+$')) a1
  JOIN (SELECT concept_code,
               concept_name,
               relationship_id,
               sno_id,
               sno_name
        FROM icd10_manual_checks
        WHERE concept_code IN (SELECT concept_code
                               FROM icd10_manual_checks
                               WHERE concept_code ~ '^\w.\d+\.9$')) a2
    ON a1.concept_code|| '.9' = a2.concept_code
   AND a1.relationship_id <> a2.relationship_id
   AND a1.sno_id = a2.sno_id
WHERE a2.concept_name ~* 'unspecified'
AND   a1.concept_name !~* 'other|not elsewhere classified'
AND   a1.concept_code NOT IN ('M76','M81','R22','S92')
-- these concepts have difference in names
UNION
SELECT 'mapping issue - mapped to Parent and Child simultaneously' AS issue_desc,
       COUNT(DISTINCT a1.concept_code)
FROM (SELECT *
      FROM icd10_manual_checks
      WHERE concept_id IN (SELECT concept_id
                           FROM icd10_manual_checks
                           GROUP BY concept_id
                           HAVING COUNT(1) >= 2)) a1
  JOIN (SELECT *
        FROM icd10_manual_checks
        WHERE concept_id IN (SELECT concept_id
                             FROM icd10_manual_checks
                             GROUP BY concept_id
                             HAVING COUNT(1) >= 2)) a2 ON a1.concept_id = a2.concept_id
  JOIN concept_ancestor ca
    ON a1.sno_id = ca.ancestor_concept_id
   AND a2.sno_id = ca.descendant_concept_id
   AND a1.sno_id <> a2.sno_id
UNION
SELECT 'relationship_id - incompatiable relationship_id combination' AS issue_desc,
       COUNT(DISTINCT concept_code)
FROM icd10_manual_checks
WHERE concept_code IN (SELECT concept_code
                       FROM icd10_manual_checks
                       GROUP BY concept_code
                       HAVING COUNT(1) > 1)
AND   concept_code IN (SELECT concept_code
                       FROM icd10_manual_checks
                       WHERE relationship_id = 'Maps to')
AND   concept_code IN (SELECT concept_code
                       FROM icd10_manual_checks
                       WHERE relationship_id = 'Is a')
UNION
SELECT 'relationship_id - Is a instead of Maps to' AS issue_desc,
       COUNT(DISTINCT concept_code)
FROM icd10_manual_checks
WHERE concept_code IN (SELECT concept_code
                       FROM icd10_manual_checks
                       GROUP BY concept_code
                       HAVING COUNT(1) = 1)
AND   concept_code IN (SELECT concept_code
                       FROM icd10_manual_checks
                       WHERE LOWER(concept_name) = LOWER(sno_name)
                       AND   relationship_id = 'Is a');

ORDER BY issue_desc;
