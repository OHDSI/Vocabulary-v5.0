-- finding of better mapping for concepts
CREATE TABLE icd10gm_map_dif AS WITH t0
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
JOIN concept_relationship r ON r.concept_id_1 = a.concept_id and a.vocabulary_id = 'ICD10GM' 
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
JOIN concept_relationship r ON r.concept_id_1 = a.concept_id and a.vocabulary_id = 'ICD10GM' 
JOIN concept d ON d.concept_id = r.concept_id_2 and r.invalid_reason is null and d.standard_concept = 'S' and r.relationship_id = 'Maps to'
  JOIN devv5.concept_synonym cs ON lower (a.concept_name) = lower (cs.concept_synonym_name) AND a.vocabulary_id = 'ICD10GM'
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


-- crm changing due to appearance in SNOMED more accurate concepts for mapping
INSERT INTO concept_relationship_manual
SELECT concept_code_1,
       concept_code_2,
       vocabulary_id_1,
       vocabulary_id_2,
       relationship_id,
       valid_start_date,
       valid_end_date,
       invalid_reason
FROM concept_relationship_stage
WHERE concept_code_1 IN (SELECT icd_code
                         FROM icd10gm_map_dif
                         WHERE icd_code NOT IN (SELECT concept_code FROM concept WHERE vocabulary_id = 'ICD10'))
AND   vocabulary_id_2 = 'SNOMED'
AND   concept_code_1 NOT IN (SELECT concept_code_1 FROM concept_relationship_manual);--27
DELETE
FROM concept_relationship_manual
WHERE concept_code_1 IN (SELECT icd_code
                         FROM icd10gm_map_dif
                         WHERE icd_code NOT IN (SELECT concept_code FROM concept WHERE vocabulary_id = 'ICD10'));--29
INSERT INTO concept_relationship_manual
SELECT DISTINCT icd_code,
       alter_code,
       'ICD10GM',
       'SNOMED',
       'Maps to',
       CURRENT_DATE -1,
       TO_DATE('20991231','yyyymmdd'),
       NULL
FROM icd10gm_map_dif
WHERE alter_code != '32864002'
AND   icd_code NOT IN (SELECT concept_code FROM concept WHERE vocabulary_id = 'ICD10'); --29
						
-- adding of deprecated relationship 						
INSERT INTO concept_relationship_manual
SELECT concept_code_1,
       concept_code_2,
       vocabulary_id_1,
       vocabulary_id_2,
       relationship_id,
       valid_start_date,
       CURRENT_DATE -1,
       'D'
FROM concept_relationship_stage
WHERE concept_code_1 IN (SELECT concept_code_1 FROM concept_relationship_manual);
