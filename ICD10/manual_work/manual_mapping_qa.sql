/*during mapping of ICD codes we recommend to use the following relationship_ids:
* Maps to - just for FULL equivalent one-to-one mapping
* Maps to + Maps to value - for Observations and Measurements with results
* Is a - for one-to-one partial equivalent AND one-to-many mapping. This relationship is used for CHECKS only (and possible OMOP Extension implemenation). 
Please preserve a manual table with 'Is a' relationships, but change 'Is a' to 'Maps to' during the insertion into concept_relatioship_manual (e.g. using CASE WHEN).

required fields for checks in the manual table: 

  icd_id INT, 
  icd_code VARHCAR, 
  icd_name VARHCAR, 
  relationship_id VARCHAR, 
  concept_id INT, 
  concept_code VARCHAR, 
  concept_name VARCHAR 

NB! change icd9cm_fullset_refresh_2020 to your table name everywhere in the script using Ctrl + H */




-- 1 -- create table for checks
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
FROM dev_icd10.concept_relationship_manual a
  JOIN concept b
    ON b.concept_code = a.concept_code_1
   AND b.vocabulary_id = 'ICD10'
  JOIN concept c
    ON c.concept_code = a.concept_code_2
   AND c.vocabulary_id = 'SNOMED'
WHERE a.invalid_reason IS NULL;


-- 2 --count different rows number and relationship_ids. The difference between total number of (distinct) rows in mapping and in the devv5.concept should be 600 rows.
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

-- c.icd_id

--3--check presence of problems in ICD10 manual mapping - all queries should return null 
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
                             WHERE relationship_id = 'Maps to value')) SELECT 'mapping issue - Condition + Procedure' AS issue_desc,COUNT(DISTINCT icd_code) FROM icd10_manual_checks WHERE icd_code IN (SELECT icd_code
                                                                                                                                                                                                                 FROM (SELECT *,
                                                                                                                                                                                                                              LAST_VALUE(domain_id) OVER (PARTITION BY icd_code) = 'Procedure' AS last_domain,
                                                                                                                                                                                                                              FIRST_VALUE(domain_id) OVER (PARTITION BY icd_code) = 'Procedure' AS first_domain
                                                                                                                                                                                                                       FROM icd10_proc_and_cond) n
                                                                                                                                                                                                                 WHERE last_domain <> first_domain
                                                                                                                                                                                                                 ORDER BY icd_code)
UNION
SELECT 'mapping issue - non-standard concepts' AS issue_desc,
       COUNT(concept_id)
FROM icd10_manual_checks
WHERE icd_id IN (SELECT icd.icd_id
                     FROM icd10_manual_checks icd
                       LEFT JOIN concept c
                              ON icd.concept_id = c.concept_id
                             AND c.standard_concept = 'S'
                     WHERE c.concept_id IS NULL)
UNION
SELECT 'empty icd_id' AS issue_desc,
       COUNT(icd_id)
FROM icd10_manual_checks
WHERE icd_id IS NULL
UNION
SELECT 'empty icd_code' AS issue_desc,
       COUNT(icd_id)
FROM icd10_manual_checks
WHERE icd_code = ''
UNION
SELECT 'empty icd_name' AS issue_desc,
       COUNT(icd_id)
FROM icd10_manual_checks
WHERE icd_name = ''
UNION
SELECT 'empty concept_id' AS issue_desc,
       COUNT(icd_id)
FROM icd10_manual_checks
WHERE concept_id IS NULL
UNION
SELECT 'empty concept_code' AS issue_desc,
       COUNT(icd_id)
FROM icd10_manual_checks
WHERE concept_code = ''
UNION
SELECT 'empty concept_name' AS issue_desc,
       COUNT(icd_id)
FROM icd10_manual_checks
WHERE concept_name = ''
UNION
SELECT 'incorrect ICD10 icd_code' AS issue_desc,
       COUNT(icd_code)
FROM icd10_manual_checks
WHERE icd_code NOT IN (SELECT icd_code FROM concept WHERE vocabulary_id = 'ICD10')
UNION
SELECT 'incorrect ICD10 icd_id' AS issue_desc,
       COUNT(icd_id)
FROM icd10_manual_checks
WHERE icd_id NOT IN (SELECT icd_id FROM concept WHERE vocabulary_id = 'ICD10')
UNION
SELECT 'incorrect ICD10 icd_name' AS issue_desc,
       COUNT(icd_name)
FROM icd10_manual_checks
WHERE icd_name NOT IN (SELECT icd_name FROM concept WHERE vocabulary_id = 'ICD10')
-- in this case these classes are ok: 'Location','Observable Entity', 'Physical Force', 'Qualifier Value'
UNION
SELECT 'incorrect relationship_id' AS issue_desc,
       COUNT(relationship_id)
FROM icd10_manual_checks
WHERE relationship_id NOT IN ('Maps to','Maps to value','Is a')
UNION
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
UNION
SELECT 'incorrect SNOMED icd_name' AS issue_desc,
       COUNT(concept_name)
FROM icd10_manual_checks
WHERE concept_name NOT IN (SELECT icd_name
                       FROM concept
                       WHERE vocabulary_id = 'SNOMED'
                       AND   standard_concept = 'S')
UNION
SELECT 'incorrect SNOMED concept_class_id' AS issue_desc,
       COUNT(a.concept_id)
FROM icd10_manual_checks a
  JOIN concept c ON a.concept_id = c.concept_id
WHERE c.vocabulary_id = 'SNOMED'
AND   c.standard_concept = 'S'
AND   c.concept_class_id IN ('Body Structure','Morph Abnormality','Organism','Physical Object','Substance','Qualifier Value')
--  in this case these classes are ok: 'Location','Observable Entity', 'Physical Force', 
AND   a.relationship_id != 'Maps to value'
UNION
SELECT 'relationship id - doubled Maps to' AS issue_desc,
       COUNT(DISTINCT icd_code)
FROM icd10_manual_checks
WHERE icd_code IN (SELECT icd_code
                       FROM icd10_manual_checks
                       WHERE relationship_id = 'Maps to'
                       GROUP BY icd_code,
                                relationship_id
                       HAVING COUNT(1) >= 2)
UNION
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
UNION
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
UNION
SELECT 'missed ICD10 concepts from concept' AS issue_desc,
       COUNT(concept_code)
FROM concept
WHERE concept_code NOT IN (SELECT icd_code FROM icd10_manual_checks)
AND   vocabulary_id = 'ICD10'
AND   concept_code !~ '^\d+'
UNION
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
UNION
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
UNION
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
UNION
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
AND   a1.icd_code NOT IN ('M76','M81','R22','S92')
-- these concepts have difference in names
UNION
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
UNION
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
UNION
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
                       AND   relationship_id = 'Is a');

ORDER BY issue_desc;


-------------------------
-----EXTENDED CHECK------
-------------------------
select 'possible duplicates - according to icd_code and snomed_code' as issue_desc, count (distinct icd_code) 
from  icd10_manual_checks  where icd_id in (
      select icd_id from icd10_manual_checks where CTID not in 
            (select min (CTID) 
      from icd10_manual_checks group by icd_code, concept_id)
      ) 
  UNION
select 'mapping issue - excessive Finding related to pregnancy' as issue_desc, count (distinct icd_code) 
from  icd10_manual_checks 
where icd_code in (
      select a.icd_code from icd10_manual_checks a 
            join icd10_manual_checks b on a.icd_code = b.icd_code and b.concept_id in (4299535, 444094)
            join concept_ancestor h on a.concept_id = h.descendant_concept_id
            and h.ancestor_concept_id = 444094
            and a.concept_id <> b.concept_id 
            and a.icd_code ~ '^O'
            and a.icd_id not in (select concept_id from concept where  domain_id = 'Procedure')
            )
  UNION
select 'relationship_id - Maps to instead of Is a' as issue_desc, count (icd_code)  
from icd10_manual_checks
where icd_name ~* 'other\s+|\s+other|classified\s+elsewhere|not\s+elsewhere\s+classified'
      and icd_name !~* 'other and unspecified|not otherwise specified|other than|another|mother'
      and relationship_id != 'Is a'
      and icd_code not in (select icd_code from icd10_manual_checks where relationship_id = 'Maps to value')
      and icd_code  in (select icd_code from icd10_manual_checks where concept_name !~* 's+other|other\s+') 
      and icd_code not in ('T36.1X5', 'S12')
  UNION
select  'mapping issue - mapped to Parent and Child simultaneously' as issue_desc,  count (distinct  a1.concept_code) 
from 
(select * from icd10_manual_checks where icd_id in (select icd_id from icd10_manual_checks group by icd_id having count (1)>=2)) a1
      join 
(select * from icd10_manual_checks where icd_id in (select icd_id from icd10_manual_checks group by icd_id having count (1)>=2)) a2 
      on a1.icd_id = a2.icd_id 
      join concept_ancestor ca on a1.concept_id = ca.ancestor_concept_id 
      and a2.concept_id = ca.descendant_concept_id 
      and a1.concept_id <> a2.concept_id
  UNION
select 'mapping issue - lost No loss of consciousness' as issue_desc, count (distinct icd_code)  
from icd10_manual_checks 
where icd_name ~* 'without loss of consciousness'
      and icd_name !~* 'sequela|with or without'
      and icd_code not in (select icd_code from icd10_manual_checks where concept_name ~* 'no loss')
  UNION 
select 'mapping issue - lost OR mapped to many Sequela' as issue_desc, count (distinct icd_code)  
from icd10_manual_checks 
where icd_code in (select icd_code from  icd10_manual_checks where  icd_name ~* 'sequela')
      and icd_code in (select icd_code from  icd10_manual_checks where  concept_name !~* 'Sequela|Late effect')
  UNION 
select 'mapping issue - lost Nonunion of fracture' as issue_desc, count (distinct icd_code)  
from icd10_manual_checks  
where icd_name ~* 'nonunion'
      and icd_id not in (select icd_id from icd10_manual_checks  where concept_name ~* 'nonunion')
  UNION 
select 'mapping issue - lost Malunion of fracture' as issue_desc, count (distinct icd_code)   
from icd10_manual_checks  where icd_name ~* 'malunion'
     and icd_id not in (select icd_id from icd10_manual_checks  where concept_name ~* 'malunion')
  UNION 
select 'mapping issue - lost Closed fracture' as issue_desc, count (distinct icd_code) 
from icd10_manual_checks  where icd_name ~* 'closed fracture'
      and icd_id not in (select icd_id from icd10_manual_checks  where concept_name ~* 'closed')
  UNION
select 'mapping issue - lost Open fracture' as issue_desc, count (distinct icd_code)
from icd10_manual_checks  where icd_name ~* 'open fracture'
      and icd_id not in (select icd_id from icd10_manual_checks  where concept_name ~* 'open')
  UNION 
select 'mapping issue - lost Delayed union of fracture' as issue_desc, count (distinct icd_code)
from icd10_manual_checks
where icd_id  in (select icd_id from icd10_manual_checks  where icd_name ~* 'with delayed healing')
      and icd_id not  in (select icd_id from icd10_manual_checks  where concept_name ~* 'delayed union')
  UNION
select 'mapping issue - lost Foreign body' as issue_desc, count (distinct icd_code)
from icd10_manual_checks where icd_name ~* 'with foreign body'
      and  icd_code not in (select icd_code from icd10_manual_checks  where concept_name ~* 'foreign body')
      and icd_name !~* 'sequela'
  UNION 
select 'mapping issue - lost relation to Diabetes Mellitus when it should be' as issue_desc, count (distinct icd_code)
from icd10_manual_checks 
where icd_code not in (
            select a.icd_code from icd10_manual_checks a 
            join concept_ancestor ca on a.concept_id = ca.descendant_concept_id 
            and ca.ancestor_concept_id = 201820 
            where icd_code ~ '^E08|^E09|^E10|^E11|^E12|^E13'
            )
      and icd_code ~ '^E08|^E09|^E10|^E11|^E12|^E13'  
  UNION 
select 'mapping issue - lost Trimester of pregnancy' as issue_desc, count (distinct icd_code)
from icd10_manual_checks 
where (icd_code in (select icd_code from icd10_manual_checks where icd_name ~*  'first trimester')
      and icd_code not in (select icd_code from icd10_manual_checks where  concept_name  ~*  'first trimester' ))  
or
      (icd_code in (select icd_code from icd10_manual_checks where icd_name ~*  'second trimester' and icd_name  !~* 'third' )
      and icd_code not in (select icd_code from icd10_manual_checks where  concept_name  ~*  'second trimester'  ))
or ( 
      icd_code in (select icd_code from icd10_manual_checks where icd_name ~*  'third trimester' and icd_name  !~* 'second')
      and icd_code not in (select icd_code from icd10_manual_checks where  concept_name  ~*  'third trimester' )
     )
  UNION 
select 'mapping issue - lost Intentional self-harm' as issue_desc, count (distinct icd_code)
from icd10_manual_checks where icd_code ~ 'T36' and icd_name ~* 'intentional self\-harm'
      and  icd_code not in (select icd_code from icd10_manual_checks where concept_name ~* 'Intentional|self' and concept_name!~* 'unintentional')
      and icd_name !~* 'sequela'
  union 
select 'mapping issue - lost Accidental event' as issue_desc, count (distinct icd_code)
from icd10_manual_checks where icd_name ~* 'accidental'
      and  icd_code not in (select icd_code from icd10_manual_checks where concept_name ~* 'accident|unintentional')
      and icd_name !~* 'sequela' and icd_code !~ '^T81'
  UNION
select 'mapping issue - lost Undetermined intent' as issue_desc, count (distinct icd_code)
from icd10_manual_checks where icd_code ~ 'T36' and icd_name ~* 'undetermined'
      and  icd_code not in (select icd_code from icd10_manual_checks where concept_name ~* 'undetermined|unknown intent')
      and icd_name !~* 'sequela'
  UNION 
select 'mapping issue - lost Primary malignant neoplasm' as issue_desc, count (distinct icd_code)
from icd10_manual_checks a 
      join concept_ancestor ca on a.concept_id = ca.ancestor_concept_id  and ca.min_levels_of_separation = 1  
      join concept c on c.concept_id = ca.descendant_concept_id and  c.vocabulary_id = 'SNOMED' and c.standard_concept = 'S' and  c.concept_name ~* 'primary'
where icd_name ~* 'Malignant neoplasm' and icd_code ~ 'C'  and icd_name !~* 'secondary|overlapping' 
      and icd_code not in (select icd_code from icd10_manual_checks where concept_name ~* 'primary') 
      and icd_code != 'C80' --and icd_code not in ('C96.9', 'C96')
  UNION 
select  'mapping issue - lost Secondary malignant neoplasm' as issue_desc, count (distinct icd_code)
from icd10_manual_checks where icd_name ~* 'Malignant' and icd_code ~ 'C'  and icd_name ~* 'secondary'  and icd_name !~*'Secondary and unspecified'
      and icd_code not in (select icd_code from icd10_manual_checks where concept_name ~* 'secondary')
      and icd_code!= 'C22.9'
  UNION 
select  'mapping issue - lost Overlapping malignant neoplasm' as issue_desc, count (distinct icd_code) 
from icd10_manual_checks where icd_code ~ 'C'  and icd_name ~* 'overlapping'
      and icd_code not in (select icd_code from icd10_manual_checks where concept_name ~* 'overlapping')
  UNION 
select 'mapping issue - incorrect gender' as issue_desc, count (distinct icd_code) 
from icd10_manual_checks where (icd_name !~* 'female' and icd_name ~*'male'
      and  icd_code  in (select icd_code from icd10_manual_checks where concept_name ~* 'female'))
or (
      icd_name !~* 'male' and icd_name ~*'female' and icd_code in (select icd_code from icd10_manual_checks where concept_name ~* '\s+male')
    )
  UNION 
select 'mapping issue - incorrect laterality' as issue_desc, count (distinct icd_code)
from icd10_manual_checks
where (
      icd_name ~* 'right' and icd_name !~* 'left|sequela'
      and  icd_code  in (select icd_code from icd10_manual_checks where concept_name ~* 'left' and concept_name !~* 'cleft')
      and  icd_code not  in (select icd_code from icd10_manual_checks where concept_name ~* 'right')
      )
or (
      icd_name ~* 'left' and icd_name !~* 'right|sequela'
      and  icd_code  in (select icd_code from icd10_manual_checks where concept_name ~* 'right')
      and  icd_code not  in (select icd_code from icd10_manual_checks where concept_name ~* 'left')
      )
  UNION 
select 'mapping issue - lost Refractory epilepsy or migraine' as issue_desc, count (distinct icd_code)
from icd10_manual_checks
where icd_name ~* 'intractable' and icd_name ~* 'epilep|migrain' and icd_name !~* 'not intractable'
      and  icd_code not in (select icd_code from icd10_manual_checks where concept_name ~* 'refractor|intractable')
      and icd_code != 'G43.D1' 
  UNION
select 'mapping issue - non-standard concepts' as issue_desc, count (concept_id) 
from  icd10_manual_checks 
where icd_id in ( 
      select a.icd_id from icd10_manual_checks a
      left join concept c
      on a.concept_id = c.concept_id and c.standard_concept = 'S'
      where c.concept_id is null
      )
  UNION
select 'relationship_id - Maps to value with incorrect pair of relationship_id' as issue_desc, count  (icd_code) 
from icd10_manual_checks 
where icd_code in (select icd_code from icd10_manual_checks where relationship_id = 'Maps to value')
      and  icd_code not  in (select icd_code from icd10_manual_checks where relationship_id = 'Maps to')   -- 0
  UNION
select 'relationship_id - Maps to value without Maps to ' as issue_desc, count  (icd_code) 
from icd10_manual_checks 
where icd_code in (select icd_code from icd10_manual_checks group by icd_code having count (1)=1)
      and icd_code in (select icd_code from  icd10_manual_checks where relationship_id = 'Maps to value') 
  UNION
select 'relationship_id - incompatiable relationship_id combination' as issue_desc, count (distinct icd_code) 
from icd10_manual_checks
where  icd_code in (select icd_code from icd10_manual_checks group by icd_code having count (1)>1)
      and  icd_code in (select icd_code from icd10_manual_checks where relationship_id = 'Maps to')
      and  icd_code in (select icd_code from icd10_manual_checks where relationship_id = 'Is a')
  UNION
select 'relationship_id - Is a instead of Maps to' as issue_desc, count (distinct icd_code) 
from  icd10_manual_checks 
where icd_code in (select icd_code from icd10_manual_checks group by icd_code having count (1)=1)
      and icd_code in (select icd_code from icd10_manual_checks  where lower (icd_name) = lower (concept_name) and relationship_id = 'Is a')
  UNION
select  'relationship_id -  hierarchical concept (^\w.\d+$) and the last concept in the chapter (^\w.\d+\.9%) should have equal rel_id, but not'  as issue_desc, count (distinct a1.icd_code) 
from 
(select icd_code, icd_name, relationship_id, concept_id, concept_name  from icd10_manual_checks where icd_code in (select icd_code from  icd10_manual_checks where icd_code ~ '^\w.\d+$') ) a1
      join 
(select icd_code, icd_name, relationship_id, concept_id, concept_name  from icd10_manual_checks where icd_code in (select icd_code from  icd10_manual_checks where icd_code ~ '^\w.\d+\.9$') ) a2
      on a1.icd_code||'.9'  = a2.icd_code 
      and a1.relationship_id <> a2.relationship_id
      and a1.concept_id = a2.concept_id
      where a2.icd_name ~* 'unspecified'
      and a1.icd_name !~* 'other|not elsewhere classified'
      and a1.icd_code != 'I08' 
      and a2.icd_code != 'I08.9'
  UNION
select  'mapping issue - equal icd_names of various icd_codes with different mappings' as issue_desc, count (distinct a.icd_code) 
from icd10_manual_checks a 
      join  icd10_manual_checks b on a.icd_name = b.icd_name
      and a.icd_code <> b.icd_code 
      and a.relationship_id <> b.relationship_id 
      and a.concept_id <> b.concept_id
where  a.icd_code not in (
      select icd_code from icd10_manual_checks where relationship_id = 'Maps to value')
order by issue_desc
;
