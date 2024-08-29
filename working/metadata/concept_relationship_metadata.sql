-- DDL:
--DROP TABLE concept_relationship_metadata;
CREATE TABLE concept_relationship_metadata (
    concept_id_1 int NOT NULL,
    concept_id_2 int NOT NULL,
    relationship_id varchar(20) NOT NULL,
    relationship_predicate_id VARCHAR(20),
	relationship_group INT,
mapping_source VARCHAR(255),
confidence FLOAT,
mapping_tool VARCHAR(50),
mapper VARCHAR(50),
reviewer VARCHAR(50),
    FOREIGN KEY (concept_id_1, concept_id_2, relationship_id)
    REFERENCES concept_relationship (concept_id_1, concept_id_2, relationship_id)
);

-- ICDs insert:
INSERT INTO concept_relationship_metadata
SELECT cr.concept_id_1 as concept_id_1,
       cr.concept_id_2 as concept_id_2,
       cr.relationship_id as relationship_id,
       p.relationship_id_predicate as relationship_predicate_id,
       null as relationship_group,
       (array_agg (DISTINCT s.mappings_origin)) as mapping_source,
       null as confidence,
       null as mapping_tool,
       null as mapper,
       null as reviewer
FROM devv5.concept_relationship cr
JOIN devv5.concept c ON cr.concept_id_1 = c.concept_id
JOIN dev_icd10.icd_cde_proc p ON p.source_code = c.concept_code AND p.source_vocabulary_id = c.vocabulary_id
LEFT JOIN dev_icd10.icd_cde_source s ON p.source_code = s.source_code and p.source_vocabulary_id = s.source_vocabulary_id
WHERE cr.relationship_id in ('Maps to', 'Maps to value')
AND cr.invalid_reason is null
GROUP BY cr.concept_id_1,
         cr.concept_id_2,
         cr.relationship_id,
         p.relationship_id_predicate;

-- CC insert:
INSERT INTO concept_relationship_metadata
SELECT cr.concept_id_1 as concept_id_1,
       cr.concept_id_2 as concept_id_2,
       cr.relationship_id as relationship_id,
       case WHEN cc.predicate_id = 'exactMatch'
              then 'eq'
       when cc.predicate_id = 'broadMatch'
              then 'up' end as relationship_predicate_id,
       null as relationship_group,
       cc.mapping_source as mapping_source,
       cc.confidence as confidence,
       cc.mapping_tool as mapping_tool,
       null as mapper,
       null as reviewer
FROM cc_mapping cc
JOIN devv5.concept c ON (cc.concept_code_1, cc.vocabulary_id_1) = (c.concept_code, c.vocabulary_id)
JOIN devv5.concept c1 ON (cc.concept_code_2, cc.vocabulary_id_2) = (c1.concept_code, c1.vocabulary_id)
JOIN devv5.concept_relationship cr ON (c.concept_id, c1.concept_id, cc.relationship_id) = (cr.concept_id_1, cr.concept_id_2, cr.relationship_id)
WHERE cr.invalid_reason is null;

-- Insert for SNOMED:
INSERT INTO concept_relationship_metadata
SELECT cr.concept_id_1 as concept_id_1,
       cr.concept_id_2 as concept_id_2,
       cr.relationship_id as relationship_id,
       m.relationship_id_predicate as relationship_predicate_id,
       null as relationship_group,
       m.mapping_source as mapping_source,
       m.confidence::float as confidence,
       m.mapping_tool as mapping_tool,
       m.mapper_id as mapper,
       m.reviewer_id as reviewer
FROM dev_snomed.snomed_mapped m
JOIN devv5.concept c on (m.source_code, m.source_vocabulary_id) = (c.concept_code, c.vocabulary_id)
JOIN devv5.concept c1 on (m.target_concept_code, m.target_vocabulary_id) = (c1.concept_code, c1.vocabulary_id)
JOIN devv5.concept_relationship cr on (c.concept_id, c1.concept_id, m.relationship_id) = (cr.concept_id_1, cr.concept_id_2, cr.relationship_id)
WHERE cr.relationship_id IN ('Maps to', 'Maps to value')
AND cr.invalid_reason IS NULL
AND m.cr_invalid_reason is null
AND m.relationship_id_predicate IS NOT NULL;

--CDISC Rel_Meta Integration
INSERT INTO concept_relationship_metadata (concept_id_1, concept_id_2, relationship_id, relationship_predicate_id, relationship_group, mapping_source, confidence, mapping_tool, mapper, reviewer)
SELECT DISTINCT
       concept_id_1,
       concept_id_2,
       relationship_id,
       relationship_predicate_id,
       relationship_group,
       mapping_source,
       confidence,
       mapping_tool,
       mapper,
       reviewer
FROM (SELECT DISTINCT c.concept_id as concept_id_1,c.concept_code as concept_code_1,c.vocabulary_id as vocabulary_id_1,c.concept_name as concept_name_1,cr.relationship_id,cc.concept_id as concept_id_2,cc.concept_code as concept_code_2,cc.vocabulary_id as vocabulary_id_2,cc.concept_name as concept_name_2,
                      REPLACE(SPLIT_PART(a.mapping_source[1], '-', 1), 'Auto', 'AM-lib') || '_U' AS mapping_tool,
                      NULL   as mapper,
                      NULL as reviewer,
                      a.confidence,
                      REPLACE(SPLIT_PART(a.mapping_source[1], '-', 2), 'OMOP', 'OHDSI')         AS mapping_source,
                     NULL  as relationship_group,a.relationship_predicate_id
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

UNION ALL

      SELECT DISTINCT c.concept_id as concept_id_1,c.concept_code as concept_code_1,c.vocabulary_id as vocabulary_id_1,c.concept_name as concept_name_1,cr.relationship_id,cc.concept_id as concept_id_2,cc.concept_code as concept_code_2,cc.vocabulary_id as vocabulary_id_2,cc.concept_name as concept_name_2,
                      REPLACE(SPLIT_PART(a.mapping_source[1], '-', 1), 'manual', 'MM') || '_C' AS mapping_tool,
                      a.mapper,
                      a.reviewer,
                      coalesce(a.confidence,0.5) as confidence,
                    NULL   AS mapping_source,
                     NULL  as relationship_group,a.relationship_predicate_id
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
ORDER BY concept_id_1,relationship_id,concept_id_2
;

-- --MedDRA Rel_Meta Integration
INSERT INTO concept_relationship_metadata (concept_id_1, concept_id_2, relationship_id, relationship_predicate_id, relationship_group, mapping_source, confidence, mapping_tool, mapper, reviewer)
with tab_array as(
SELECT concept_id_1,
       concept_id_2,
       relationship_id,
       array_agg(trim(relationship_predicate_id)) as relationship_predicate_id,
       array_agg(trim(relationship_group))  as relationship_group,
      array_agg(trim(mapping_source))  as mapping_source  ,
       array_agg(trim(confidence))  as confidence,
     array_agg(trim(mapping_tool))  as mapping_tool  ,
          array_agg(trim(mapper))  as mapper  ,
        array_agg(trim(reviewer))  as reviewer
FROM (SELECT DISTINCT c.concept_id as concept_id_1,c.concept_code as concept_code_1,c.vocabulary_id as vocabulary_id_1,c.concept_name as concept_name_1,cr.relationship_id,cc.concept_id as concept_id_2,cc.concept_code as concept_code_2,cc.vocabulary_id as vocabulary_id_2,cc.concept_name as concept_name_2,
                   CASE WHEN lower(trim(origin_of_mapping))='manual' then 'MM_C'
                       WHEN lower(trim(origin_of_mapping)) like '%meddra_mapped%' then 'MM_C'
                        WHEN lower(trim(origin_of_mapping))='python' then 'AM-tool_C'
                        WHEN lower(trim(origin_of_mapping))='chatgpt' then 'AM-tool_C'
                        WHEN lower(trim(origin_of_mapping))='python+chatgpt' then 'AM-tool_C'
                       else 'AM-lib_C' end AS mapping_tool,
                     CASE WHEN length(trim(a.mapper_id))=0  then NULL
                          WHEN trim(a.mapper_id) ='DB'  then 'dmitry.buralkin@odysseusinc.com'
                         WHEN trim(a.mapper_id) ='MS'  then 'mikita.salavei@odysseusinc.com'
                         WHEN trim(a.mapper_id) ='EP'  then 'yauheni.paulenkovich@odysseusinc.com'
                         WHEN trim(a.mapper_id) ='JC'  then 'janice.cruz@odysseusinc.com'
                         WHEN trim(a.mapper_id) ='VK'  then 'vlad.korsik@odysseusinc.com'
                         WHEN trim(a.mapper_id) ='OZ'  then 'oleg.zhuk@odysseusinc.com'
                         WHEN trim(a.mapper_id) ='OT'  then 'tetiana.orlova@odysseusinc.com'
                         WHEN trim(a.mapper_id) ='YK'  then 'yuri.korin@odysseusinc.com'
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
                       ELSE a.origin_of_mapping    END  AS mapping_source,
                     NULL  as relationship_group,
                        CASE WHEN lower(trim(a.relationship_id_predicate)) ='downhill' then 'down'
                             WHEN lower(trim(a.relationship_id_predicate)) ='uphill' then 'up' else a.relationship_id_predicate END as relationship_predicate_id
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
                (relationship_group)[ARRAY_LENGTH(s.relationship_group, 1)] as relationship_group,
             (mapping_source)[ARRAY_LENGTH(s.mapping_source, 1)] as    mapping_source,
                (confidence)[ARRAY_LENGTH(s.confidence, 1)] as     confidence,
                 (mapping_tool)[ARRAY_LENGTH(s.mapping_tool, 1)] as     mapping_tool,
                  (mapper)[ARRAY_LENGTH(s.mapper, 1)] as     mapper,
                (reviewer)[ARRAY_LENGTH(s.reviewer, 1)] as     reviewer
FROM tab_array s
ORDER BY concept_id_1,relationship_id,concept_id_2
;