
--ICDO3 /6 codes mappings to Cancer Modifier
--1st step
WITH getherd_mts_codes as (
     --aggregate the source
    SELECT DISTINCT concept_name, concept_code, tumor_site_code, vocabulary_id, source_flag
    FROM (SELECT distinct concept_name,
                          concept_code,
                          split_part(concept_code,'-',2) as tumor_site_code,
                          vocabulary_id,
                          'ICDO3' as source_flag
          FROM concept c
         WHERE c.vocabulary_id = 'ICDO3'
           and c.concept_class_id = 'ICDO Condition'
           and c.concept_code ILIKE '%/6%'

          UNION ALL

          select d.concept_name || ' of ' || c.concept_name,
                morphology_code || '-' || tumor_site_code,
                tumor_site_code,
                'ICDO3',
                'TrinetX'
          from dev_icdo3.trinetx t
                  join concept c on c.concept_code = tumor_site_code and c.vocabulary_id = 'ICDO3'
                  join concept d on d.concept_code = morphology_code and d.vocabulary_id = 'ICDO3'
          where morphology_code ILIKE '%/6%') as tab
)
, icd_to_localisation as (
    SELECT distinct
                    s.concept_name,
                    s.concept_code,
                    tumor_site_code,
                    s.vocabulary_id,
                    source_flag,
                    cc.concept_id as somed_id,
                    cc.concept_name as snomed_name ,
                    cc.vocabulary_id as snomed_voc,
                    cc.concept_code as snomed_code
    FROM getherd_mts_codes s
             LEFT JOIN  dev_cancer_modifier.concept c
                       ON s.tumor_site_code = c.concept_code
                           and c.concept_class_id = 'ICDO Topography'
             LEFT JOIN  dev_cancer_modifier.concept_relationship cr
                       ON c.concept_id = cr.concept_id_1
                           and cr.invalid_reason is null
                           and cr.relationship_id = 'Maps to'
             LEFT JOIN  dev_cancer_modifier.concept cc
                       on cr.concept_id_2 = cc.concept_id
                           and cr.invalid_reason is null
                           and cc.standard_concept = 'S'

    WHERE s.concept_code IN (
        SELECT concept_code
        FROM getherd_mts_codes
        group by 1
        having count(distinct source_flag) =1
    )
),
res as (
SELECT distinct i.*,
                ct.concept_id as cm_id,
                ct.concept_name as cm_name,
                ct.vocabulary_id as  cm_voc,
                ct.concept_code as  cm_code
FROM icd_to_localisation i
LEFT JOIN dev_cancer_modifier.concept_relationship crs
ON i.somed_id = crs.concept_id_2
    and crs.relationship_id ='Has finding site'
LEFT JOIN concept  ct
ON ct.concept_id = crs.concept_id_1
    and ct.vocabulary_id='Cancer Modifier')
,
     resulted_mapping_of_slash6 as (
         SELECT *
         FROM RES
         where concept_code IN (SELECT concept_code from res group by 1 having count(distinct cm_id) > 1)
           and cm_name not ilike '% and %'
           and cm_name not ilike '% other %'
           and cm_name not ilike '% same %'
           and cm_name not ilike '% Ipsilateral %'
           and cm_name not ilike '%Pleural Effusion%'
           and cm_name not ilike '%Blood Vessel%'
           and cm_name not ilike '% leg%'
           and cm_name not ilike '% arm%'
           and cm_id <> 36770544 -- OMOP5000224	Cancer Modifier
         and cm_id <> 35225721	--OMOP5031913	Cancer Modifier




         UNION ALL

         SELECT *
         FROM RES
         where concept_code IN (SELECT concept_code from res group by 1 having count(distinct cm_id) = 1)
     )
--ICDO3 maps to
/*INSERT INTO concept_relationship_stage (
                                        concept_id_1,
                                        concept_code_1,
                                        vocabulary_id_1,
                                        concept_id_2,
                                        concept_code_2 ,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason

)*/

SELECT
c.concept_id,
       s.concept_code,
       s.vocabulary_id,
       cm_id,
            cm_code,
       cm_voc,
          'Maps to' as relationship_id,
                CURRENT_DATE,
                TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
                null as invalid_reason
FROM resulted_mapping_of_slash6 s
LEFT JOIN  dev_cancer_modifier.concept  c
on c.concept_code=s.concept_code
and c.vocabulary_id=s.vocabulary_id

UNION ALL

SELECT cc.concept_id,
      g.concept_code,g.vocabulary_id,
       cs.concept_id  as cm_id,
              cs.concept_code,
       cs.vocabulary_id,
          'Maps to' as relationship_id,
                CURRENT_DATE,
                TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
                null as invalid_reason
FROM getherd_mts_codes g
JOIN dev_cancer_modifier.concept c
ON split_part(g.tumor_site_code,'.',1) =c.concept_code
and c.concept_class_id ='ICDO Topography'
JOIN concept_stage cs
ON lower('metastasis to ' || regexp_replace(c.concept_name,'\, NOS','','gi'))=lower(cs.concept_name)
LEFT JOIN dev_cancer_modifier.concept  cc
on cc.concept_code=g.concept_code
and c.vocabulary_id=g.vocabulary_id
WHERE g.concept_code NOT IN (
    select concept_code from resulted_mapping_of_slash6
    )
and tumor_site_code <>'NULL'

;


--Step2
WITH getherd_mts_codes as (
     --agragate the scource
    SELECT DISTINCT concept_name, concept_code, tumor_site_code, vocabulary_id, source_flag
    FROM (SELECT distinct concept_name,
                          concept_code,
                          split_part(concept_code,'-',2) as tumor_site_code,
                          vocabulary_id,
                          'ICDO3' as source_flag
          FROM concept c
         WHERE c.vocabulary_id = 'ICDO3'
           and c.concept_class_id = 'ICDO Condition'
           and c.concept_code ILIKE '%/6%'

          UNION ALL

          select d.concept_name || ' of ' || c.concept_name,
                morphology_code || '-' || tumor_site_code,
                tumor_site_code,
                'ICDO3',
                'TrinetX'
          from dev_icdo3.trinetx t
                  join concept c on c.concept_code = tumor_site_code and c.vocabulary_id = 'ICDO3'
                  join concept d on d.concept_code = morphology_code and d.vocabulary_id = 'ICDO3'
          where morphology_code ILIKE '%/6%') as tab
)
--ICDO3 maps to
/*INSERT INTO concept_relationship_stage (
                                        concept_id_1,
                                        concept_code_1,
                                        vocabulary_id_1,
                                        concept_id_2,
                                        concept_code_2 ,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason

)*/

SELECT cc.concept_id,

      s.concept_code,s.vocabulary_id,
       cs.concept_id_2  as cm_id,
              cs.concept_code_2,
       cs.vocabulary_id_2,
          'Maps to' as relationship_id,
                CURRENT_DATE,
                TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
                null as invalid_reason
FROM getherd_mts_codes s
JOIN concept_relationship_stage cs
on '8000/6-'||split_part(s.tumor_site_code,'.',1)||'.9' = cs.concept_code_1
and cs.vocabulary_id_1='ICDO3'
LEFT JOIN concept cc
on cc.concept_code=s.concept_code
and cc.vocabulary_id=s.vocabulary_id
WHERE s.concept_code NOT IN (
SELECT concept_code_1
FROM concept_relationship_stage)
and tumor_site_code<>'NULL'
;
WITH getherd_mts_codes as (
     --agragate the scource
    SELECT DISTINCT concept_name, concept_code, tumor_site_code, vocabulary_id, source_flag
    FROM (SELECT distinct concept_name,
                          concept_code,
                          split_part(concept_code,'-',2) as tumor_site_code,
                          vocabulary_id,
                          'ICDO3' as source_flag
          FROM concept c
         WHERE c.vocabulary_id = 'ICDO3'
           and c.concept_class_id = 'ICDO Condition'
           and c.concept_code ILIKE '%/6%'

          UNION ALL

          select d.concept_name || ' of ' || c.concept_name,
                morphology_code || '-' || tumor_site_code,
                tumor_site_code,
                'ICDO3',
                'TrinetX'
          from dev_icdo3.trinetx t
                  join concept c on c.concept_code = tumor_site_code and c.vocabulary_id = 'ICDO3'
                  join concept d on d.concept_code = morphology_code and d.vocabulary_id = 'ICDO3'
          where morphology_code ILIKE '%/6%') as tab
)
SELECT *
FROM getherd_mts_codes s
WHERE s.concept_code NOT IN (
SELECT concept_code_1
FROM concept_relationship_stage)
;