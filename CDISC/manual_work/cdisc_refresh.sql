-- MetaData enriched mapping lookup
--DROP TABLE cdisc_mapped;
--TRUNCATE cdisc_mapped;
CREATE TABLE cdisc_mapped
(   metadata_enriched boolean DEFAULT TRUE,
    concept_code VARCHAR (50) NOT NULL, --CDISC code
    concept_name   VARCHAR (255), --CDISC name
    vocabulary_id VARCHAR (20)  DEFAULT 'CDISC',
    sty VARCHAR, -- semantic type form NCImetha
    mapability VARCHAR, -- -OMOP mapability of source code e.g.: FoN - flavor of null;NOmop - non omop use-case; NULL - mappable (voc_metadata extension)
    relationship_id VARCHAR (20), --OMOP Rel
    relationship_id_predicate VARCHAR (20),  --OMOP Rel Predicate (voc_metadata extension)
    mapping_source VARCHAR [], -- Origin of Mapping
    mapping_path VARCHAR [], -- For non-manual sources the array with codes in a chain
    decision  boolean,
    confidence FLOAT,  --OMOP Rel Confidence (voc_metadata extension)
    mapper_id VARCHAR,  --OMOP Rel mapper_id - email (voc_metadata extension)
    reviewer_id VARCHAR, --OMOP Rel reviewer_id - email (voc_metadata extension)
    valid_start_date date, --OMOP Rel valid_start_date
    valid_end_date date, --OMOP Rel valid_end_date
    invalid_reason VARCHAR,  --OMOP Rel invalid_reason
    comments VARCHAR, --technical comments on mapping
    target_concept_id BIGINT,
    target_concept_code VARCHAR (50),
    target_concept_name VARCHAR (255),
    target_concept_class VARCHAR (50),
    target_standard_concept VARCHAR (10),
    target_invalid_reason VARCHAR (20),
    target_domain_id VARCHAR (20),
    target_vocabulary_id VARCHAR (20));
;

--domain_id and concept_class_id to attributes equivalency
--SNOMED attributes to be used for mapping (all of Domain-Class permutations are possible)
--Table to be populated wit STY associated with CDISC CUIs
--DROP TABLE concept_class_lookup
--TRUNCATE TABLE concept_class_lookup;
CREATE TABLE concept_class_lookup
(attribute varchar, --sty from meta_mrsty
concept_class varchar,
domain_id varchar
);


--Population of the concept_relationship_manual table
-- concept_relationship_manual table population
INSERT INTO  concept_relationship_manual (concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id,valid_start_date,valid_end_date,invalid_reason)
SELECT DISTINCT concept_code as concept_code_1,
       target_concept_code as concept_code_2,
       vocabulary_id as vocabulary_id_1,
       target_vocabulary_id as vocabulary_id_2,
       relationship_id as relationship_id,
       valid_start_date as valid_start_date,
       valid_end_date as valid_end_date,
       null as invalid_reason
       FROM cdisc_mapped
    WHERE target_concept_id is not null
      AND target_concept_code !='No matching concept'  -- _mapped file can contain them
    and decision is true
        ORDER BY concept_code,relationship_id;

