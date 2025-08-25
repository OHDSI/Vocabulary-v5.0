-- DDL:
--DROP TABLE concept_relationship_metadata;
TRUNCATE concept_relationship_metadata;
CREATE TABLE concept_relationship_metadata (
concept_id_1 int NOT NULL,
concept_id_2 int NOT NULL,
relationship_id varchar(20) NOT NULL,
relationship_predicate_id VARCHAR(20),
relationship_group INT,
mapping_source VARCHAR(50),
confidence FLOAT,
mapping_tool VARCHAR(50),
mapper VARCHAR(50),
reviewer VARCHAR(50),
FOREIGN KEY (concept_id_1, concept_id_2, relationship_id)
REFERENCES concept_relationship (concept_id_1, concept_id_2, relationship_id),
CONSTRAINT chk_relationship_predicate_id
CHECK (relationship_predicate_id IN ('narrowMatch','exactMatch','broadMatch','eq', 'up', 'down')),
CONSTRAINT xpk_concept_relationship_metadata
UNIQUE (concept_id_1,concept_id_2,relationship_id, relationship_predicate_id, mapping_source, confidence, mapping_tool, mapper, reviewer)
);


--Community contribution
INSERT INTO concept_relationship_metadata
SELECT DISTINCT cr.concept_id_1 as concept_id_1,
       cr.concept_id_2 as concept_id_2,
       cr.relationship_id as relationship_id,
  predicate_id as relationship_predicate_id,
       null::int as relationship_group,
     CASE WHEN   cc.mapping_source ~* 'manual|new snomed' then NULL
         WHEN   cc.mapping_source ~* 'OMOP|OHDSI' then 'OHDSI'
         ELSE cc.mapping_source end as mapping_source,
       cc.confidence as confidence,
          CASE WHEN   cc.mapping_source ~* 'manual|new snomed' then 'MM_C'
         WHEN   cc.mapping_source ~* 'OMOP|OHDSI' then 'AM-lib_C'
         ELSE cc.mapping_tool end as  mapping_tool,
       null as mapper,
       null as reviewer
FROM dev_voc_metadata.cc_mapping cc
JOIN devv5.concept c ON (cc.concept_code_1, cc.vocabulary_id_1) = (c.concept_code, c.vocabulary_id)
JOIN devv5.concept c1 ON (cc.concept_code_2, cc.vocabulary_id_2) = (c1.concept_code, c1.vocabulary_id)
JOIN devv5.concept_relationship cr ON (c.concept_id, c1.concept_id, cc.relationship_id) = (cr.concept_id_1, cr.concept_id_2, cr.relationship_id)
WHERE cr.invalid_reason is null;

UPDATE  concept_relationship_metadata
    SEt mapping_tool='MM_U'
where mapping_tool IN (
'exactMatch',
'Atlas, Databricks, and human',
'Athena'
    );


--ICDs
INSERT INTO concept_relationship_metadata (concept_id_1, concept_id_2, relationship_id, relationship_predicate_id, relationship_group, mapping_source, confidence, mapping_tool, mapper, reviewer)
SELECT concept_id_1,
       concept_id_2,
       relationship_id,
       relationship_predicate_id[array_length(relationship_predicate_id,1)],
       relationship_group::int,
     CASE WHEN  'manual' = ANY(mapping_source)  and  'UMLS/NCIm' != all(mapping_source) then NULL
          WHEN  array_length(mapping_source,1)>1  and  'UMLS/NCIm' = ANY(mapping_source) then 'OHDSI+UMLS/NCIm'
          ELSE 'OHDSI' end as mapping_source,
       confidence::float,
         CASE WHEN  'manual' = ANY(mapping_source)  and  'UMLS/NCIm' != all(mapping_source)  then 'MM_C'
            else 'AM-lib_C' end as mapping_tool,
       mapper[array_length(mapper,1)],
       reviewer[array_length(reviewer,1)]
FROM
            (
SELECT cr.concept_id_1 as concept_id_1,
       cr.concept_id_2 as concept_id_2,
       cr.relationship_id as relationship_id,
      array_remove((array_agg (DISTINCT CASE WHEN length(trim(p.relationship_id_predicate))=0 then null
          when lower(trim(p.relationship_id_predicate))='eq' then 'exactMatch'
           when lower(trim(p.relationship_id_predicate))='up' then 'broadMatch'
           when lower(trim(p.relationship_id_predicate))='down' then 'narrowMatch'
          else p.relationship_id_predicate end)),NULL) as relationship_predicate_id,
       NULL::int as relationship_group,
       array_remove( (array_agg (DISTINCT s.mappings_origin)),NULL) as mapping_source,
       NULL::float as confidence,
       NULL as mapping_tool,
      array_remove((array_agg (distinct replace(p.mapper,'Mapper: ',''))),NULL)  as mapper,
      array_remove((array_agg (distinct replace(p.reviewer,'Reviewer: ',''))),NULL)  as reviewer
FROM devv5.concept_relationship cr
JOIN devv5.concept c ON cr.concept_id_1 = c.concept_id
JOIN dev_icd10.icd_cde_proc p ON p.source_code = c.concept_code AND p.source_vocabulary_id = c.vocabulary_id
LEFT JOIN dev_icd10.icd_cde_source s ON p.source_code = s.source_code AND p.source_vocabulary_id = s.source_vocabulary_id
WHERE cr.relationship_id IN ('Maps to', 'Maps to value')
  AND (cr.concept_id_1, cr.concept_id_2, cr.relationship_id) NOT IN (SELECT concept_id_1, concept_id_2, relationship_id FROM concept_relationship_metadata)
AND cr.invalid_reason IS NULL
GROUP BY cr.concept_id_1,
         cr.concept_id_2,
         cr.relationship_id) As tab
;


--SNOMED
INSERT INTO concept_relationship_metadata
SELECT cr.concept_id_1 as concept_id_1,
       cr.concept_id_2 as concept_id_2,
       cr.relationship_id as relationship_id,
       CASE WHEN length(trim(m.relationship_id_predicate))=0 then null
          when lower(trim(m.relationship_id_predicate))='eq' then 'exactMatch'
           when lower(trim(m.relationship_id_predicate))='up' then 'broadMatch'
           when lower(trim(m.relationship_id_predicate))='down' then 'narrowMatch'
          else m.relationship_id_predicate end as relationship_predicate_id,
       null as relationship_group,
       m.mapping_source as mapping_source,
       m.confidence::float as confidence,
       m.mapping_tool as mapping_tool,
       m.mapper_id as mapper,
      CASE WHEN  m.reviewer_id = 'N/A' then NULL else  m.reviewer_id END as reviewer
FROM dev_snomed.snomed_mapped m
JOIN devv5.concept c on (m.source_code, m.source_vocabulary_id) = (c.concept_code, c.vocabulary_id)
JOIN devv5.concept c1 on (m.target_concept_code, m.target_vocabulary_id) = (c1.concept_code, c1.vocabulary_id)
JOIN devv5.concept_relationship cr on (c.concept_id, c1.concept_id, m.relationship_id) = (cr.concept_id_1, cr.concept_id_2, cr.relationship_id)
WHERE cr.relationship_id IN ('Maps to', 'Maps to value')
    AND (cr.concept_id_1, cr.concept_id_2, cr.relationship_id) NOT IN (SELECT concept_id_1, concept_id_2, relationship_id FROM concept_relationship_metadata)
AND cr.invalid_reason IS NULL
AND m.cr_invalid_reason is null
AND m.relationship_id_predicate IS NOT NULL;


--CDISC
INSERT INTO concept_relationship_metadata (concept_id_1, concept_id_2, relationship_id, relationship_predicate_id, relationship_group, mapping_source, confidence, mapping_tool, mapper, reviewer)
SELECT DISTINCT
       concept_id_1,
       concept_id_2,
       relationship_id,
       relationship_predicate_id,
       relationship_group,
    (array_agg( DISTINCT mapping_source))[1] as mapping_source,
       confidence,
       mapping_tool,
       mapper,
       reviewer
FROM (SELECT DISTINCT c.concept_id     AS concept_id_1,
                      c.concept_code   AS concept_code_1,
                      c.vocabulary_id  AS vocabulary_id_1,
                      c.concept_name   AS concept_name_1,
                      cr.relationship_id,
                      cc.concept_id    AS concept_id_2,
                      cc.concept_code  AS concept_code_2,
                      cc.vocabulary_id AS vocabulary_id_2,
                      cc.concept_name  AS concept_name_2,
                      REPLACE(SPLIT_PART(a.mapping_source[1], '-', 1), 'Auto', 'AM-lib') || '_U' AS mapping_tool,
                      NULL as mapper,
                      NULL as reviewer,
                      NULL::float as confidence,
                      REPLACE(SPLIT_PART(a.mapping_source[1], '-', 2), 'OMOP', 'OHDSI')         AS mapping_source,
                     NULL::int as relationship_group,
                     CASE WHEN length(trim(a.relationship_id_predicate))=0 then null
          when lower(trim(a.relationship_id_predicate))='eq' then 'exactMatch'
           when lower(trim(a.relationship_id_predicate))='up' then 'broadMatch'
           when lower(trim(a.relationship_id_predicate))='down' then 'narrowMatch'
          else a.relationship_id_predicate end as  relationship_predicate_id
      FROM dev_cdisc.cdisc_automapped a
               JOIN devv5.concept c
                    ON c.concept_code = a.concept_code
                        AND c.vocabulary_id = 'CDISC'
             JOIN devv5.concept_relationship cr
                    ON c.concept_id = cr.concept_id_1
                        AND cr.relationship_id in ('Maps to','Maps to value')
          and cr.invalid_reason IS NULL
             JOIN devv5.concept cc
      on cc.concept_id=cr.concept_id_2
      and cc.concept_code=a.target_concept_code
      and cc.vocabulary_id=a.target_vocabulary_id
      and a.relationship_id=cr.relationship_id
      where c.concept_code NOT IN (SELECT concept_code from dev_cdisc.cdisc_mapped)

UNION ALL

      SELECT DISTINCT c.concept_id as concept_id_1,c.concept_code as concept_code_1,c.vocabulary_id as vocabulary_id_1,c.concept_name as concept_name_1,cr.relationship_id,cc.concept_id as concept_id_2,cc.concept_code as concept_code_2,cc.vocabulary_id as vocabulary_id_2,cc.concept_name as concept_name_2,
                      REPLACE(SPLIT_PART(a.mapping_source[1], '-', 1), 'manual', 'MM') || '_C' AS mapping_tool,
                      a.mapper,
                      a.reviewer,
                      coalesce(a.confidence,0.5) as confidence,
                     NULL AS mapping_source,
                     NULL::int as relationship_group,
                     CASE WHEN length(trim(a.relationship_predicate_id))=0 then null
          when lower(trim(a.relationship_predicate_id))='eq' then 'exactMatch'
           when lower(trim(a.relationship_predicate_id))='up' then 'broadMatch'
           when lower(trim(a.relationship_predicate_id))='down' then 'narrowMatch'
          else a.relationship_predicate_id end as  relationship_predicate_id
      FROM dev_cdisc.cdisc_mapped a
               JOIN devv5.concept c
                    ON c.concept_code = a.concept_code
                        AND c.vocabulary_id = 'CDISC'
                JOIN devv5.concept_relationship cr
                    ON c.concept_id = cr.concept_id_1
                        AND cr.relationship_id in ('Maps to','Maps to value')
          and cr.invalid_reason IS NULL
             JOIN devv5.concept cc
      on cc.concept_id=cr.concept_id_2
      and cc.concept_code=a.target_concept_code
      and cc.vocabulary_id=a.target_vocabulary_id
      and a.relationship_id=cr.relationship_id
      )
    AS cdisc_concept_relationship_meta_bypass
WHERE (concept_id_1,relationship_id,concept_id_2) NOT IN (SELECT  c.concept_id_1,c.relationship_id,c.concept_id_2 FROM concept_relationship_metadata as c)
GROUP BY concept_id_1,
       concept_id_2,
       relationship_id,
       relationship_predicate_id,
       relationship_group,confidence,
       mapping_tool,
       mapper,
       reviewer
ORDER BY concept_id_1,relationship_id,concept_id_2
;


--MedDRA
INSERT INTO concept_relationship_metadata (concept_id_1, concept_id_2, relationship_id, relationship_predicate_id, relationship_group, mapping_source, confidence, mapping_tool, mapper, reviewer)
with tab_array as(
SELECT concept_id_1,
       concept_id_2,
       relationship_id,
       array_agg(trim(relationship_predicate_id)) as relationship_predicate_id,
       NULL as relationship_group,
      array_agg(trim(mapping_source))  as mapping_source  ,
       array_agg(trim(confidence))  as confidence,
     array_agg(trim(mapping_tool))  as mapping_tool  ,
          array_agg(trim(mapper))  as mapper  ,
        array_agg(trim(reviewer))  as reviewer
FROM (SELECT DISTINCT c.concept_id as concept_id_1,c.concept_code as concept_code_1,c.vocabulary_id as vocabulary_id_1,c.concept_name as concept_name_1,cr.relationship_id,cc.concept_id as concept_id_2,cc.concept_code as concept_code_2,cc.vocabulary_id as vocabulary_id_2,cc.concept_name as concept_name_2,
                   CASE WHEN lower(trim(origin_of_mapping)) IN ('manual','meddra_mapped') then 'MM_C'
                        WHEN lower(trim(origin_of_mapping))='python' then 'AM-tool_C'
                        WHEN lower(trim(origin_of_mapping))='chatgpt' then 'AM-tool_C'
                        WHEN lower(trim(origin_of_mapping))='python+chatgpt' then 'AM-tool_C'
                       else 'AM-lib_C' end AS mapping_tool,
                     CASE WHEN length(trim(a.mapper_id))=0  then NULL
                         WHEN trim(a.mapper_id) ='DB'  then 'dmitry.buralkin@odysseusinc.com'
                         WHEN trim(a.mapper_id) = 'MS'  then 'mikita.salavei@odysseusinc.com'
                         WHEN trim(a.mapper_id) = 'EP'  then 'yauheni.paulenkovich@odysseusinc.com'
                         WHEN trim(a.mapper_id) ='JC'  then 'janice.cruz@odysseusinc.com'
                         WHEN trim(a.mapper_id) = 'VK'  then 'vlad.korsik@odysseusinc.com'
                         WHEN trim(a.mapper_id) = 'OZ' or a.mapper_id ilike '%zhuk%'   then 'oleg.zhuk@odysseusinc.com'
                         WHEN trim(a.mapper_id) = 'OT'  then 'tetiana.orlova@odysseusinc.com'
                         WHEN trim(a.mapper_id) = 'YK'  then 'yuri.korin@odysseusinc.com'
                                 else replace(a.mapper_id,'Mapper: ','') END  as mapper,
                       CASE WHEN length(trim(coalesce(a.reviewer_id,'')))=0 then 'vocabulary team'
                           WHEN a.reviewer_id like 'Value:%'  OR a.reviewer_id like '%mikita.salavei@odysseusinc.com' OR a.reviewer_id = 'MS' then 'mikita.salavei@odysseusinc.com'
                           WHEN a.reviewer_id ='VK' then 'vlad.korsik@odysseusinc.com'
                           else  replace(a.reviewer_id,'Reviewer: ','') END   as reviewer,
                      null as confidence,
                   CASE WHEN lower(trim(origin_of_mapping))='python' then 'NLP'
                        WHEN lower(trim(origin_of_mapping))='chatgpt' then 'LLM'
                        WHEN lower(trim(origin_of_mapping))='python+chatgpt' then 'NLP+LLM'
                        WHEN lower(trim(origin_of_mapping)) ~*'man|meddra_mapped|maual' then NULL
                        WHEN lower(trim(origin_of_mapping)) ~*'MedDRA-SNOMED eq' then 'OHDSI'
                       ELSE  UPPER(trim(replace(trim(replace(replace(a.origin_of_mapping,'meddra_mapped','OHDSI'),' ','')),',','+')))   END  AS mapping_source,
                     NULL::int  as relationship_group,
                        CASE WHEN lower(trim(a.relationship_id_predicate)) in ('downhill','down') then 'narrowMatch'
                             WHEN lower(trim(a.relationship_id_predicate)) in ('uphill','up') then 'broadMatch'
                                 WHEN lower(trim(a.relationship_id_predicate)) in ('eq') then 'exactMatch' else a.relationship_id_predicate END as relationship_predicate_id
      FROM dev_meddra.meddra_environment a
               JOIN devv5.concept c
                    ON c.concept_code = a.source_code
                        AND c.vocabulary_id = 'MedDRA'
             JOIN devv5.concept_relationship cr
                    ON c.concept_id = cr.concept_id_1
                        AND cr.relationship_id in ('Maps to','Maps to value')
          and cr.invalid_reason IS NULL
             JOIN devv5.concept cc
      on cc.concept_id=cr.concept_id_2
      and cc.concept_code=a.target_concept_code
      and cc.vocabulary_id=a.target_vocabulary_id
      and a.relationship_id=cr.relationship_id
      where a.decision='1'

      )
    AS meddra_concept_relationship_meta_bypass
GROUP BY   concept_id_1,
       concept_id_2,
       relationship_id )
SELECT DISTINCT concept_id_1,
                concept_id_2,
                relationship_id,
               ( relationship_predicate_id )[ARRAY_LENGTH(s.relationship_predicate_id, 1)] as relationship_predicate_id ,
                NULL::int as relationship_group,
             (mapping_source)[ARRAY_LENGTH(s.mapping_source, 1)] as    mapping_source,
                (confidence)[ARRAY_LENGTH(s.confidence, 1)]::float as     confidence,
                 (mapping_tool)[ARRAY_LENGTH(s.mapping_tool, 1)] as     mapping_tool,
                  (mapper)[ARRAY_LENGTH(s.mapper, 1)] as     mapper,
                (reviewer)[ARRAY_LENGTH(s.reviewer, 1)] as     reviewer
FROM tab_array s
ORDER BY concept_id_1,relationship_id,concept_id_2
;

UPDATE concept_relationship_metadata
SET mapping_source = replace(mapping_source,'MEDDRA-ICD10-SNOMED','RefSet:MedDRA-ICD10+OHDSI')
WHERE mapping_source like '%MEDDRA-ICD10-SNOMED%';

UPDATE concept_relationship_metadata
SET mapping_source = replace(replace(mapping_source,'MEDDRA_SNOMED','RefSet:MEDDRA_SNOMED'),'SNOMED_MEDDRA','RefSet:SNOMED_MEDDRA')
WHERE mapping_source like '%MEDDRA_SNOMED+SNOMED_MEDDRA%';


-- CPT4:
INSERT INTO concept_relationship_metadata
SELECT cr.concept_id_1 as concept_id_1,
       cr.concept_id_2 as concept_id_2,
       cr.relationship_id as relationship_id,
     CASE WHEN length(trim(m.relationship_id_predicate))=0 then null
          when lower(trim(m.relationship_id_predicate))='eq' then 'exactMatch'
           when lower(trim(m.relationship_id_predicate))='up' then 'broadMatch'
           when lower(trim(m.relationship_id_predicate))='down' then 'narrowMatch'
          else m.relationship_id_predicate end as relationship_predicate_id,
       null as relationship_group,
       CASE WHEN m.mapping_source = 'manual mapping' then NULL else m.mapping_source end as mapping_source,
       m.confidence::float as confidence,
     CASE WHEN m.mapping_source = 'manual mapping' and m.mapping_source !~* 'UMLS|NCIm|OMOP|OHDSI'  then 'MM_C'
         WHEN m.mapping_source ~* 'UMLS|NCIm|OMOP|OHDSI' then 'AM-lib_C'
         else m.mapping_tool end  as mapping_tool,
       m.mapper_id as mapper,
       m.reviewer_id as reviewer
FROM dev_cpt4.cpt4_mapped m
JOIN devv5.concept c on (m.source_code, m.source_vocabulary_id) = (c.concept_code, c.vocabulary_id)
JOIN devv5.concept c1 on (m.target_concept_code, m.target_vocabulary_id) = (c1.concept_code, c1.vocabulary_id)
JOIN devv5.concept_relationship cr on (c.concept_id, c1.concept_id, m.relationship_id) = (cr.concept_id_1, cr.concept_id_2, cr.relationship_id)
WHERE cr.relationship_id IN ('Maps to', 'Maps to value')
      AND (cr.concept_id_1, cr.concept_id_2, cr.relationship_id) NOT IN (SELECT concept_id_1, concept_id_2, relationship_id FROM concept_relationship_metadata)
AND cr.invalid_reason IS NULL
AND m.cr_invalid_reason is null
AND m.relationship_id_predicate IS NOT NULL;

-- HCPCS:
INSERT INTO concept_relationship_metadata
SELECT cr.concept_id_1 as concept_id_1,
       cr.concept_id_2 as concept_id_2,
       cr.relationship_id as relationship_id,
      CASE WHEN length(trim(m.relationship_id_predicate))=0 then null
          when lower(trim(m.relationship_id_predicate))='eq' then 'exactMatch'
           when lower(trim(m.relationship_id_predicate))='up' then 'broadMatch'
           when lower(trim(m.relationship_id_predicate))='down' then 'narrowMatch'
          else m.relationship_id_predicate end as relationship_predicate_id,
       null as relationship_group,
      CASE WHEN m.mapping_source = 'manual mapping' then NULL else m.mapping_source end as mapping_source,
       m.confidence::float as confidence,
     CASE WHEN m.mapping_source = 'manual mapping' and m.mapping_source !~* 'UMLS|NCIm|OMOP|OHDSI'  then 'MM_C'
         WHEN m.mapping_source ~* 'UMLS|NCIm|OMOP|OHDSI' then 'AM-lib_C'
         else m.mapping_tool end  as mapping_tool,
       m.mapper_id as mapper,
       m.reviewer_id as reviewer
FROM dev_hcpcs.hcpcs_mapped m
JOIN devv5.concept c on (m.source_code, m.source_vocabulary_id) = (c.concept_code, c.vocabulary_id)
JOIN devv5.concept c1 on (m.target_concept_code, m.target_vocabulary_id) = (c1.concept_code, c1.vocabulary_id)
JOIN devv5.concept_relationship cr on (c.concept_id, c1.concept_id, m.relationship_id) = (cr.concept_id_1, cr.concept_id_2, cr.relationship_id)
WHERE cr.relationship_id IN ('Maps to', 'Maps to value')
      AND (cr.concept_id_1, cr.concept_id_2, cr.relationship_id) NOT IN (SELECT concept_id_1, concept_id_2, relationship_id FROM concept_relationship_metadata)
AND cr.invalid_reason IS NULL
AND m.cr_invalid_reason is null
AND m.relationship_id_predicate IS NOT NULL;


--Insertion of relationships that are currently not injested
-- Scope is limited to Valid Triples
INSERT INTO concept_relationship_metadata (concept_id_1, concept_id_2, relationship_id, relationship_predicate_id,
                                           relationship_group, mapping_source, confidence, mapping_tool, mapper,
                                           reviewer)
SELECT concept_id_1,
       concept_id_2,
       relationship_id,
      CASE WHEN length(trim(crm.relationship_predicate_id))=0 then null
          when lower(trim(crm.relationship_predicate_id))='eq' then 'exactMatch'
           when lower(trim(crm.relationship_predicate_id))='up' then 'broadMatch'
           when lower(trim(crm.relationship_predicate_id))='down' then 'narrowMatch'
          else crm.relationship_predicate_id end as relationship_predicate_id,
       relationship_group,
       mapping_source,
       confidence,
       mapping_tool,
       mapper,
       reviewer
FROM devv5.concept_relationship_metadata crm
where  not exists (
    SELECT 1
    from dev_voc_metadata.concept_relationship_metadata crmt
    where crmt.concept_id_1=crm.concept_id_1
)
and exists (
    SElECT 1
    FROM  devv5.concept_relationship cr
    where cr.concept_id_1=crm.concept_id_1
    and cr.relationship_id=crm.relationship_id
    and cr.concept_id_2=crm.concept_id_2
    and cr.invalid_reason IS NULL
)
  and crm.relationship_id IN (
'Maps to',
'Maps to value'
)
;

--issues/1073
UPDATE concept_relationship_metadata
    SET relationship_predicate_id='narrowMatch'
where concept_id_1=1572266
and concept_id_2=36717032
;

--relationship_predicate_id
UPDATE concept_relationship_metadata
SET relationship_predicate_id = NULL 
WHERE length(trim(relationship_predicate_id)) = 0;


--mapping_tool
UPDATE concept_relationship_metadata
SET mapping_tool = NULL 
WHERE length(trim(mapping_tool)) = 0;


--relationship_predicate_id
UPDATE concept_relationship_metadata
SET relationship_predicate_id = NULL
WHERE length(trim(relationship_predicate_id)) = 0;

--Mapping source UPD
UPDATE concept_relationship_metadata
SET mapping_source = 'Community Contribution'
WHERE mapping_tool IN ('Atlas, Databricks, and human');

--Mapping tool UPD
UPDATE concept_relationship_metadata
SET mapping_tool = 'MM_U'
WHERE mapping_tool IN ('Atlas, Databricks, and human');

UPDATE concept_relationship_metadata
SET mapping_tool = 'MM_C'
WHERE mapping_tool IN ('ManualMapping');

UPDATE concept_relationship_metadata
SET mapping_tool = 'MM_U'
WHERE mapping_tool ='MM_C'
and mapper is NULL
and reviewer is NULL
;

UPDATE concept_relationship_metadata
SET mapping_tool = 'MM_U'
WHERE mapping_tool ='MM_C'
and (mapper is NOT NULL
OR reviewer is NOT NULL)
and relationship_predicate_id is NULL
;

UPDATE concept_relationship_metadata
SET mapping_tool = 'AM-lib_U'
WHERE mapping_tool ='AM-lib_C'
and mapper is NULL
and reviewer is NULL
;

UPDATE concept_relationship_metadata
SET mapping_tool = 'MM_U',
    mapping_source=NULL
WHERE mapping_source ='MannualMapping'
and mapper is NULL
and reviewer is NULL
;

UPDATE concept_relationship_metadata
SET mapping_tool = 'AM-lib_U'
WHERE mapping_tool ='AM-lib_C'
and (mapper is NOT NULL
OR reviewer is NOT NULL)
and relationship_predicate_id is NULL
and confidence is NULL
;



--Set emails of reviewer
UPDATE concept_relationship_metadata AS b
    SET reviewer = CASE
               WHEN upper(trim(a.reviewer)) ='DB' THEN 'dmitry.buralkin@odysseusinc.com'
               WHEN upper(trim(a.reviewer)) ='EP' THEN 'yauheni.paulenkovich@odysseusinc.com'
               WHEN upper(trim(a.reviewer)) ='MS'or  a.reviewer ilike '%salavei%' THEN 'mikita.salavei@odysseusinc.com'
               WHEN upper(trim(a.reviewer)) ='JC' THEN 'janice.cruz@odysseusinc.com'
               WHEN upper(trim(a.reviewer)) ='VK' THEN 'vlad.korsik@odysseusinc.com'
               WHEN upper(trim(a.reviewer)) ='OZ' or a.reviewer ilike '%zhuk%'   THEN 'oleg.zhuk@odysseusinc.com'
               WHEN upper(trim(a.reviewer))  IN ('OT','TO')  then 'tetiana.orlova@odysseusinc.com'
               WHEN upper(trim(a.reviewer)) ='YK'  then 'yuri.korin@odysseusinc.com'
               WHEN upper(trim(a.reviewer)) ='IZ'  then 'irina.zherko@odysseusinc.com'
               WHEN upper(trim(a.reviewer)) IN ('AT')  then 'anton.tatur@epam.com'
              WHEN upper(trim(a.reviewer)) IN ('VALUE:')  then 'Vocabulary Team@epam.com'
               WHEN upper(trim(a.reviewer)) IN ('AY')  then 'aliaksand.yurchanka3@epam.com'
               WHEN upper(trim(a.reviewer)) ='MK' or  a.reviewer like '%khitrun%' then 'masha.khitrun@odysseusinc.com'
               WHEN upper(trim(a.reviewer)) ='VS'  then 'varvara.savitskaya@odysseusinc.com'
               WHEN upper(trim(a.reviewer)) ='TS'  then 'tatiana.skugarevskaya@odysseusinc.com'
               WHEN length(trim(a.reviewer)) = 0 then NULL
        ELSE a.reviewer
              END
from concept_relationship_metadata a
where a.concept_id_1=b.concept_id_1
and a.concept_id_2=b.concept_id_2
and a.relationship_id=b.relationship_id;

UPDATE concept_relationship_metadata
    SET reviewer = initcap(replace(split_part(reviewer,'@',1),'.',' '));



--Set emails of mappers
UPDATE concept_relationship_metadata AS b
    SET mapper = CASE
               WHEN upper(trim(a.mapper)) ='DB' THEN 'dmitry.buralkin@odysseusinc.com'
               WHEN upper(trim(a.mapper)) ='EP' THEN 'yauheni.paulenkovich@odysseusinc.com'
               WHEN upper(trim(a.mapper)) ='MS'or  a.mapper  ilike '%salavei%' THEN 'mikita.salavei@odysseusinc.com'
               WHEN upper(trim(a.mapper)) ='JC' THEN 'janice.cruz@odysseusinc.com'
               WHEN upper(trim(a.mapper)) ='VK' THEN 'vlad.korsik@odysseusinc.com'
               WHEN upper(trim(a.mapper)) ='OZ' or a.mapper ilike '%zhuk%'   THEN 'oleg.zhuk@odysseusinc.com'
               WHEN upper(trim(a.mapper))  IN ('OT','TO')  then 'tetiana.orlova@odysseusinc.com'
               WHEN upper(trim(a.mapper)) ='YK'  then 'yuri.korin@odysseusinc.com'
               WHEN upper(trim(a.mapper)) ='IZ'  then 'irina.zherko@odysseusinc.com'
               WHEN upper(trim(a.mapper)) IN ('AT')  then 'anton.tatur@epam.com'
               WHEN upper(trim(a.mapper)) IN ('VALUE:')  then 'Vocabulary Team@epam.com'
               WHEN upper(trim(a.mapper)) IN ('AY')  then 'aliaksand.yurchanka3@epam.com'
               WHEN upper(trim(a.mapper)) ='MK' or  a.mapper like '%khitrun%' then 'masha.khitrun@odysseusinc.com'
               WHEN upper(trim(a.mapper)) ='VS'  then 'varvara.savitskaya@odysseusinc.com'
               WHEN upper(trim(a.mapper)) ='TS'  then 'tatiana.skugarevskaya@odysseusinc.com'
               WHEN length(trim(a.mapper)) = 0 then NULL
               ELSE a.mapper
              END
from concept_relationship_metadata a
where a.concept_id_1=b.concept_id_1
and a.concept_id_2=b.concept_id_2
and a.relationship_id=b.relationship_id;

UPDATE concept_relationship_metadata
    SET mapper = initcap(replace(split_part(mapper,'@',1),'.',' '));

SELECT *
FROM concept_relationship_metadata
ORDER BY concept_id_1,relationship_id,concept_id_2
;

--loss of concepts compared to prev release
--predictable behaviour as it's resulted from mapping propagation and entire mapping inactivation/invalidation
SELECT c.vocabulary_id,count(*) as row_cnt, count(DISTINCT c.concept_id) as id_cnt
from devv5.concept_relationship_metadata crm
JOIN devv5.concept c
on crm.concept_id_1=c.concept_id
where  not exists (
    SELECT 1
    from dev_voc_metadata.concept_relationship_metadata crmt
    where crmt.concept_id_1=crm.concept_id_1
)
  and crm.relationship_id IN (
'Maps to',
'Maps to value'
)
GROUP BY c.vocabulary_id
;

--new CRMeta elements
SELECT c.vocabulary_id,count(*) as row_cnt, count(DISTINCT c.concept_id) as id_cnt
from dev_voc_metadata.concept_relationship_metadata crm
JOIN devv5.concept c
on crm.concept_id_1=c.concept_id
where  not exists (
    SELECT 1
    from devv5.concept_relationship_metadata crmt
    where crmt.concept_id_1=crm.concept_id_1
      and crmt.relationship_id IN (
'Maps to',
'Maps to value'
)
)
  and crm.relationship_id IN (
'Maps to',
'Maps to value'
)
GROUP BY c.vocabulary_id
;






--TODO @irina --fix ICD-env!!! (duplication is here)
--TODO @Masha -- add mapping source where possible
