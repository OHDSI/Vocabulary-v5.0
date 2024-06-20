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
	pVocabularyName			=> 'ICD10CM',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.icd10cm LIMIT 1),
	pVocabularyVersion		=> (SELECT vocabulary_version FROM sources.icd10cm LIMIT 1),
	pVocabularyDevSchema	=> 'DEV_ICD10CM'
);
END $_$;

-- 2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3. Load into concept_stage from ICD10CM
INSERT INTO concept_stage (
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
SELECT SUBSTR(CASE 
			WHEN LENGTH(LONG_NAME) > 255
				AND SHORT_NAME IS NOT NULL
				THEN SHORT_NAME
			ELSE LONG_NAME
			END, 1, 255) AS concept_name,
	NULL AS domain_id,
	'ICD10CM' AS vocabulary_id,
	CASE 
		WHEN CODE_TYPE = 1
			THEN LENGTH(code) || '-char billing code'
		ELSE LENGTH(code) || '-char nonbill code'
		END AS concept_class_id,
	NULL AS standard_concept,
	REGEXP_REPLACE(code, '([[:print:]]{3})([[:print:]]+)', '\1.\2') -- Dot after 3 characters
	AS concept_code,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'ICD10CM'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.icd10cm;

--4. Add manual concepts or changes
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualConcepts();
END $_$;

--5. Add ICD10CM to SNOMED manual mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--6. Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

--7. Add "subsumes" relationship between concepts where the concept_code is like of another
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

--8. Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

--9. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--10. Add mapping from deprecated to fresh concepts for 'Maps to value'
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMapsToValue();
END $_$;

--11. Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;

--12. Update domain_id for ICD10CM from target vocabularies
UPDATE concept_stage cs
SET domain_id = i.domain_id
FROM (
	(
		SELECT DISTINCT ON (cs1.concept_code) cs1.concept_code,
			c2.domain_id
		FROM concept_relationship_stage crs
		JOIN concept_stage cs1 ON cs1.concept_code = crs.concept_code_1
			AND cs1.vocabulary_id = crs.vocabulary_id_1
			AND cs1.vocabulary_id = 'ICD10CM'
		JOIN concept c2 ON c2.concept_code = crs.concept_code_2
			AND c2.vocabulary_id = crs.vocabulary_id_2
			AND c2.vocabulary_id IN (
				'SNOMED',
				'Cancer Modifier',
				'OMOP Extension'
				)
		WHERE crs.relationship_id = 'Maps to'
			AND crs.invalid_reason IS NULL
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
	
	UNION ALL
	
	(
		SELECT DISTINCT ON (cs1.concept_code) cs1.concept_code,
			c2.domain_id
		FROM concept_relationship cr
		JOIN concept c1 ON c1.concept_id = cr.concept_id_1
			AND c1.vocabulary_id = 'ICD10CM'
		JOIN concept c2 ON c2.concept_id = cr.concept_id_2
			AND c2.vocabulary_id IN (
				'SNOMED',
				'Cancer Modifier',
				'OMOP Extension'
				)
		JOIN concept_stage cs1 ON cs1.concept_code = c1.concept_code
			AND cs1.vocabulary_id = c1.vocabulary_id
		WHERE cr.relationship_id = 'Maps to'
			AND cr.invalid_reason IS NULL
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
	AND cs.vocabulary_id = 'ICD10CM';

--Update domain for tumor concepts
UPDATE concept_stage
SET domain_id = 'Condition'
WHERE concept_code ILIKE '%C%';

--TODO: check why the actual U* code limitation is not used.
--Only unassigned Emergency use codes (starting with U) don't have mappings to SNOMED, put Observation as closest meaning to Unknown domain
UPDATE concept_stage
SET domain_id = 'Observation'
WHERE domain_id IS NULL;

--13. Check for NULL in domain_id
ALTER TABLE concept_stage ALTER COLUMN domain_id SET NOT NULL;
ALTER TABLE concept_stage ALTER COLUMN domain_id DROP NOT NULL;

--14. Load into concept_synonym_stage name from ICD10CM
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_name,
	synonym_vocabulary_id,
	language_concept_id
	)
SELECT code AS synonym_concept_code,
	synonym_name,
	'ICD10CM' AS synonym_vocabulary_id,
	4180186 AS language_concept_id -- English
FROM (
	SELECT long_name AS synonym_name,
		REGEXP_REPLACE(code, '([[:print:]]{3})([[:print:]]+)', '\1.\2') AS code
	FROM sources.icd10cm
	
	UNION
	
	SELECT short_name AS synonym_name,
		REGEXP_REPLACE(code, '([[:print:]]{3})([[:print:]]+)', '\1.\2') AS code
	FROM sources.icd10cm
	) AS s0;

--15. Working with manual synonyms
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualSynonyms();
END $_$;

--16. Build reverse relationship. This is necessary for next point
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

--17. Deprecate all relationships in concept_relationship that aren't exist in concept_relationship_stage
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
WHERE 'ICD10CM' IN (
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