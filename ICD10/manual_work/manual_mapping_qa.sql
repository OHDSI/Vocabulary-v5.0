/**************************************************************************
* Copyright 2016 Observational Health Data Sciences and Informatics (OHDSI)
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
* 
* Authors: Polina Talapova, Darina Ivakhnenko, Dmitry Dymshyts
* Date: 2021
**************************************************************************/

--  create table for checks
DROP TABLE icd10_manual_checks;
CREATE TABLE icd10_manual_checks 
AS
SELECT b.concept_id as icd_id,
       b.concept_code as icd_code,
       b.concept_name as icd_name,
       a.relationship_id,
       c.concept_id,
       c.concept_code ,
       c.concept_name 
FROM concept_relationship_manual a
  JOIN concept b
    ON b.concept_code = a.concept_code_1
   AND b.vocabulary_id = 'ICD10'
  JOIN concept c
    ON c.concept_code = a.concept_code_2
   AND c.vocabulary_id = 'SNOMED'
WHERE a.invalid_reason IS NULL;

-- count different rows number and relationship_ids. The difference between total number of (distinct) rows in mapping and in the devv5.concept should be 600 rows.
SELECT 'row number - total in mapping' AS issue_desc,
       COUNT(icd_code)
FROM icd10_manual_checks
  UNION
SELECT 'row number - total distinct in mapping' AS issue_desc,
       COUNT(DISTINCT icd_code)
FROM icd10_manual_checks
  UNION
SELECT 'row number - total ICD10 concepts in concept' AS issue_desc,
       COUNT(concept_code)
FROM concept c
WHERE c.vocabulary_id = 'ICD10'
  UNION
SELECT 'relationship_id - Maps to + Maps to value' AS issue_desc,
       COUNT(DISTINCT icd_code)
FROM icd10_manual_checks
WHERE icd_code IN (SELECT icd_code
                       FROM icd10_manual_checks
                       WHERE relationship_id = 'Maps to value')
AND   icd_code IN (SELECT icd_code
                       FROM icd10_manual_checks
                       WHERE relationship_id = 'Maps to')
  UNION
SELECT 'relationship_id - Maps to  only' AS issue_desc,
       COUNT(DISTINCT icd_code)
FROM icd10_manual_checks
WHERE icd_code IN (SELECT icd_code
                       FROM icd10_manual_checks
                       WHERE relationship_id = 'Maps to')
AND   icd_code NOT IN (SELECT icd_code
                           FROM icd10_manual_checks
                           WHERE relationship_id = 'Maps to value')
  UNION
SELECT 'relationship_id - to more then one Is a ' AS issue_desc,
       COUNT(DISTINCT icd_code)
FROM icd10_manual_checks
WHERE relationship_id = 'Is a'
AND   icd_code IN (SELECT icd_code
                       FROM icd10_manual_checks
                       GROUP BY icd_code
                       HAVING COUNT(1) >= 2)
  UNION
SELECT 'relationship_id - to one Is a' AS issue_desc,
       COUNT(DISTINCT icd_code)
FROM icd10_manual_checks
WHERE relationship_id = 'Is a'
AND   icd_code IN (SELECT icd_code
                       FROM icd10_manual_checks
                       GROUP BY icd_code
                       HAVING COUNT(1) = 1)
ORDER BY issue_desc;
/*******************************
**** MECHANICAL ERROR CHECK ****
********************************/
-- check presence of problems in ICD10 manual mapping - all queries should return null 
WITH icd10_proc_and_cond
AS
(SELECT a.*,
       c.concept_class_id,
       c.domain_id
FROM icd10_manual_checks a
  JOIN concept c ON a.concept_id = c.concept_id
WHERE a.icd_code IN (SELECT icd_code
                         FROM icd10_manual_checks
                         GROUP BY icd_code
                         HAVING COUNT(1) > 1)
AND   a.icd_code IN (SELECT a.icd_code
                         FROM icd10_manual_checks a
                           JOIN concept c
                             ON a.concept_id = c.concept_id
                            AND c.domain_id IN ('Procedure'))
AND   domain_id NOT IN ('Measurement')
AND   a.icd_code NOT IN (SELECT icd_code
                             FROM icd10_manual_checks
                             WHERE relationship_id = 'Maps to value'))
SELECT 'mapping issue - Condition + Procedure' AS issue_desc,
       COUNT(DISTINCT icd_code)
FROM icd10_manual_checks
WHERE icd_code IN (
SELECT icd_code
FROM (SELECT *,
             LAST_VALUE(domain_id) OVER (PARTITION BY icd_code) = 'Procedure' AS last_domain,
             FIRST_VALUE(domain_id) OVER (PARTITION BY icd_code) = 'Procedure' AS first_domain
      FROM icd10_proc_and_cond) n
WHERE last_domain <> first_domain
  UNION ALL
SELECT 'mapping issue - non-standard concepts' AS issue_desc,
       COUNT(concept_id)
FROM icd10_manual_checks
WHERE icd_id IN (SELECT icd.icd_id
                     FROM icd10_manual_checks icd
                       LEFT JOIN concept c
                              ON icd.concept_id = c.concept_id
                             AND c.standard_concept = 'S'
                     WHERE c.concept_id IS NULL)
  UNION ALL
SELECT 'empty icd_id' AS issue_desc,
       COUNT(icd_id)
FROM icd10_manual_checks
WHERE icd_id IS NULL
  UNION ALL
SELECT 'empty icd_code' AS issue_desc,
       COUNT(icd_id)
FROM icd10_manual_checks
WHERE icd_code = ''
  UNION ALL
SELECT 'empty icd_name' AS issue_desc,
       COUNT(icd_id)
FROM icd10_manual_checks
WHERE icd_name = ''
  UNION ALL
SELECT 'empty concept_id' AS issue_desc,
       COUNT(icd_id)
FROM icd10_manual_checks
WHERE concept_id IS NULL
  UNION ALL
SELECT 'empty concept_code' AS issue_desc,
       COUNT(icd_id)
FROM icd10_manual_checks
WHERE concept_code = ''
   UNION ALL
SELECT 'empty concept_name' AS issue_desc,
       COUNT(icd_id)
FROM icd10_manual_checks
WHERE concept_name = ''
  UNION ALL
SELECT 'incorrect ICD10 icd_code' AS issue_desc,
       COUNT(icd_code)
FROM icd10_manual_checks
WHERE icd_code NOT IN (SELECT icd_code FROM concept WHERE vocabulary_id = 'ICD10')
UNION
SELECT 'incorrect ICD10 icd_id' AS issue_desc,
       COUNT(icd_id)
FROM icd10_manual_checks
WHERE icd_id NOT IN (SELECT icd_id FROM concept WHERE vocabulary_id = 'ICD10')
  UNION ALL
SELECT 'incorrect ICD10 icd_name' AS issue_desc,
       COUNT(icd_name)
FROM icd10_manual_checks
WHERE icd_name NOT IN (SELECT icd_name FROM concept WHERE vocabulary_id = 'ICD10')
-- in this case these classes are ok: 'Location','Observable Entity', 'Physical Force', 'Qualifier Value'
  UNION ALL
SELECT 'incorrect relationship_id' AS issue_desc,
       COUNT(relationship_id)
FROM icd10_manual_checks
WHERE relationship_id NOT IN ('Maps to','Maps to value','Is a')
  UNION ALL
SELECT 'incorrect SNOMED icd_id' AS issue_desc,
       COUNT(concept_id)
FROM icd10_manual_checks
WHERE concept_id NOT IN (SELECT icd_id FROM concept WHERE vocabulary_id = 'SNOMED')
UNION
SELECT 'incorrect SNOMED icd_code' AS issue_desc,
       COUNT(concept_code)
FROM icd10_manual_checks
WHERE concept_code NOT IN (SELECT icd_code
                       FROM concept
                       WHERE vocabulary_id = 'SNOMED'
                       AND   standard_concept = 'S')
  UNION ALL
SELECT 'incorrect SNOMED icd_name' AS issue_desc,
       COUNT(concept_name)
FROM icd10_manual_checks
WHERE concept_name NOT IN (SELECT icd_name
                       FROM concept
                       WHERE vocabulary_id = 'SNOMED'
                       AND   standard_concept = 'S')
  UNION ALL
SELECT 'incorrect SNOMED concept_class_id' AS issue_desc,
       COUNT(a.concept_id)
FROM icd10_manual_checks a
  JOIN concept c ON a.concept_id = c.concept_id
WHERE c.vocabulary_id = 'SNOMED'
AND   c.standard_concept = 'S'
AND   c.concept_class_id IN ('Body Structure','Morph Abnormality','Organism','Physical Object','Substance','Qualifier Value')
--  in this case these classes are ok: 'Location','Observable Entity', 'Physical Force', 
AND   a.relationship_id != 'Maps to value'
  UNION ALL
SELECT 'relationship id - doubled Maps to' AS issue_desc,
       COUNT(DISTINCT icd_code)
FROM icd10_manual_checks
WHERE icd_code IN (SELECT icd_code
                       FROM icd10_manual_checks
                       WHERE relationship_id = 'Maps to'
                       GROUP BY icd_code,
                                relationship_id
                       HAVING COUNT(1) >= 2)
  UNION ALL
SELECT 'duplicates' AS issue_desc,
       COUNT(DISTINCT icd_code)
FROM icd10_manual_checks
WHERE icd_code IN (SELECT icd_code
                       FROM icd10_manual_checks
                       GROUP BY icd_code,
                                concept_id
                       HAVING COUNT(1) >= 2)
UNION
SELECT 'relationship_id - Maps to value with incorrect pair of relationship_id' AS issue_desc,
       COUNT(icd_code)
FROM icd10_manual_checks
WHERE icd_code IN (SELECT icd_code
                       FROM icd10_manual_checks
                       WHERE relationship_id = 'Maps to value')
AND   icd_code NOT IN (SELECT icd_code
                           FROM icd10_manual_checks
                           WHERE relationship_id = 'Maps to')
  UNION ALL
SELECT 'relationship_id - Maps to value without Maps to ' AS issue_desc,
       COUNT(icd_code)
FROM icd10_manual_checks
WHERE icd_code IN (SELECT icd_code
                       FROM icd10_manual_checks
                       GROUP BY icd_code
                       HAVING COUNT(1) = 1)
AND   icd_code IN (SELECT icd_code
                       FROM icd10_manual_checks
                       WHERE relationship_id = 'Maps to value')
  UNION ALL
SELECT 'missed ICD10 concepts from concept' AS issue_desc,
       COUNT(concept_code)
FROM concept
WHERE concept_code NOT IN (SELECT icd_code FROM icd10_manual_checks)
AND   vocabulary_id = 'ICD10'
AND   concept_code !~ '^\d+'
  UNION ALL
SELECT 'mapping issue - incorrect History of' AS issue_desc,
       COUNT(DISTINCT icd_code)
FROM icd10_manual_checks
WHERE icd_name ~* 'histor'
AND   icd_code IN (SELECT icd_code
                       FROM icd10_manual_checks
                       GROUP BY icd_code
                       HAVING COUNT(1) > 1)
AND   icd_code NOT IN (SELECT icd_code
                           FROM icd10_manual_checks
                           WHERE concept_id IN (4167217,4214956,4215685))
AND   icd_code !~* 'Z35'
  UNION ALL
SELECT 'mapping issue - lost Finding related to pregnancy' AS issue_desc,
       COUNT(DISTINCT k.icd_code)
FROM icd10_manual_checks k
  JOIN concept c ON k.concept_id = c.concept_id
WHERE k.icd_id NOT IN (SELECT a.icd_id
                           FROM icd10_manual_checks a
                             JOIN concept_ancestor b
                               ON concept_id = b.descendant_concept_id
                              AND ancestor_concept_id = 444094)
AND   k.icd_id IN (SELECT icd_id
                       FROM icd10_manual_checks
                       WHERE icd_code ~ '^O')
AND   c.domain_id != 'Procedure'
  UNION ALL
SELECT 'relationship_id - Maps to instead of Is a' AS issue_desc,
       COUNT(icd_code)
FROM icd10_manual_checks
WHERE icd_name ~* 'other\s+|\s+other|classified\s+elsewhere|not\s+elsewhere\s+classified'
AND   icd_name !~* 'other and unspecified|not otherwise specified|other than'
AND   relationship_id != 'Is a'
AND   icd_code NOT IN (SELECT icd_code
                           FROM icd10_manual_checks
                           WHERE relationship_id = 'Maps to value')
AND   concept_name !~* 's+other|other\s+'
  UNION ALL
SELECT 'relationship_id -  hierarchical concept (^\w.\d+$) and the last concept in the chapter (^\w.\d+\.9%) should have equal rel_id, but not' AS issue_desc,
       COUNT(DISTINCT a1.icd_code)
FROM (SELECT icd_code,
             icd_name,
             relationship_id,
             concept_id,
             concept_name
      FROM icd10_manual_checks
      WHERE icd_code IN (SELECT icd_code
                             FROM icd10_manual_checks
                             WHERE icd_code ~ '^\w.\d+$')) a1
  JOIN (SELECT icd_code,
               icd_name,
               relationship_id,
               concept_id,
               concept_name
        FROM icd10_manual_checks
        WHERE icd_code IN (SELECT icd_code
                               FROM icd10_manual_checks
                               WHERE icd_code ~ '^\w.\d+\.9$')) a2
    ON a1.icd_code|| '.9' = a2.icd_code
   AND a1.relationship_id <> a2.relationship_id
   AND a1.concept_id = a2.concept_id
WHERE a2.icd_name ~* 'unspecified'
AND   a1.icd_name !~* 'other|not elsewhere classified'
AND   a1.icd_code NOT IN ('M76','M81','R22','S92') -- these concepts have difference in names
  UNION ALL
SELECT 'mapping issue - mapped to Parent and Child simultaneously' AS issue_desc,
       COUNT(DISTINCT a1.icd_code)
FROM (SELECT *
      FROM icd10_manual_checks
      WHERE icd_id IN (SELECT icd_id
                           FROM icd10_manual_checks
                           GROUP BY icd_id
                           HAVING COUNT(1) >= 2)) a1
  JOIN (SELECT *
        FROM icd10_manual_checks
        WHERE icd_id IN (SELECT icd_id
                             FROM icd10_manual_checks
                             GROUP BY icd_id
                             HAVING COUNT(1) >= 2)) a2 ON a1.icd_id = a2.icd_id
  JOIN concept_ancestor ca
    ON a1.concept_id = ca.ancestor_concept_id
   AND a2.concept_id = ca.descendant_concept_id
   AND a1.concept_id <> a2.concept_id
  UNION ALL
SELECT 'relationship_id - incompatiable relationship_id combination' AS issue_desc,
       COUNT(DISTINCT icd_code)
FROM icd10_manual_checks
WHERE icd_code IN (SELECT icd_code
                       FROM icd10_manual_checks
                       GROUP BY icd_code
                       HAVING COUNT(1) > 1)
AND   icd_code IN (SELECT icd_code
                       FROM icd10_manual_checks
                       WHERE relationship_id = 'Maps to')
AND   icd_code IN (SELECT icd_code
                       FROM icd10_manual_checks
                       WHERE relationship_id = 'Is a')
  UNION ALL
SELECT 'relationship_id - Is a instead of Maps to' AS issue_desc,
       COUNT(DISTINCT icd_code)
FROM icd10_manual_checks
WHERE icd_code IN (SELECT icd_code
                       FROM icd10_manual_checks
                       GROUP BY icd_code
                       HAVING COUNT(1) = 1)
AND   icd_code IN (SELECT icd_code
                       FROM icd10_manual_checks
                       WHERE LOWER(icd_name) = LOWER(concept_name)
                       AND   relationship_id = 'Is a')
ORDER BY issue_desc;
/************************
**** SEMANTICS CHECK ****
*************************/
                         
SELECT 'possible duplicates - according to icd_code and snomed_code' AS issue_desc,
       COUNT(DISTINCT icd_code)
FROM icd10_manual_checks
WHERE icd_id IN (SELECT icd_id
                 FROM icd10_manual_checks
                 WHERE CTID NOT IN (SELECT MIN(CTID)
                                    FROM icd10_manual_checks
                                    GROUP BY icd_code,
                                             concept_id))

  UNION ALL
SELECT 'mapping issue - excessive Finding related to pregnancy' AS issue_desc,
       COUNT(DISTINCT icd_code)
FROM icd10_manual_checks
WHERE icd_code IN (SELECT a.icd_code
                   FROM icd10_manual_checks a
                     JOIN icd10_manual_checks b
                       ON a.icd_code = b.icd_code
                      AND b.concept_id IN (4299535, 444094)
            
                     JOIN concept_ancestor h
                       ON a.concept_id = h.descendant_concept_id
                      AND h.ancestor_concept_id = 444094
                      AND a.concept_id <> b.concept_id
                      AND a.icd_code ~ '^O'
                      AND a.icd_id NOT IN (SELECT concept_id FROM concept WHERE domain_id = 'Procedure'))
  UNION ALL
SELECT 'relationship_id - Maps to instead of Is a' AS issue_desc,
       COUNT(icd_code)
FROM icd10_manual_checks
WHERE icd_name ~* 'other\s+|\s+other|classified\s+elsewhere|not\s+elsewhere\s+classified'
AND   icd_name !~* 'other and unspecified|not otherwise specified|other than|another|mother'
AND   relationship_id != 'Is a'
AND   icd_code NOT IN (SELECT icd_code
                       FROM icd10_manual_checks
                       WHERE relationship_id = 'Maps to value')
AND   icd_code IN (SELECT icd_code
                   FROM icd10_manual_checks
                   WHERE concept_name !~* 's+other|other\s+')
AND   icd_code NOT IN ('T36.1X5','S12')
  UNION ALL
SELECT 'mapping issue - mapped to Parent and Child simultaneously' AS issue_desc,
       COUNT(DISTINCT a1.concept_code)
FROM (SELECT *
      FROM icd10_manual_checks
      WHERE icd_id IN (SELECT icd_id
                       FROM icd10_manual_checks
                       GROUP BY icd_id
                       HAVING COUNT(1) >= 2)) a1
  JOIN (SELECT *
        FROM icd10_manual_checks
        WHERE icd_id IN (SELECT icd_id
                         FROM icd10_manual_checks
                         GROUP BY icd_id
                         HAVING COUNT(1) >= 2)) a2 ON a1.icd_id = a2.icd_id
  JOIN concept_ancestor ca
    ON a1.concept_id = ca.ancestor_concept_id
   AND a2.concept_id = ca.descendant_concept_id
   AND a1.concept_id <> a2.concept_id
  UNION ALL
SELECT 'mapping issue - lost No loss of consciousness' AS issue_desc,
       COUNT(DISTINCT icd_code)
FROM icd10_manual_checks
WHERE icd_name ~* 'without loss of consciousness'
AND   icd_name !~* 'sequela|with or without'
AND   icd_code NOT IN (SELECT icd_code
                       FROM icd10_manual_checks
                       WHERE concept_name ~* 'no loss')
  UNION ALL 
SELECT 'mapping issue - lost OR mapped to many Sequela' AS issue_desc,
       COUNT(DISTINCT icd_code)
FROM icd10_manual_checks
WHERE icd_code IN (SELECT icd_code
                   FROM icd10_manual_checks
                   WHERE icd_name ~* 'sequela')
AND   icd_code IN (SELECT icd_code
                   FROM icd10_manual_checks
                   WHERE concept_name !~* 'Sequela|Late effect')
  UNION ALL 
SELECT 'mapping issue - lost Nonunion of fracture' AS issue_desc,
       COUNT(DISTINCT icd_code)
FROM icd10_manual_checks
WHERE icd_name ~* 'nonunion'
AND   icd_id NOT IN (SELECT icd_id
                     FROM icd10_manual_checks
                     WHERE concept_name ~* 'nonunion')
  UNION ALL 
SELECT 'mapping issue - lost Malunion of fracture' AS issue_desc,
       COUNT(DISTINCT icd_code)
FROM icd10_manual_checks
WHERE icd_name ~* 'malunion'
AND   icd_id NOT IN (SELECT icd_id
                     FROM icd10_manual_checks
                     WHERE concept_name ~* 'malunion')
  UNION ALL 
SELECT 'mapping issue - lost Closed fracture' AS issue_desc,
       COUNT(DISTINCT icd_code)
FROM icd10_manual_checks
WHERE icd_name ~* 'closed fracture'
AND   icd_id NOT IN (SELECT icd_id
                     FROM icd10_manual_checks
                     WHERE concept_name ~* 'closed')
  UNION ALL
SELECT 'mapping issue - lost Open fracture' AS issue_desc,
       COUNT(DISTINCT icd_code)
FROM icd10_manual_checks
WHERE icd_name ~* 'open fracture'
AND   icd_id NOT IN (SELECT icd_id
                     FROM icd10_manual_checks
                     WHERE concept_name ~* 'open')
  UNION ALL 
SELECT 'mapping issue - lost Delayed union of fracture' AS issue_desc,
       COUNT(DISTINCT icd_code)
FROM icd10_manual_checks
WHERE icd_id IN (SELECT icd_id
                 FROM icd10_manual_checks
                 WHERE icd_name ~* 'with delayed healing')
AND   icd_id NOT IN (SELECT icd_id
                     FROM icd10_manual_checks
                     WHERE concept_name ~* 'delayed union')
  UNION ALL
SELECT 'mapping issue - lost Foreign body' AS issue_desc,
       COUNT(DISTINCT icd_code)
FROM icd10_manual_checks
WHERE icd_name ~* 'with foreign body'
AND   icd_code NOT IN (SELECT icd_code
                       FROM icd10_manual_checks
                       WHERE concept_name ~* 'foreign body')
AND   icd_name !~* 'sequela'
  UNION ALL 
SELECT 'mapping issue - lost relation to Diabetes Mellitus when it should be' AS issue_desc,
       COUNT(DISTINCT icd_code)
FROM icd10_manual_checks
WHERE icd_code NOT IN (SELECT a.icd_code
                       FROM icd10_manual_checks a
                         JOIN concept_ancestor ca
                           ON a.concept_id = ca.descendant_concept_id
                          AND ca.ancestor_concept_id = 201820
                       WHERE icd_code ~ '^E08|^E09|^E10|^E11|^E12|^E13')
AND   icd_code ~ '^E08|^E09|^E10|^E11|^E12|^E13'
  UNION ALL 
SELECT 'mapping issue - lost Trimester of pregnancy' AS issue_desc,
       COUNT(DISTINCT icd_code)
FROM icd10_manual_checks
WHERE (icd_code IN (SELECT icd_code
                    FROM icd10_manual_checks
                    WHERE icd_name ~* 'first trimester') AND icd_code NOT IN (SELECT icd_code
                                                                              FROM icd10_manual_checks
                                                                              WHERE concept_name ~* 'first trimester'))
OR    (icd_code IN (SELECT icd_code
                    FROM icd10_manual_checks
                    WHERE icd_name ~* 'second trimester'
                    AND   icd_name !~* 'third') AND icd_code NOT IN (SELECT icd_code
                                                                     FROM icd10_manual_checks
                                                                     WHERE concept_name ~* 'second trimester'))
OR    (icd_code IN (SELECT icd_code
                    FROM icd10_manual_checks
                    WHERE icd_name ~* 'third trimester'
                    AND   icd_name !~* 'second') AND icd_code NOT IN (SELECT icd_code
                                                                      FROM icd10_manual_checks
                                                                      WHERE concept_name ~* 'third trimester'))
  UNION ALL 
SELECT 'mapping issue - lost Intentional self-harm' AS issue_desc,
       COUNT(DISTINCT icd_code)
FROM icd10_manual_checks
WHERE icd_code ~ 'T36'
AND   icd_name ~* 'intentional self\-harm'
AND   icd_code NOT IN (SELECT icd_code
                       FROM icd10_manual_checks
                       WHERE concept_name ~* 'Intentional|self'
                       AND   concept_name !~* 'unintentional')
AND   icd_name !~* 'sequela'
  UNION ALL 
SELECT 'mapping issue - lost Accidental event' AS issue_desc,
       COUNT(DISTINCT icd_code)
FROM icd10_manual_checks
WHERE icd_name ~* 'accidental'
AND   icd_code NOT IN (SELECT icd_code
                       FROM icd10_manual_checks
                       WHERE concept_name ~* 'accident|unintentional')
AND   icd_name !~* 'sequela'
AND   icd_code !~ '^T81'
  UNION ALL
SELECT 'mapping issue - lost Undetermined intent' AS issue_desc,
       COUNT(DISTINCT icd_code)
FROM icd10_manual_checks
WHERE icd_code ~ 'T36'
AND   icd_name ~* 'undetermined'
AND   icd_code NOT IN (SELECT icd_code
                       FROM icd10_manual_checks
                       WHERE concept_name ~* 'undetermined|unknown intent')
AND   icd_name !~* 'sequela'
  UNION ALL 
SELECT 'mapping issue - lost Primary malignant neoplasm' AS issue_desc,
       COUNT(DISTINCT icd_code)
FROM icd10_manual_checks a
  JOIN concept_ancestor ca
    ON a.concept_id = ca.ancestor_concept_id
   AND ca.min_levels_of_separation = 1
  JOIN concept c
    ON c.concept_id = ca.descendant_concept_id
   AND c.vocabulary_id = 'SNOMED'
   AND c.standard_concept = 'S'
   AND c.concept_name ~* 'primary'
WHERE icd_name ~* 'Malignant neoplasm'
AND   icd_code ~ 'C'
AND   icd_name !~* 'secondary|overlapping'
AND   icd_code NOT IN (SELECT icd_code
                       FROM icd10_manual_checks
                       WHERE concept_name ~* 'primary')
AND   icd_code != 'C80' --and icd_code not in ('C96.9', 'C96')
  UNION ALL 
SELECT 'mapping issue - lost Secondary malignant neoplasm' AS issue_desc,
       COUNT(DISTINCT icd_code)
FROM icd10_manual_checks
WHERE icd_name ~* 'Malignant'
AND   icd_code ~ 'C'
AND   icd_name ~* 'secondary'
AND   icd_name !~* 'Secondary and unspecified'
AND   icd_code NOT IN (SELECT icd_code
                       FROM icd10_manual_checks
                       WHERE concept_name ~* 'secondary')
AND   icd_code != 'C22.9'
  UNION ALL 
SELECT 'mapping issue - lost Overlapping malignant neoplasm' AS issue_desc,
       COUNT(DISTINCT icd_code)
FROM icd10_manual_checks
WHERE icd_code ~ 'C'
AND   icd_name ~* 'overlapping'
AND   icd_code NOT IN (SELECT icd_code
                       FROM icd10_manual_checks
                       WHERE concept_name ~* 'overlapping')
  UNION ALL 
SELECT 'mapping issue - incorrect gender' AS issue_desc,
       COUNT(DISTINCT icd_code)
FROM icd10_manual_checks
WHERE (icd_name !~* 'female' AND icd_name ~* 'male' AND icd_code IN (SELECT icd_code
                                                                     FROM icd10_manual_checks
                                                                     WHERE concept_name ~* 'female'))
OR    (icd_name !~* 'male' AND icd_name ~* 'female' AND icd_code IN (SELECT icd_code
                                                                     FROM icd10_manual_checks
                                                                     WHERE concept_name ~* '\s+male'))
  UNION ALL 
SELECT 'mapping issue - incorrect laterality' AS issue_desc,
       COUNT(DISTINCT icd_code)
FROM icd10_manual_checks
WHERE (icd_name ~* 'right' AND icd_name !~* 'left|sequela' AND icd_code IN (SELECT icd_code
                                                                            FROM icd10_manual_checks
                                                                            WHERE concept_name ~* 'left'
                                                                            AND   concept_name !~* 'cleft') AND icd_code NOT IN (SELECT icd_code
                                                                                                                                 FROM icd10_manual_checks
                                                                                                                                 WHERE concept_name ~* 'right'))
OR    (icd_name ~* 'left' AND icd_name !~* 'right|sequela' AND icd_code IN (SELECT icd_code
                                                                            FROM icd10_manual_checks
                                                                            WHERE concept_name ~* 'right') AND icd_code NOT IN (SELECT icd_code
                                                                                                                                FROM icd10_manual_checks
                                                                                                                                WHERE concept_name ~* 'left'))
  UNION ALL 
SELECT 'mapping issue - lost Refractory epilepsy or migraine' AS issue_desc,
       COUNT(DISTINCT icd_code)
FROM icd10_manual_checks
WHERE icd_name ~* 'intractable'
AND   icd_name ~* 'epilep|migrain'
AND   icd_name !~* 'not intractable'
AND   icd_code NOT IN (SELECT icd_code
                       FROM icd10_manual_checks
                       WHERE concept_name ~* 'refractor|intractable')
AND   icd_code != 'G43.D1'
  UNION ALL
SELECT 'mapping issue - non-standard concepts' AS issue_desc,
       COUNT(concept_id)
FROM icd10_manual_checks
WHERE icd_id IN (SELECT a.icd_id
                 FROM icd10_manual_checks a
                   LEFT JOIN concept c
                          ON a.concept_id = c.concept_id
                         AND c.standard_concept = 'S'
                 WHERE c.concept_id IS NULL)
  UNION ALL
SELECT 'relationship_id - Maps to value with incorrect pair of relationship_id' AS issue_desc,
       COUNT(icd_code)
FROM icd10_manual_checks
WHERE icd_code IN (SELECT icd_code
                   FROM icd10_manual_checks
                   WHERE relationship_id = 'Maps to value')
AND   icd_code NOT IN (SELECT icd_code
                       FROM icd10_manual_checks
                       WHERE relationship_id = 'Maps to')
  UNION ALL
SELECT 'relationship_id - Maps to value without Maps to ' AS issue_desc,
       COUNT(icd_code)
FROM icd10_manual_checks
WHERE icd_code IN (SELECT icd_code
                   FROM icd10_manual_checks
                   GROUP BY icd_code
                   HAVING COUNT(1) = 1)
AND   icd_code IN (SELECT icd_code
                   FROM icd10_manual_checks
                   WHERE relationship_id = 'Maps to value')
  UNION ALL
SELECT 'relationship_id - incompatiable relationship_id combination' AS issue_desc,
       COUNT(DISTINCT icd_code)
FROM icd10_manual_checks
WHERE icd_code IN (SELECT icd_code
                   FROM icd10_manual_checks
                   GROUP BY icd_code
                   HAVING COUNT(1) > 1)
AND   icd_code IN (SELECT icd_code
                   FROM icd10_manual_checks
                   WHERE relationship_id = 'Maps to')
AND   icd_code IN (SELECT icd_code
                   FROM icd10_manual_checks
                   WHERE relationship_id = 'Is a')
  UNION ALL
SELECT 'relationship_id - Is a instead of Maps to' AS issue_desc,
       COUNT(DISTINCT icd_code)
FROM icd10_manual_checks
WHERE icd_code IN (SELECT icd_code
                   FROM icd10_manual_checks
                   GROUP BY icd_code
                   HAVING COUNT(1) = 1)
AND   icd_code IN (SELECT icd_code
                   FROM icd10_manual_checks
                   WHERE LOWER(icd_name) = LOWER(concept_name)
                   AND   relationship_id = 'Is a')
  UNION ALL
SELECT 'relationship_id -  hierarchical concept (^\w.\d+$) and the last concept in the chapter (^\w.\d+\.9%) should have equal rel_id, but not' AS issue_desc,
       COUNT(DISTINCT a1.icd_code)
FROM (SELECT icd_code,
             icd_name,
             relationship_id,
             concept_id,
             concept_name
      FROM icd10_manual_checks
      WHERE icd_code IN (SELECT icd_code
                         FROM icd10_manual_checks
                         WHERE icd_code ~ '^\w.\d+$')) a1
  JOIN (SELECT icd_code,
               icd_name,
               relationship_id,
               concept_id,
               concept_name
        FROM icd10_manual_checks
        WHERE icd_code IN (SELECT icd_code
                           FROM icd10_manual_checks
                           WHERE icd_code ~ '^\w.\d+\.9$')) a2
    ON a1.icd_code|| '.9' = a2.icd_code
   AND a1.relationship_id <> a2.relationship_id
   AND a1.concept_id = a2.concept_id
WHERE a2.icd_name ~* 'unspecified'
AND   a1.icd_name !~* 'other|not elsewhere classified'
AND   a1.icd_code != 'I08'
AND   a2.icd_code != 'I08.9'
  UNION ALL
SELECT 'mapping issue - equal icd_names of various icd_codes with different mappings' AS issue_desc,
       COUNT(DISTINCT a.icd_code)
FROM icd10_manual_checks a
  JOIN icd10_manual_checks b
    ON a.icd_name = b.icd_name
   AND a.icd_code <> b.icd_code
   AND a.relationship_id <> b.relationship_id
   AND a.concept_id <> b.concept_id
WHERE a.icd_code NOT IN (SELECT icd_code
                         FROM icd10_manual_checks
                         WHERE relationship_id = 'Maps to value')
ORDER BY issue_desc;
