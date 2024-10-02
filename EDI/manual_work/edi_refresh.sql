--populate concept_relationship_manual table from a manual lookup (edi_mapped) table 

--add mappings into concept_relationship_manual
CREATE TABLE edi_mapped(
source_concept_code varchar,
source_domain_id varchar,
source_concept_name varchar,
target_concept_id int,
target_concept_code varchar,
target_concept_name varchar,
target_concept_class varchar,
target_domain_id varchar,
target_vocabulary_id varchar,
target_standard_concept varchar,
target_invalid_reason varchar,
valid_start_date date,
valid_end_date date);

INSERT INTO concept_relationship_manual
SELECT
source_concept_code AS concept_code_1,
target_concept_code AS concept_code_2,
'EDI' AS vocabulary_id_1,
target_vocabulary_id AS vocabulary_id_2,
relationship_id,
valid_start_date,
valid_end_date,
target_invalid_reason AS invalid_reason
FROM edi_mapped
WHERE target_concept_id IS NOT NULL
AND target_invalid_reason IS NULL;