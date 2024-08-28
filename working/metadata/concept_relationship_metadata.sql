-- DDL:
--TRUNCATE TABLE concept_relationship_metadata;
CREATE TABLE concept_relationship_metadata (
    concept_id_1 int NOT NULL,
    concept_id_2 int NOT NULL,
    relationship_id varchar(20) NOT NULL,
    relationship_predicate_id VARCHAR(20),
	relationship_group INT,
mapping_source VARCHAR(255),
confidence INT,
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
