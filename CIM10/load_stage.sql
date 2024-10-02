/**************************************************************************
* Copyright 2020 Observational Health Data Sciences and Informatics (OHDSI)
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
* Authors: Timur Vakhitov, Dmitry Dymshyts
* Date: 2022
**************************************************************************/

--1. Update latest_update field to new date
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'CIM10',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.cim10 LIMIT 1),
	pVocabularyVersion		=> (SELECT vocabulary_version FROM sources.cim10 LIMIT 1),
	pVocabularyDevSchema	=> 'DEV_CIM10'
);
END $_$;

--2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3. Fill the concept_stage
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
SELECT vocabulary_pack.CutConceptName(lib_complet) AS concept_name,
	NULL AS domain_id,
	'CIM10' AS vocabulary_id,
	CASE
		WHEN LENGTH(code) = 3
			THEN 'ICD10 Hierarchy'
		ELSE 'ICD10 code'
		END AS concept_class_id,
	NULL AS standard_concept,
	REGEXP_REPLACE(code, '(.{3})(.+)', '\1.\2') AS concept_code, --add a dot after the 3d position
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'CIM10'
		) AS valid_start_date,
	TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.cim10;

--4. Append manual concepts and relationships
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualConcepts();
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--5. Inherit external relations from international ICD10 whenever possible
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date
	)
SELECT c.concept_code AS concept_code_1,
	c2.concept_code AS concept_code_2,
	'CIM10' AS vocabulary_id_1,
	c2.vocabulary_id AS vocabulary_id_2,
	r.relationship_id AS relationship_id,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'CIM10'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM concept_stage cs
JOIN concept c ON c.concept_code = cs.concept_code
	AND c.vocabulary_id = 'ICD10'
JOIN concept_relationship r ON r.concept_id_1 = c.concept_id
	AND r.invalid_reason IS NULL
	AND r.relationship_id IN (
		'Maps to',
		'Maps to value'
		)
JOIN concept c2 ON c2.concept_id = r.concept_id_2
LEFT JOIN concept_relationship_stage crs ON crs.concept_code_1 = c.concept_code
	AND crs.vocabulary_id_1 = 'CIM10'
WHERE crs.concept_code_1 IS NULL;

--6. Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

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

--11. Add "subsumes" relationship between concepts where the concept_code is like of another
CREATE INDEX IF NOT EXISTS trgm_idx ON concept_stage USING GIN (concept_code devv5.gin_trgm_ops); --for LIKE patterns
ANALYZE concept_stage;

INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date
	)
SELECT c1.concept_code AS concept_code_1,
	c2.concept_code AS concept_code_2,
	c1.vocabulary_id AS vocabulary_id_1,
	c1.vocabulary_id AS vocabulary_id_2,
	'Subsumes' AS relationship_id,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'CIM10'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM concept_stage c1
JOIN concept_stage c2 ON c2.concept_code LIKE c1.concept_code || '%'
	AND c1.concept_code <> c2.concept_code;

DROP INDEX trgm_idx;

--12. Update domain_id for ICD10 from target concepts domains
ANALYZE concept_relationship_stage;

UPDATE concept_stage cs
SET domain_id = i.domain_id
FROM (
	(
		SELECT DISTINCT ON (cs1.concept_code) cs1.concept_code,
			c2.domain_id
		FROM concept_relationship_stage crs
		JOIN concept_stage cs1 ON cs1.concept_code = crs.concept_code_1
			AND cs1.vocabulary_id = crs.vocabulary_id_1
			AND cs1.vocabulary_id = 'CIM10'
		JOIN concept c2 ON c2.concept_code = crs.concept_code_2
			AND c2.vocabulary_id = crs.vocabulary_id_2
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
			AND c1.vocabulary_id = 'CIM10'
		JOIN concept c2 ON c2.concept_id = cr.concept_id_2
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
WHERE i.concept_code = cs.concept_code;

--13. Manual fix for concepts without mapping
UPDATE concept_stage
SET domain_id = 'Observation'
WHERE domain_id IS NULL;

--14. Update domain for tumor concepts
UPDATE concept_stage
SET domain_id = 'Condition'
WHERE concept_code ILIKE '%C%';

--15. Fill synonyms
INSERT INTO concept_synonym_stage (
	synonym_name,
	synonym_concept_code,
	synonym_vocabulary_id,
	language_concept_id
	)
SELECT lib_complet AS synonym_name,
	REGEXP_REPLACE(code, '(.{3})(.+)', '\1.\2') AS synonym_concept_code,
	'CIM10' AS synonym_vocabulary_id,
	4180190 AS language_concept_id -- French language
FROM sources.cim10;

--16. Update concept_stage, set english names from ICD10
UPDATE concept_stage cs
SET concept_name = c.concept_name
FROM concept c
WHERE c.concept_code = cs.concept_code
	AND c.vocabulary_id = 'ICD10';

--17. Translate the rest of names
--DROP TABLE cim10_translated_source;
--TRUNCATE TABLE cim10_translated_source;
--CREATE TABLE cim10_translated_source
--(concept_code text,
--concept_name  text,
--concept_name_translated text);
--
--INSERT INTO cim10_translated_source
--    SELECT concept_code,
--          concept_name,
--          null as concept_name_translated
--    FROM concept_stage
--where concept_code not in (SELECT concept_code FROM concept c where c.vocabulary_id = 'ICD10')
--;

----Translation
--DO $_$
--BEGIN
--	PERFORM google_pack.GTranslate(
--		pInputTable    =>'cim10_translated_source',
--		pInputField    =>'concept_name',
--		pOutputField   =>'concept_name_translated',
--		pDestLang      =>'en',
--	    pSrcLang       =>'fr'
--	);
--END $_$;
--
--UPDATE cim10_translated_source
--SET concept_name_translated = cim10_translated_source.concept_name_translated ||' (machine translation)'
--where concept_name_translated !~* '(machine translation)';
--

UPDATE concept_stage cs
SET concept_name = vocabulary_pack.CutConceptName(ts.concept_name_translated)
FROM dev_cim10.cim10_translated_source ts
WHERE cs.concept_name = ts.concept_name;

--18. Working with concept_manual table
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualConcepts();
END $_$;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script