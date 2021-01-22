-- NEWLY ADDED BREAST CANCER PROTOCOLS CODED. TO BE MAPPED
--  RUN AFTER CONCEPT AND CONCEPT_RELATIONSHIP POPULATION IN LOAD STAGE   AND BEFORE  point -- 8. Add manual source in LOAD STAGE.sql
SELECT *
FROM concept_stage cs
         JOIN concept_relationship_stage crs
              ON cs.concept_code = crs.concept_code_1
                and crs.relationship_id='Has CAP protocol'
         JOIN concept_stage cs2
ON crs.concept_code_2=cs2.concept_code
AND cs2.concept_name ilike '%breast%'
WHERE cs.concept_code  NOT IN (SELECT cc.concept_code
FROM devv5.concept c
    JOIN devv5.concept_relationship cr
        ON c.concept_id=cr.concept_id_1
               and c.concept_name ilike '%breast%'
    JOIN devv5.concept cc
        ON cr.concept_id_2=cc.concept_id
where c.vocabulary_id='CAP'
  and c.concept_class_id='CAP Protocol'
    )
;