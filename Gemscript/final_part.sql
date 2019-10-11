--concept_stage
TRUNCATE TABLE concept_stage;

INSERT INTO concept_stage
SELECT *
FROM basic_concept_stage;

--get the domains for gemscript concepts
UPDATE concept_stage cs
SET domain_id = tt.domain_id
FROM (
	SELECT domain_id,
		gemscript_code,
		thin_code
	FROM thin_need_to_map
	) tt
WHERE tt.gemscript_code = cs.concept_code

--get the domains for thin concepts
UPDATE concept_stage cs
SET domain_id = tt.domain_id
FROM (
	SELECT domain_id,
		gemscript_code,
		thin_code
	FROM thin_need_to_map
	) tt
WHERE tt.thin_code = cs.concept_code

--make devices standard (only for those that don't have mappings to dmd and gemscript) 
--define drug domain (Drug set by default) based on target concept domain in basic tables, so we can look on thin_need_to_map table
UPDATE concept_stage
SET standard_concept = 'S'
WHERE domain_id = 'Device'
	AND concept_code IN (
		SELECT gemscript_code
		FROM thin_need_to_map
		);

--concept_relationship_stage
TRUNCATE TABLE concept_relationship_stage;
INSERT INTO concept_relationship_stage
SELECT *
FROM basic_con_rel_stage;

DELETE
FROM concept_relationship_stage
WHERE invalid_reason = 'D';

--insert mappings from best_map
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
SELECT cs.concept_code,
	c.concept_code,
	cs.vocabulary_id,
	c.vocabulary_id,
	'Maps to',
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'Gemscript'
		),
	TO_DATE('20991231', 'yyyymmdd'),
	NULL
FROM map_drug b
JOIN concept_stage cs ON cs.concept_code = b.from_code
JOIN concept c ON c.concept_id = b.TO_ID;

--Devices mapping
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
SELECT b.concept_code,
	b.concept_code,
	b.vocabulary_id,
	b.vocabulary_id,
	'Maps to',
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'Gemscript'
		),
	TO_DATE('20991231', 'yyyymmdd'),
	NULL
FROM concept_stage b
WHERE b.domain_id = 'Device'
	--so no existing mappings present before
	AND b.concept_code NOT IN (
		SELECT concept_code_1
		FROM concept_relationship_stage
		);

--hard to follow the script that build relationships for Gemscript THIN
DELETE
FROM concept_relationship_stage cr
WHERE concept_code_1 IN (
		SELECT concept_code
		FROM concept_stage
		WHERE concept_class_id = 'Gemscript THIN'
		);

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
SELECT encrypted_drugcode,
	concept_code_2,
	'Gemscript',
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
FROM THIN_GEMSC_DMD_0717
JOIN concept_relationship_stage ON GEMSCRIPT_DRUGCODE = concept_code_1;

--procedures 
-- Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;
/

-- Add mapping from deprecated to fresh concepts, and also from non-standard to standard concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;
/

-- Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;
/

-- Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;
/

--select count(*) from concept_relationship_Stage join concept_stage on  concept_code = concept_code_1;
--select count(*) from concept_relationship_Stage join concept_stage on  concept_code = concept_code_1;