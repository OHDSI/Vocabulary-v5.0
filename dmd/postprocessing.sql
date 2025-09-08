--DROP TABLE concept_relationship_stage_backup, concept_stage_backup;
--CREATE TABLE concept_relationship_stage_backup AS (SELECT * FROM concept_relationship_stage);
--CREATE TABLE concept_stage_backup AS (SELECT * FROM concept_stage);
--TRUNCATE concept_relationship_stage, concept_stage;

--INSERT INTO concept_relationship_stage (SELECT * FROM concept_relationship_stage_backup);
--INSERT INTO concept_stage (SELECT * FROM concept_stage_backup);

--18. Replace mapping for concepts which already exist, but change attributes
--18.1. Exclude suppliers; they will be created as new Marketed Products
--18.1.1. first define concepts with new suppliers
DROP TABLE IF EXISTS new_supp;

CREATE TABLE new_supp AS (
SELECT DISTINCT coalesce(cs.concept_code, cc1.concept_code) AS new_supp_code,
	coalesce (cs.concept_name, cc1.concept_name) AS new_supp_name,
	cs1.concept_code AS new_prod_code,
	cs1.concept_name AS new_prod_name,
	cs1.vocabulary_id AS new_prod_vocab
FROM concept_relationship_stage crs
LEFT JOIN concept_stage cs ON crs.concept_code_1 = cs.concept_code AND crs.vocabulary_id_1 = cs.vocabulary_id
LEFT JOIN concept_stage cs1 ON cs1.concept_code = crs.concept_code_2 AND crs.vocabulary_id_2 = cs1.vocabulary_id
LEFT JOIN concept cc1 ON cc1.concept_code = crs.concept_code_1 AND cc1.vocabulary_id = crs.vocabulary_id_1
WHERE crs.relationship_id = 'Supplier of'
);

--18.1.2. extract existing concepts with suppliers
DROP TABLE IF EXISTS old_supp;

CREATE TABLE old_supp AS (
SELECT DISTINCT c.concept_code AS old_supp_code,
	c.concept_name AS old_supp_name,
	cc.concept_id AS old_prod_id,
	cc.concept_code AS old_prod_code,
	cc.concept_name AS old_prod_name
FROM concept c
JOIN concept_relationship cr
	ON cr.concept_id_1 = c.concept_id
	AND cr.invalid_reason IS NULL
JOIN concept cc
	ON cc.concept_id = cr.concept_id_2
WHERE cc.vocabulary_id = 'RxNorm Extension'
	AND cr.relationship_id = 'Supplier of'
);

---18.1.3. check what will change
DROP TABLE IF EXISTS supplier_changes;

CREATE TABLE supplier_changes AS
SELECT DISTINCT cs2.concept_code AS dmd_code,
	cs2.concept_name AS new_dmd_name,
	c2.concept_name AS old_dmd_name,
	new_supp.*,
	old_supp.*
FROM concept_relationship_stage crs1
JOIN concept_stage cs2 ON cs2.concept_code = crs1.concept_code_1 AND cs2.vocabulary_id = crs1.vocabulary_id_1
JOIN concept c2 ON c2.concept_code = crs1.concept_code_1 AND c2.vocabulary_id = crs1.vocabulary_id_1 
JOIN concept_relationship cr1 ON cr1.concept_id_1 = c2.concept_id 
JOIN new_supp ON crs1.concept_code_2 = new_supp.new_prod_code AND crs1.vocabulary_id_2 = new_supp.new_prod_vocab
JOIN old_supp ON cr1.concept_id_2 = old_supp.old_prod_id
WHERE crs1.vocabulary_id_1 = 'dm+d'
	AND old_supp.old_supp_code != new_supp.new_supp_code;

--18.2. Table to change mappings
DROP TABLE IF EXISTS to_change_mapping;

CREATE TABLE to_change_mapping AS 
SELECT DISTINCT cs.concept_code AS dmd_code,
	cs.concept_name AS dmd_name,
	cs.concept_class_id AS dmd_class,
	cs.vocabulary_id AS dmd_voc,
	c.concept_code AS new_code,
	c.concept_name AS new_name,
	c.concept_class_id AS new_class,
	c1.concept_code AS old_code,
	c1.concept_name AS old_name, 
	c1.concept_class_id AS old_class,
	c1.vocabulary_id AS old_voc
FROM concept_stage cs
JOIN concept_relationship_stage crs ON cs.concept_code = crs.concept_code_1 AND cs.vocabulary_id = crs.vocabulary_id_1
	AND cs.concept_class_id IN ('AMP', 'AMPP', 'VMP', 'VMPP') AND crs.relationship_id = 'Maps to'
JOIN concept_stage c ON c.concept_code = crs.concept_code_2 AND c.vocabulary_id = crs.vocabulary_id_2
JOIN concept cc ON cs.concept_code = cc.concept_code AND cs.vocabulary_id = c.vocabulary_id AND cc.invalid_reason IS NULL
JOIN concept_relationship cr ON cr.concept_id_1 = cc.concept_id AND cr.invalid_reason IS NULL AND cr.relationship_id = 'Maps to'
JOIN concept c1 ON c1.concept_id = cr.concept_id_2 AND c1.vocabulary_id LIKE 'Rx%' AND c1.invalid_reason IS NULL
WHERE NOT EXISTS (SELECT 1
	FROM supplier_changes sc
	WHERE sc.dmd_code = cs.concept_code);

--18.3. Update the mapping
UPDATE concept_relationship_stage crs
SET
	concept_code_2 = old_code,
	vocabulary_id_2 = old_voc
FROM to_change_mapping tcm
WHERE crs.concept_code_1 = tcm.dmd_code
	AND crs.vocabulary_id_1 = tcm.dmd_voc;

-- 19. Delete unnecessary concepts
DELETE
FROM concept_stage cs
WHERE
	EXISTS (SELECT	1
	FROM to_change_mapping crs
	WHERE cs.concept_code = crs.new_code)
	AND vocabulary_id LIKE 'Rx%';

--19.1. Delete duplicates by name that already exist in concept
DROP TABLE IF EXISTS crs_remove_rxe_dublicates;

CREATE TABLE crs_remove_rxe_dublicates AS
SELECT DISTINCT crs.*, c.concept_code AS new_code
FROM concept_stage cs
JOIN concept_relationship_stage crs ON crs.concept_code_2 = cs.concept_code AND crs.relationship_id IN ('Source - RxNorm eq','Maps to')
JOIN concept c ON cs.concept_name = c.concept_name AND c.vocabulary_id = cs.vocabulary_id AND c.invalid_reason is null
WHERE cs.vocabulary_id = 'RxNorm Extension' 
AND crs.vocabulary_id_1 = 'dm+d'
;

UPDATE concept_relationship_stage a 
SET concept_code_2 = b.new_code
FROM crs_remove_rxe_dublicates b
WHERE a.concept_code_1 = b.concept_code_1 
AND a.concept_code_2 = b.concept_code_2;

DELETE FROM concept_stage 
WHERE concept_code IN (
    SELECT DISTINCT concept_code_2
    FROM crs_remove_rxe_dublicates
    );

--20. Devices can and should be mapped to SNOMED as they are the same concepts
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
JOIN concept x ON x.concept_code = c.concept_code
    AND x.invalid_reason IS NULL
    AND x.vocabulary_id = 'SNOMED'
    AND x.standard_concept = 'S'
    AND x.domain_id = 'Device' -- some are Observations, we don't want them
    AND c.vocabulary_id = 'dm+d'
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

--20.1. SNOMED mappings now take precedence
UPDATE concept_relationship_stage r
SET invalid_reason = 'D',
	valid_end_date = 
	(
        SELECT MAX(latest_update) - 1
        FROM vocabulary
        WHERE vocabulary_id IN (r.vocabulary_id_1, r.vocabulary_id_2)
              AND latest_update IS NOT NULL
      )
WHERE vocabulary_id_2 != 'SNOMED'
  AND relationship_id = 'Maps to'
  AND invalid_reason IS NULL
  AND EXISTS
		(
			SELECT
			FROM concept_relationship_stage
			WHERE concept_code_1 = r.concept_code_1
			  AND vocabulary_id_2 = 'SNOMED'
			  AND relationship_id = 'Maps to'
		)
;

--20.2. Destandardize devices that are mapped to SNOMED
UPDATE concept_stage
SET standard_concept = NULL
WHERE domain_id = 'Device'
  AND vocabulary_id = 'dm+d'
  AND EXISTS
		(
			SELECT
			FROM concept_relationship_stage
			WHERE concept_code_1 = concept_code
			  AND relationship_id = 'Maps to'
			  AND vocabulary_id_2 = 'SNOMED'
		);

ANALYZE concept_relationship_stage;

--21. Delete useless deprecations (non-existent relations)
DELETE FROM concept_relationship_stage crs
WHERE crs.invalid_reason IS NOT NULL
  AND NOT EXISTS (
    SELECT 1
    FROM concept c1
    JOIN concept_relationship r ON r.concept_id_1 = c1.concept_id
    JOIN concept c2 ON r.concept_id_2 = c2.concept_id
    WHERE c1.concept_code = crs.concept_code_1
      AND c1.vocabulary_id = crs.vocabulary_id_1
      AND c2.concept_code = crs.concept_code_2
      AND c2.vocabulary_id = crs.vocabulary_id_2
      -- AND r.relationship_id = crs.relationship_id -- uncomment if you need to match relationship_id
  );

--22. Add replacements for VMPs, replaced by source
--- These concepts are absent in sources, but already available in Athena from previous releases
INSERT INTO concept_stage
SELECT
	NULL :: int4 AS concept_id,
	coalesce (v.nmprev, v.nm) AS concept_name,
	CASE --take domain ID from the replacement drug
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
LEFT JOIN vmps u ON --make sure old code was not processed on its own
	v.vpidprev = u.vpid
LEFT JOIN devices d ON u.vpid = d.vpid
WHERE v.vpidprev IS NOT NULL
  AND u.vpid IS NULL
;

--23. Get replacement mappings for deprecated VMPs
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
WHERE vpidprev IS NOT NULL
  AND vpidprev NOT IN (SELECT concept_code_1 FROM concept_relationship_stage WHERE invalid_reason IS NULL)
;

--24. Deprecate all old mappings
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
JOIN concept c ON c.concept_id = r.concept_id_1 AND	c.vocabulary_id = 'dm+d' AND r.relationship_id = 'Maps to'
JOIN concept_stage cs ON cs.concept_code = c.concept_code
JOIN concept c2 ON c2.concept_id = r.concept_id_2
WHERE NOT EXISTS
		(
			SELECT 1
			FROM concept_relationship_stage
			WHERE concept_code_1 = c.concept_code
			  AND concept_code_2 = c2.concept_code
			  AND vocabulary_id_2 = c2.vocabulary_id
		)
  --Except for relationships between deprecated and fresh concepts inside dm+d
AND c2.vocabulary_id != 'dm+d'
;

--25. Delete mapping from concept_relationship_stage if it exists in concept_relationship_manual
DELETE
FROM concept_relationship_stage crs
WHERE EXISTS (
    SELECT 1 FROM concept_relationship_manual crm
    WHERE crm.concept_code_1 = crs.concept_code_1
    AND crm.vocabulary_id_1 = crs.vocabulary_id_1
          );

--26. Deprecate old ingredient mappings
UPDATE concept_relationship_stage crs
SET invalid_reason = 'D',
    valid_end_date = current_date
FROM concept c
JOIN concept_relationship r ON r.concept_id_1 = c.concept_id AND r.relationship_id = 'Maps to' AND r.invalid_reason IS NULL AND c.vocabulary_id = 'dm+d'
JOIN concept c2 ON c2.concept_id = r.concept_id_2 AND c2.concept_class_id = 'Ingredient'
LEFT JOIN internal_relationship_stage i ON i.concept_code_2 = c.concept_code
WHERE i.concept_code_2 IS NULL
  AND c.concept_class_id NOT IN ('VMP','AMP','VMPP','AMPP')
  AND crs.concept_code_1 = c.concept_code
  AND crs.concept_code_2 = c2.concept_code
  AND crs.vocabulary_id_1 = c.vocabulary_id
  AND crs.vocabulary_id_2 = c2.vocabulary_id
  AND crs.relationship_id = 'Maps to'
  AND NOT EXISTS (
            SELECT 1 FROM concept_relationship_manual crm
            WHERE crm.concept_code_1 = crs.concept_code_1
             AND crm.vocabulary_id_1 = crs.vocabulary_id_1
            );


--27. Integration of manual mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--28. Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

--29. Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

--30. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--31. Final manual changes
UPDATE concept_stage SET concept_name = trim(concept_name);

--32. Deduplication of concept_stage, concept_relationship_stage table
WITH duplicates AS (
  SELECT ctid,
    ROW_NUMBER() OVER (PARTITION BY concept_id_1, concept_id_2, concept_code_1, concept_code_2, relationship_id,
        vocabulary_id_1, vocabulary_id_2, valid_start_date, valid_end_date, invalid_reason ORDER BY ctid
    ) AS rn
  FROM concept_relationship_stage
)
DELETE FROM concept_relationship_stage crs
USING duplicates d
WHERE crs.ctid = d.ctid
  AND d.rn > 1;

WITH duplicates AS (
  SELECT ctid,
    ROW_NUMBER() OVER (PARTITION BY concept_id, concept_name, domain_id, vocabulary_id, concept_class_id,
        standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason ORDER BY ctid
    ) AS rn
  FROM concept_stage
)
DELETE FROM concept_stage cs
USING duplicates d
WHERE cs.ctid = d.ctid
  AND d.rn > 1;
 
--33. boiler takes vocabs not need in the refresh
DELETE
FROM concept_relationship_stage crs
WHERE NOT EXISTS (SELECT 1
	FROM concept_stage cs
	WHERE (cs.concept_code = crs.concept_code_1
		AND cs.vocabulary_id = crs.vocabulary_id_1))
	AND NOT EXISTS (SELECT 1
	FROM concept_stage cs
	WHERE (cs.concept_code = crs.concept_code_2
		AND cs.vocabulary_id = crs.vocabulary_id_2));

DELETE
FROM concept_relationship_stage crs
WHERE NOT EXISTS (SELECT	1
	FROM concept_stage cs
	WHERE crs.concept_code_1 = cs.concept_code
		AND crs.vocabulary_id_1 = cs.vocabulary_id);

DELETE
FROM concept_relationship_stage crs
WHERE NOT EXISTS (SELECT	1
	FROM concept_stage cs
	WHERE crs.concept_code_2 = cs.concept_code
		AND crs.vocabulary_id_2 = cs.vocabulary_id)
	AND NOT EXISTS (SELECT	1
	FROM concept cs
	WHERE crs.concept_code_2 = cs.concept_code
		AND crs.vocabulary_id_2 = cs.vocabulary_id);
	
DELETE FROM concept_stage cs
WHERE vocabulary_id = 'dm+d'
  AND NOT EXISTS (SELECT 1 FROM concept_relationship_stage crs WHERE cs.concept_code = crs.concept_code_1 AND invalid_reason IS NULL) 
  AND NOT EXISTS (SELECT 1 FROM concept c WHERE cs.concept_code = c.concept_code AND cs.vocabulary_id = c.vocabulary_id)
  AND concept_class_id IN ('Brand Name','Ingredient')
  AND concept_code LIKE 'OMOP%'
  ; 