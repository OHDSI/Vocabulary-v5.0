-- DDL:
-- DROP TABLE concept_relationship_metadata;
TRUNCATE TABLE concept_relationship_metadata;
CREATE TABLE concept_relationship_metadata (
    concept_id_1               INT NOT NULL,
    concept_id_2               INT NOT NULL,
    relationship_id            VARCHAR(20) NOT NULL,
    relationship_predicate_id   VARCHAR(20),
    relationship_group         INT,
    mapping_source             VARCHAR(50),
    confidence                 FLOAT,
    mapping_tool               VARCHAR(50),
    mapper                     VARCHAR(50),
    reviewer                   VARCHAR(50),
    FOREIGN KEY (concept_id_1, concept_id_2, relationship_id)
        REFERENCES concept_relationship (concept_id_1, concept_id_2, relationship_id),
    CONSTRAINT chk_relationship_predicate_id
        CHECK (relationship_predicate_id IN ('narrowMatch', 'exactMatch', 'broadMatch')),
    CONSTRAINT xpk_concept_relationship_metadata
        UNIQUE (concept_id_1, concept_id_2, relationship_id)
);


-- 1. Community contribution
INSERT INTO concept_relationship_metadata
SELECT DISTINCT
    cr.concept_id_1 AS concept_id_1,
    cr.concept_id_2 AS concept_id_2,
    cr.relationship_id AS relationship_id,
    predicate_id AS relationship_predicate_id,
    NULL::INT AS relationship_group,
    CASE WHEN cc.mapping_source ~* 'manual|new snomed' THEN NULL
         WHEN cc.mapping_source ~* 'OMOP|OHDSI' THEN 'OHDSI'
         ELSE cc.mapping_source
    END AS mapping_source,
    cc.confidence AS confidence,
    CASE WHEN cc.mapping_source ~* 'manual|new snomed' THEN 'MM_C'
         WHEN cc.mapping_source ~* 'OMOP|OHDSI' THEN 'AM-lib_C'
         ELSE cc.mapping_tool
    END AS mapping_tool,
    'CC' AS mapper,
    'MK' AS reviewer
FROM dev_voc_metadata.cc_mapping cc
JOIN devv5.concept c
    ON (cc.concept_code_1, cc.vocabulary_id_1) = (c.concept_code, c.vocabulary_id)
JOIN devv5.concept c1
    ON (cc.concept_code_2, cc.vocabulary_id_2) = (c1.concept_code, c1.vocabulary_id)
JOIN devv5.concept_relationship cr
    ON (c.concept_id, c1.concept_id, cc.relationship_id) = (cr.concept_id_1, cr.concept_id_2, cr.relationship_id)
WHERE cr.invalid_reason IS NULL
ON CONFLICT ON CONSTRAINT xpk_concept_relationship_metadata
DO UPDATE SET
    relationship_predicate_id = EXCLUDED.relationship_predicate_id,
    relationship_group = EXCLUDED.relationship_group,
    mapping_source = EXCLUDED.mapping_source,
    confidence = EXCLUDED.confidence,
    mapping_tool = EXCLUDED.mapping_tool,
    mapper = EXCLUDED.mapper,
    reviewer = EXCLUDED.reviewer;


-- 2. ICD-family
INSERT INTO concept_relationship_metadata (
    concept_id_1, concept_id_2, relationship_id, relationship_predicate_id,
    relationship_group, mapping_source, confidence, mapping_tool, mapper, reviewer
)
SELECT
    concept_id_1,
    concept_id_2,
    relationship_id,
    relationship_predicate_id[array_length(relationship_predicate_id, 1)],
    relationship_group::INT,
    CASE WHEN 'manual' = ANY(mapping_source) AND 'UMLS/NCIm' != ALL(mapping_source) THEN NULL
         WHEN array_length(mapping_source, 1) > 1 AND 'UMLS/NCIm' = ANY(mapping_source) THEN 'OHDSI+UMLS/NCIm'
         ELSE 'OHDSI'
    END AS mapping_source,
    confidence::FLOAT,
    CASE WHEN 'manual' = ANY(mapping_source) AND 'UMLS/NCIm' != ALL(mapping_source) THEN 'MM_C'
         ELSE 'AM-lib_C'
    END AS mapping_tool,
    mapper[array_length(mapper, 1)],
    reviewer[array_length(reviewer, 1)]
FROM (
    SELECT
        cr.concept_id_1 AS concept_id_1,
        cr.concept_id_2 AS concept_id_2,
        cr.relationship_id AS relationship_id,
        ARRAY_REMOVE(
            ARRAY_AGG(DISTINCT
                CASE WHEN LENGTH(TRIM(p.relationship_id_predicate)) = 0 THEN NULL
                     WHEN LOWER(TRIM(p.relationship_id_predicate)) = 'eq' THEN 'exactMatch'
                     WHEN LOWER(TRIM(p.relationship_id_predicate)) = 'up' THEN 'broadMatch'
                     WHEN LOWER(TRIM(p.relationship_id_predicate)) = 'down' THEN 'narrowMatch'
                     ELSE p.relationship_id_predicate
                END
            ), NULL
        ) AS relationship_predicate_id,
        NULL::INT AS relationship_group,
        ARRAY_REMOVE(ARRAY_AGG(DISTINCT s.mappings_origin), NULL) AS mapping_source,
        NULL::FLOAT AS confidence,
        NULL AS mapping_tool,
        ARRAY_REMOVE(ARRAY_AGG(DISTINCT REPLACE(p.mapper, 'Mapper: ', '')), NULL) AS mapper,
        ARRAY_REMOVE(ARRAY_AGG(DISTINCT REPLACE(p.reviewer, 'Reviewer: ', '')), NULL) AS reviewer
    FROM devv5.concept_relationship cr
    JOIN devv5.concept c
        ON cr.concept_id_1 = c.concept_id
    JOIN dev_icd10.icd_cde_proc p
        ON p.source_code = c.concept_code AND p.source_vocabulary_id = c.vocabulary_id
    LEFT JOIN dev_icd10.icd_cde_source s
        ON p.source_code = s.source_code AND p.source_vocabulary_id = s.source_vocabulary_id
    WHERE cr.relationship_id IN ('Maps to', 'Maps to value')
    AND (cr.concept_id_1, cr.concept_id_2, cr.relationship_id) NOT IN (
        SELECT concept_id_1, concept_id_2, relationship_id
        FROM concept_relationship_metadata
    )
    AND cr.invalid_reason IS NULL
    GROUP BY cr.concept_id_1, cr.concept_id_2, cr.relationship_id
) AS tab
;


--3. SNOMED
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
       null as mapping_source,
       m.confidence::float as confidence,
       'MM_C' as mapping_tool,
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


--4. CDISC
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


--5. MedDRA
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


--6. CPT4:
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

--7. HCPCS:
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

--8. CIEL:
    INSERT INTO concept_relationship_metadata (
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
)
SELECT distinct
    c.concept_id AS concept_id_1,
    target_concept_id AS concept_id_2,
    relationship_id as relationship_id,
    -- SSSOM Predicates based on Mapping Direction
    CASE
        -- EQ: Equivalent [exactMatch]
        WHEN rule_applied ~* '^1\.01' THEN 'exactMatch'
        -- UP: Uphill [broadMatch]
        WHEN rule_applied ~* '^1\.02|^2\.06|^2\.10|^2\.12|^2\.14|^2\.15'
           THEN 'broadMatch'
    END AS relationship_predicate_id,
    NULL::INT AS relationship_group,
    'CIEL' AS mapping_source,
    1 AS confidence,
    'AM-lib_C' AS mapping_tool,
    'Andrew S. Kanter' AS mapper,
    NULL AS reviewer
FROM dev_ciel.maps_for_load_stage a
JOIN concept c
  ON a.source_code = c.concept_code
WHERE c.vocabulary_id = 'CIEL'
AND rule_applied ~* '^1\.01|^1\.02|^2\.06|^2\.10|^2\.12|^2\.14|^2\.15'
;

--9. Cancer Modifier metadata enrichment
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
      null as mapping_source,  -- Add this column
      1.0 as confidence,
      'MM_C' as mapping_tool,
       'Vlad Korsik' as mapper,
       'Nemesis Health/Oncology WG' as reviewer
FROM dev_cancer_modifier.cancer_modifier_cde m
JOIN devv5.concept c on (m.source_concept_code, m.source_vocabulary_id) = (c.concept_code, c.vocabulary_id)
JOIN devv5.concept c1 on (m.target_concept_code, m.target_vocabulary_id) = (c1.concept_code, c1.vocabulary_id)
JOIN devv5.concept_relationship cr on (c.concept_id, c1.concept_id, m.relationship_id) = (cr.concept_id_1, cr.concept_id_2, cr.relationship_id)
WHERE cr.relationship_id IN ('Maps to', 'Maps to value')
      AND (cr.concept_id_1, cr.concept_id_2, cr.relationship_id) NOT IN (SELECT concept_id_1, concept_id_2, relationship_id FROM concept_relationship_metadata)
AND cr.invalid_reason IS NULL
AND m.relationship_id_predicate IS NOT NULL;

--10. Insertion of relationships that are currently not ingested
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
WHERE NOT EXISTS (
    SELECT 1
    FROM dev_voc_metadata.concept_relationship_metadata crmt
    WHERE crmt.concept_id_1 = crm.concept_id_1
)
AND EXISTS (
    SELECT 1
    FROM devv5.concept_relationship cr
    WHERE cr.concept_id_1 = crm.concept_id_1
    AND cr.relationship_id = crm.relationship_id
    AND cr.concept_id_2 = crm.concept_id_2
    AND cr.invalid_reason IS NULL
)
  and crm.relationship_id IN (
'Maps to',
'Maps to value'
)
;


--Mapping source UPD
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

-- Set emails of reviewer
UPDATE concept_relationship_metadata AS b
SET reviewer = CASE
    WHEN UPPER(TRIM(a.reviewer)) = 'DB' THEN 'dmitry.buralkin@odysseusinc.com'
    WHEN UPPER(TRIM(a.reviewer)) = 'EP' THEN 'yauheni.paulenkovich@odysseusinc.com'
    WHEN UPPER(TRIM(a.reviewer)) = 'MS' OR a.reviewer ILIKE '%salavei%' THEN 'mikita_salavei@epam.com'
    WHEN UPPER(TRIM(a.reviewer)) = 'JC' THEN 'janice.cruz@odysseusinc.com'
    WHEN UPPER(TRIM(a.reviewer)) = 'VK' THEN 'vlad.korsik@odysseusinc.com'
    WHEN UPPER(TRIM(a.reviewer)) = 'OZ' OR a.reviewer ILIKE '%zhuk%' THEN 'oleg.zhuk@odysseusinc.com'
    WHEN UPPER(TRIM(a.reviewer)) IN ('OT', 'TO') THEN 'tetiana_orlova@epam.com'
    WHEN UPPER(TRIM(a.reviewer)) = 'YK' THEN 'yuri.korin@odysseusinc.com'
    WHEN UPPER(TRIM(a.reviewer)) = 'IZ' THEN 'irina.zherko@odysseusinc.com'
    WHEN UPPER(TRIM(a.reviewer)) = 'AT' THEN 'anton_tatur1@epam.com'
    WHEN UPPER(TRIM(a.reviewer)) = 'VALUE:' THEN 'Vocabulary Team@epam.com'
    WHEN UPPER(TRIM(a.reviewer)) = 'AY' THEN 'aliaksandr_yurchanka3@epam.com'
    WHEN UPPER(TRIM(a.reviewer)) = 'MK' OR a.reviewer ILIKE '%khitrun%' THEN 'maria_khitrun@epam.com'
    WHEN UPPER(TRIM(a.reviewer)) = 'MR' THEN 'maria_rahozhkina@epam.com'
    WHEN UPPER(TRIM(a.reviewer)) = 'VS' THEN 'varvara_savitskaya@epam.com'
    WHEN UPPER(TRIM(a.reviewer)) = 'TS' OR a.reviewer ILIKE '%skugarevskaya%' THEN 'tatsiana_skuhareuskaya@epam.com'
    WHEN LENGTH(TRIM(a.reviewer)) = 0 THEN NULL
    ELSE a.reviewer
END
FROM concept_relationship_metadata a
WHERE a.concept_id_1 = b.concept_id_1
AND a.concept_id_2 = b.concept_id_2
AND a.relationship_id = b.relationship_id;

UPDATE concept_relationship_metadata
    SET reviewer = INITCAP(REPLACE(SPLIT_PART(reviewer, '@', 1), '.', ' '));
UPDATE concept_relationship_metadata
    SET reviewer = INITCAP(REPLACE(SPLIT_PART(reviewer, '@', 1), '_', ' '));


-- Set emails of mappers
UPDATE concept_relationship_metadata AS b
SET mapper = CASE
    WHEN UPPER(TRIM(a.mapper)) = 'DB' THEN 'dmitry.buralkin@odysseusinc.com'
    WHEN UPPER(TRIM(a.mapper)) = 'EP' THEN 'yauheni.paulenkovich@odysseusinc.com'
    WHEN UPPER(TRIM(a.mapper)) = 'MS' OR a.mapper ILIKE '%salavei%' THEN 'mikita.salavei@odysseusinc.com'
    WHEN UPPER(TRIM(a.mapper)) = 'JC' THEN 'janice.cruz@odysseusinc.com'
    WHEN UPPER(TRIM(a.mapper)) = 'VK' THEN 'vlad.korsik@odysseusinc.com'
    WHEN UPPER(TRIM(a.mapper)) = 'OZ' OR a.mapper ILIKE '%zhuk%' THEN 'oleg.zhuk@odysseusinc.com'
    WHEN UPPER(TRIM(a.mapper)) IN ('OT', 'TO') THEN 'tetiana_orlova@epam.com'
    WHEN UPPER(TRIM(a.mapper)) = 'YK' THEN 'yuri.korin@odysseusinc.com'
    WHEN UPPER(TRIM(a.mapper)) = 'IZ' THEN 'irina.zherko@odysseusinc.com'
    WHEN UPPER(TRIM(a.mapper)) = 'AT' THEN 'anton.tatur@epam.com'
    WHEN UPPER(TRIM(a.mapper)) = 'VALUE:' THEN 'Vocabulary Team@epam.com'
    WHEN UPPER(TRIM(a.mapper)) = 'AY' THEN 'aliaksandr_yurchanka3@epam.com'
    WHEN UPPER(TRIM(a.mapper)) = 'MK' OR a.mapper ILIKE '%khitrun%' THEN 'maria_khitrun@epam.com'
    WHEN UPPER(TRIM(a.mapper)) = 'VS' THEN 'varvara_savitskaya@epam.com'
    WHEN UPPER(TRIM(a.mapper)) = 'TS' OR a.mapper ILIKE '%skugarevskaya%' THEN 'tatsiana_skuhareuskaya@epam.com'
    WHEN UPPER(TRIM(a.mapper)) ILIKE 'CC' THEN 'OHDSI community'
    WHEN LENGTH(TRIM(a.mapper)) = 0 THEN NULL
    ELSE a.mapper
END
FROM concept_relationship_metadata a
WHERE a.concept_id_1 = b.concept_id_1
AND a.concept_id_2 = b.concept_id_2
AND a.relationship_id = b.relationship_id;

UPDATE concept_relationship_metadata
    SET mapper = INITCAP(REPLACE(SPLIT_PART(mapper, '@', 1), '.', ' '));
UPDATE concept_relationship_metadata
    SET mapper = INITCAP(REPLACE(SPLIT_PART(mapper, '@', 1), '_', ' '));


--TODO @irina --fix ICD-env!!! (duplication is here)
--TODO @Masha -- add mapping source where possible
