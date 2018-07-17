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

--4. Add ICD10CM to SNOMED manual mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--5. Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

--6. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--7. Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

--8. Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;

--9. Add "subsumes" relationship between concepts where the concept_code is like of another
CREATE INDEX IF NOT EXISTS trgm_idx ON concept_stage USING GIN (concept_code devv5.gin_trgm_ops); --for LIKE patterns
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

--10. Update domain_id for ICD10CM from SNOMED
--create temporary table icd10cm_domain
--if domain_id is empty we use previous and next domain_id or its combination
DROP TABLE IF EXISTS icd10cm_domain;
CREATE UNLOGGED TABLE icd10cm_domain AS
	WITH filled_domain AS (
			WITH domain_map2value AS (
					--ICD10CM have direct "Maps to value" mapping
					SELECT c1.concept_code,
						c2.domain_id
					FROM concept_relationship_stage r,
						concept_stage c1,
						concept c2
					WHERE c1.concept_code = r.concept_code_1
						AND c2.concept_code = r.concept_code_2
						AND c1.vocabulary_id = r.vocabulary_id_1
						AND c2.vocabulary_id = r.vocabulary_id_2
						AND r.vocabulary_id_1 = 'ICD10CM'
						AND r.vocabulary_id_2 = 'SNOMED'
						AND r.relationship_id = 'Maps to value'
						AND r.invalid_reason IS NULL
					)
			SELECT d.concept_code,
				--some rules for domain_id
				CASE 
					WHEN d.domain_id IN (
							'Procedure',
							'Measurement'
							)
						AND EXISTS (
							SELECT 1
							FROM domain_map2value t
							WHERE t.concept_code = d.concept_code
								AND t.domain_id IN (
									'Meas Value',
									'Spec Disease Status'
									)
							)
						THEN 'Measurement'
					WHEN d.domain_id = 'Procedure'
						AND EXISTS (
							SELECT 1
							FROM domain_map2value t
							WHERE t.concept_code = d.concept_code
								AND t.domain_id = 'Condition'
							)
						THEN 'Condition'
					WHEN d.domain_id = 'Condition'
						AND EXISTS (
							SELECT 1
							FROM domain_map2value t
							WHERE t.concept_code = d.concept_code
								AND t.domain_id = 'Procedure'
							)
						THEN 'Condition'
					WHEN d.domain_id = 'Observation'
						THEN 'Observation'
					ELSE d.domain_id
					END domain_id
			FROM --simplify domain_id
				(
				SELECT concept_code,
					CASE 
						WHEN domain_id = 'Condition/Measurement'
							THEN 'Condition'
						WHEN domain_id = 'Condition/Procedure'
							THEN 'Condition'
						WHEN domain_id = 'Condition/Observation'
							THEN 'Observation'
						WHEN domain_id = 'Observation/Procedure'
							THEN 'Observation'
						WHEN domain_id = 'Measurement/Observation'
							THEN 'Observation'
						WHEN domain_id = 'Measurement/Procedure'
							THEN 'Measurement'
						ELSE 'Condition' --if some concepts don't have any mappings, 'Condition' by default for ICD10CM
						END domain_id
				FROM (
					--ICD10CM have direct "Maps to" mapping
					SELECT concept_code,
						string_agg(domain_id, '/' ORDER BY domain_id) domain_id
					FROM (
						SELECT DISTINCT c1.concept_code,
							c2.domain_id
						FROM concept_relationship_stage r,
							concept_stage c1,
							concept c2
						WHERE c1.concept_code = r.concept_code_1
							AND c2.concept_code = r.concept_code_2
							AND c1.vocabulary_id = r.vocabulary_id_1
							AND c2.vocabulary_id = r.vocabulary_id_2
							AND r.vocabulary_id_1 = 'ICD10CM'
							AND r.vocabulary_id_2 = 'SNOMED'
							AND r.relationship_id = 'Maps to'
							AND r.invalid_reason IS NULL
						) AS s0
					GROUP BY concept_code
					) AS s1
				) AS d
			)

SELECT concept_code,
	CASE 
		WHEN domain_id IS NOT NULL
			THEN domain_id
		ELSE CASE 
				WHEN prev_domain = next_domain
					THEN prev_domain --prev and next domain are the same (and of course not null both)
				WHEN prev_domain IS NOT NULL
					AND next_domain IS NOT NULL
					THEN CASE 
							WHEN prev_domain < next_domain
								THEN prev_domain || '/' || next_domain
							ELSE next_domain || '/' || prev_domain
							END -- prev and next domain are not same and not null both, with order by name
				ELSE coalesce(prev_domain, next_domain, 'Unknown')
				END
		END domain_id
FROM (
	SELECT concept_code,
		string_agg(domain_id, '/' ORDER BY domain_id) domain_id,
		prev_domain,
		next_domain
	FROM (
		SELECT DISTINCT c1.concept_code,
			r1.domain_id,
			(
				SELECT DISTINCT LAST_VALUE(fd.domain_id) OVER (
						ORDER BY fd.concept_code ROWS BETWEEN UNBOUNDED PRECEDING
								AND UNBOUNDED FOLLOWING
						)
				FROM filled_domain fd
				WHERE fd.concept_code < c1.concept_code
					AND r1.domain_id IS NULL
				) prev_domain,
			(
				SELECT DISTINCT FIRST_VALUE(fd.domain_id) OVER (
						ORDER BY fd.concept_code ROWS BETWEEN UNBOUNDED PRECEDING
								AND UNBOUNDED FOLLOWING
						)
				FROM filled_domain fd
				WHERE fd.concept_code > c1.concept_code
					AND r1.domain_id IS NULL
				) next_domain
		FROM concept_stage c1
		LEFT JOIN filled_domain r1 ON r1.concept_code = c1.concept_code
		WHERE c1.vocabulary_id = 'ICD10CM'
		) AS s2
	GROUP BY concept_code,
		prev_domain,
		next_domain
	) AS s3;

-- INDEX was set as UNIQUE to prevent concept_code duplication
CREATE UNIQUE INDEX idx_icd10cm_domain ON icd10cm_domain (concept_code);

--11. Simplify the list by removing Observations
UPDATE icd10cm_domain
SET domain_id = trim('/' FROM replace('/' || domain_id || '/', '/Observation/', '/'))
WHERE '/' || domain_id || '/' LIKE '%/Observation/%'
	AND devv5.instr(domain_id, '/') <> 0;

--Reducing some domain_id if his length>20
UPDATE icd10cm_domain
SET domain_id = 'Condition/Meas'
WHERE domain_id = 'Condition/Measurement';

-- Check that all domain_id are exists in domain table
ALTER TABLE icd10cm_domain ADD CONSTRAINT fk_icd10cm_domain FOREIGN KEY (domain_id) REFERENCES domain (domain_id);

--12. Update each domain_id with the domains field from icd10cm_domain.
UPDATE concept_stage c
SET domain_id = rd.domain_id
FROM icd10cm_domain rd
WHERE rd.concept_code = c.concept_code
	AND c.vocabulary_id = 'ICD10CM'
	AND c.domain_id <> rd.domain_id;

--13. Load into concept_synonym_stage name from ICD10CM
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

--14. Clean up
DROP TABLE icd10cm_domain;
-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script