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
-- define gaps in mapping
-- A) generates lookup for mapping

WITH t0
AS
(
	-- 'deprecated mapping'
	SELECT c.concept_code AS icd_code,
       c.concept_name AS icd_name,
       b.concept_id AS deprecated_id,
       b.concept_code AS deprecated_code,
       b.concept_name AS deprecated_name,
       b.domain_id AS deprecated_domain,
       b.vocabulary_id AS deprecated_vocabulary,
       'deprecated mapping' AS reason
FROM concept_relationship_stage a
  JOIN concept b
    ON a.concept_code_2 = b.concept_code
   AND b.vocabulary_id = a.vocabulary_id_2
   AND a.relationship_id = 'Maps to'
   AND b.invalid_reason IN ('D', 'U')

  JOIN concept_stage c
    ON a.concept_code_1 = c.concept_code
AND a.invalid_reason IS NULL
UNION
-- 'non-standard mapping'
SELECT c.concept_code,
       c.concept_name,
       b.concept_id AS deprecated_id,
       b.concept_code AS deprecated_code,
       b.concept_name AS deprecated_name,
       b.domain_id AS deprecated_domain,
       b.vocabulary_id AS deprecated_vocabulary,
       'non-standard mapping' AS reason
FROM concept_relationship_stage a
  JOIN concept b
    ON a.concept_code_2 = b.concept_code
   AND b.vocabulary_id = a.vocabulary_id_2
   AND a.relationship_id = 'Maps to'
   AND b.invalid_reason IS NULL
   AND b.standard_concept IS NULL
  JOIN concept_stage c
    ON a.concept_code_1 = c.concept_code
UNION
-- 'without mapping'
SELECT a.concept_code,
       a.concept_name,
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
AND   b.concept_id IS NULL),
-- concepts which mapping can be replaced through 'Maps to' relationship
t1 AS (SELECT d.concept_code AS icd_code,
              d.concept_name AS icd_name,
              d.domain_id AS icd_domain,
              j.concept_id AS sno_id,
              j.concept_code AS sno_code,
              j.concept_name AS sno_name,
              j.domain_id AS sno_domain,
              j.vocabulary_id AS sno_vocabulary,
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
       WHERE a.concept_code_1 IN (SELECT icd_code FROM t0)),
-- concepts which mapping can be replaced through 'Concept replaces' relationship
t2 AS (SELECT d.concept_code AS icd_code,
              d.concept_name AS icd_name,
              d.domain_id AS icd_domain,
              j.concept_id AS sno_id,
              j.concept_code AS sno_code,
              j.concept_name AS sno_name,
              j.domain_id AS sno_domain,
              j.vocabulary_id AS sno_vocabulary,
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
       WHERE a.concept_code_1 IN (SELECT icd_code FROM t0)),
-- all concepts which can be remapped autimatically (however, should be reviewed)
t3 AS (SELECT * FROM t1 UNION SELECT * FROM t2),
-- look-up table with all concepts with deprecated mapping + automatically remapped
t4 AS (SELECT t0.icd_code,
              t0.icd_name,
              t0.deprecated_id,
              t0.deprecated_code,
              t0.deprecated_name,
              t0.deprecated_domain,
              t0.deprecated_vocabulary,
              t3.sno_id,
              t3.sno_code,
              t3.sno_name,
              t3.sno_domain,
              t3.sno_vocabulary,
              t0.reason
       FROM t0
         LEFT JOIN t3 ON t0.icd_code = t3.icd_code) SELECT*FROM t4;


-- B) check sources.mrconso and devv5.concept_synonym for possible mappings to newly added target concepts with full name similarity (should be reviewed by an eye)
WITH t0
AS
(SELECT DISTINCT a.concept_code as icd_code,
       a.concept_name as icd_name,
       r.relationship_id,
       d.concept_code AS current_code,
       d.concept_name AS current_name,
       c.concept_id AS alter_id,
       code AS alter_code,
       str AS alter_name,
       c.concept_class_id,
       c.domain_id,
       c.standard_concept
FROM concept a
JOIN concept_relationship r ON r.concept_id_1 = a.concept_id and a.vocabulary_id = 'ICD10' 
JOIN concept d ON d.concept_id = r.concept_id_2 and r.invalid_reason is null and d.standard_concept = 'S' and r.relationship_id = 'Maps to'
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
t1 as (
SELECT  * FROM t0
WHERE icd_code IN (SELECT icd_code
                   FROM t0
                   WHERE alter_code != current_code)
                   ), 
t2 AS (
SELECT DISTINCT a.concept_code as icd_code,
       a.concept_name as icd_name,
       r.relationship_id,
       d.concept_code AS current_code,
       d.concept_name AS current_name,
       c.concept_id AS alter_id,
       c.concept_code AS alter_code,
       c.concept_name AS alter_name,
       c.concept_class_id,
       c.domain_id,
       c.standard_concept
FROM concept a
JOIN concept_relationship r ON r.concept_id_1 = a.concept_id and a.vocabulary_id = 'ICD10' 
JOIN concept d ON d.concept_id = r.concept_id_2 and r.invalid_reason is null and d.standard_concept = 'S' and r.relationship_id = 'Maps to'
  JOIN devv5.concept_synonym cs ON lower (a.concept_name) = lower (cs.concept_synonym_name) AND a.vocabulary_id = 'ICD10'
  JOIN devv5.concept c
    ON cs.concept_id = c.concept_id
   AND c.vocabulary_id = 'SNOMED'
   AND c.standard_concept = 'S'
   AND c.concept_class_id IN ('Procedure', 'Context-dependent', 'Clinical Finding', 'Event', 'Social Context', 'Observable Entity')
WHERE d.concept_id != c.concept_id),
p_map AS (    
    SELECT * FROM t1
  UNION
    SELECT * FROM t2 )
SELECT * FROM p_map 
WHERE icd_code NOT IN (SELECT icd_code FROM p_map where current_name ~ '^Primary malignant')
AND  icd_code NOT IN (SELECT icd_code FROM p_map where current_name ~ 'Finding related to pregnancy')
ORDER BY icd_code;
