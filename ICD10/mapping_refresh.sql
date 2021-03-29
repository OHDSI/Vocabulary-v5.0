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
* Authors: Dmitry Dymshyts, Polina Talapova, Daryna Ivakhnenko
* Date: 2021
**************************************************************************/
DROP TABLE IF EXISTS refresh_lookup;
CREATE TABLE refresh_lookup AS WITH miss_map 
AS
(
	-- 'deprecated mapping'
	SELECT c.concept_code AS icd_code,
       c.concept_name AS icd_name,
       a.relationship_id AS current_relationship,
       b.concept_id AS current_id,
       b.concept_code AS current_code,
       b.concept_name AS current_name,
       b.domain_id AS current_domain,
       b.vocabulary_id AS current_vocabulary,
       'deprecated mapping' AS reason
FROM concept_relationship_stage a
  JOIN concept b
    ON a.concept_code_2 = b.concept_code
   AND b.vocabulary_id = a.vocabulary_id_2
   AND a.relationship_id IN ('Maps to', 'Maps to value')
   AND b.invalid_reason IN ('D', 'U')
  JOIN concept_stage c
    ON a.concept_code_1 = c.concept_code 
    AND c.concept_class_id NOT IN ('ICD10 Chapter','ICD10 SubChapter')
AND a.invalid_reason IS NULL
UNION
-- 'non-standard mapping'
SELECT c.concept_code,
       c.concept_name,
       a.relationship_id AS current_relationship,
       b.concept_id AS current_id,
       b.concept_code AS current_code,
       b.concept_name AS current_name,
       b.domain_id AS current_domain,
       b.vocabulary_id AS current_vocabulary,
       'non-standard mapping' AS reason
FROM concept_relationship_stage a
  JOIN concept b
    ON a.concept_code_2 = b.concept_code
   AND b.vocabulary_id = a.vocabulary_id_2
   AND a.relationship_id IN ('Maps to', 'Maps to value')
   AND b.invalid_reason IS NULL
   AND b.standard_concept IS NULL
  JOIN concept_stage c
    ON a.concept_code_1 = c.concept_code
    AND c.concept_class_id NOT IN ('ICD10 Chapter','ICD10 SubChapter')
UNION
-- 'without mapping'
SELECT a.concept_code,
       a.concept_name,
       NULL,
       NULL,
       NULL,
       NULL,
       NULL,
       NULL,
       'without mapping' AS reason
FROM concept_stage a
  LEFT JOIN concept_relationship_stage r
         ON a.concept_code = concept_code_1
        AND r.relationship_id IN ('Maps to') 
        AND r.invalid_reason IS NULL
  LEFT JOIN concept b
         ON b.concept_code = concept_code_2
        AND b.vocabulary_id = vocabulary_id_2
WHERE a.vocabulary_id = 'ICD10'
AND   a.invalid_reason IS NULL
AND   b.concept_id IS NULL
AND a.concept_class_id NOT IN ('ICD10 Chapter','ICD10 SubChapter')),
-- concepts which mapping can be replaced through 'Maps to' relationship
t1 AS (SELECT d.concept_code AS icd_code,
              d.concept_name AS icd_name,
              d.domain_id AS icd_domain,
              j.concept_id AS repl_by_id,
              j.concept_code AS repl_by_code,
              j.concept_name AS repl_by_name,
              j.domain_id AS repl_by_domain,
              j.vocabulary_id AS repl_by_vocabulary,
              NULL
       FROM concept_relationship_stage a
         JOIN concept b
           ON a.concept_code_2 = b.concept_code
          AND b.vocabulary_id = a.vocabulary_id_2
          AND a.relationship_id = 'Maps to'
          AND b.invalid_reason IN ('D', 'U')
          JOIN concept_stage d
    ON a.concept_code_1 = d.concept_code
         JOIN concept_relationship r2 ON b.concept_id = r2.concept_id_1
         JOIN concept j
           ON j.concept_id = r2.concept_id_2
          AND j.vocabulary_id = 'SNOMED'-- place for target vocabulary       
          AND j.standard_concept = 'S'
          AND r2.relationship_id = 'Maps to'
       WHERE a.concept_code_1 IN (SELECT icd_code FROM miss_map)),
-- concepts which mapping can be replaced through 'Concept replaces' relationship
t2 AS (SELECT d.concept_code AS icd_code,
              d.concept_name AS icd_name,
              d.domain_id AS icd_domain,
              j.concept_id AS repl_by_id,
              j.concept_code AS repl_by_code,
              j.concept_name AS repl_by_name,
              j.domain_id AS repl_by_domain,
              j.vocabulary_id AS repl_by_vocabulary,
              NULL
       FROM concept_relationship_stage a
         JOIN concept b
           ON a.concept_code_2 = b.concept_code
          AND b.vocabulary_id = a.vocabulary_id_2
          AND a.relationship_id = 'Maps to'
          AND b.invalid_reason IN ('D', 'U')
        JOIN concept_stage d
    ON a.concept_code_1 = d.concept_code
         JOIN concept_relationship r2 ON b.concept_id = r2.concept_id_1
         JOIN concept j
           ON j.concept_id = r2.concept_id_2
          AND j.vocabulary_id = 'SNOMED' -- place for target vocabulary      
          AND j.standard_concept = 'S'
          AND r2.relationship_id = 'Concept replaced by'
       WHERE a.concept_code_1 IN (SELECT icd_code FROM miss_map)),
-- all concepts which can be remapped autimatically (however, should be reviewed)
t3 AS (SELECT * FROM t1 UNION SELECT * FROM t2),
-- look-up table with all concepts with deprecated mapping + automatically remapped
t4 AS (SELECT miss_map.icd_code,
              miss_map.icd_name,
              miss_map.current_relationship,
              miss_map.current_id,
              miss_map.current_code,
              miss_map.current_name,
              miss_map.current_domain,
              miss_map.current_vocabulary,
              t3.repl_by_id,
              t3.repl_by_code,
              t3.repl_by_name,
              t3.repl_by_domain,
              t3.repl_by_vocabulary,
              miss_map.reason
       FROM miss_map
         LEFT JOIN t3 ON miss_map.icd_code = t3.icd_code),
-- improve_map - automatically detected mapping improvements. Look carefully! Target vocabulary could have the same names of concepts with different domain_ids. Also, ICD10 chapter means a lot and should be taken into account for choosing appropriate mapping
improve_map
AS
(SELECT DISTINCT
a.concept_code AS icd_code,
       a.concept_name AS icd_name,
       r.relationship_id AS current_relationship,
       d.concept_id AS current_id,
       d.concept_code AS current_code,
       d.concept_name AS current_name,
       d.domain_id AS current_domain,
       d.vocabulary_id AS current_vocabulary,
       c.concept_id AS repl_by_id,
       code AS repl_by_code,
       str AS repl_by_name,
       c.domain_id AS repl_by_domain,
       c.vocabulary_id AS repl_by_vocabulary,
       'improve_map' AS reason
FROM concept a
JOIN concept_relationship r ON r.concept_id_1 = a.concept_id AND a.vocabulary_id = 'ICD10' 
JOIN concept d ON d.concept_id = r.concept_id_2 AND r.invalid_reason IS NULL AND d.standard_concept = 'S' AND r.relationship_id IN ('Maps to', 'Maps to value')
  JOIN sources.mrconso
    ON lower (a.concept_name) = lower (str)
   AND sab = 'SNOMEDCT_US'
   AND suppress = 'N'
   AND tty = 'PT'
  JOIN devv5.concept c
    ON c.concept_code = code
   AND c.vocabulary_id = 'SNOMED'
   AND c.standard_concept = 'S'
   AND c.concept_class_id IN ('Procedure', 'Context-dependent', 'Clinical Finding', 'Event', 'Social Context', 'Observable Entity')),
t5 as (
SELECT  * FROM improve_map
WHERE icd_code IN (SELECT icd_code
                   FROM improve_map
                   WHERE repl_by_code != current_code)
                   ), 
t6 AS (
SELECT DISTINCT 
a.concept_code AS icd_code,
       a.concept_name AS icd_name,
       r.relationship_id AS current_relationship,
       d.concept_id AS current_id,
       d.concept_code AS current_code,
       d.concept_name AS current_name,
       d.domain_id AS current_domain,
       d.vocabulary_id AS current_vocabulary,
       c.concept_id AS repl_by_id,
       c.concept_code AS repl_by_code,
       c.concept_name AS repl_by_name,
       c.domain_id AS repl_by_domain,
       c.vocabulary_id AS repl_by_vocabulary,
       'improve_map' AS reason
FROM concept a
JOIN concept_relationship r ON r.concept_id_1 = a.concept_id and a.vocabulary_id = 'ICD10' 
JOIN concept d ON d.concept_id = r.concept_id_2 AND r.invalid_reason IS NULL AND d.standard_concept = 'S' AND r.relationship_id IN ('Maps to', 'Maps to value')
  JOIN devv5.concept_synonym cs ON lower (a.concept_name) = lower (cs.concept_synonym_name) AND a.vocabulary_id = 'ICD10'
  JOIN devv5.concept c
    ON cs.concept_id = c.concept_id
   AND c.vocabulary_id = 'SNOMED'
   AND c.standard_concept = 'S'
   AND c.concept_class_id IN ('Procedure', 'Context-dependent', 'Clinical Finding', 'Event', 'Social Context', 'Observable Entity')
WHERE d.concept_id != c.concept_id),
p_map AS (    
    SELECT * FROM t5
  UNION
    SELECT * FROM t6 )
SELECT * FROM p_map 
UNION 
SELECT * FROM t4
ORDER BY icd_code;
