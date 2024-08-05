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


--Insert new relationships
--Update existing relationships
INSERT INTO concept_relationship_manual AS mapped
    (concept_code_1,
    concept_code_2,
    vocabulary_id_1,
    vocabulary_id_2,
    relationship_id,
    valid_start_date,
    valid_end_date,
    invalid_reason)

	SELECT concept_code as source_code,
	       target_concept_code,
	       vocabulary_id as source_vocabulary_id,
	       target_vocabulary_id,
	       m.relationship_id,
	       current_date AS valid_start_date,
           to_date('20991231','yyyymmdd') AS valid_end_date,
           m.invalid_reason
	FROM dev_cdisc.cdisc_mapped m
	--Only related to LOINC vocabulary
	WHERE (vocabulary_id = 'CDISC' OR target_vocabulary_id = 'CDISC')
	    AND target_concept_id != 0

	ON CONFLICT ON CONSTRAINT unique_manual_relationships
	DO UPDATE
	    --In case of mapping 'resuscitation' use current_date as valid_start_date; in case of mapping deprecation use previous valid_start_date
	SET valid_start_date = CASE WHEN excluded.invalid_reason IS NULL THEN excluded.valid_start_date ELSE mapped.valid_start_date END,
	    --In case of mapping 'resuscitation' use 2099-12-31 as valid_end_date; in case of mapping deprecation use current_date
		valid_end_date = CASE WHEN excluded.invalid_reason IS NULL THEN excluded.valid_end_date ELSE current_date END,
		invalid_reason = excluded.invalid_reason
	WHERE ROW (mapped.invalid_reason)
	IS DISTINCT FROM
	ROW (excluded.invalid_reason);

--Correction of valid_start_dates and valid_end_dates for deprecation of existing mappings, existing in base, but not manual tables
UPDATE concept_relationship_manual crm 
SET valid_start_date = cr.valid_start_date,
    valid_end_date = current_date
FROM dev_cdisc.cdisc_mapped m
JOIN concept c 
ON c.concept_code = m.concept_code AND m.vocabulary_id = c.vocabulary_id
JOIN concept_relationship cr 
ON cr.concept_id_1 = c.concept_id AND cr.relationship_id = m.relationship_id
JOIN concept c1 
ON c1.concept_id = cr.concept_id_2 AND c1.concept_code = m.target_concept_code AND c1.vocabulary_id = m.target_vocabulary_id
WHERE m.invalid_reason IS NOT NULL
AND crm.concept_code_1 = m.concept_code AND crm.vocabulary_id_1 = m.vocabulary_id
AND crm.concept_code_2 = m.target_concept_code AND crm.vocabulary_id_2 = m.target_vocabulary_id
AND crm.relationship_id = m.relationship_id
AND crm.invalid_reason IS NOT NULL
;
