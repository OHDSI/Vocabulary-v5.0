--DROP TABLE concept_relationship_stage_backup, concept_stage_backup;
--CREATE TABLE concept_relationship_stage_backup AS (SELECT * FROM concept_relationship_stage);
--CREATE TABLE concept_stage_backup AS (SELECT * FROM concept_stage);
--TRUNCATE concept_relationship_stage, concept_stage;

--INSERT INTO concept_relationship_stage (SELECT * FROM concept_relationship_stage_backup);
--INSERT INTO concept_stage (SELECT * FROM concept_stage_backup);

-- replace mapping for concepts which are already exist, but change attributes
-- excl supplier, they will be created as new Marketed Products
-- first define concepts with new suppliers
DROP TABLE IF EXISTS NEW_SUPP;

CREATE TABLE NEW_SUPP AS (
SELECT
	DISTINCT COALESCE(CS.CONCEPT_CODE,
	CC1.CONCEPT_CODE) AS NEW_SUPP_CODE,
	COALESCE (CS.CONCEPT_NAME,
	CC1.CONCEPT_NAME) AS NEW_SUPP_NAME,
	CS1.CONCEPT_CODE AS NEW_PROD_CODE,
	CS1.CONCEPT_NAME AS NEW_PROD_NAME,
	CS1.VOCABULARY_ID AS NEW_PROD_VOCAB
FROM CONCEPT_RELATIONSHIP_STAGE CRS
LEFT JOIN CONCEPT_STAGE CS
	ON CRS.CONCEPT_CODE_1 = CS.CONCEPT_CODE
	AND CRS.VOCABULARY_ID_1 = CS.VOCABULARY_ID
LEFT JOIN CONCEPT_STAGE CS1 
	ON CS1.CONCEPT_CODE = CRS.CONCEPT_CODE_2
	AND CRS.VOCABULARY_ID_2 = CS1.VOCABULARY_ID
LEFT JOIN CONCEPT CC1 
	ON CC1.CONCEPT_CODE = CRS.CONCEPT_CODE_1
	AND CC1.VOCABULARY_ID = CRS.VOCABULARY_ID_1
WHERE
	CRS.RELATIONSHIP_ID = 'Supplier of'
);

-- extract existing concepts with suppliers
DROP TABLE IF EXISTS OLD_SUPP;

CREATE TABLE OLD_SUPP AS (
SELECT
	DISTINCT C.CONCEPT_CODE AS OLD_SUPP_CODE,
	C.CONCEPT_NAME AS OLD_SUPP_NAME,
	CC.CONCEPT_ID AS OLD_PROD_ID,
	CC.CONCEPT_CODE AS OLD_PROD_CODE,
	CC.CONCEPT_NAME AS OLD_PROD_NAME
FROM CONCEPT C
JOIN CONCEPT_RELATIONSHIP CR 
	ON CR.CONCEPT_ID_1 = C.CONCEPT_ID
	AND CR.INVALID_REASON IS NULL
JOIN CONCEPT CC 
	ON CC.CONCEPT_ID = CR.CONCEPT_ID_2
WHERE
	CC.VOCABULARY_ID = 'RxNorm Extension'
	AND CR.RELATIONSHIP_ID = 'Supplier of'
);

-- check what will change
DROP TABLE IF EXISTS SUPPLIER_CHANGES;

CREATE TABLE SUPPLIER_CHANGES AS 
SELECT
	DISTINCT CS2.CONCEPT_CODE AS DMD_CODE,
	CS2.CONCEPT_NAME AS NEW_DMD_NAME,
	C2.CONCEPT_NAME AS OLD_DMD_NAME,
	NEW_SUPP.*,
	OLD_SUPP.*
FROM CONCEPT_RELATIONSHIP_STAGE CRS1
JOIN CONCEPT_STAGE CS2 
	ON CS2.CONCEPT_CODE = CRS1.CONCEPT_CODE_1
	AND CS2.VOCABULARY_ID = CRS1.VOCABULARY_ID_1
JOIN CONCEPT C2 
	ON C2.CONCEPT_CODE = CRS1.CONCEPT_CODE_1
	AND C2.VOCABULARY_ID = CRS1.VOCABULARY_ID_1
JOIN CONCEPT_RELATIONSHIP CR1 
	ON CR1.CONCEPT_ID_1 = C2.CONCEPT_ID
JOIN NEW_SUPP 
	ON CRS1.CONCEPT_CODE_2 = NEW_SUPP.NEW_PROD_CODE
	AND CRS1.VOCABULARY_ID_2 = NEW_SUPP.NEW_PROD_VOCAB
JOIN OLD_SUPP
	ON CR1.CONCEPT_ID_2 = OLD_SUPP.OLD_PROD_ID
WHERE
	CRS1.VOCABULARY_ID_1 = 'dm+d'
	AND OLD_SUPP.OLD_SUPP_CODE != NEW_SUPP.NEW_SUPP_CODE;

-- table to change mappings
DROP TABLE IF EXISTS TO_CHANGE_MAPPING;

CREATE TABLE TO_CHANGE_MAPPING AS 
SELECT
	DISTINCT CS.CONCEPT_CODE AS DMD_CODE,
	CS.CONCEPT_NAME AS DMD_NAME,
	CS.CONCEPT_CLASS_ID AS DMD_CLASS,
	CS.VOCABULARY_ID AS DMD_VOC,
	C.CONCEPT_CODE AS NEW_CODE,
	C.CONCEPT_NAME AS NEW_NAME,
	C.CONCEPT_CLASS_ID AS NEW_CLASS,
	C1.CONCEPT_CODE AS OLD_CODE,
	C1.CONCEPT_NAME AS OLD_NAME, 
	C1.CONCEPT_CLASS_ID AS OLD_CLASS,
	C1.VOCABULARY_ID AS OLD_VOC
FROM CONCEPT_STAGE CS
JOIN CONCEPT_RELATIONSHIP_STAGE CRS 
	ON CS.CONCEPT_CODE = CRS.CONCEPT_CODE_1
	AND CS.VOCABULARY_ID = CRS.VOCABULARY_ID_1
	AND CS.CONCEPT_CLASS_ID IN ('AMP', 'AMPP', 'VMP', 'VMPP')
	AND CRS.RELATIONSHIP_ID = 'Maps to'
JOIN CONCEPT_STAGE C 
	ON C.CONCEPT_CODE = CRS.CONCEPT_CODE_2
	AND C.VOCABULARY_ID = CRS.VOCABULARY_ID_2
JOIN CONCEPT CC 
	ON CS.CONCEPT_CODE = CC.CONCEPT_CODE
	AND CS.VOCABULARY_ID = CC.VOCABULARY_ID
	AND CC.INVALID_REASON IS NULL
JOIN CONCEPT_RELATIONSHIP CR 
	ON CR.CONCEPT_ID_1 = CC.CONCEPT_ID
	AND CR.INVALID_REASON IS NULL
	AND CR.RELATIONSHIP_ID = 'Maps to'
JOIN CONCEPT C1 
	ON C1.CONCEPT_ID = CR.CONCEPT_ID_2
	AND C1.VOCABULARY_ID LIKE 'Rx%'
	AND C1.INVALID_REASON IS NULL
WHERE
	NOT EXISTS (SELECT	1
	FROM SUPPLIER_CHANGES SC
	WHERE SC.DMD_CODE = CS.CONCEPT_CODE);

-- update the mapping
UPDATE CONCEPT_RELATIONSHIP_STAGE CRS
SET
	CONCEPT_CODE_2 = OLD_CODE,
	VOCABULARY_ID_2 = OLD_VOC
FROM TO_CHANGE_MAPPING TCM
WHERE CRS.CONCEPT_CODE_1 = TCM.DMD_CODE
	AND CRS.VOCABULARY_ID_1 = TCM.DMD_VOC;

-- delete unnecescary concepts
DELETE
FROM CONCEPT_STAGE CS
WHERE
	EXISTS (SELECT	1
	FROM TO_CHANGE_MAPPING CRS
	WHERE CS.CONCEPT_CODE = CRS.NEW_CODE)
	AND VOCABULARY_ID LIKE 'Rx%';

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
	EXISTS
		(
			SELECT
			FROM concept_relationship_stage
			WHERE
				concept_code_1 = concept_code AND
				relationship_id = 'Maps to' AND
				vocabulary_id_2 = 'SNOMED'
		);

ANALYZE concept_relationship_stage;

--Delete useless deprecations (non-existent relations)
DELETE FROM concept_relationship_stage crs
WHERE
  crs.invalid_reason IS NOT NULL
  AND NOT EXISTS (
    SELECT 1
    FROM concept c1
    JOIN concept_relationship r
      ON r.concept_id_1 = c1.concept_id
    JOIN concept c2
      ON r.concept_id_2 = c2.concept_id
    WHERE
      c1.concept_code   = crs.concept_code_1
      AND c1.vocabulary_id   = crs.vocabulary_id_1
      AND c2.concept_code   = crs.concept_code_2
      AND c2.vocabulary_id   = crs.vocabulary_id_2
      -- AND r.relationship_id = crs.relationship_id  -- un-comment if you need to match relationship_id
  );

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
    SELECT 1 FROM concept_relationship_manual crm
    WHERE crm.concept_code_1 = concept_relationship_stage.concept_code_1
    and crm.vocabulary_id_1 = concept_relationship_stage.vocabulary_id_1
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

--Deduplication of concept_stage, concept_relationship_stage table
WITH duplicates AS (
  SELECT
    ctid,
    ROW_NUMBER() OVER (
      PARTITION BY
        concept_id_1,
        concept_id_2,
        concept_code_1,
        concept_code_2,
        relationship_id,
        vocabulary_id_1,
        vocabulary_id_2,
        valid_start_date,
        valid_end_date,
        invalid_reason
      ORDER BY ctid
    ) AS rn
  FROM concept_relationship_stage
)
DELETE FROM concept_relationship_stage crs
USING duplicates d
WHERE
  crs.ctid = d.ctid
  AND d.rn > 1;

WITH duplicates AS (
  SELECT
    ctid,
    ROW_NUMBER() OVER (
      PARTITION BY
        concept_id,
        concept_name,
        domain_id,
        vocabulary_id,
        concept_class_id,
        standard_concept,
        concept_code,
        valid_start_date,
        valid_end_date,
        invalid_reason
      ORDER BY ctid
    ) AS rn
  FROM concept_stage
)
DELETE FROM concept_stage cs
USING duplicates d
WHERE
  cs.ctid = d.ctid
  AND d.rn > 1;
 
-- boiler takes vocabs not need in the refresh
DELETE
FROM CONCEPT_RELATIONSHIP_STAGE CRS
WHERE NOT EXISTS (SELECT 1
	FROM CONCEPT_STAGE CS
	WHERE (CS.CONCEPT_CODE = CRS.CONCEPT_CODE_1
		AND CS.VOCABULARY_ID = CRS.VOCABULARY_ID_1))
	AND NOT EXISTS (SELECT 1
	FROM CONCEPT_STAGE CS
	WHERE (CS.CONCEPT_CODE = CRS.CONCEPT_CODE_2
		AND CS.VOCABULARY_ID = CRS.VOCABULARY_ID_2));

DELETE
FROM CONCEPT_RELATIONSHIP_STAGE CRS
WHERE NOT EXISTS (SELECT	1
	FROM CONCEPT_STAGE CS
	WHERE CRS.CONCEPT_CODE_1 = CS.CONCEPT_CODE
		AND CRS.VOCABULARY_ID_1 = CS.VOCABULARY_ID);

DELETE
FROM CONCEPT_RELATIONSHIP_STAGE CRS
WHERE NOT EXISTS (SELECT	1
	FROM CONCEPT_STAGE CS
	WHERE CRS.CONCEPT_CODE_2 = CS.CONCEPT_CODE
		AND CRS.VOCABULARY_ID_2 = CS.VOCABULARY_ID)
	AND NOT EXISTS (SELECT	1
	FROM CONCEPT CS
	WHERE CRS.CONCEPT_CODE_2 = CS.CONCEPT_CODE
		AND CRS.VOCABULARY_ID_2 = CS.VOCABULARY_ID);