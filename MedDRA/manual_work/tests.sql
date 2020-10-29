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

SELECT distinct  * FROM
dev_vkorsik.combined_meddra_to_snomed_set
WHERE meddra_code NOT IN (SELECT referencedcomponentid::varchar from dev_meddra.der2_srefset_meddratosnomedmap
    UNION ALL
    SELECT maptarget::varchar from dev_meddra.der2_srefset_snomedtomeddramap)

--MeddraToSnomed statistics
--Number of meddra codes in devv5 schema=105787
SELECT count(distinct concept_code)
FROM devv5.concept c
WHERE vocabulary_id='MedDRA'
;
-- MedDRA codes distribution by classes in dev schema
SELECT domain_id,concept_class_id,count(distinct concept_code) as abs_count,round(count(distinct concept_code)::numeric/105787*100,3)as portion_of_codes
FROM devv5.concept c
WHERE vocabulary_id='MedDRA'
group by 1,2
order by 1,2,3 desc
;
-- Number of codes used in RWD =8294
SELECT count (distinct source_code)
FROM dev_jnj.jj_general_custom_mapping s
WHERE s.source_vocabulary_id='JJ_MedDRA_maps_to'

-- MedDRA codes distribution by classes in RWD
SELECT c.domain_id,c.concept_class_id,count(distinct source_code) as abs_count,round(count( distinct s.source_code)::numeric/8294*100,3)as portion_of_total_meddra_codes
FROM dev_jnj.jj_general_custom_mapping s
JOIN devv5.concept c
ON s.source_code=c.concept_code
AND c.vocabulary_id='MedDRA'
WHERE s.source_vocabulary_id='JJ_MedDRA_maps_to'
group by 1,2
order by 1,2,3 desc
;

--Number of meddra codes in refset = 6861
Select count(distinct meddra_code)
from dev_vkorsik.combined_meddra_to_snomed_set
;
--MedDRA codes distribution by classes in refset
SELECT  c.domain_id,c.concept_class_id,count(distinct c.concept_code) as abs_count,round(count(distinct c.concept_code)::numeric/6861*100,3) as portion_of_codes
FROM dev_vkorsik.combined_meddra_to_snomed_set s
JOIN devv5.concept c
ON s.meddra_code::varchar=c.concept_code
AND c.vocabulary_id='MedDRA'
group by 1,2
order by 1,2,3 desc
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
SELECT count(distinct meddra_code) as non_in_real_world_data_abs_count, round(count(distinct s.meddra_code)::numeric/6861*100,3) as portion_of_codes
FROM dev_vkorsik.combined_meddra_to_snomed_set s
WHERE  meddra_code::varchar NOT  IN (   SELECT DISTINCT source_code
    FROM dev_jnj.jj_general_custom_mapping  s
    WHERE s.source_vocabulary_id IN ('JJ_MedDRA_maps_to',
'JJ_MedDRA_maps_to_value')
)
;
-- Conclusion 1 - The refset looks representative if compare with RWD and General OMOPed meddra

--What is a number of codes with 1 to many mappings (aka postcoordianted) in RefSet?
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
    FROM dev_jnj.jj_general_custom_mapping  s
    WHERE s.source_vocabulary_id IN ('JJ_MedDRA_maps_to',
'JJ_MedDRA_maps_to_value')
)

SELECT count(distinct source_code)
FROM tab
WHERE source_code in (

    SELECT source_code
    FROM tab
    GROUP BY source_code
    HAVING count (*) > 1)
;

--all other 1-to-many mappings
-- 1 Maps to only
---- 460  1 to many Only codes
with tab as (
      SELECT DISTINCT s.*
    FROM dev_jnj.jj_general_custom_mapping  s
    WHERE s.source_vocabulary_id IN ('JJ_MedDRA_maps_to',
'JJ_MedDRA_maps_to_value')
)

SELECT count(distinct source_code)
FROM tab
WHERE source_code IN (
    SELECT source_code
    FROM tab
    GROUP BY source_code
    HAVING count(*) > 1)

    AND source_code NOT IN (
        SELECT source_code
        FROM tab t
        WHERE source_code in (
                SELECT source_code
                FROM tab
                GROUP BY source_code
                HAVING count(*)>1
        )
            AND EXISTS(SELECT 1
                       FROM tab b
                       WHERE t.source_code = b.source_code
                         AND b.source_vocabulary_id ~* 'value|modifier|qualifier|unit')
    )
;

--654/(1236-460) are 1var+1val
--1 maps_to mapping and 1 maps_to_value/unit/modifier/qualifier mapping
WITH tab AS (
    SELECT DISTINCT s.*
    FROM dev_jnj.jj_general_custom_mapping  s
    WHERE s.source_vocabulary_id IN ('JJ_MedDRA_maps_to',
'JJ_MedDRA_maps_to_value')
)

SELECT count(distinct source_code)
FROM tab t
WHERE source_code in (
        SELECT source_code
        FROM tab
        GROUP BY source_code
        HAVING count(*) =2
)
    AND EXISTS(SELECT 1
               FROM tab b
               WHERE t.source_code = b.source_code
                 AND b.source_vocabulary_id ~* 'value|modifier|qualifier|unit')
;

-- How often does Refset provide mapping of 1 SNOMED CODE to differnet meddra?
-- 1310 SNOMED for 3994 Meddras
SELECT  c.domain_id,c.concept_class_id,c.concept_name,count(s.referencedcomponentid) as number_of_meddra_codes
FROM dev_meddra.der2_srefset_meddratosnomedmap s
JOIN devv5.concept c
ON s.maptarget=c.concept_code
AND c.vocabulary_id='SNOMED'
WHERE maptarget IN (
    SELECT maptarget
FROM dev_meddra.der2_srefset_meddratosnomedmap
    GROUP BY 1 having count(distinct referencedcomponentid)>1)
GROUP BY c.domain_id,c.concept_class_id,c.concept_name
order by number_of_meddra_codes desc
limit 400;

-- An example of Usage of 1 SNOMED  Code to cover  different MedDRA codes
-- Look at Switch From Measurement to Condition for ALT
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
SELECT cc.domain_id as meddra_domain, c.domain_id as target_domain,c.concept_class_id as target_concept_class,count( s.referencedcomponentid) as abs_meddra_code_count,round(count( s.referencedcomponentid)::numeric/6861*100,3)as portion_of_total_meddra_codes
FROM dev_meddra.der2_srefset_meddratosnomedmap s
JOIN devv5.concept c
ON s.maptarget::varchar=c.concept_code
AND c.vocabulary_id='SNOMED'
JOIN devv5.concept cc
ON s.referencedcomponentid::varchar=cc.concept_code
AND cc.vocabulary_id='MedDRA'
group by cc.domain_id,c.domain_id,c.concept_class_id
ORDER BY cc.domain_id,c.domain_id,c.concept_class_id,portion_of_total_meddra_codes desc
;

-- domain switch-
SELECT  cc.domain_id,cc.concept_code,cc.concept_name,c.concept_id as targtet_id, c.concept_code as targtet_code, c.concept_name as target_name,c.domain_id as target_domain
FROM dev_meddra.der2_srefset_meddratosnomedmap s
JOIN devv5.concept c
ON s.maptarget::varchar=c.concept_code
AND c.vocabulary_id='SNOMED'
JOIN devv5.concept cc
ON cc.concept_code=s.referencedcomponentid::varchar
AND cc.vocabulary_id='MedDRA'
--AND cc.domain_id<>'Condition'
WHERE cc.domain_id<>c.domain_id
ORDER BY random(),cc.concept_code
LIMIT 100
;
-- RWD TO SNOMED mapping statistics 
SELECT   cc.domain_id as meddra_domain,s.source_vocabulary_id, c.domain_id as target_domain,c.concept_class_id as target_concept_class,count( distinct s.source_code) as abs_meddra_code_count
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
SELECT count (distinct s.referencedcomponentid) as and_meddra_codes,round(count (distinct s.referencedcomponentid)::numeric/3507*100,2)as portion_of_overlapped_codes_with_same_mappings
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



