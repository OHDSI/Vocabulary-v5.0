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
* Date: 2022
**************************************************************************/
SELECT 'row number - total in mapping' AS issue_desc,
       COUNT(icd_code)
FROM refresh_lookup_done
  UNION
SELECT 'row number - total distinct in mapping' AS issue_desc,
       COUNT(DISTINCT icd_code)
FROM refresh_lookup_done
  UNION
SELECT 'relationship_id - Maps to + Maps to value' AS issue_desc,
       COUNT(DISTINCT icd_code)
FROM refresh_lookup_done
WHERE icd_code IN (SELECT icd_code
                       FROM refresh_lookup_done
                       WHERE repl_by_relationship = 'Maps to value')
AND   icd_code IN (SELECT icd_code
                       FROM refresh_lookup_done
                       WHERE repl_by_relationship = 'Maps to')
  UNION
SELECT 'relationship_id - Maps to only' AS issue_desc,
       COUNT(DISTINCT icd_code)
FROM refresh_lookup_done
WHERE icd_code IN (SELECT icd_code
                       FROM refresh_lookup_done
                       WHERE repl_by_relationship = 'Maps to')
AND   icd_code NOT IN (SELECT icd_code
                           FROM refresh_lookup_done
                           WHERE repl_by_relationship = 'Maps to value')
  UNION
SELECT 'relationship_id - to more than one Is a ' AS issue_desc,
       COUNT(DISTINCT icd_code)
FROM refresh_lookup_done
WHERE repl_by_relationship = 'Is a'
AND   icd_code IN (SELECT icd_code
                       FROM refresh_lookup_done
                       GROUP BY icd_code
                       HAVING COUNT(1) >= 2)
  UNION
SELECT 'relationship_id - to one Is a' AS issue_desc,
       COUNT(DISTINCT icd_code)
FROM refresh_lookup_done
WHERE repl_by_relationship = 'Is a'
AND   icd_code IN (SELECT icd_code
                       FROM refresh_lookup_done
                       GROUP BY icd_code
                       HAVING COUNT(1) = 1)
ORDER BY issue_desc;

/*******************************
**** MECHANICAL ERROR CHECK ****
********************************/
-- check presence of problems in ICD9CM manual mapping - all queries should return null
WITH ICD9CM_proc_and_cond
AS
(SELECT a.*,
       c.concept_class_id,
       c.domain_id
FROM refresh_lookup_done a
  JOIN concept c ON a.repl_by_id = c.concept_id
WHERE a.icd_code IN (SELECT icd_code
                         FROM refresh_lookup_done
                         GROUP BY icd_code
                         HAVING COUNT(1) > 1)
AND   a.icd_code IN (SELECT a.icd_code
                         FROM refresh_lookup_done a
                           JOIN concept c
                             ON a.repl_by_id = c.concept_id
                            AND c.domain_id IN ('Procedure'))
AND   c.domain_id NOT IN ('Measurement')
AND   a.icd_code NOT IN (SELECT icd_code
                             FROM refresh_lookup_done
                             WHERE repl_by_relationship = 'Maps to value'))
SELECT 'mapping issue - Condition + Procedure' AS issue_desc,
       COUNT(DISTINCT icd_code)
FROM refresh_lookup_done
WHERE icd_code IN (
SELECT icd_code
FROM (SELECT *,
             LAST_VALUE(domain_id) OVER (PARTITION BY icd_code) = 'Procedure' AS last_domain,
             FIRST_VALUE(domain_id) OVER (PARTITION BY icd_code) = 'Procedure' AS first_domain
      FROM ICD9CM_proc_and_cond) n
WHERE last_domain <> first_domain)
  UNION ALL
SELECT 'mapping issue - non-standard concepts' AS issue_desc,
       COUNT(repl_by_id)
FROM refresh_lookup_done
WHERE repl_by_id IN (SELECT icd.repl_by_id
                     FROM refresh_lookup_done icd
                       LEFT JOIN concept c
                              ON icd.repl_by_id = c.concept_id
                             AND c.standard_concept = 'S'
                     WHERE c.concept_id IS NULL)
  UNION ALL
SELECT 'empty icd_code' AS issue_desc,
       COUNT(icd_code)
FROM refresh_lookup_done
WHERE icd_code = ''
  UNION ALL
SELECT 'empty icd_name' AS issue_desc,
       COUNT(icd_code)
FROM refresh_lookup_done
WHERE icd_name = ''
  UNION ALL
SELECT 'empty repl_by_id' AS issue_desc,
       COUNT(icd_code)
FROM refresh_lookup_done
WHERE repl_by_id IS NULL
  UNION ALL
SELECT 'empty repl_by_code' AS issue_desc,
       COUNT(icd_code)
FROM refresh_lookup_done
WHERE repl_by_code = ''
   UNION ALL
SELECT 'empty repl_by_name' AS issue_desc,
       COUNT(icd_code)
FROM refresh_lookup_done
WHERE repl_by_name = ''
  UNION ALL
SELECT 'incorrect ICD9CM icd_code' AS issue_desc,
       COUNT(icd_code)
FROM refresh_lookup_done
WHERE icd_code NOT IN (SELECT concept_code FROM concept WHERE vocabulary_id = 'ICD9CM')
  UNION ALL
SELECT 'incorrect ICD9CM icd_name' AS issue_desc,
       COUNT(icd_name)
FROM refresh_lookup_done
WHERE icd_name NOT IN (SELECT concept_name FROM concept WHERE vocabulary_id = 'ICD9CM')
-- in this case these classes are ok: 'Location','Observable Entity', 'Physical Force', 'Qualifier Value'
  UNION ALL
SELECT 'incorrect repl_by_relationship' AS issue_desc,
       COUNT(repl_by_relationship)
FROM refresh_lookup_done
WHERE repl_by_relationship NOT IN ('Maps to','Maps to value','Is a')
  UNION ALL
SELECT 'incorrect SNOMED concept_id' AS issue_desc,
       COUNT(repl_by_id)
FROM refresh_lookup_done
WHERE repl_by_id NOT IN (SELECT concept_id FROM concept WHERE vocabulary_id = 'SNOMED')
UNION
SELECT 'incorrect SNOMED concept_code' AS issue_desc,
       COUNT(repl_by_code)
FROM refresh_lookup_done
WHERE repl_by_code NOT IN (SELECT concept_code
                       FROM concept
                       WHERE vocabulary_id = 'SNOMED'
                       AND   standard_concept = 'S')
  UNION ALL
SELECT 'incorrect SNOMED concept_name' AS issue_desc,
       COUNT(repl_by_name)
FROM refresh_lookup_done
WHERE repl_by_name NOT IN (SELECT concept_name
                       FROM concept
                       WHERE vocabulary_id = 'SNOMED'
                       AND   standard_concept = 'S')
  UNION ALL
SELECT 'incorrect SNOMED concept_class_id' AS issue_desc,
       COUNT(a.repl_by_id)
FROM refresh_lookup_done a
  JOIN concept c ON a.repl_by_id = c.concept_id
WHERE c.vocabulary_id = 'SNOMED'
AND   c.standard_concept = 'S'
AND   c.concept_class_id IN ('Body Structure','Morph Abnormality','Organism','Physical Object','Substance','Qualifier Value')
--  in this case these classes are ok: 'Location','Observable Entity', 'Physical Force',
AND   a.repl_by_relationship != 'Maps to value'
  UNION ALL
SELECT 'duplicates' AS issue_desc,
       COUNT(DISTINCT icd_code)
FROM refresh_lookup_done
WHERE icd_code IN (SELECT icd_code
                       FROM refresh_lookup_done
                       GROUP BY icd_code,
                                repl_by_id
                       HAVING COUNT(1) >= 2)
UNION
SELECT 'relationship_id - Maps to value with incorrect pair of repl_by_relationship' AS issue_desc,
       COUNT(icd_code)
FROM refresh_lookup_done
WHERE icd_code IN (SELECT icd_code
                       FROM refresh_lookup_done
                       WHERE repl_by_relationship = 'Maps to value')
AND   icd_code NOT IN (SELECT icd_code
                           FROM refresh_lookup_done
                           WHERE repl_by_relationship = 'Maps to')
  UNION ALL
SELECT 'relationship_id - Maps to value without Maps to ' AS issue_desc,
       COUNT(icd_code)
FROM refresh_lookup_done
WHERE icd_code IN (SELECT icd_code
                       FROM refresh_lookup_done
                       GROUP BY icd_code
                       HAVING COUNT(1) = 1)
AND   icd_code IN (SELECT icd_code
                       FROM refresh_lookup_done
                       WHERE repl_by_relationship = 'Maps to value')
  UNION ALL
SELECT 'mapping issue - incorrect History of' AS issue_desc,
       COUNT(DISTINCT icd_code)
FROM refresh_lookup_done
WHERE icd_name ~* 'histor'
AND   icd_code IN (SELECT icd_code
                       FROM refresh_lookup_done
                       GROUP BY icd_code
                       HAVING COUNT(1) > 1)
AND   icd_code NOT IN (SELECT icd_code
                           FROM refresh_lookup_done
                           WHERE repl_by_id IN (4167217,4214956,4215685))
AND   icd_code !~* 'Z35'
  UNION ALL
SELECT 'mapping issue - lost Finding related to pregnancy' AS issue_desc,
       COUNT(DISTINCT k.icd_code)
FROM refresh_lookup_done k
  JOIN concept c ON k.repl_by_id = c.concept_id
WHERE k.icd_code NOT IN (SELECT icd_code
                           FROM refresh_lookup_done
                             WHERE repl_by_id = 444094)
AND   k.icd_code ~ '^O'
AND   c.domain_id != 'Procedure'
  UNION ALL
SELECT 'relationship_id - Maps to instead of Is a' AS issue_desc,
       COUNT(icd_code)
FROM refresh_lookup_done
WHERE icd_name ~* 'other\s+|\s+other|classified\s+elsewhere|not\s+elsewhere\s+classified'
AND   icd_name !~* 'other and unspecified|not otherwise specified|other than'
AND   repl_by_relationship != 'Is a'
AND   icd_code NOT IN (SELECT icd_code
                           FROM refresh_lookup_done
                           WHERE repl_by_relationship = 'Maps to value')
AND   repl_by_name !~* 's+other|other\s+'
  UNION ALL
SELECT 'mapping issue - mapped to Parent and Child simultaneously' AS issue_desc,
       COUNT(DISTINCT a1.icd_code)
FROM (SELECT *
      FROM refresh_lookup_done
      WHERE icd_code IN (SELECT icd_code
                           FROM refresh_lookup_done
                           GROUP BY icd_code
                           HAVING COUNT(1) >= 2)) a1
  JOIN (SELECT *
        FROM refresh_lookup_done
        WHERE icd_code IN (SELECT icd_code
                             FROM refresh_lookup_done
                             GROUP BY icd_code
                             HAVING COUNT(1) >= 2)) a2 ON a1.icd_code = a2.icd_code
  JOIN concept c1 ON a1.icd_code = c1.concept_code AND c1.vocabulary_id = 'ICD9CM'
  JOIN concept c2 ON a2.icd_code = c2.concept_code AND c2.vocabulary_id = 'ICD9CM'
  JOIN concept_ancestor ca
    ON c1.concept_id = ca.ancestor_concept_id
   AND c2.concept_id = ca.descendant_concept_id
   AND c1.concept_id <> c2.concept_id
  UNION ALL
SELECT 'relationship_id - incompatiable repl_by_relationship combination' AS issue_desc,
       COUNT(DISTINCT icd_code)
FROM refresh_lookup_done
WHERE icd_code IN (SELECT icd_code
                       FROM refresh_lookup_done
                       GROUP BY icd_code
                       HAVING COUNT(1) > 1)
AND   icd_code IN (SELECT icd_code
                       FROM refresh_lookup_done
                       WHERE repl_by_relationship = 'Maps to')
AND   icd_code IN (SELECT icd_code
                       FROM refresh_lookup_done
                       WHERE repl_by_relationship = 'Is a')
  UNION ALL
SELECT 'relationship_id - Is a instead of Maps to' AS issue_desc,
       COUNT(DISTINCT icd_code)
FROM refresh_lookup_done
WHERE icd_code IN (SELECT icd_code
                       FROM refresh_lookup_done
                       GROUP BY icd_code
                       HAVING COUNT(1) = 1)
AND   icd_code IN (SELECT icd_code
                       FROM refresh_lookup_done
                       WHERE LOWER(icd_name) = LOWER(repl_by_name)
                       AND   repl_by_relationship = 'Is a')
ORDER BY issue_desc;

/************************
**** SEMANTICS CHECK ****
*************************/

SELECT 'possible duplicates - according to icd_code and snomed_code' AS issue_desc,
       COUNT(DISTINCT icd_code)
FROM refresh_lookup_done
WHERE icd_code IN (SELECT icd_code
                 FROM refresh_lookup_done
                 WHERE CTID NOT IN (SELECT MIN(CTID)
                                    FROM refresh_lookup_done
                                    GROUP BY icd_code,
                                             repl_by_id))

  UNION ALL
SELECT 'relationship_id - Maps to instead of Is a' AS issue_desc,
       COUNT(icd_code)
FROM refresh_lookup_done
WHERE icd_name ~* 'other\s+|\s+other|classified\s+elsewhere|not\s+elsewhere\s+classified'
AND   icd_name !~* 'other and unspecified|not otherwise specified|other than|another|mother'
AND   repl_by_relationship != 'Is a'
AND   icd_code NOT IN (SELECT icd_code
                       FROM refresh_lookup_done
                       WHERE repl_by_relationship = 'Maps to value')
AND   icd_code IN (SELECT icd_code
                   FROM refresh_lookup_done
                   WHERE repl_by_name !~* 's+other|other\s+')
AND   icd_code NOT IN ('T36.1X5','S12')
  UNION ALL
SELECT 'mapping issue - mapped to Parent and Child simultaneously' AS issue_desc,
       COUNT(DISTINCT a1.icd_code)
FROM (SELECT *
      FROM refresh_lookup_done
      WHERE icd_code IN (SELECT icd_code
                       FROM refresh_lookup_done
                       GROUP BY icd_code
                       HAVING COUNT(1) >= 2)) a1
  JOIN (SELECT *
        FROM refresh_lookup_done
        WHERE icd_code IN (SELECT icd_code
                         FROM refresh_lookup_done
                         GROUP BY icd_code
                         HAVING COUNT(1) >= 2)) a2 ON a1.icd_code = a2.icd_code
  JOIN concept c1 ON c1.concept_code = a1.icd_code AND c1.vocabulary_id = 'ICD9CM'
  JOIN concept c2 ON c2.concept_code = a2.icd_code AND c1.vocabulary_id = 'ICD9CM'
  JOIN concept_ancestor ca
    ON c1.concept_id = ca.ancestor_concept_id
   AND c2.concept_id = ca.descendant_concept_id
   AND c1.concept_id <> c2.concept_id
  UNION ALL
SELECT 'mapping issue - lost No loss of consciousness' AS issue_desc,
       COUNT(DISTINCT icd_code)
FROM refresh_lookup_done
WHERE icd_name ~* 'without loss of consciousness'
AND   icd_name !~* 'sequela|with or without'
AND   icd_code NOT IN (SELECT icd_code
                       FROM refresh_lookup_done
                       WHERE repl_by_name ~* 'no loss')
  UNION ALL
SELECT 'mapping issue - lost OR mapped to many Sequela' AS issue_desc,
       COUNT(DISTINCT icd_code)
FROM refresh_lookup_done
WHERE icd_code IN (SELECT icd_code
                   FROM refresh_lookup_done
                   WHERE icd_name ~* 'sequela')
AND   icd_code IN (SELECT icd_code
                   FROM refresh_lookup_done
                   WHERE repl_by_name !~* 'Sequela|Late effect')
  UNION ALL
SELECT 'mapping issue - lost Nonunion of fracture' AS issue_desc,
       COUNT(DISTINCT icd_code)
FROM refresh_lookup_done
WHERE icd_name ~* 'nonunion'
AND   icd_code NOT IN (SELECT icd_code
                     FROM refresh_lookup_done
                     WHERE repl_by_name ~* 'nonunion')
  UNION ALL
SELECT 'mapping issue - lost Malunion of fracture' AS issue_desc,
       COUNT(DISTINCT icd_code)
FROM refresh_lookup_done
WHERE icd_name ~* 'malunion'
AND   icd_code NOT IN (SELECT icd_code
                     FROM refresh_lookup_done
                     WHERE repl_by_name ~* 'malunion')
  UNION ALL
SELECT 'mapping issue - lost Closed fracture' AS issue_desc,
       COUNT(DISTINCT icd_code)
FROM refresh_lookup_done
WHERE icd_name ~* 'closed fracture'
AND   icd_code NOT IN (SELECT icd_code
                     FROM refresh_lookup_done
                     WHERE repl_by_name ~* 'closed')
  UNION ALL
SELECT 'mapping issue - lost Open fracture' AS issue_desc,
       COUNT(DISTINCT icd_code)
FROM refresh_lookup_done
WHERE icd_name ~* 'open fracture'
AND   icd_code NOT IN (SELECT icd_code
                     FROM refresh_lookup_done
                     WHERE repl_by_name ~* 'open')
  UNION ALL
SELECT 'mapping issue - lost Delayed union of fracture' AS issue_desc,
       COUNT(DISTINCT icd_code)
FROM refresh_lookup_done
WHERE icd_code IN (SELECT icd_code
                 FROM refresh_lookup_done
                 WHERE icd_name ~* 'with delayed healing')
AND   icd_code NOT IN (SELECT icd_code
                     FROM refresh_lookup_done
                     WHERE repl_by_name ~* 'delayed union')
  UNION ALL
SELECT 'mapping issue - lost Foreign body' AS issue_desc,
       COUNT(DISTINCT icd_code)
FROM refresh_lookup_done
WHERE icd_name ~* 'with foreign body'
AND   icd_code NOT IN (SELECT icd_code
                       FROM refresh_lookup_done
                       WHERE repl_by_name ~* 'foreign body')
AND   icd_name !~* 'sequela'
UNION ALL
SELECT 'relationship_id - Maps to value with incorrect pair of repl_by_relationship' AS issue_desc,
       COUNT(icd_code)
FROM refresh_lookup_done
WHERE icd_code IN (SELECT icd_code
                   FROM refresh_lookup_done
                   WHERE repl_by_relationship = 'Maps to value')
AND   icd_code NOT IN (SELECT icd_code
                       FROM refresh_lookup_done
                       WHERE repl_by_relationship = 'Maps to')
  UNION ALL
SELECT 'relationship_id - Maps to value without Maps to ' AS issue_desc,
       COUNT(icd_code)
FROM refresh_lookup_done
WHERE icd_code IN (SELECT icd_code
                   FROM refresh_lookup_done
                   GROUP BY icd_code
                   HAVING COUNT(1) = 1)
AND   icd_code IN (SELECT icd_code
                   FROM refresh_lookup_done
                   WHERE repl_by_relationship = 'Maps to value')
  UNION ALL
SELECT 'relationship_id - incompatiable repl_by_relationship combination' AS issue_desc,
       COUNT(DISTINCT icd_code)
FROM refresh_lookup_done
WHERE icd_code IN (SELECT icd_code
                   FROM refresh_lookup_done
                   GROUP BY icd_code
                   HAVING COUNT(1) > 1)
AND   icd_code IN (SELECT icd_code
                   FROM refresh_lookup_done
                   WHERE repl_by_relationship = 'Maps to')
AND   icd_code IN (SELECT icd_code
                   FROM refresh_lookup_done
                   WHERE repl_by_relationship = 'Is a')
  UNION ALL
SELECT 'relationship_id - Is a instead of Maps to' AS issue_desc,
       COUNT(DISTINCT icd_code)
FROM refresh_lookup_done
WHERE icd_code IN (SELECT icd_code
                   FROM refresh_lookup_done
                   GROUP BY icd_code
                   HAVING COUNT(1) = 1)
AND   icd_code IN (SELECT icd_code
                   FROM refresh_lookup_done
                   WHERE LOWER(icd_name) = LOWER(repl_by_name)
                   AND   repl_by_relationship = 'Is a')
 UNION ALL
SELECT 'mapping issue - equal icd_names of various icd_codes with different mappings' AS issue_desc,
       COUNT(DISTINCT a.icd_code)
FROM refresh_lookup_done a
  JOIN refresh_lookup_done b
    ON a.icd_name = b.icd_name
   AND a.icd_code <> b.icd_code
   AND a.repl_by_relationship <> b.repl_by_relationship
   AND a.repl_by_id <> b.repl_by_id
WHERE a.icd_code NOT IN (SELECT icd_code
                         FROM refresh_lookup_done
                         WHERE repl_by_relationship = 'Maps to value')
ORDER BY issue_desc;
