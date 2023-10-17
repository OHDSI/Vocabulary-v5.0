--New pipeline to work with _manual tables from one lookup table
DROP TABLE vocab_manual_lookup;
CREATE TABLE vocab_manual_lookup
(
    id SERIAL PRIMARY KEY,
    concept_name varchar(255) NOT NULL,
    concept_synonym_name varchar(1000),
    language_concept_id int,
    concept_code varchar(50),
    domain_id varchar(20),
    concept_class_id varchar(20),
    standard_concept varchar(1),
    invalid_reason varchar(1),
    vocabulary_id varchar(20) NOT NULL,
    process_manual_names int,           --Put 1 if you want to change concept_name
    valid_start_date date,
    valid_end_date date,
    relationship_id varchar(50),
    cr_invalid_reason varchar(1),
    source varchar(255),
    target_concept_id int,
    target_concept_code varchar(50),
    target_concept_name varchar(255),
    target_concept_class_id varchar(50),
    target_standard_concept varchar(20),
    target_invalid_reason varchar(20),
    target_domain_id varchar(50),
    target_vocabulary_id varchar(50)
);

UPDATE vocab_manual_lookup
SET
  concept_synonym_name = NULLIF(concept_synonym_name, ''),
  concept_code = NULLIF(concept_code, ''),
  domain_id = NULLIF(domain_id, ''),
  concept_class_id = NULLIF(concept_class_id, ''),
  standard_concept = NULLIF(standard_concept, ''),
  invalid_reason = NULLIF(invalid_reason, ''),
  relationship_id = NULLIF(relationship_id, ''),
  cr_invalid_reason = NULLIF(cr_invalid_reason, ''),
  source = NULLIF(source, ''),
  target_concept_code = NULLIF(target_concept_code, ''),
  target_concept_name = NULLIF(target_concept_name, ''),
  target_concept_class_id = NULLIF(target_concept_class_id, ''),
  target_standard_concept = NULLIF(target_standard_concept, ''),
  target_invalid_reason = NULLIF(target_invalid_reason, ''),
  target_domain_id = NULLIF(target_domain_id, ''),
  target_vocabulary_id = NULLIF(target_vocabulary_id, '')
;

--Adding constraints for unique records
--concept_name used instead of concept_code because we want to assign concept codes to new OMOP generated concepts automatically
ALTER TABLE vocab_manual_lookup ADD CONSTRAINT idx_pk_lookup UNIQUE (concept_name, target_concept_code, vocabulary_id, target_vocabulary_id, relationship_id);
ALTER TABLE vocab_manual_lookup ADD CONSTRAINT unique_synonyms_lookup UNIQUE (concept_name, concept_synonym_name);


/*
 In general, a unique constraint is violated if there is more than one row in the table where the values of all of the columns included in the constraint are equal. 
 By default, two null values are not considered equal in this comparison. 
 That means even in the presence of a unique constraint it is possible to store duplicate rows that contain a null value in at least one of the constrained columns. 
 This behavior can be changed by adding the clause NULLS NOT DISTINCT, like
 */
 
 
--Assigning codes to new OMOP Extension concepts
-- Create sequence for new OMOP-created standard concepts
DO $$
DECLARE
	ex INTEGER;
BEGIN
	SELECT MAX(replace(concept_code, 'OMOP','')::int4) + 1 into ex FROM devv5.concept WHERE concept_code like 'OMOP%'  and concept_code not like '% %'; -- Last valid value of the OMOP123-type codes
	DROP SEQUENCE IF EXISTS new_voc;
	EXECUTE 'CREATE SEQUENCE new_voc INCREMENT BY 1 START WITH ' || ex || ' NO CYCLE CACHE 20';
END$$;

--For source concepts
with a AS (
    SELECT DISTINCT concept_name, vocabulary_id, 'OMOP' || nextval('new_voc') AS concept_code
    FROM vocab_manual_lookup 
    WHERE vocabulary_id = 'OMOP Extension'
    AND concept_code IS NULL
)

UPDATE vocab_manual_lookup
SET concept_code = a.concept_code
FROM a 
WHERE vocab_manual_lookup.concept_code IS NULL 
AND vocab_manual_lookup.vocabulary_id = 'OMOP Extension'
AND a.concept_name = vocab_manual_lookup.concept_name;

--For target concepts
with a AS (SELECT DISTINCT concept_code, concept_name, vocabulary_id
           FROM vocab_manual_lookup 
           WHERE vocabulary_id = 'OMOP Extension'
           )
UPDATE vocab_manual_lookup
SET target_concept_code = a.concept_code
FROM a 
WHERE vocab_manual_lookup.target_concept_code IS NULL 
AND vocab_manual_lookup.target_vocabulary_id = 'OMOP Extension'
AND a.concept_name = vocab_manual_lookup.target_concept_name;

--Changing constraint to concept code
ALTER TABLE vocab_manual_lookup DROP CONSTRAINT idx_pk_lookup;
ALTER TABLE vocab_manual_lookup ADD CONSTRAINT idx_pk_code_lookup UNIQUE (concept_code, target_concept_code, vocabulary_id, target_vocabulary_id, relationship_id);
ALTER TABLE vocab_manual_lookup ADD CONSTRAINT unique_manual_concepts_lookup UNIQUE (concept_code, concept_name, vocabulary_id, domain_id, concept_class_id, 
                                                                                     standard_concept, invalid_reason, process_manual_names, valid_start_date, valid_end_date);



--! Processing concept_manual table
--update existing records
	UPDATE concept_manual cm
	SET concept_name = CASE WHEN coalesce(lk.process_manual_names, 0) = 1 THEN lk.concept_name ELSE cm.concept_name END,
		domain_id = COALESCE(lk.domain_id, cm.domain_id),
		concept_class_id = COALESCE(lk.concept_class_id, cm.concept_class_id),
		standard_concept = lk.standard_concept,
		valid_start_date = COALESCE(lk.valid_start_date, cm.valid_start_date),
		valid_end_date = COALESCE(lk.valid_end_date, cm.valid_end_date),
		invalid_reason = lk.invalid_reason
	FROM vocab_manual_lookup lk
	WHERE 
		lk.concept_code = cm.concept_code
		AND lk.vocabulary_id = cm.vocabulary_id
AND vocabulary_id = 'vocabulary'
;


--add new records
	INSERT INTO concept_manual (
		concept_name,
		domain_id,
		vocabulary_id,
		concept_class_id,
		standard_concept,
		concept_code,
		valid_start_date,
		valid_end_date,
		invalid_reason
		)
	SELECT DISTINCT lk.concept_name,
	       lk.domain_id,
	       lk.vocabulary_id,
	       lk.concept_class_id,
	       lk.standard_concept,
           lk.concept_code,
           lk.valid_start_date,
           lk.valid_end_date,
           lk.invalid_reason
    FROM vocab_manual_lookup lk
	WHERE NOT EXISTS (
				SELECT 1
				FROM concept_manual cm
				WHERE cm.concept_code = lk.concept_code
					AND cm.vocabulary_id = lk.vocabulary_id
				);



--! Processing concept_synonym_manual table
	INSERT INTO concept_synonym_manual (
		synonym_name,
		synonym_concept_code,
		synonym_vocabulary_id,
		language_concept_id
		)
	SELECT lk.concept_synonym_name,
           lk.concept_code,
           lk.vocabulary_id,
           coalesce(lk.language_concept_id, 4180186) --English by default
    FROM vocab_manual_lookup lk
    WHERE lk.vocabulary_id = 'vocabulary'
    AND lk.concept_synonym_name IS NOT NULL
	ON CONFLICT DO NOTHING;



--! Processing concept_relationship_manual
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

	SELECT DISTINCT concept_code,
	       target_concept_code,
	       vocabulary_id,
	       target_vocabulary_id,
	       m.relationship_id,
	       current_date AS valid_start_date,
           to_date('20991231','yyyymmdd') AS valid_end_date,
           m.cr_invalid_reason
	FROM vocab_manual_lookup m
	--Only related to specific vocabulary
	WHERE (vocabulary_id = 'vocabulary' OR target_vocabulary_id = 'vocabulary')
	    AND target_concept_id != 0 AND target_concept_code IS NOT NULL
	
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
FROM vocab_manual_lookup m 
JOIN concept c 
ON c.concept_code = m.concept_code AND m.vocabulary_id = c.vocabulary_id 
JOIN concept_relationship cr 
ON cr.concept_id_1 = c.concept_id AND cr.relationship_id = m.relationship_id
JOIN concept c1 
ON c1.concept_id = cr.concept_id_2 AND c1.concept_code = m.target_concept_code AND c1.vocabulary_id = m.target_vocabulary_id
WHERE m.cr_invalid_reason IS NOT NULL
AND crm.concept_code_1 = m.concept_code AND crm.vocabulary_id_1 = m.vocabulary_id
AND crm.concept_code_2 = m.target_concept_code AND crm.vocabulary_id_2 = m.target_vocabulary_id
AND crm.relationship_id = m.relationship_id
AND crm.invalid_reason IS NOT NULL
;