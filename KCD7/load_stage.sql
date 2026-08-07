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
* Authors: Denys Kaduk, Dmitry Dymshyts
* Date: 2019
**************************************************************************/

--1. Update latest_update field to new date
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'KCD7',
	pVocabularyDate			=> TO_DATE('20170701','yyyymmdd'),
	pVocabularyVersion		=> '7th revision',
	pVocabularyDevSchema	=> 'dev_kcd7'
);
END $_$;

--2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3. Load into concept_stage
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
SELECT english_description AS concept_name,
	NULL AS domain_id,
	'KCD7' AS vocabulary_id,
	'KCD7 code' AS concept_class_id,
	NULL AS standard_concept,
	regexp_replace(kcd_cd, '^(\w\d{2})(\d+)$', '\1.\2') AS concept_code, -- insert dot into code
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'KCD7'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.kcd7;

--3.1. Manual concepts
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
VALUES ('Provisional assignment of new diseases or emergency use','Observation','KCD7','KCD7 code',NULL,'U18', TO_DATE('19700101','yyyymmdd'),TO_DATE('20991231','yyyymmdd')),
	('Novel coronavirus infection','Observation','KCD7','KCD7 code',NULL,'U18.1', TO_DATE('19700101','yyyymmdd'),TO_DATE('20991231','yyyymmdd'));

--4. Load into concept_synonym_stage
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_name,
	synonym_vocabulary_id,
	language_concept_id
	)
SELECT regexp_replace(kcd_cd, '^(\w\d{2})(\d+)$', '\1.\2') AS synonym_concept_code,
	korean_description AS synonym_name,
	'KCD7' AS synonym_vocabulary_id,
	4175771 AS language_concept_id -- Korean
FROM sources.kcd7

UNION ALL

VALUES ('U18','신종질환의 국내 임시적 지정이나 응급사용','KCD7',4175771),
	('U18.1','신종 코로나바이러스 감염','KCD7',4175771);

--7. Add KCD7 to SNOMED manual mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualConcepts();
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--5. Add mapping through ICD10 
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date
	)
SELECT cs.concept_code AS concept_code_1,
	c2.concept_code AS concept_code_2,
	cs.vocabulary_id AS vocabulary_id_1,
	c2.vocabulary_id AS vocabulary_id_2,
	cr.relationship_id AS relationship_id,
	CURRENT_DATE AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM concept_stage cs
JOIN concept c ON c.concept_code = cs.concept_code
	AND c.vocabulary_id = 'ICD10'
JOIN concept_relationship cr ON cr.concept_id_1 = c.concept_id
	AND cr.invalid_reason IS NULL
	AND cr.relationship_id IN (
		'Maps to',
		'Maps to value'
		)
JOIN concept c2 ON c2.concept_id = cr.concept_id_2
LEFT JOIN concept_relationship_stage crs ON crs.concept_code_1 = cs.concept_code
	AND crs.vocabulary_id_1 = cs.vocabulary_id
WHERE crs.concept_code_1 IS NULL;


--6. Add "Subsumes" relationship between concepts where the concept_code is like of another
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
	CURRENT_DATE AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM concept_stage c1,
	concept_stage c2
WHERE c2.concept_code LIKE c1.concept_code || '%'
	AND c1.concept_code <> c2.concept_code;

DROP INDEX trgm_idx;

--7. Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

--8. Add mapping from deprecated to fresh concepts for 'Maps to value'
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMapsToValue();
END $_$;

--9. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--10. Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;

--11. Update domain_id for KCD7
UPDATE concept_stage cs
SET domain_id = i.domain_id
FROM (
	SELECT DISTINCT ON (cs1.concept_code) cs1.concept_code,
		c2.domain_id
	FROM concept_relationship_stage crs
	JOIN concept_stage cs1 ON cs1.concept_code = crs.concept_code_1
		AND cs1.vocabulary_id = crs.vocabulary_id_1
		AND cs1.vocabulary_id = 'KCD7'
	JOIN concept c2 ON c2.concept_code = crs.concept_code_2
		AND c2.vocabulary_id = crs.vocabulary_id_2
	--AND c2.vocabulary_id = 'SNOMED'
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
	) i
WHERE i.concept_code = cs.concept_code
	AND cs.vocabulary_id = 'KCD7';

--12. If domain_id is empty we use previous and next domain_id
UPDATE concept_stage c
SET domain_id = rd.domain_id
FROM (
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
									THEN LEFT((prev_domain || '/' || next_domain),20) -- essential due to length constraints
								ELSE LEFT((next_domain || '/' || prev_domain),20) -- essential due to length constraints
								END -- prev and next domain are not same and not null both, with order by name
					ELSE COALESCE(prev_domain, next_domain, 'Condition')
					END
			END domain_id
	FROM (
		SELECT cs.concept_code,
			cs.domain_id,
			LAG(cs.domain_id) OVER (
				ORDER BY concept_code
				) prev_domain,
			LEAD(cs.domain_id) OVER (
				ORDER BY concept_code
				) next_domain
		FROM concept_stage cs
		) AS s1
	) rd
WHERE rd.concept_code = c.concept_code
	AND c.vocabulary_id = 'KCD7'
	AND c.domain_id IS NULL;

--Detect and Update misclassified domains to Condition
UPDATE concept_stage c
SET domain_id = 'Condition'
WHERE domain_id = 'Condition/Observatio';

UPDATE concept_stage c
SET domain_id = 'Condition'
WHERE domain_id = 'Condition/Measuremen';

UPDATE concept_stage c
SET domain_id = 'Observation'
WHERE domain_id = 'Measurement/Observat';

--Update domain for tumor concepts
UPDATE concept_stage
SET domain_id = 'Condition'
WHERE concept_code ILIKE '%C%';

--13. Manual name fix
UPDATE concept_stage
SET concept_name = 'Emergency use of U07.1 | Disease caused by severe acute respiratory syndrome coronavirus 2'
WHERE concept_code = 'U07.1';

UPDATE concept_synonym_stage
SET synonym_name = '코로나바이러스질환2019[코로나-19]'
WHERE synonym_concept_code = 'U07.1' and language_concept_id=4175771;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script