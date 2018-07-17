UPDATE concept_stage a
SET concept_name = b.concept_name
FROM complete_name b
WHERE a.concept_code = b.concept_code;

--inverse relationships
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT crs.concept_code_2,
	crs.concept_code_1,
	crs.vocabulary_id_2,
	crs.vocabulary_id_1,
	r.reverse_relationship_id,
	crs.valid_start_date,
	crs.valid_end_date,
	crs.invalid_reason
FROM concept_relationship_stage crs
JOIN relationship r ON r.relationship_id = crs.relationship_id
WHERE NOT EXISTS (
		-- the inverse record
		SELECT 1
		FROM concept_relationship_stage i
		WHERE crs.concept_code_1 = i.concept_code_2
			AND crs.concept_code_2 = i.concept_code_1
			AND crs.vocabulary_id_1 = i.vocabulary_id_2
			AND crs.vocabulary_id_2 = i.vocabulary_id_1
			AND r.reverse_relationship_id = i.relationship_id
		);

TRUNCATE TABLE concept_relationship_manual;

--contains deprecated concepts 
INSERT INTO concept_relationship_manual
SELECT c1.concept_code,
	c2.concept_code,
	c1.vocabulary_id,
	c2.vocabulary_id,
	r.relationship_id,
	r.valid_start_date,
	TO_DATE('20160802', 'yyyymmdd'),
	'D'
FROM concept_relationship r
JOIN concept c1 ON r.concept_id_1 = c1.concept_id
JOIN concept c2 ON r.concept_id_2 = c2.concept_id
WHERE (
		c1.vocabulary_id = 'DA_France'
		OR c2.vocabulary_id = 'DA_France'
		)
	AND NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage b
		WHERE c1.concept_code = b.concept_code_1
			AND c2.concept_code = b.concept_code_2
			AND r.relationship_id = b.relationship_id
			AND vocabulary_id_1 = c1.vocabulary_id
			AND vocabulary_id_2 = c2.vocabulary_id
		);

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--concept_stage
DELETE
FROM concept_stage
WHERE concept_code LIKE 'OMOP%';

UPDATE concept_stage
SET standard_concept = NULL;

TRUNCATE TABLE drug_strength_stage;