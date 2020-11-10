-- DROP TABLE dev_vkorsik.combined_meddra_to_snomed_set
CREATE TABLE dev_vkorsik.combined_meddra_to_snomed_set as (
    select c.concept_code      as snomed_code,
           c.concept_name      as snomed_name,
           c.concept_class_id  as snomed_class,
           c.domain_id         as snomed_domain,
           c.standard_concept  as snomed_standard,
           c.invalid_reason    as snomed_validity,
           cc.concept_code     as meddra_code,
           cc.concept_name     as meddra_name,
           cc.concept_class_id as meddra_class,
           cc.domain_id        as meddra_domain,
           cc.standard_concept as meddra_standard,
           cc.invalid_reason   as meddra_validity,
            'SM' as flag
    from dev_meddra.der2_srefset_snomedtomeddramap s
             JOIN devv5.concept c
                  ON s.referencedcomponentid::varchar = c.concept_code
                      AND c.vocabulary_id = 'SNOMED'
             JOIN devv5.concept cc
                  ON s.maptarget::varchar = cc.concept_code
                      AND cc.vocabulary_id = 'MedDRA'
    WHERE (maptarget::varchar,referencedcomponentid::varchar) NOT IN (SELECT referencedcomponentid::varchar,maptarget::varchar from dev_meddra.der2_srefset_meddratosnomedmap ss)

    UNION ALL

    select c.concept_code      as snomed_code,
           c.concept_name      as snomed_name,
           c.concept_class_id  as snomed_class,
           c.domain_id         as snomed_domain,
           c.standard_concept  as snomed_standard,
           c.invalid_reason    as snomed_validity,
           cc.concept_code     as meddra_code,
           cc.concept_name     as meddra_name,
           cc.concept_class_id as meddra_class,
           cc.domain_id        as meddra_domain,
           cc.standard_concept as meddra_standard,
           cc.invalid_reason   as meddra_validity,
            'MS' as flag
    from dev_meddra.der2_srefset_meddratosnomedmap s
             JOIN devv5.concept c
                  ON s.maptarget::varchar = c.concept_code
                      AND c.vocabulary_id = 'SNOMED'
             JOIN devv5.concept cc
                  ON s.referencedcomponentid::varchar = cc.concept_code
                      AND cc.vocabulary_id = 'MedDRA'
)
;
-- 1 to many meddra mappings in SNOMED to MedDRA table
SELECT     c.concept_code      as snomed_code,
           c.concept_name      as snomed_name,
           c.concept_class_id  as snomed_class,
           c.domain_id         as snomed_domain,
           c.standard_concept  as snomed_standard,
           c.invalid_reason    as snomed_validity,
           cc.concept_code     as meddra_code,
           cc.concept_name     as meddra_name,
           cc.concept_class_id as meddra_class,
           cc.domain_id        as meddra_domain,
           cc.standard_concept as meddra_standard,
           cc.invalid_reason   as meddra_validity
    from dev_meddra.der2_srefset_snomedtomeddramap s
             JOIN devv5.concept c
                  ON s.referencedcomponentid::varchar = c.concept_code
                      AND c.vocabulary_id = 'SNOMED'
             JOIN devv5.concept cc
                  ON s.maptarget::varchar = cc.concept_code
                      AND cc.vocabulary_id = 'MedDRA'
WHERE s.maptarget IN (SELECT maptarget FROM dev_meddra.der2_srefset_snomedtomeddramap group by 1 having count( distinct referencedcomponentid)>1)

--todo   case when MedDRA-SNOMED mappings are  different in 2 set tables
  select c.concept_code      as snomed_code,
           c.concept_name      as snomed_name,
           c.concept_class_id  as snomed_class,
           c.domain_id         as snomed_domain,
           c.standard_concept  as snomed_standard,
           c.invalid_reason    as snomed_validity,
           cc.concept_code     as meddra_code,
           cc.concept_name     as meddra_name,
           cc.concept_class_id as meddra_class,
           cc.domain_id        as meddra_domain,
           cc.standard_concept as meddra_standard,
           cc.invalid_reason   as meddra_validity,
         c2.concept_code     as snomed_sm_code,
           c2.concept_name     as snomed_sm_name,
           c2.concept_class_id as snomed_sm_class,
           c2.domain_id        as snomed_sm_domain,
           c2.standard_concept as snomed_sm_standard,
           c2.invalid_reason   as snomed_sm_validity
    from dev_meddra.der2_srefset_meddratosnomedmap s
             JOIN devv5.concept c
                  ON s.maptarget::varchar = c.concept_code
                      AND c.vocabulary_id = 'SNOMED'
             JOIN devv5.concept cc
                  ON s.referencedcomponentid::varchar = cc.concept_code
                      AND cc.vocabulary_id = 'MedDRA'
               JOIN dev_meddra.der2_srefset_snomedtomeddramap p
                  ON s.referencedcomponentid::varchar =p.maptarget
               JOIN devv5.concept c2
                  ON p.referencedcomponentid::varchar = c2.concept_code
                      AND c2.vocabulary_id = 'SNOMED'
WHERE NOT EXISTs (select 1
      from dev_meddra.der2_srefset_meddratosnomedmap s1
     join dev_meddra.der2_srefset_snomedtomeddramap a
    ON s1.referencedcomponentid::varchar=a.maptarget::varchar
    AND s1.maptarget::varchar=a.referencedcomponentid::varchar
    WHERE s1.referencedcomponentid=s.referencedcomponentid
    )
AND EXISTs (select 1
      from dev_meddra.der2_srefset_meddratosnomedmap s2
     join dev_meddra.der2_srefset_snomedtomeddramap a2
    ON s2.referencedcomponentid::varchar=a2.maptarget::varchar
    WHERE s2.referencedcomponentid=s.referencedcomponentid
    )
;
-- Number of fully overlapped mappings =3114
  select s.referencedcomponentid,s.maptarget,count(*)
    from dev_meddra.der2_srefset_meddratosnomedmap s
             JOIN devv5.concept c
                  ON s.maptarget::varchar = c.concept_code
                      AND c.vocabulary_id = 'SNOMED'
             JOIN devv5.concept cc
                  ON s.referencedcomponentid::varchar = cc.concept_code
                      AND cc.vocabulary_id = 'MedDRA'
               JOIN dev_meddra.der2_srefset_snomedtomeddramap p
                  ON s.referencedcomponentid::varchar =p.maptarget
               JOIN devv5.concept c2
                  ON p.referencedcomponentid::varchar = c2.concept_code
                      AND c2.vocabulary_id = 'SNOMED'
WHERE  EXISTs (select 1
      from dev_meddra.der2_srefset_meddratosnomedmap s1
     join dev_meddra.der2_srefset_snomedtomeddramap a
    ON s1.referencedcomponentid::varchar=a.maptarget::varchar
    AND s1.maptarget::varchar=a.referencedcomponentid::varchar
    WHERE s1.referencedcomponentid=s.referencedcomponentid
    )
AND EXISTs (select 1
      from dev_meddra.der2_srefset_meddratosnomedmap s2
     join dev_meddra.der2_srefset_snomedtomeddramap a2
    ON s2.referencedcomponentid::varchar=a2.maptarget::varchar
    WHERE s2.referencedcomponentid=s.referencedcomponentid
    )
AND  c.concept_code=c2.concept_code
GROUP BY 1,2
;
-- full match in sets
  select distinct c.concept_code      as snomed_code,
           c.concept_name      as snomed_name,
           c.concept_class_id  as snomed_class,
           c.domain_id         as snomed_domain,
           c.standard_concept  as snomed_standard,
           c.invalid_reason    as snomed_validity,
           cc.concept_code     as meddra_code,
           cc.concept_name     as meddra_name,
           cc.concept_class_id as meddra_class,
           cc.domain_id        as meddra_domain,
           cc.standard_concept as meddra_standard,
           cc.invalid_reason   as meddra_validity,
         c2.concept_code     as snomed_sm_code,
           c2.concept_name     as snomed_sm_name,
           c2.concept_class_id as snomed_sm_class,
           c2.domain_id        as snomed_sm_domain,
           c2.standard_concept as snomed_sm_standard,
           c2.invalid_reason   as snomed_sm_validity
    from dev_meddra.der2_srefset_meddratosnomedmap s
             JOIN devv5.concept c
                  ON s.maptarget::varchar = c.concept_code
                      AND c.vocabulary_id = 'SNOMED'
             JOIN devv5.concept cc
                  ON s.referencedcomponentid::varchar = cc.concept_code
                      AND cc.vocabulary_id = 'MedDRA'
               JOIN dev_meddra.der2_srefset_snomedtomeddramap p
                  ON s.referencedcomponentid::varchar =p.maptarget
               JOIN devv5.concept c2
                  ON p.referencedcomponentid::varchar = c2.concept_code
                      AND c2.vocabulary_id = 'SNOMED'
WHERE  EXISTs (select 1
      from dev_meddra.der2_srefset_meddratosnomedmap s1
     join dev_meddra.der2_srefset_snomedtomeddramap a
    ON s1.referencedcomponentid::varchar=a.maptarget::varchar
    AND s1.maptarget::varchar=a.referencedcomponentid::varchar
    WHERE s1.referencedcomponentid=s.referencedcomponentid
    )
AND EXISTs (select 1
      from dev_meddra.der2_srefset_meddratosnomedmap s2
     join dev_meddra.der2_srefset_snomedtomeddramap a2
    ON s2.referencedcomponentid::varchar=a2.maptarget::varchar
    WHERE s2.referencedcomponentid=s.referencedcomponentid
    )
AND  c.concept_code=c2.concept_code
;

-- NON MATCHED IN in sets
with taba as (select distinct c.concept_code      as snomed_ms_code,
                                c.concept_name      as snomed_ms_name,
                                c.concept_class_id  as snomed_ms_class,
                                c.domain_id         as snomed_ms_domain,
                                c.standard_concept  as snomed_ms_standard,
                                c.invalid_reason    as snomed_ms_validity,
                                cc.concept_code     as meddra_code,
                                cc.concept_name     as meddra_name,
                                cc.concept_class_id as meddra_class,
                                cc.domain_id        as meddra_domain,
                                cc.standard_concept as meddra_standard,
                                cc.invalid_reason   as meddra_validity,
                                c2.concept_code     as snomed_sm_code,
                                c2.concept_name     as snomed_sm_name,
                                c2.concept_class_id as snomed_sm_class,
                                c2.domain_id        as snomed_sm_domain,
                                c2.standard_concept as snomed_sm_standard,
                                c2.invalid_reason   as snomed_sm_validity
                from dev_meddra.der2_srefset_meddratosnomedmap s
                         JOIN devv5.concept c
                              ON s.maptarget::varchar = c.concept_code
                                  AND c.vocabulary_id = 'SNOMED'
                         JOIN devv5.concept cc
                              ON s.referencedcomponentid::varchar = cc.concept_code
                                  AND cc.vocabulary_id = 'MedDRA'
                         JOIN dev_meddra.der2_srefset_snomedtomeddramap p
                              ON s.referencedcomponentid::varchar = p.maptarget
                         JOIN devv5.concept c2
                              ON p.referencedcomponentid::varchar = c2.concept_code
                                  AND c2.vocabulary_id = 'SNOMED'
                WHERE EXISTs(select 1
                             from dev_meddra.der2_srefset_meddratosnomedmap s1
                                      join dev_meddra.der2_srefset_snomedtomeddramap a
                                           ON s1.referencedcomponentid::varchar = a.maptarget::varchar
                                               AND s1.maptarget::varchar = a.referencedcomponentid::varchar
                             WHERE s1.referencedcomponentid = s.referencedcomponentid
                    )
                  AND EXISTs(select 1
                             from dev_meddra.der2_srefset_meddratosnomedmap s2
                                      join dev_meddra.der2_srefset_snomedtomeddramap a2
                                           ON s2.referencedcomponentid::varchar = a2.maptarget::varchar
                             WHERE s2.referencedcomponentid = s.referencedcomponentid
                    )
                  AND c.concept_code <> c2.concept_code
  )
  ,

tabb  as (
     select c.concept_code      as snomed_ms_code,
           c.concept_name      as snomed_ms_name,
           c.concept_class_id  as snomed_ms_class,
           c.domain_id         as snomed_ms_domain,
           c.standard_concept  as snomed_ms_standard,
           c.invalid_reason    as snomed_ms_validity,
           cc.concept_code     as meddra_code,
           cc.concept_name     as meddra_name,
           cc.concept_class_id as meddra_class,
           cc.domain_id        as meddra_domain,
           cc.standard_concept as meddra_standard,
           cc.invalid_reason   as meddra_validity,
         c2.concept_code     as snomed_sm_code,
           c2.concept_name     as snomed_sm_name,
           c2.concept_class_id as snomed_sm_class,
           c2.domain_id        as snomed_sm_domain,
           c2.standard_concept as snomed_sm_standard,
           c2.invalid_reason   as snomed_sm_validity
    from dev_meddra.der2_srefset_meddratosnomedmap s
             JOIN devv5.concept c
                  ON s.maptarget::varchar = c.concept_code
                      AND c.vocabulary_id = 'SNOMED'
             JOIN devv5.concept cc
                  ON s.referencedcomponentid::varchar = cc.concept_code
                      AND cc.vocabulary_id = 'MedDRA'
               JOIN dev_meddra.der2_srefset_snomedtomeddramap p
                  ON s.referencedcomponentid::varchar =p.maptarget
               JOIN devv5.concept c2
                  ON p.referencedcomponentid::varchar = c2.concept_code
                      AND c2.vocabulary_id = 'SNOMED'
WHERE NOT EXISTs (select 1
      from dev_meddra.der2_srefset_meddratosnomedmap s1
     join dev_meddra.der2_srefset_snomedtomeddramap a
    ON s1.referencedcomponentid::varchar=a.maptarget::varchar
    AND s1.maptarget::varchar=a.referencedcomponentid::varchar
    WHERE s1.referencedcomponentid=s.referencedcomponentid
    )
AND EXISTs (select 1
      from dev_meddra.der2_srefset_meddratosnomedmap s2
     join dev_meddra.der2_srefset_snomedtomeddramap a2
    ON s2.referencedcomponentid::varchar=a2.maptarget::varchar
    WHERE s2.referencedcomponentid=s.referencedcomponentid
    )

)
,
     not_equals as (
         SELECT distinct snomed_ms_code,
                         snomed_ms_name,
                         snomed_ms_class,
                         snomed_ms_domain,
                         snomed_ms_standard,
                         snomed_ms_validity,
                         meddra_code,
                         meddra_name,
                         meddra_class,
                         meddra_domain,
                         meddra_standard,
                         meddra_validity,
                         snomed_sm_code,
                         snomed_sm_name,
                         snomed_sm_class,
                         snomed_sm_domain,
                         snomed_sm_standard,
                         snomed_sm_validity,
                         'a' as flag
         FROM taba
         UNION ALL
         SELECT distinct snomed_ms_code,
                         snomed_ms_name,
                         snomed_ms_class,
                         snomed_ms_domain,
                         snomed_ms_standard,
                         snomed_ms_validity,
                         meddra_code,
                         meddra_name,
                         meddra_class,
                         meddra_domain,
                         meddra_standard,
                         meddra_validity,
                         snomed_sm_code,
                         snomed_sm_name,
                         snomed_sm_class,
                         snomed_sm_domain,
                         snomed_sm_standard,
                         snomed_sm_validity,
                         'b' as flag
         from tabb
         where (snomed_ms_code, meddra_code, snomed_sm_code) NOT IN
               (SELECT snomed_ms_code, meddra_code, snomed_sm_code FROM taba)
     )

SELECT distinct *
from not_equals
;

--What is a number of codes with 1 to many mappings (aka postcoordianted) in RefSet?
SELECT a.meddra_code,a.meddra_name,a.flag,a.snomed_code,a.snomed_name,a.snomed_class
FROM combined_meddra_to_snomed_set a
JOIN combined_meddra_to_snomed_set b
ON a.meddra_code=b.meddra_code
AND a.flag<>b.flag
AND a.snomed_code<>b.snomed_code
WHERE a.meddra_code IN
(SELECT meddra_code FROM combined_meddra_to_snomed_set group by 1 having count(distinct snomed_code)>1)
order by meddra_code,flag,snomed_code
;

-- TODO case when mappings exists only in SNOMED to MEDDRA table
-- 489 rows are due to 1 to Many mappings in Snomed to MedDRA
with tab_sm_map_only as (SELECT c.concept_id as snomed_id,
       c.concept_name as  snomed_name,
       c.domain_id as snomed_domain,
       c.concept_class_id as  snomed_class,
       c.concept_code as  snomed_code,
       c.invalid_reason as   snomed_validity,
       cc.concept_id as meddra_concept_id,
              cc.concept_code as meddra_code,
       cc.concept_name as meddra_name,
       cc.domain_id as meddra_domain,
       cc.concept_class_id as meddra_class,
       cc.invalid_reason as meddra_validity
FROM dev_meddra.der2_srefset_snomedtomeddramap a
JOIN devv5.concept c
                  ON a.referencedcomponentid::varchar = c.concept_code
                      AND c.vocabulary_id = 'SNOMED'
             JOIN devv5.concept cc
                  ON a.maptarget::varchar = cc.concept_code
                      AND cc.vocabulary_id = 'MedDRA'
WHERE NOT  exists (select 1
      from dev_meddra.der2_srefset_meddratosnomedmap s2
    WHERE s2.referencedcomponentid::varchar=a.maptarget::varchar)
AND maptarget NOT IN (
   SELECT a.maptarget
  FROM dev_meddra.der2_srefset_snomedtomeddramap a
 WHERE NOT   exists (select 1
   from dev_meddra.der2_srefset_meddratosnomedmap s2
    WHERE s2.referencedcomponentid::varchar=a.maptarget::varchar)
    group by 1 having count(a.referencedcomponentid)>1

    )
),
full_name_eq as (SELECT
        a.snomed_name,
        a.snomed_class,
        a.snomed_code,
        a.meddra_code,
        a.meddra_name,
        a.meddra_domain,
        a.meddra_class,
        'Full name SNOMED-MedDRA equivalents' as mapping_category
FROM tab_sm_map_only a
JOIN tab_sm_map_only b
ON regexp_replace(lower(a.snomed_name),'\s|\.','','g')=regexp_replace(lower(b.meddra_name),'\s|\.','','g'))
, other as (
    SELECT
        a.snomed_name,
        a.snomed_class,
        a.snomed_code,
        a.meddra_code,
        a.meddra_name,
        a.meddra_domain,
        a.meddra_class,
        'Other not added to MedDRA to SNOMED set mappings' as mapping_category
FROM tab_sm_map_only a
    WHERE (a.snomed_code,a.meddra_code) NOT IN
    (SELECT a.snomed_code,a.meddra_code FROm full_name_eq a ))

    SELECT * FROM full_name_eq
    UNION ALL
    SELECT * FROM other


;
SELECT distinct maptarget
FROM dev_meddra.der2_srefset_snomedtomeddramap a
WHERE maptarget::varchar NOT IN    (select s2.referencedcomponentid::varchar
      from dev_meddra.der2_srefset_meddratosnomedmap s2
    )
AND (maptarget::varchar,referencedcomponentid::varchar)  IN (SELECT meddra_code,snomed_code from dev_vkorsik.combined_meddra_to_snomed_set)
;

-- todo статситка маппинга overlap between sts, overlap between combined and RWD ,
--done
-- todo показате меддру по классам и валидности , показать как классы замапплены


--checks
-- Are all meddra codes from set are in combined table

SELECT distinct  * FROM
dev_vkorsik.combined_meddra_to_snomed_set
WHERE meddra_code NOT IN (SELECT referencedcomponentid::varchar from dev_meddra.der2_srefset_meddratosnomedmap
    UNION ALL
    SELECT maptarget::varchar from dev_meddra.der2_srefset_snomedtomeddramap)
;

-- Are all snomed codes from set are in combined table
SELECT distinct  * FROM
dev_vkorsik.combined_meddra_to_snomed_set
WHERE snomed_code NOT IN (SELECT maptarget::varchar from dev_meddra.der2_srefset_meddratosnomedmap
    UNION ALL
    SELECT referencedcomponentid::varchar from dev_meddra.der2_srefset_snomedtomeddramap)
;

-- to prove  all the mappings from both sets were included
SELECT distinct  * FROM
dev_vkorsik.combined_meddra_to_snomed_set
WHERE (snomed_code,meddra_code) NOT IN (SELECT maptarget::varchar,referencedcomponentid::varchar from dev_meddra.der2_srefset_meddratosnomedmap
    UNION ALL
    SELECT referencedcomponentid::varchar,maptarget::varchar from dev_meddra.der2_srefset_snomedtomeddramap)
;
SELECT *
FROM dev_meddra.der2_srefset_snomedtomeddramap ms
-- NUmber of fully overlapping  mappings in 2 sets
-- 3114
SELECT count(*)
FROM dev_meddra.der2_srefset_meddratosnomedmap ms
WHERE exists(SELECT 1
    FROM dev_meddra.der2_srefset_meddratosnomedmap m
    JOIN dev_meddra.der2_srefset_snomedtomeddramap s
    ON m.referencedcomponentid::varchar=s.maptarget::varchar
    AND m.maptarget::varchar=s.referencedcomponentid::varchar
    WHERE m.referencedcomponentid=ms.referencedcomponentid
    AND s.referencedcomponentid::varchar=ms.maptarget::varchar)

--selection of overlapped codes
SELECT  c.concept_code      as snomed_code,
           c.concept_name      as snomed_name,
           c.concept_class_id  as snomed_class,
           c.domain_id         as snomed_domain,
           c.standard_concept  as snomed_standard,
           c.invalid_reason    as snomed_validity,
           cc.concept_code     as meddra_code,
           cc.concept_name     as meddra_name,
           cc.concept_class_id as meddra_class,
           cc.domain_id        as meddra_domain,
           cc.standard_concept as meddra_standard,
           cc.invalid_reason   as meddra_validity
FROM dev_meddra.der2_srefset_meddratosnomedmap ms
    JOIN devv5.concept c
                  ON ms.maptarget::varchar = c.concept_code
                      AND c.vocabulary_id = 'SNOMED'
             JOIN devv5.concept cc
                  ON ms.referencedcomponentid::varchar = cc.concept_code
                      AND cc.vocabulary_id = 'MedDRA'
WHERE  exists (SELECT 1
    FROM dev_meddra.der2_srefset_meddratosnomedmap m
    JOIN dev_meddra.der2_srefset_snomedtomeddramap s
    ON m.referencedcomponentid::varchar=s.maptarget::varchar
    AND m.maptarget::varchar=s.referencedcomponentid::varchar
    WHERE m.referencedcomponentid=ms.referencedcomponentid
    AND s.referencedcomponentid::varchar IN (SELECT maptarget::varchar FROM dev_meddra.der2_srefset_meddratosnomedmap )
       )
;
--Number of meddra codes in devv5 schema=105787
SELECT count(distinct concept_code)
FROM devv5.concept c
WHERE vocabulary_id='MedDRA'
;
-- VALID MedDRA codes distribution by classes in dev schema
SELECT concept_class_id,count(distinct concept_code) as abs_count,round(count(distinct concept_code)::numeric/(SELECT count(distinct concept_code)
FROM devv5.concept c
WHERE vocabulary_id='MedDRA' and c.invalid_reason is NULL)*100,3)as portion_of_codes
FROM devv5.concept c
WHERE vocabulary_id='MedDRA'
AND invalid_reason is NULL
group by 1
order by 2 desc
;
-- Invalid meddra general
SELECT concept_class_id,count(distinct concept_code) as abs_count,round(count(distinct concept_code)::numeric/(SELECT count(distinct concept_code)
FROM devv5.concept c
WHERE vocabulary_id='MedDRA' and c.invalid_reason ='D')*100,3)as portion_of_codes
FROM devv5.concept c
WHERE vocabulary_id='MedDRA'
AND invalid_reason ='D'
group by 1
order by 2 desc
;
-- DROP table dev_vkorsik.meddra_rwd_mappings
CREATE TABLE dev_vkorsik.meddra_rwd_mappings AS (
                         SELECT c.concept_id as meddra_id,
                                        c.concept_code as meddra_code,
                                            c.concept_name as meddra_name,
                                            c.concept_class_id as meddra_concept_class,
                                            c.domain_id as meddra_domain,
                                            CASE WHEN  s.source_vocabulary_id='JJ_MedDRA_maps_to' THEN 'event_concept_id' ELSE 'value_as_concept_id' END as cdm_field,
                                           coalesce(cc.concept_id,s.target_concept_id) as target_id,
                                              coalesce( cc.concept_code,'custom')                                  as target_code,
                                             coalesce( cc.concept_name,'custom')      as target_name,
                                            coalesce( cc.concept_class_id,'custom') as target_concept_class,
                                           coalesce( cc.domain_id,'custom') as target_domain,
                                            coalesce( cc.vocabulary_id,'custom') as target__vocabulary

                                     FROM dev_jnj.jj_general_custom_mapping s
JOIN devv5.concept c
ON s.source_code=c.concept_code
AND c.vocabulary_id='MedDRA'
LEFT JOIN devv5.concept cc
ON s.target_concept_id=cc.concept_id
WHERE s.source_vocabulary_id IN ('JJ_MedDRA_maps_to','JJ_MedDRA_maps_to_value')
    )
;


-- Number of codes used in RWD =8294
SELECT c.invalid_reason,c.concept_class_id,count(distinct meddra_code)
FROM dev_vkorsik.meddra_rwd_mappings m
JOIN devv5.concept c
ON m.meddra_id=c.concept_id
GROUP BY 1,2
ORDER BY 1,3 desc

;

-- Valid MedDRA codes distribution by classes in RWD
SELECT cc.invalid_reason,meddra_concept_class,count(distinct meddra_code) as abs_count,round(count( distinct meddra_code)::numeric/(SELECT count(distinct meddra_code)
FROM dev_vkorsik.meddra_rwd_mappings m
JOIN devv5.concept c
ON m.meddra_id=c.concept_id
)*100,3) as portion_of_total_meddra_codes
FROM dev_vkorsik.meddra_rwd_mappings c
JOIN devv5.concept cc
ON c.meddra_id=cc.concept_id
GROUP BY cc.invalid_reason,c.meddra_concept_class
order by cc.invalid_reason,c.meddra_concept_class,abs_count desc
;
-- inValid MedDRA codes distribution by classes in RWD
SELECT c.meddra_concept_class,count(distinct meddra_code) as abs_count,round(count( distinct meddra_code)::numeric/(SELECT count(distinct meddra_code)
FROM dev_vkorsik.meddra_rwd_mappings m
JOIN devv5.concept c
ON m.meddra_id=c.concept_id
AND c.invalid_reason IS  NOT NULL
)*100,3) as portion_of_total_meddra_codes
FROM dev_vkorsik.meddra_rwd_mappings c
JOIN devv5.concept cc
ON c.meddra_id=cc.concept_id
AND cc.invalid_reason IS  NOT NULL
GROUP BY c.meddra_concept_class
order by c.meddra_concept_class,abs_count desc
;


--Number of meddra codes in refset = 6861
Select count(distinct meddra_code)
from dev_vkorsik.combined_meddra_to_snomed_set
;
--MedDRA codes distribution by classes in refset
SELECT  s.meddra_validity,s.meddra_class,count(distinct s.meddra_code) as abs_count,round(count(distinct s.meddra_code)::numeric/(SELECT count(distinct meddra_code)::numeric FROM dev_vkorsik.combined_meddra_to_snomed_set)*100,3) as portion_of_codes
FROM dev_vkorsik.combined_meddra_to_snomed_set s
group by s.meddra_validity,s.meddra_class
order by s.meddra_validity,s.meddra_class,abs_count desc
;

-- Is our devv5 schema meddra have all the concepts from refset? - Yep
--check if any  code are lost
SELECT *
FROM dev_vkorsik.combined_meddra_to_snomed_set s
WHERE NOT EXISTS(SELECT 1
               FROM devv5.concept m
WHERE vocabulary_id='MedDRA'
                 AND s.meddra_code::varchar  = m.concept_code
                    );

-- How many codes do not appear in real world data  but exist in RefSet
SELECT count(distinct meddra_code) as non_in_real_world_data_abs_count, round(count(distinct s.meddra_code)::numeric/(SELECT count(distinct meddra_code)::numeric FROM dev_vkorsik.combined_meddra_to_snomed_set)*100,3) as portion_of_codes_in_refset
FROM dev_vkorsik.combined_meddra_to_snomed_set s
WHERE  meddra_code::varchar NOT  IN (   SELECT DISTINCT meddra_rwd_mappings.meddra_code
    FROM dev_vkorsik.meddra_rwd_mappings
)
;

-- Conclusion 1 - The refset looks representative if compare with RWD and General OMOPed meddra


--to show differnt mappings in 2 sets
SELECT a.meddra_code,c.concept_class_id as meddra_class,a.meddra_name, --string_agg(cc.concept_name,'->' order by ca.min_levels_of_separation) as meddra_parents,
CASE WHEN a.flag='SM' then 'SNOMED to MedDRA' else 'MedDRA to SNOMED' END as direction,
       a.snomed_code,
       a.snomed_name,
   --    string_agg(cs.concept_synonym_name,'|') as somed_synonym,
       a.snomed_class
FROM combined_meddra_to_snomed_set a
JOIN combined_meddra_to_snomed_set b
ON a.meddra_code=b.meddra_code
AND a.flag<>b.flag
JOIN devv5.concept c
ON a.meddra_code=c.concept_code
AND c.vocabulary_id='MedDRA'
JOIN devv5.concept_ancestor ca
ON c.concept_id=ca.descendant_concept_id
JOIN devv5.concept cc
ON ca.ancestor_concept_id=cc.concept_id
    JOIN devv5.concept c2
    ON c2.concept_code=a.snomed_code
    AND c2.vocabulary_id='SNOMED'
JOIN devv5.concept_synonym cs
ON cs.concept_id=c2.concept_id
WHERE a.meddra_code IN
(SELECT meddra_code FROM combined_meddra_to_snomed_set group by 1 having count(distinct snomed_code)>1)
GROUP BY a.meddra_code,c.concept_class_id,a.meddra_name,a.flag,a.snomed_code,a.snomed_name,a.snomed_class
order by meddra_code,direction,snomed_code
;
-- 0 meddra codes from refset have 1toMany mappings
WITH tabMS AS (SELECT snomed_code,
                     snomed_name,
                     snomed_class,
                     snomed_domain,
                     snomed_standard,
                     snomed_validity,
                     meddra_code,
                     meddra_name,
                     meddra_class,
                     meddra_domain,
                     meddra_standard,
                     meddra_validity
              FROM dev_vkorsik.combined_meddra_to_snomed_set
    WHERE flag='MS'),
     tabSM as (SELECT snomed_code,
                     snomed_name,
                     snomed_class,
                     snomed_domain,
                     snomed_standard,
                     snomed_validity,
                     meddra_code,
                     meddra_name,
                     meddra_class,
                     meddra_domain,
                     meddra_standard,
                     meddra_validity
              FROM dev_vkorsik.combined_meddra_to_snomed_set
    WHERE flag='SM')
SELECT * FROM tabMS
WHERE meddra_code IN (
    SELECT meddra_code
FROM tabMS
    GROUP BY 1 having count(snomed_code)>1)
;
-- 2 postcoordinated codes appeared in SNOMED to Merddra
WITH tabMS AS (SELECT snomed_code,
                     snomed_name,
                     snomed_class,
                     snomed_domain,
                     snomed_standard,
                     snomed_validity,
                     meddra_code,
                     meddra_name,
                     meddra_class,
                     meddra_domain,
                     meddra_standard,
                     meddra_validity
              FROM dev_vkorsik.combined_meddra_to_snomed_set
    WHERE flag='MS'),
     tabSM as (SELECT snomed_code,
                     snomed_name,
                     snomed_class,
                     snomed_domain,
                     snomed_standard,
                     snomed_validity,
                     meddra_code,
                     meddra_name,
                     meddra_class,
                     meddra_domain,
                     meddra_standard,
                     meddra_validity
              FROM dev_vkorsik.combined_meddra_to_snomed_set
    WHERE flag='SM')
SELECT * FROM tabsm
WHERE meddra_code IN (
    SELECT meddra_code
FROM tabsm
    GROUP BY 1 having count(snomed_code)>1)

--What is a number of codes with 1 to many mappings (aka postcoordianted) in Real World Data (RWD) by Odysseus?
--1-to-many mapping
-- 1236 1 to many codes
with tab as (
    SELECT DISTINCT s.*
   FROM dev_vkorsik.meddra_rwd_mappings s
)

SELECT count(distinct meddra_code)
FROM tab
WHERE meddra_code in (

    SELECT meddra_code
    FROM tab
    GROUP BY meddra_code
    HAVING count (*) > 1)
;

--all other 1-to-many mappings
-- 1 Maps to only
---- 460  1 to many Only codes
with tab as (
    SELECT DISTINCT s.*
   FROM dev_vkorsik.meddra_rwd_mappings s
)

SELECT count( distinct meddra_code)
FROM tab
WHERE meddra_code IN (
    SELECT meddra_code
    FROM tab
    GROUP BY meddra_code
    HAVING count(*) > 1)

    AND meddra_code NOT IN (
        SELECT meddra_code
        FROM tab t
        WHERE meddra_code in (
                SELECT meddra_code
                FROM tab
                GROUP BY meddra_code
                HAVING count(*)>1
        )
            AND EXISTS(SELECT 1
                       FROM tab b
                       WHERE t.meddra_code = b.meddra_code
                         AND b.cdm_field ~* 'value')
    )
;
--look at them
with tab as (
    SELECT DISTINCT s.*
   FROM dev_vkorsik.meddra_rwd_mappings s
)

SELECT distinct *
FROM tab a
LEFT JOIN dev_vkorsik.combined_meddra_to_snomed_set b
ON a.meddra_code=b.meddra_code
WHERE a.meddra_code IN (
    SELECT meddra_code
    FROM tab
    GROUP BY meddra_code
    HAVING count(*) > 1)

    AND a.meddra_code NOT IN (
        SELECT meddra_code
        FROM tab t
        WHERE meddra_code in (
                SELECT meddra_code
                FROM tab
                GROUP BY meddra_code
                HAVING count(*)>1
        )
            AND EXISTS(SELECT 1
                       FROM tab b
                       WHERE t.meddra_code = b.meddra_code
                         AND b.cdm_field ~* 'value')
    )
and b.meddra_code IS NOT NULL
;


--todo как маппили их ребята из меддры? (если они есть в рефсете)
-- сколько смаппили из них они,
-- в чем разницы (примеры)
--654/(1236-460) are 1var+1val
--1 maps_to mapping and 1 maps_to_value/unit/modifier/qualifier mapping
WITH tab AS (
    SELECT DISTINCT s.*
   FROM dev_vkorsik.meddra_rwd_mappings s
)

SELECT count(distinct meddra_code)
FROM tab t
WHERE meddra_code in (
        SELECT meddra_code
        FROM tab
        GROUP BY meddra_code
        HAVING count(*) =2
)
    AND EXISTS(SELECT 1
               FROM tab b
               WHERE t.meddra_code = b.meddra_code
                 AND b.cdm_field ~* 'value')
;

-- How often does Refset provide mapping of 1 SNOMED CODE to differnet meddra?
-- 1310 SNOMED for 3994 Meddras
SELECT  s.snomed_domain,s.snomed_class,s.snomed_name,count(s.meddra_code) as number_of_meddra_codes
FROM dev_vkorsik.combined_meddra_to_snomed_set s
WHERE snomed_code IN (
    SELECT snomed_code
FROM  dev_vkorsik.combined_meddra_to_snomed_set s
    GROUP BY 1 having count(distinct meddra_code)>1)
GROUP BY s.snomed_domain,s.snomed_class,s.snomed_name
order by number_of_meddra_codes desc
limit 400;

-- An example of Usage of 1 SNOMED  Code to cover  different MedDRA codes
-- Look at Switch From Measurement to Condition for ALT

-- todo найти еще абсолюно точно Clinical finding которые модно не маппит на morph abnor
SELECT cc.concept_id,
       cc.concept_name as meddra_name,
       cc.domain_id as meddra_domain,
       cc.concept_code as meddra_code,
       c.concept_name as snomed_name,
       c.domain_id as snomed_domain,
       c.concept_class_id as  snomed_concept_class,
       c.concept_code as snomed_code
FROM dev_meddra.der2_srefset_meddratosnomedmap s
    JOIN devv5.concept cc
ON s.referencedcomponentid::varchar=cc.concept_code
AND cc.vocabulary_id='MedDRA'
JOIN devv5.concept c
ON s.maptarget=c.concept_code
AND c.vocabulary_id='SNOMED'
WHERE s.maptarget IN (
    SELECT maptarget
FROM dev_meddra.der2_srefset_meddratosnomedmap
    GROUP BY 1 having count(distinct referencedcomponentid)>1)
AND c.concept_name IN ('Angioedema','Local anesthesia','Decrease in appetite','Precursor cell lymphoblastic leukemia','Inflammation','ALT (SGPT) level raised')
ORDER By c.concept_code
;

-- RefSet TO SNOMED mapping statistics
SELECT meddra_class,snomed_class,/*count( distinct s.meddra_code) as abs_meddra_code_count,*/round(count(distinct s.meddra_code)::numeric/(SELECT count(distinct meddra_code)::numeric FROM dev_vkorsik.combined_meddra_to_snomed_set)*100,2) as portion_of_total_meddra_codes
FROM  dev_vkorsik.combined_meddra_to_snomed_set s
group by meddra_class,snomed_class
ORDER BY meddra_class,portion_of_total_meddra_codes desc
;

-- domain switch
SELECT  s.meddra_domain,meddra_code,meddra_name,snomed_code, snomed_name , snomed_domain
FROM dev_vkorsik.combined_meddra_to_snomed_set s
WHERE s.meddra_domain<>s.snomed_domain
ORDER BY random(),s.meddra_code
LIMIT 100
;
-- RWD TO SNOMED mapping statistics 
SELECT   cc.concept_class_id as meddra_domain,s.source_vocabulary_id, c.domain_id as target_domain,c.concept_class_id as target_concept_class,count( distinct s.source_code) as abs_meddra_code_count
FROM dev_jnj.jj_general_custom_mapping s
JOIN devv5.concept c
ON s.target_concept_id=c.concept_id
JOIN devv5.concept cc
ON s.source_code=cc.concept_code
AND cc.vocabulary_id='MedDRA'
WHERE s.source_vocabulary_id IN ('JJ_MedDRA_maps_to',
'JJ_MedDRA_maps_to_value')
AND c.vocabulary_id='SNOMED'
group by cc.domain_id,s.source_vocabulary_id,c.domain_id,c.concept_class_id
ORDER BY cc.domain_id,c.domain_id,s.source_vocabulary_id,c.concept_class_id,abs_meddra_code_count desc
;

SELECT c.concept_class_id as meddra_class,target_concept_class,count( distinct s.meddra_code) as abs_meddra_code_count,round(count(distinct s.meddra_code)::numeric/(SELECT count(distinct meddra_code)::numeric FROM dev_vkorsik.meddra_rwd_mappings WHERE target__vocabulary='SNOMED')*100,2) as portion_of_total_meddra_codes
FROM  dev_vkorsik.meddra_rwd_mappings s
join DEVV5.CONCEPT C
ON S.meddra_code=c.concept_code
AND c.vocabulary_id='MedDRA'
WHERE target__vocabulary='SNOMED'
group by meddra_class,target_concept_class
ORDER BY meddra_class,portion_of_total_meddra_codes desc
;

SELECT  cc.concept_id,
       cc.concept_name as meddra_name,
       cc.domain_id as meddra_domain,
       cc.concept_code as meddra_code,
       c.concept_name as snomed_name,
       c.domain_id as snomed_domain,
       c.concept_class_id as  snomed_concept_class,
       c.concept_code as snomed_code
FROM dev_jnj.jj_general_custom_mapping s
JOIN devv5.concept c
ON s.target_concept_id=c.concept_id
JOIN devv5.concept cc
ON s.source_code=cc.concept_code
AND cc.vocabulary_id='MedDRA'
WHERE s.source_vocabulary_id IN ('JJ_MedDRA_maps_to',
'JJ_MedDRA_maps_to_value')
AND c.vocabulary_id='SNOMED'
AND cc.concept_code IN (
    '10000842',
'10000846',
'10000848',
'10000843',
'10021961',
'10021995',
'10061218',
'10002095',
'10024760',
'10002325',
'10024758',
'10024759',
'10001551',
'10018644',
'10040526',
'10001550',
'10001845',
'10055396',
'10014254',
'10014212',
'10037735',
'10002471',
'10055912',
'10048331',
'10037734',
'10014260',
'10000672',
'10002473',
'10002424',
'10020198',
'10079442',
'10055936',
'10002474',
'10002394',
'10054326',
'10003025',
'10061428',
'10054792',
'10002646',
'10003020'
    )
;
-- Non congruent mapping statistics
SELECT count (distinct s.referencedcomponentid) as and_meddra_codes,round(count (distinct s.referencedcomponentid)::numeric/3507*100,2)as portion_of_overlapped_codes_with_different_mappings
FROM dev_meddra.der2_srefset_meddratosnomedmap s
JOIN devv5.concept c
ON s.maptarget=c.concept_code
    AND c.vocabulary_id='SNOMED'
JOIN devv5.concept cc
ON s.referencedcomponentid::varchar=cc.concept_code
AND cc.vocabulary_id='MedDRA'
JOIN dev_jnj.jj_general_custom_mapping aa
ON aa.source_code=s.referencedcomponentid::varchar
JOIN devv5.concept c3
ON aa.target_concept_id=c3.concept_id
AND aa.source_vocabulary_id  IN ('JJ_MedDRA_maps_to',
'JJ_MedDRA_maps_to_value')
WHERE NOT EXISTS( SELECT 1
    FROM dev_jnj.jj_general_custom_mapping a
    JOIN dev_meddra.der2_srefset_meddratosnomedmap ss
    ON a.source_code=ss.referencedcomponentid::varchar
           WHERE s.referencedcomponentid=ss.referencedcomponentid
    AND c.concept_id=a.target_concept_id)
AND s.referencedcomponentid::varchar IN (SELECT source_code
    FROM dev_jnj.jj_general_custom_mapping a
    WHERE source_vocabulary_id  IN ('JJ_MedDRA_maps_to',
'JJ_MedDRA_maps_to_value') )
;

-- Breast cancer recurrent - redundant context
-- Non congruent mapping (RWD vs RefSet)
SELECT cc.concept_code as meddra_code, cc.concept_name as meddra_name, cc.domain_id as meddra_domain,
       c.concept_code as target_code,
       c.concept_name as target_name,
       c.concept_class_id as target_class,
       c.domain_id as target_domain,
       c3.concept_code as rwd_code,
       c3.concept_name as rwd_name,
       c3.vocabulary_id as rwd_vocabulary,
        c3.domain_id as rwd_domain,
        c3.concept_class_id as rwd_class
FROM dev_meddra.der2_srefset_meddratosnomedmap s
JOIN devv5.concept c
ON s.maptarget=c.concept_code
    AND c.vocabulary_id='SNOMED'
JOIN devv5.concept cc
ON s.referencedcomponentid::varchar=cc.concept_code
AND cc.vocabulary_id='MedDRA'
JOIN dev_jnj.jj_general_custom_mapping aa
ON aa.source_code=s.referencedcomponentid::varchar
JOIN devv5.concept c3
ON aa.target_concept_id=c3.concept_id
AND aa.source_vocabulary_id  IN ('JJ_MedDRA_maps_to',
'JJ_MedDRA_maps_to_value')
WHERE NOT EXISTS( SELECT 1
    FROM dev_jnj.jj_general_custom_mapping a
    JOIN dev_meddra.der2_srefset_meddratosnomedmap ss
    ON a.source_code=ss.referencedcomponentid::varchar
           WHERE s.referencedcomponentid=ss.referencedcomponentid
    AND c.concept_id=a.target_concept_id)
AND s.referencedcomponentid::varchar IN (SELECT source_code
    FROM dev_jnj.jj_general_custom_mapping a
    WHERE source_vocabulary_id  IN ('JJ_MedDRA_maps_to',
'JJ_MedDRA_maps_to_value') )
;

--  congruent mapping statistics
SELECT count (distinct s.meddra_code) as and_meddra_codes,round(count (distinct s.meddra_code)::numeric/(select count(distinct meddra_code) from combined_meddra_to_snomed_set WHERE meddra_code::varchar IN (SELECT aa.meddra_code
                               FROM dev_vkorsik.meddra_rwd_mappings aa))*100,2) as portion_of_overlapped_codes_with_same_mappings
FROM dev_vkorsik.combined_meddra_to_snomed_set s
JOIN dev_vkorsik.meddra_rwd_mappings aa
ON aa.meddra_code=s.meddra_code
WHERE  EXISTS(SELECT 1
              FROM dev_vkorsik.meddra_rwd_mappings a
                       JOIN dev_vkorsik.combined_meddra_to_snomed_set ss
                            ON a.meddra_code = ss.meddra_code
AND a.target_code=ss.snomed_code
AND a.target__vocabulary='SNOMED'
              WHERE s.meddra_code = ss.meddra_code
    )
AND s.meddra_code::varchar IN (SELECT aa.meddra_code
                               FROM dev_vkorsik.meddra_rwd_mappings aa
)
;
-- NON-CONGRUEN set
SELECT s.meddra_name,s.meddra_code,s.flag,s.snomed_code,s.snomed_name,s.snomed_class,
             aa.target_code,aa.target_name,aa.target_concept_class
FROM dev_vkorsik.combined_meddra_to_snomed_set s
JOIN dev_vkorsik.meddra_rwd_mappings aa
ON aa.meddra_code=s.meddra_code
WHERE  NOT EXISTS(SELECT 1
              FROM dev_vkorsik.meddra_rwd_mappings a
                       JOIN dev_vkorsik.combined_meddra_to_snomed_set ss
                            ON a.meddra_code = ss.meddra_code
AND a.target_code=ss.snomed_code
AND a.target__vocabulary='SNOMED'

              WHERE s.meddra_code = ss.meddra_code
    )
  AND s.meddra_code NOT IN   (SELECT meddra_code FROM meddra_rwd_mappings x group by 1 having count (distinct x.cdm_field)>1)
  AND aa.target__vocabulary='SNOMED'
AND s.meddra_code::varchar IN (SELECT aa.meddra_code
                               FROM dev_vkorsik.meddra_rwd_mappings aa
)
order by s.meddra_code
;

SELECT * FROM meddra_rwd_mappings

-- Non congruent mapping (RWD vs RefSet)
SELECT cc.concept_code as meddra_code, cc.concept_name as meddra_name, cc.domain_id as meddra_domain,
       c.concept_code as target_code,
       c.concept_name as target_name,
       c.concept_class_id as target_class,
       c.domain_id as target_domain,
       c3.concept_code as rwd_code,
       c3.concept_name as rwd_name,
       c3.vocabulary_id as rwd_vocabulary,
        c3.domain_id as rwd_domain,
        c3.concept_class_id as rwd_class
FROM dev_meddra.der2_srefset_meddratosnomedmap s
JOIN devv5.concept c
ON s.maptarget=c.concept_code
    AND c.vocabulary_id='SNOMED'
JOIN devv5.concept cc
ON s.referencedcomponentid::varchar=cc.concept_code
AND cc.vocabulary_id='MedDRA'
JOIN dev_jnj.jj_general_custom_mapping aa
ON aa.source_code=s.referencedcomponentid::varchar
JOIN devv5.concept c3
ON aa.target_concept_id=c3.concept_id
AND aa.source_vocabulary_id  IN ('JJ_MedDRA_maps_to',
'JJ_MedDRA_maps_to_value')
WHERE  EXISTS( SELECT 1
    FROM dev_jnj.jj_general_custom_mapping a
    JOIN dev_meddra.der2_srefset_meddratosnomedmap ss
    ON a.source_code=ss.referencedcomponentid::varchar
           WHERE s.referencedcomponentid=ss.referencedcomponentid
    AND c.concept_id=a.target_concept_id)
AND s.referencedcomponentid::varchar IN (SELECT source_code
    FROM dev_jnj.jj_general_custom_mapping a
    WHERE source_vocabulary_id  IN ('JJ_MedDRA_maps_to',
'JJ_MedDRA_maps_to_value') )
;


--to calculate coverage
-- 13509 - 7 invlad
with tab as(SELECT distinct meddra_code,snomed_code FROM combined_meddra_to_snomed_set WHERE (meddra_code, snomed_code) NOT IN (SELECT meddra_code,target_code from meddra_rwd_mappings WHERE target__vocabulary='SNOMED')
UNION ALL
SELECT distinct meddra_code,target_code from meddra_rwd_mappings)
SELECT distinct * from tab