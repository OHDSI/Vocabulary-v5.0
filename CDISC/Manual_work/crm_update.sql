-- Update crm with manual mappings
--DROP TABLE cdisc_mapped;
--TRUNCATE cdisc_mapped;
CREATE TABLE cdisc_mapped -- contains all the manual mappings with metadata
(
    concept_code VARCHAR (50) NOT NULL,
    concept_name  VARCHAR (255),
    vocabulary_id VARCHAR (20),
    sty VARCHAR,
    relationship_id VARCHAR (20),
    relationship_id_predicate VARCHAR (20),
    mapping_source VARCHAR,
    confidence VARCHAR,
    mapper_id VARCHAR,
    reviewer_id VARCHAR,
    valid_start_date date,
    valid_end_date date,
    invalid_reason VARCHAR,
    comments VARCHAR,
    target_concept_id BIGINT,
    target_concept_code VARCHAR (50),
    target_concept_name VARCHAR (255),
    target_concept_class VARCHAR (50),
    target_standard_concept VARCHAR (10),
    target_invalid_reason VARCHAR (20),
    target_domain_id VARCHAR (20),
    target_vocabulary_id VARCHAR (20));

SELECT * FROM cdisc_mapped;

--TRUNCATE TABLE concept_relationship_manual;
INSERT INTO  concept_relationship_manual (
SELECT concept_code as concept_code_1,
       target_concept_code as concept_code_2,
       vocabulary_id as vocabulary_id_1,
       target_vocabulary_id as vocabulary_id_2,
       relationship_id as relationship_id,
       '2024-05-31' as valid_start_date,
       '2099-12-31' as valid_end_date,
       null as invalid_reason
       FROM cdisc_mapped
    WHERE target_concept_id is not null);

--Working with concept_relationship_manual table
DELETE FROM concept_relationship_manual
where vocabulary_id_1='CDISC'
and concept_code_2='No matching concept'
;