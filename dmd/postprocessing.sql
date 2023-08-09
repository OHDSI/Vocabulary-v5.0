/*;
update concept_relationship
set
	invalid_reason = 'D',
	valid_end_date = current_date - 1
where
	concept_id_1 in 
		(
			select c.concept_id
			from concept c
			join concept_relationship_stage r on
				r.concept_code_1 = c.concept_code and
				r.vocabulary_id_1 = c.vocabulary_id	and
				r.vocabulary_id_2 = 'CVX'
		) and
	relationship_id = 'Maps to'
;
update concept_relationship
set
	invalid_reason = 'D',
	valid_end_date = current_date - 1
where
	concept_id_2 in 
		(
			select c.concept_id
			from concept c
			join concept_relationship_stage r on
				r.concept_code_1 = c.concept_code and
				r.vocabulary_id_1 = c.vocabulary_id	and
				r.vocabulary_id_2 = 'CVX'
		) and
	relationship_id = 'Mapped from'*/
; -- old mappings to RxN* are not deprecated automatically

--DROP TABLE concept_relationship_stage_backup, concept_stage_backup, drug_concept_stage_backup;
--CREATE TABLE concept_relationship_stage_backup AS (SELECT * FROM concept_relationship_stage);
--CREATE TABLE concept_stage_backup AS (SELECT * FROM concept_stage);
--CREATE TABLE drug_concept_stage_backup AS (SELECT * FROM drug_concept_stage);

--TRUNCATE concept_relationship_stage, concept_stage, drug_concept_stage;

--INSERT INTO concept_relationship_stage (SELECT * FROM concept_relationship_stage_backup);
--INSERT INTO concept_stage (SELECT * FROM concept_stage_backup);
--INSERT INTO drug_concept_stage (SELECT * FROM drug_concept_stage_backup);



--Save CVX mappings from relationship_to_concept
INSERT INTO concept_relationship_stage
SELECT DISTINCT
	NULL :: int4,
	NULL :: int4,
	c.concept_code,
	c2.concept_code,
	'dm+d',
	c2.vocabulary_id,
	'Maps to',
	r.valid_start_date,
	current_date - 1,
	'D'
FROM concept_relationship r
JOIN concept c ON
	c.concept_id = r.concept_id_1 AND
	c.vocabulary_id = 'dm+d' AND
	r.relationship_id = 'Maps to'
JOIN relationship_to_concept t ON
	c.concept_code = t.concept_code_1
JOIN concept cx ON
	cx.concept_id = t.concept_id_2 AND
	cx.vocabulary_id = 'CVX'
JOIN concept c2 ON
	c2.concept_id = r.concept_id_2
WHERE c2.vocabulary_id LIKE 'RxN%'
;


INSERT INTO concept_relationship_stage
SELECT
	NULL,
	NULL,
	r.concept_code_1,
	c.concept_code,
	'dm+d',
	c.vocabulary_id,
	'Maps to',
	current_date,
	TO_DATE('20991231','yyyymmdd'),
	null
FROM relationship_to_concept r
JOIN concept c ON
	r.concept_id_2 = c.concept_id AND
	(
		c.vocabulary_id = 'CVX' OR
		c.concept_class_id ~ '(Drug|Pack)'
	)
    --Avoiding duplication
WHERE NOT EXISTS
(
    SELECT * FROM concept_relationship_stage crs1
    WHERE r.concept_code_1 = crs1.concept_code_1
        AND c.concept_code = crs1.concept_code_2
        AND c.vocabulary_id = crs1.vocabulary_id_2
        AND crs1.invalid_reason IS NULL
    )
;


--Devices can and should be mapped to SNOMED as they are the same concepts
INSERT INTO concept_relationship_stage
SELECT DISTINCT
	NULL :: int4 as concept_id_1,
	NULL :: int4 as concept_id_2,
	c.concept_code as concept_code_1,
	x.concept_code as concept_code_2,
	'dm+d',
	'SNOMED',
	'Maps to',
	current_date as valid_start_date,
	to_date ('20991231','yyyymmdd') as valid_end_date,
	NULL as invalid_reason
FROM concept_stage c
JOIN concept x
    ON x.concept_code = c.concept_code
    AND x.invalid_reason IS NULL
    AND x.vocabulary_id = 'SNOMED'
    AND x.standard_concept = 'S'
    AND x.domain_id = 'Device'
    AND -- some are Observations, we don't want them
        c.vocabulary_id = 'dm+d'
    AND c.domain_id = 'Device'
    --Avoiding duplication
WHERE NOT EXISTS
(
    SELECT * FROM concept_relationship_stage crs1
    WHERE c.concept_code = crs1.concept_code_1
        AND x.concept_code = crs1.concept_code_2
        AND crs1.vocabulary_id_2 = 'SNOMED'
        AND crs1.invalid_reason IS NULL
    )
;


--SNOMED mappings now take precedence
UPDATE concept_relationship_stage r
SET
	invalid_reason = 'D',
	valid_end_date = 
	(
        SELECT MAX(latest_update) - 1
        FROM vocabulary
        WHERE vocabulary_id IN (r.vocabulary_id_1, r.vocabulary_id_2)
              AND latest_update IS NOT NULL
      )
WHERE
	vocabulary_id_2 != 'SNOMED' AND
	relationship_id = 'Maps to' AND
	invalid_reason IS NULL AND
	exists
		(
			SELECT
			FROM concept_relationship_stage
			WHERE
				concept_code_1 = r.concept_code_1 AND
				vocabulary_id_2 = 'SNOMED' AND
				relationship_id = 'Maps to'
		)
;


--Destandardise devices, that are mapped to SNOMED
UPDATE concept_stage
SET standard_concept = NULL
WHERE
	domain_id = 'Device' AND
	vocabulary_id = 'dm+d' AND
	exists
		(
			SELECT
			FROM concept_relationship_stage
			WHERE
				concept_code_1 = concept_code AND
				relationship_id = 'Maps to' AND
				vocabulary_id_2 = 'SNOMED'
		)
;


ANALYZE concept_relationship_stage;


--Delete useless deprecations (non-existent relations)
DELETE FROM concept_relationship_stage i
WHERE
	(concept_code_1, vocabulary_id_1, concept_code_2, vocabulary_id_2/*, relationship_id*/) NOT IN
	(
		SELECT
			c1.concept_code,
			c1.vocabulary_id,
			c2.concept_code,
			c2.vocabulary_id/*,
			r.relationship_id*/
		FROM concept_relationship r
		JOIN concept c1 ON
			c1.concept_id = r.concept_id_1 AND
			(c1.concept_code, c1.vocabulary_id) = (i.concept_code_1, i.vocabulary_id_1)
		JOIN concept c2 ON
			c2.concept_id = r.concept_id_2 AND
			(c2.concept_code, c2.vocabulary_id) = (i.concept_code_2, i.vocabulary_id_2)
	) AND
	invalid_reason IS NOT NULL
;


--add replacements for VMPs, replaced by source
--these concepts are absent in sources, but already available in Athena from previous releases
INSERT INTO concept_stage
SELECT
	NULL :: int4 AS concept_id,
	coalesce (v.nmprev, v.nm) AS concept_name,
	CASE --take domain ID from replacement drug
		WHEN d.vpid IS NULL THEN 'Drug'
		ELSE 'Device'
	END AS domain_id,
	'dm+d',
	'VMP',
	NULL :: varchar AS standard_concept,
	v.vpidprev AS concept_code,
	to_date ('19700101','yyyymmdd') AS valid_start_date,
	coalesce (v.NMDT, current_date - 1) AS valid_end_date,
	'U' AS invalid_reason
FROM vmps v
LEFT JOIN vmps u ON --make sure old code was not processed on it's own
	v.vpidprev = u.vpid
LEFT JOIN devices d ON u.vpid = d.vpid
WHERE
	v.vpidprev IS NOT NULL AND
	u.vpid IS NULL
;


--Get replacement mappings for deprecated VMPs
INSERT INTO concept_relationship_stage
SELECT DISTINCT
	NULL :: int4,
	NULL :: int4,
	v.vpidprev,
	v.vpid,
	'dm+d',
	'dm+d',
	'Maps to',
	(SELECT vocabulary_date FROM sources.f_lookup2 LIMIT 1),
	TO_DATE('20991231','yyyymmdd'),
	NULL
FROM vmps v
WHERE vpidprev IS NOT NULL AND
	vpidprev NOT IN (SELECT concept_code_1 FROM concept_relationship_stage WHERE invalid_reason IS NULL)
;

--deprecate all old maps
INSERT INTO concept_relationship_stage
SELECT DISTINCT
	NULL :: int4,
	NULL :: int4,
	c.concept_code,
	c2.concept_code,
	'dm+d',
	c2.vocabulary_id,
	'Maps to',
	r.valid_start_date,
	current_date - 1,
	'D'
FROM concept_relationship r
JOIN concept c ON
	c.concept_id = r.concept_id_1 AND
	c.vocabulary_id = 'dm+d' AND
	r.relationship_id = 'Maps to'
JOIN concept_stage cs ON
	cs.concept_code = c.concept_code
JOIN concept c2 ON
	c2.concept_id = r.concept_id_2
WHERE
	NOT exists
		(
			SELECT 1
			FROM concept_relationship_stage
			WHERE
				concept_code_1 = c.concept_code AND
				concept_code_2 = c2.concept_code AND
				vocabulary_id_2 = c2.vocabulary_id
		)
  --Except for relationships between deprecated and fresh concepts inside dm+d
AND c2.vocabulary_id != 'dm+d'
;

--delete mapping from concept_relationship_stage if it exists in concept_relationship_manual
DELETE
FROM concept_relationship_stage
WHERE exists (
    SELECT * FROM concept_relationship_manual crm
    WHERE crm.concept_code_1 = concept_relationship_stage.concept_code_1
          );

--Integration of manual mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

-- Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

-- Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

-- Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--deprecate old ingredient mappings
UPDATE concept_relationship_stage crs
SET invalid_reason = 'D',
    valid_end_date = current_date
FROM concept c
JOIN concept_relationship r ON
	r.concept_id_1 = c.concept_id AND
	r.relationship_id = 'Maps to' AND
	r.invalid_reason IS NULL AND
	c.vocabulary_id = 'dm+d'
JOIN concept c2 ON
	c2.concept_id = r.concept_id_2 AND
	c2.concept_class_id = 'Ingredient'
LEFT JOIN internal_relationship_stage i ON
	i.concept_code_2 = c.concept_code
WHERE
	i.concept_code_2 IS NULL AND
	c.concept_class_id NOT IN
		('VMP','AMP','VMPP','AMPP')

AND crs.concept_code_1 = c.concept_code
AND crs.concept_code_2 = c2.concept_code
AND crs.vocabulary_id_1 = c.vocabulary_id
AND crs.vocabulary_id_2 = c2.vocabulary_id
AND crs.relationship_id = 'Maps to'
;



--Final manual changes
UPDATE concept_stage SET concept_name = trim(concept_name);
DELETE FROM concept_relationship_stage WHERE concept_code_1 = '8203003' AND invalid_reason IS NULL;

--Deduplication of concept_stage, concept_relationship_stage table
DELETE FROM concept_relationship_stage s 
WHERE EXISTS (SELECT 1 FROM concept_relationship_stage s_int 
                WHERE coalesce(s_int.concept_id_1, 'x') = coalesce(s.concept_id_1, 'x')
                  AND coalesce(s_int.concept_id_2, 'x') = coalesce(s.concept_id_2, 'x') 
                  AND coalesce(s_int.concept_code_1, 'x') = coalesce(s.concept_code_1, 'x') 
                  AND coalesce(s_int.concept_code_2, 'x') = coalesce(s.concept_code_2, 'x')
                  AND coalesce(s_int.relationship_id, 'x') = coalesce(s.relationship_id, 'x')
                  AND coalesce(s_int.vocabulary_id_1, 'x') = coalesce(s.vocabulary_id_1, 'x')
                  AND coalesce(s_int.vocabulary_id_2, 'x') = coalesce(s.vocabulary_id_2, 'x')
                  AND coalesce(s_int.valid_start_date, 'x') = coalesce(s.valid_start_date, 'x')
                  AND coalesce(s_int.valid_end_date, 'x') = coalesce(s.valid_end_date, 'x')
                  AND coalesce(s_int.invalid_reason, 'x') = coalesce(s.invalid_reason, 'x')
                  AND s_int.ctid > s.ctid);


DELETE FROM concept_stage s 
WHERE EXISTS (SELECT 1 FROM concept_stage s_int 
                WHERE coalesce(s_int.concept_id, 'x') = coalesce(s.concept_id, 'x')
                  AND coalesce(s_int.concept_name, 'x') = coalesce(s.concept_name, 'x') 
                  AND coalesce(s_int.domain_id, 'x') = coalesce(s.domain_id, 'x')
                  AND coalesce(s_int.vocabulary_id, 'x') = coalesce(s.vocabulary_id, 'x')
                  AND coalesce(s_int.concept_class_id, 'x') = coalesce(s.concept_class_id, 'x')
                  AND coalesce(s_int.standard_concept, 'x') = coalesce(s.standard_concept, 'x')
                  AND coalesce(s_int.concept_code, 'x') = coalesce(s.concept_code, 'x')
                  AND coalesce(s_int.valid_start_date, 'x') = coalesce(s.valid_start_date, 'x')
                  AND coalesce(s_int.valid_end_date, 'x') = coalesce(s.valid_end_date, 'x')
                  AND coalesce(s_int.invalid_reason, 'x') = coalesce(s.invalid_reason, 'x')
                  AND s_int.ctid > s.ctid);