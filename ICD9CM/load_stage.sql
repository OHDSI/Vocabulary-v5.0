/**************************************************************************
* Copyright 2016 Observational Health Data Sciences and Informatics (OHDSI)
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
* 
* Authors: Timur Vakhitov, Christian Reich
* Date: 2017
**************************************************************************/

-- 1. Update latest_update field to new date
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
		pVocabularyName			=> 'ICD9CM',
		pVocabularyDate			=> (SELECT vocabulary_date FROM sources.cms_desc_short_dx LIMIT 1),
		pVocabularyVersion		=> (SELECT vocabulary_version FROM sources.cms_desc_short_dx LIMIT 1),
		pVocabularyDevSchema	=> 'DEV_ICD9CM'
	);
END $_$;

-- 2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3. Load into concept_stage from CMS_DESC_LONG_DX
INSERT INTO concept_stage (
	concept_name,
	domain_id,
	vocabulary_id,
	concept_class_id,
	standard_concept,
	concept_code,
	valid_start_date,
	valid_end_date
	)
SELECT NAME AS concept_name,
	NULL AS domain_id,
	'ICD9CM' AS vocabulary_id,
	CASE 
		WHEN SUBSTR(code, 1, 1) = 'V'
			THEN LENGTH(code) || '-dig billing V code'
		WHEN SUBSTR(code, 1, 1) = 'E'
			THEN LENGTH(code) - 1 || '-dig billing E code'
		ELSE LENGTH(code) || '-dig billing code'
		END AS concept_class_id,
	NULL AS standard_concept,
	CASE -- add dots to the codes
		WHEN SUBSTR(code, 1, 1) = 'V'
			THEN REGEXP_REPLACE(code, 'V([0-9]{2})([0-9]+)', 'V\1.\2','g') -- Dot after 2 digits for V codes
		WHEN SUBSTR(code, 1, 1) = 'E'
			THEN REGEXP_REPLACE(code, 'E([0-9]{3})([0-9]+)', 'E\1.\2','g') -- Dot after 3 digits for E codes
		ELSE REGEXP_REPLACE(code, '^([0-9]{3})([0-9]+)', '\1.\2','g') -- Dot after 3 digits for normal codes
		END AS concept_code,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'ICD9CM'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM sources.cms_desc_long_dx;

--4. Add codes which are not in the cms_desc_long_dx table
INSERT INTO concept_stage (
	concept_name,
	domain_id,
	vocabulary_id,
	concept_class_id,
	standard_concept,
	concept_code,
	valid_start_date,
	valid_end_date
	)
SELECT vocabulary_pack.CutConceptName(str) AS concept_name,
	NULL AS domain_id,
	'ICD9CM' AS vocabulary_id,
	CASE 
		WHEN SUBSTR(code, 1, 1) = 'V'
			THEN LENGTH(REPLACE(code, '.', '')) || '-dig nonbill V code'
		WHEN SUBSTR(code, 1, 1) = 'E'
			THEN LENGTH(REPLACE(code, '.', '')) - 1 || '-dig nonbill E code'
		ELSE LENGTH(REPLACE(code, '.', '')) || '-dig nonbill code'
		END AS concept_class_id,
	NULL AS standard_concept,
	code AS concept_code,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'ICD9CM'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM sources.mrconso
WHERE sab = 'ICD9CM'
	AND NOT code LIKE '%-%'
	AND tty = 'HT'
	AND position('.' IN code) <> 3 -- Dot in 3rd position in Procedure codes, in UMLS also called ICD9CM
	AND LENGTH(code) <> 2 -- Procedure code
	AND code NOT IN (
		SELECT concept_code
		FROM concept_stage
		WHERE vocabulary_id = 'ICD9CM'
		)
	AND suppress = 'N';

--5. load into concept_synonym_stage name from both cms_desc_long_dx.txt and CMS_DESC_SHORT_DX
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_name,
	synonym_vocabulary_id,
	language_concept_id
	)
SELECT CASE -- add dots to the codes
		WHEN SUBSTR(code, 1, 1) = 'V'
			THEN REGEXP_REPLACE(code, 'V([0-9]{2})([0-9]+)', 'V\1.\2','g') -- Dot after 2 digits for V codes
		WHEN SUBSTR(code, 1, 1) = 'E'
			THEN REGEXP_REPLACE(code, 'E([0-9]{3})([0-9]+)', 'E\1.\2','g') -- Dot after 3 digits for E codes
		ELSE REGEXP_REPLACE(code, '^([0-9]{3})([0-9]+)', '\1.\2','g') -- Dot after 3 digits for normal codes
		END AS synonym_concept_code,
	NAME AS synonym_name,
	'ICD9CM' AS synonym_vocabulary_id,
	4180186 AS language_concept_id -- English
FROM (
	SELECT *
	FROM sources.cms_desc_long_dx
	
	UNION
	
	SELECT code,
		name
	FROM sources.cms_desc_short_dx
	) AS s0;

--6. Add codes which are not in the cms_desc_long_dx table as a synonym
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_name,
	synonym_vocabulary_id,
	language_concept_id
	)
SELECT code AS synonym_concept_code,
	vocabulary_pack.CutConceptSynonymName(str) AS synonym_name,
	'ICD9CM' AS vocabulary_id,
	4180186 AS language_concept_id -- English
FROM sources.mrconso
WHERE sab = 'ICD9CM'
	AND NOT code LIKE '%-%'
	AND tty = 'HT'
	AND position('.' IN code) <> 3 -- Dot in 3rd position in Procedure codes, in UMLS also called ICD9CM
	AND LENGTH(code) <> 2 -- Procedure code
	AND code NOT IN (
		SELECT concept_code
		FROM concept_stage
		WHERE vocabulary_id = 'ICD9CM'
		)
	AND suppress = 'N';
/*
--7. Create text for Medical Coder with new codes and mappings
SELECT c.concept_code AS concept_code_1,
	u2.scui AS concept_code_2,
	'Maps to' AS relationship_id, -- till here strawman for concept_relationship to be checked and filled out, the remaining are supportive information to be truncated in the return file
	c.concept_name AS icd9_name,
	u2.str AS snomed_str,
	sno.concept_id AS snomed_concept_id,
	sno.concept_name AS snomed_name
FROM concept_stage c
LEFT JOIN (
	-- UMLS record for ICD9 code
	SELECT DISTINCT cui,
		scui
	FROM SOURCES.mrconso
	WHERE sab = 'ICD9CM'
		AND suppress NOT IN (
			'E',
			'O',
			'Y'
			)
	) u1 ON u1.scui = concept_code -- join UMLS for code one
LEFT JOIN (
	-- UMLS record for SNOMED code of the same cui
	SELECT DISTINCT cui,
		scui,
		FIRST_VALUE(str) OVER (
			PARTITION BY scui ORDER BY CASE tty
					WHEN 'PT'
						THEN 1
					WHEN 'PTGB'
						THEN 2
					ELSE 10
					END
			) AS str
	FROM SOURCES.mrconso
	WHERE sab IN ('SNOMEDCT_US')
		AND suppress NOT IN (
			'E',
			'O',
			'Y'
			)
	) u2 ON u2.cui = u1.cui
LEFT JOIN concept sno ON sno.vocabulary_id = 'SNOMED'
	AND sno.concept_code = u2.scui -- SNOMED concept
WHERE c.vocabulary_id = 'ICD9CM'
	AND NOT EXISTS (
		SELECT 1
		FROM concept co
		WHERE co.concept_code = c.concept_code
			AND co.vocabulary_id = 'ICD9CM'
		) limit 10;-- only new codes we don't already have
*/
--7. Add manual concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualConcepts();
END $_$;

--8. Append resulting file from Medical Coder (in concept_relationship_stage format) to concept_relationship_stage
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--9. Add "subsumes" relationship between concepts where the concept_code is like of another
CREATE INDEX IF NOT EXISTS trgm_idx ON concept_stage USING GIN (concept_code devv5.gin_trgm_ops); --for LIKE patterns
ANALYZE concept_stage;

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
SELECT c1.concept_code AS concept_code_1,
	c2.concept_code AS concept_code_2,
	c1.vocabulary_id AS vocabulary_id_1,
	c1.vocabulary_id AS vocabulary_id_2,
	'Subsumes' AS relationship_id,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = c1.vocabulary_id
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM concept_stage c1,
	concept_stage c2
WHERE c2.concept_code LIKE c1.concept_code || '%'
	AND c1.concept_code <> c2.concept_code
	AND NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage r_int
		WHERE r_int.concept_code_1 = c1.concept_code
			AND r_int.concept_code_2 = c2.concept_code
			AND r_int.relationship_id = 'Subsumes'
		);
DROP INDEX trgm_idx;

--10. Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

--11. Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

--12. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--13. Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;

--14. Add mapping from deprecated to fresh concepts for 'Maps to value'
--DO $_$
--BEGIN
--	PERFORM VOCABULARY_PACK.AddFreshMapsToValue();
--END $_$;

--15. Update domain_id for ICD9CM
UPDATE concept_stage cs
SET domain_id = i.domain_id
FROM (
	(
		SELECT DISTINCT ON (cs1.concept_code) cs1.concept_code,
			c2.domain_id
		FROM concept_relationship_stage crs
		JOIN concept_stage cs1 ON cs1.concept_code = crs.concept_code_1
			AND cs1.vocabulary_id = crs.vocabulary_id_1
			AND cs1.vocabulary_id = 'ICD9CM'
		JOIN concept c2 ON c2.concept_code = crs.concept_code_2
			AND c2.vocabulary_id = crs.vocabulary_id_2
		    --AND c2.vocabulary_id = 'SNOMED'
		WHERE crs.relationship_id = 'Maps to'
			--AND crs.invalid_reason IS NULL
		ORDER BY cs1.concept_code,
			CASE c2.domain_id
				WHEN 'Condition'
					THEN 1
				WHEN 'Observation'
					THEN 2
				WHEN 'Procedure'
					THEN 3
				WHEN 'Measurement'
					THEN 4
				WHEN 'Device'
					THEN 5
				END
		)
	
	UNION
	
	(
		SELECT DISTINCT ON (cs1.concept_code) cs1.concept_code,
			c2.domain_id
		FROM concept_relationship cr
		JOIN concept c1 ON c1.concept_id = cr.concept_id_1
			AND c1.vocabulary_id = 'ICD9CM'
		JOIN concept c2 ON c2.concept_id = cr.concept_id_2
		        --AND c2.vocabulary_id = 'SNOMED'
		JOIN concept_stage cs1 ON cs1.concept_code = c1.concept_code
			AND cs1.vocabulary_id = c1.vocabulary_id
		WHERE cr.relationship_id = 'Maps to'
			--AND cr.invalid_reason IS NULL
			AND NOT EXISTS (
				SELECT 1
				FROM concept_relationship_stage crs_int
				WHERE crs_int.concept_code_1 = cs1.concept_code
					AND crs_int.vocabulary_id_1 = cs1.vocabulary_id
					AND crs_int.relationship_id = cr.relationship_id
				)
		ORDER BY cs1.concept_code,
			CASE c2.domain_id
				WHEN 'Condition'
					THEN 1
				WHEN 'Observation'
					THEN 2
				WHEN 'Procedure'
					THEN 3
				WHEN 'Measurement'
					THEN 4
				WHEN 'Device'
					THEN 5
				END
		)
	) i
WHERE i.concept_code = cs.concept_code
	AND cs.vocabulary_id = 'ICD9CM';

--16. Check for NULL in domain_id
ALTER TABLE concept_stage ALTER COLUMN domain_id SET NOT NULL;
ALTER TABLE concept_stage ALTER COLUMN domain_id DROP NOT NULL;

--17. Build reverse relationship. This is necessary for next point
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

--18. Deprecate all relationships in concept_relationship that aren't exist in concept_relationship_stage
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
SELECT a.concept_code,
	b.concept_code,
	a.vocabulary_id,
	b.vocabulary_id,
	relationship_id,
	r.valid_start_date,
	CURRENT_DATE,
	'D'
FROM concept a
JOIN concept_relationship r ON a.concept_id = concept_id_1
	AND r.invalid_reason IS NULL
	AND r.relationship_id NOT IN (
		'Concept replaced by',
		'Concept replaces'
		)
JOIN concept b ON b.concept_id = concept_id_2
WHERE 'ICD9CM' IN (
		a.vocabulary_id,
		b.vocabulary_id
		)
	AND NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs_int
		WHERE crs_int.concept_code_1 = a.concept_code
			AND crs_int.concept_code_2 = b.concept_code
			AND crs_int.vocabulary_id_1 = a.vocabulary_id
			AND crs_int.vocabulary_id_2 = b.vocabulary_id
			AND crs_int.relationship_id = r.relationship_id
		);

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script