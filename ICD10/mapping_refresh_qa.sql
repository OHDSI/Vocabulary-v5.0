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
-- A) unmapped ICD10 concepts
WITH non_mapped
AS
(SELECT a.concept_code,
       a.concept_name
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
AND   b.concept_id IS NULL) 
SELECT * FROM non_mapped n;

-- B) deprecated mappings (can occur after the SNOMED refresh)
-- var. 1
WITH d_map
AS
(SELECT *
FROM concept_relationship_stage a
  JOIN devv5.concept c
    ON a.concept_code_2 = c.concept_code
   AND c.vocabulary_id = 'SNOMED'
   AND c.invalid_reason IN ('D', 'U')

  JOIN devv5.concept d
    ON a.concept_code_1 = d.concept_code
   AND d.vocabulary_id = 'ICD10'
WHERE a.concept_code_1 IN (SELECT concept_code_1
                           FROM concept_relationship_manual)) 
SELECT * FROM d_map;

-- var. 2 => generates lookup for mapping
WITH t1 AS
 (
SELECT DISTINCT d.concept_id AS icd_id,
       d.concept_code AS icd_code,
       d.concept_name AS icd_name,
       d.domain_id,
       a.relationship_id,
       j.concept_id,
       j.concept_code,
       j.concept_name,
       j.domain_id,
       j.standard_concept,
       j.invalid_reason
FROM concept_relationship_stage a
  JOIN devv5.concept c
    ON a.concept_code_2 = c.concept_code
   AND c.vocabulary_id = 'SNOMED'
   AND c.invalid_reason IN ('D', 'U')
  JOIN devv5.concept d
    ON a.concept_code_1 = d.concept_code
   AND d.vocabulary_id = 'ICD10'
  LEFT JOIN devv5.concept_relationship r2 ON c.concept_id = r2.concept_id_1
  LEFT JOIN devv5.concept j
         ON j.concept_id = r2.concept_id_2
        AND j.vocabulary_id = 'SNOMED'
        AND j.standard_concept = 'S'
        AND r2.relationship_id IN ('Maps to', 'Concept replaces')
	WHERE a.concept_code_1 IN (SELECT concept_code_1
                            FROM concept_relationship_manual)
		),
		t2 AS (
SELECT DISTINCT d.concept_id AS icd_id,
       d.concept_code AS icd_code,
       d.concept_name AS icd_name,
       d.domain_id,
       a.relationship_id,
       c.concept_id,
       c.concept_code,
       c.concept_name,
       c.domain_id,
       c.standard_concept,
       c.invalid_reason
FROM concept_relationship_stage a
  JOIN devv5.concept c
    ON a.concept_code_2 = c.concept_code
   AND c.vocabulary_id = 'SNOMED'
   AND c.invalid_reason IN ('D', 'U')
	
  JOIN devv5.concept d
    ON a.concept_code_1 = d.concept_code
   AND d.vocabulary_id = 'ICD10'
WHERE a.concept_code_1 IN (SELECT concept_code_1
                           FROM concept_relationship_manual)
AND   d.concept_id NOT IN (SELECT icd_id FROM t1)
),
	t3 AS (
SELECT * FROM t1
UNION
SELECT * FROM t2)
,
t4
AS
(SELECT DISTINCT d.concept_id AS icd_id,
       d.concept_code AS icd_code,
       d.concept_name AS icd_name,
       d.domain_id,
       a.relationship_id,
       j.concept_id,
       j.concept_code,
       j.concept_name,
       j.domain_id,
       j.standard_concept,
       j.invalid_reason
FROM devv5.concept d
  JOIN devv5.concept_relationship a
    ON d.concept_id = a.concept_id_1
   AND d.vocabulary_id = 'ICD10'
   AND a.invalid_reason IS NULL
  JOIN devv5.concept j ON a.concept_id_2 = j.concept_id
WHERE j.vocabulary_id = 'SNOMED'
AND   j.invalid_reason is  null
AND   a.relationship_id = 'Maps to')
,
t5 AS (
SELECT * FROM t4
WHERE icd_id IN (SELECT icd_id FROM t3)
UNION
SELECT * FROM t3) 
     SELECT DISTINCT*
     FROM t5
WHERE concept_id IS NOT NULL
; 

-- C) check sources.mrconso and devv5.concept_synonym for possible mappings to newly added target concepts with full name similarity (should be reviewed by an eye)
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
