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
* Date: 2022
**************************************************************************/

--1. Update latest_update field to new date 
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'MeSH',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.mrsmap LIMIT 1),
	pVocabularyVersion		=> (SELECT EXTRACT (YEAR FROM vocabulary_date)||' Release' FROM sources.mrsmap LIMIT 1),
	pVocabularyDevSchema	=> 'DEV_MESH'
);
END $_$;

--2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3. Create temp table with concepts and possible mappings to another vocabs
DROP TABLE IF EXISTS mesh_source;
CREATE UNLOGGED TABLE mesh_source AS
SELECT DISTINCT ON (mh.code) mh.str AS concept_name,
	c.domain_id,
	CASE mh.tty
		WHEN 'NM'
			THEN 'Suppl Concept'
		ELSE 'Main Heading'
		END AS concept_class_id,
	mh.code AS concept_code,
	c.concept_code AS target_concept_code,
	c.vocabulary_id AS target_vocabulary_id
FROM sources.mrconso mh
--join to umls cpt4, hcpcs, snomed and rxnorm concepts
LEFT JOIN sources.mrconso m ON mh.cui = m.cui
	AND m.sab IN (
		'CPT',
		'HCPCS',
		'HCPT',
		'RXNORM',
		'SNOMEDCT_US'
		)
	AND m.suppress = 'N'
	AND m.tty <> 'SY'
LEFT JOIN concept c ON c.concept_code = m.code
	AND c.standard_concept = 'S'
	AND c.vocabulary_id = CASE m.sab
		WHEN 'CPT'
			THEN 'CPT4'
		WHEN 'HCPT'
			THEN 'CPT4'
		WHEN 'RXNORM'
			THEN 'RxNorm'
		WHEN 'SNOMEDCT_US'
			THEN 'SNOMED'
		END
	AND c.domain_id IN (
		'Condition',
		'Procedure',
		'Drug',
		'Measurement'
		)
WHERE mh.suppress = 'N'
	AND mh.sab = 'MSH'
	AND mh.lat = 'ENG'
	AND mh.tty IN (
		'MH',
		'NM'
		) --Main Heading (Descriptors) and Supplementary Concepts
ORDER BY mh.code,
	--pick the domain from existing mapping in UMLS with the following order of precedence
	CASE c.vocabulary_id
		WHEN 'RxNorm'
			THEN 1
		WHEN 'SNOMED'
			THEN 2
		WHEN 'CPT4'
			THEN 3
		END;

--4. Load into concept_stage
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
SELECT concept_name,
	domain_id,
	'MeSH' AS vocabulary_id,
	concept_class_id,
	NULL AS standard_concept,
	concept_code,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'MeSH'
		) AS valid_start_date,
	TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date
FROM mesh_source;

ANALYZE concept_stage;

--5. Fill empty domains [AVOF-3594]
UPDATE concept_stage cs
SET domain_id = i.domain_id
FROM (
	WITH RECURSIVE hierarchy_concepts(ancestor_concept_code, descendant_concept_code, root_ancestor_concept_code, full_path, hierarchy_depth) AS (
			SELECT ancestor_concept_code,
				descendant_concept_code,
				ancestor_concept_code AS root_ancestor_concept_code,
				ARRAY [descendant_concept_code] AS full_path,
				0 AS hierarchy_depth
			FROM concepts
			
			UNION ALL
			
			SELECT c.ancestor_concept_code,
				c.descendant_concept_code,
				hc.root_ancestor_concept_code,
				hc.full_path || c.descendant_concept_code AS full_path,
				hc.hierarchy_depth + 1
			FROM concepts c
			JOIN hierarchy_concepts hc ON hc.descendant_concept_code = c.ancestor_concept_code
			WHERE c.descendant_concept_code <> ALL (full_path) --there is cycles, e.g. 'D054990'<->'D054988'
			),
		concepts AS (
			SELECT mrc1.code AS ancestor_concept_code,
				mrc2.code::TEXT AS descendant_concept_code
			FROM sources.mrrel mr
			JOIN sources.mrconso mrc1 ON mrc1.sab = 'MSH'
				AND mrc1.cui = mr.cui1
				AND mrc1.lat = 'ENG'
				AND mrc1.suppress = 'N'
				AND mrc1.tty IN (
					'NM',
					'MH'
					)
			JOIN sources.mrconso mrc2 ON mrc2.sab = 'MSH'
				AND mrc2.cui = mr.cui2
				AND mrc2.lat = 'ENG'
				AND mrc2.suppress = 'N'
				AND mrc2.tty IN (
					'NM',
					'MH'
					)
			WHERE mr.sab = 'MSH'
				AND mr.rel = 'CHD'
				AND mr.suppress = 'N'
			)
	SELECT DISTINCT ON (s0.descendant_concept_code) s0.descendant_concept_code,
		s0.domain_id
	FROM (
		SELECT hc.descendant_concept_code,
			hc.hierarchy_depth,
			ancestor_cs.domain_id,
			MIN(hc.hierarchy_depth) OVER (PARTITION BY hc.descendant_concept_code) AS min_hierarchy_depth --min depth with non-null domain(s)
		FROM hierarchy_concepts hc
		JOIN concept_stage ancestor_cs ON ancestor_cs.concept_code = hc.root_ancestor_concept_code
			AND ancestor_cs.domain_id IS NOT NULL --ancestor concepts without a domain can be on the same level (depth), we filter such
		JOIN concept_stage descendant_cs ON descendant_cs.concept_code = hc.descendant_concept_code
			AND descendant_cs.domain_id IS NULL --get concepts with no domain defined
		) s0
	WHERE s0.hierarchy_depth = s0.min_hierarchy_depth
	ORDER BY s0.descendant_concept_code,
		--if there are more than one ancestors with different domains, pick the domain with the following order of precedence
		CASE s0.domain_id
			WHEN 'Condition'
				THEN 1
			WHEN 'Procedure'
				THEN 2
			WHEN 'Measurement'
				THEN 3
			WHEN 'Drug'
				THEN 4
			END
	) i
WHERE cs.concept_code = i.descendant_concept_code;

--6. Check for NULL in domain_id
ALTER TABLE concept_stage ALTER COLUMN domain_id SET NOT NULL;
ALTER TABLE concept_stage ALTER COLUMN domain_id DROP NOT NULL;

--7. Create concept_relationship_stage
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date,
	)
SELECT concept_code AS concept_code_1,
	target_concept_code AS concept_code_2,
	'MeSH' AS vocabulary_id_1,
	target_vocabulary_id AS vocabulary_id_2,
	'Maps to' AS relationship_id,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'MeSH'
		) AS valid_start_date,
	TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date
FROM mesh_source
WHERE target_concept_code IS NOT NULL;

--8. Add synonyms
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_vocabulary_id,
	synonym_name,
	language_concept_id
	)
SELECT DISTINCT c.concept_code AS synonym_concept_code,
	'MeSH' AS synonym_vocabulary_id,
	m.str AS synonym_name,
	4180186 AS language_concept_id -- English 
FROM concept_stage c
JOIN sources.mrconso m ON m.code = c.concept_code
	AND m.sab = 'MSH'
	AND m.suppress = 'N'
	AND m.lat = 'ENG'
WHERE c.concept_name <> m.str;

--9. Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

--10. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--11. Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;

--12. Clean up
DROP TABLE mesh_source;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script