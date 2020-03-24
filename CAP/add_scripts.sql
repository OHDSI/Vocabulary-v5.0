
SELECT *
FROM concept_relationship_stage cr
JOIN concept_stage c
ON cr.concept_code_1=c.concept_code
JOIN concept_stage c2
ON cr.concept_code_2=c2.concept_code
-----------------------------------------------------------------------------------------
--- CHECKS CRS source
-- SQL to retrieve all the hierarchical direct parent-child pairs generated in dev_cap.cap_breast_2019_concept_stage_preliminary
SELECT distinct
       cs.concept_class_id,
       cs2.concept_class_id,
       count(*) as COUNTS
FROM dev_cap.ecc_202002 e
JOIN dev_cap.cap_breast_2019_concept_stage_preliminary cs
ON e.value_code=cs.concept_code
JOIN dev_cap.cap_breast_2019_concept_stage_preliminary cs2
ON e.variable_code=cs2.concept_code
WHERE e.filename ~* 'breast'
AND e.level_of_separation =1
GROUP BY cs.concept_class_id,
         cs2.concept_class_id
Order BY COUNTS desc
;

-- not included to any hierarchy codes from source plus newly created class CAP protocols
SELECT distinct *

FROM dev_cap.ecc_202002 e
LEFT JOIN  dev_cap.cap_breast_2019_concept_stage_preliminary cs
ON e.variable_code=cs.concept_code

WHERE e.filename ~* 'breast'
AND e.variable_code NOT IN (SELECT distinct
       e.value_code
FROM dev_cap.ecc_202002 e
JOIN dev_cap.cap_breast_2019_concept_stage_preliminary cs
ON e.value_code=cs.concept_code
JOIN dev_cap.cap_breast_2019_concept_stage_preliminary cs2
ON e.variable_code=cs2.concept_code
WHERE e.filename ~* 'breast'
AND e.level_of_separation =1

    UNION
    SELECT distinct
       e.variable_code
FROM dev_cap.ecc_202002 e
JOIN dev_cap.cap_breast_2019_concept_stage_preliminary cs
ON e.value_code=cs.concept_code
JOIN dev_cap.cap_breast_2019_concept_stage_preliminary cs2
ON e.variable_code=cs2.concept_code
WHERE e.filename ~* 'breast'
AND e.level_of_separation =1
)
;

--- CHECKS CRS resulting
-- check af multiple relationships
-- for only one relationship created
SELECT *
FROM concept_relationship_stage
WHERE concept_code_1 IN
(SELECT concept_code_1
    FROM concept_relationship_stage
    GROUP BY concept_code_1
    having count(relationship_id)=1)
;
-- Check for uniqueness of pair concept_code_1, concept_code_2
select concept_code_1, concept_code_2
from dev_cap.concept_relationship_stage
group by concept_code_1, concept_code_2 having count(1) > 1
;



SELECT c.concept_id,c.concept_code,c.concept_name,c.concept_class_id,cr.relationship_id,cc.concept_id,cc.concept_code,cc.concept_name,cc.concept_class_id
FROM concept_relationship cr
JOIN concept c
    ON cr.concept_id_1=c.concept_id
JOIN concept cc
    ON cr.concept_id_2=cc.concept_id
WHERE c.vocabulary_id='CAP';




--dev_lexicon - for Nebraska_Lexicon mappings
select distinct cs.concept_code,cs.concept_name, cs.concept_class_id, cs.alternative_concept_name, n.*,
                CASE WHEN length(n.concept_name)>20 then 'CHECK' else '' END AS comment
FROM dev_cap.cap_breast_2020_concept_stage_preliminary cs
left JOIN  dev_lexicon.concept n
ON trim(lower(regexp_replace(cs.alternative_concept_name,'[[:punct:]]|\s','','g')))
    = trim(lower(regexp_replace(n.concept_name,'\sposition|[[:punct:]]|\s','','g')))
AND n.vocabulary_id='Nebraska Lexicon'
AND n.invalid_reason IS NULL
ORDER BY cs.concept_name
;

SELECT distinct *
FROM dev_cap.cap_breast_2020_concept_relationship_stage_preliminary
WHERE concept_name_2='Extent of Medial Margin Involvement|Medial|Specify Margin(s)|Positive for DCIS|Margins|MARGINS (Note H)'
;

SELECT distinct n.concept_id,
               n.concept_code	,
               n.concept_name	,
               n. domain_id	,
               n. concept_class_id	,
               n. vocabulary_id	,
               n. valid_start_date	,
               n. valid_end_date	,
               n. invalid_reason	,
               n. standard_concept
FROM devv5.concept n
WHERE n.vocabulary_id='Nebraska Lexicon'
--AND  n.concept_code='445028008'
AND n.concept_name ~*'pM1'
--AND n.concept_name ~*'surgica'
--AND n.concept_name !~*'clos'
--AND n.invalid_reason is NULL
;
SELECT * FROM  dev_lexicon.concept n
WHERE n.vocabulary_id='Nebraska Lexicon'
;

SELECT distinct nn.concept_id,
               nn.concept_code	,
               nn.concept_name	,
               nn. domain_id	,
               nn. concept_class_id	,
               nn. vocabulary_id	,
               nn. valid_start_date	,
               nn. valid_end_date	,
               nn. invalid_reason	,
               nn. standard_concept,
                nn.concept_name	,
                nr.relationship_id,
                n.concept_name

FROM dev_lexicon.concept n
JOIN dev_lexicon.concept_relationship nr
ON n.concept_id=nr.concept_id_2
JOIN dev_lexicon.concept nn ON nn.concept_id=nr.concept_id_1
WHERE n.vocabulary_id='Nebraska Lexicon'
AND nn.vocabulary_id='Nebraska Lexicon'
AND n.concept_code = '84921008'-- from above select
/* AND n.concept_name ~*'skin'*/
AND n.invalid_reason is NULL
;


select * from ddymshyts.concept where vocabulary_id ='Nebraska Lexicon'
and concept_code not in (select concept_code from dev_lexicon.concept where vocabulary_id ='Nebraska Lexicon')
AND CONCEPT_id IN ('36902312',
'36902319',
'36902401',
'36902461',
'36902542',
'36902644',
'36902651',
'36902670',
'36902679',
'36902696',
'36902711',
'36902732',
'36902735',
'36902742',
'36902754',
'36902795',
'36902806',
'36903138');

SELECT distinct vocabulary_id
FROM devv5.concept
WHERE vocabulary_id ilike'n%'


-- used to upload to g-dock for manual
WITH all_concepts AS (
    SELECT DISTINCT a.name, cc.concept_id, cc.vocabulary_id,cc.standard_concept, cc.invalid_reason, a.algorithm
    FROM (
             SELECT concept_name as name,
                    concept_id as concept_id,
                    'CN' as algorithm
             FROM dev_lexicon.concept c
             WHERE c.vocabulary_id='Nebraska Lexicon'
UNION ALL
             --Mapping non-standard to standard through concept relationship
             SELECT c.concept_name as name,
                    cr.concept_id_2 as concept_id,
                    'CR' as algorithm
             FROM  dev_lexicon.concept c
             JOIN dev_lexicon.concept_relationship cr
             ON (cr.concept_id_1 = c.concept_id
                 AND cr.invalid_reason IS NULL AND cr.relationship_id in ('Maps to','Concept same_as to','Concept poss_eq to'))
             JOIN dev_lexicon.concept cc
             ON (cr.concept_id_2 = cc.concept_id
                 AND (cc.standard_concept IN ('S','') or cc.standard_concept IS NULL) AND cc.invalid_reason IS NULL)
             WHERE c.standard_concept != 'S' OR c.standard_concept IS NULL
AND cc.vocabulary_id in ('Nebraska Lexicon')
AND c.vocabulary_id in ('Nebraska Lexicon') --vocabularies selection
         ) AS a

             JOIN dev_lexicon.concept cc
                  ON a.concept_id = cc.concept_id

      WHERE (cc.standard_concept IN ('S','') or cc.standard_concept IS NULL)
      AND cc.invalid_reason IS NULL
)

    SELECT DISTINCT  S.CONCEPT_CODE,
                    S.CONCEPT_NAME,
                    S.ALTERNATIVE_CONCEPT_NAME,
                    S.DOMAIN_ID,
                    S.VOCABULARY_ID,
                    S.CONCEPT_CLASS_ID,
                    S.STANDARD_CONCEPT,
                    S.INVALID_REASON,
                    dc.*


    FROM  dev_cap.cap_breast_2020_concept_stage_preliminary s --source table
        LEFT  JOIN all_concepts ac
          ON trim(lower(regexp_replace(s.alternative_concept_name,'[[:punct:]]|\s','','g')))
                                           = trim(lower(regexp_replace(ac.name,'\sposition|[[:punct:]]|\s','','g')))
LEFT join DEV_LEXICON.CONCEPT D
ON d.concept_id=ac.concept_id

        /* JOIN  ddymshyts.concept dc
    ON trim(lower(regexp_replace(s.alternative_concept_name,'[[:punct:]]|\s','','g')))
                                           = trim(lower(regexp_replace(dc.concept_name,'\sposition|[[:punct:]]|\s','','g')))
     AND  dc.vocabulary_id ='Nebraska Lexicon'
and dc.concept_code not in (select concept_code from dev_lexicon.concept where vocabulary_id ='Nebraska Lexicon')*/ -- to map to 36902696	 Cannot be assessed

;
