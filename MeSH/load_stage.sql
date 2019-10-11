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

--3. Load into concept_stage.
-- Build Main Heading (Descriptors)
INSERT INTO CONCEPT_STAGE (
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
SELECT DISTINCT mh.str AS concept_name,
	-- Pick the domain from existing mapping in UMLS with the following order of predence:
	first_value(c.domain_id) OVER (
		PARTITION BY mh.code ORDER BY CASE c.vocabulary_id
				WHEN 'RxNorm'
					THEN 1
				WHEN 'SNOMED'
					THEN 2
				WHEN 'LOINC'
					THEN 3
				WHEN 'CPT4'
					THEN 4
				ELSE 9
				END
		) AS domain_id,
	'MeSH' AS vocabulary_id,
	'Main Heading' AS concept_class_id,
	NULL AS standard_concept,
	mh.code AS concept_code,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'MeSH'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM SOURCES.mrconso mh
-- join to umls cpt4, hcpcs and rxnorm concepts
JOIN SOURCES.mrconso m ON mh.cui = m.cui
	AND m.sab IN (
		'CPT',
		'HCPCS',
		'HCPT',
		'RXNORM',
		'SNOMEDCT_US'
		)
	AND m.suppress = 'N'
	AND m.tty <> 'SY'
JOIN concept c ON c.concept_code = m.code
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
		WHEN 'LNC'
			THEN 'LOINC'
		ELSE m.sab
		END
	AND domain_id IN (
		'Condition',
		'Procedure',
		'Drug',
		'Measurement'
		)
WHERE mh.suppress = 'N'
	AND mh.sab = 'MSH'
	AND mh.lat = 'ENG'
	AND mh.tty = 'MH';

-- Build Supplementary Concepts
INSERT INTO CONCEPT_STAGE (
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
SELECT DISTINCT mh.str AS concept_name,
	-- Pick the domain from existing mapping in UMLS with the following order of predence:
	first_value(c.domain_id) OVER (
		PARTITION BY mh.code ORDER BY CASE c.vocabulary_id
				WHEN 'RxNorm'
					THEN 1
				WHEN 'SNOMED'
					THEN 2
				WHEN 'LOINC'
					THEN 3
				WHEN 'CPT4'
					THEN 4
				ELSE 9
				END
		) AS domain_id,
	'MeSH' AS vocabulary_id,
	'Suppl Concept' AS concept_class_id,
	NULL AS standard_concept,
	mh.code AS concept_code,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'MeSH'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM SOURCES.mrconso mh
-- join to umls cpt4, hcpcs and rxnorm concepts
JOIN SOURCES.mrconso m ON mh.cui = m.cui
	AND m.sab IN (
		'CPT',
		'HCPCS',
		'HCPT',
		'RXNORM',
		'SNOMEDCT_US'
		)
	AND m.suppress = 'N'
	AND m.tty <> 'SY'
JOIN concept c ON c.concept_code = m.code
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
		WHEN 'LNC'
			THEN 'LOINC'
		ELSE m.sab
		END
	AND domain_id IN (
		'Condition',
		'Procedure',
		'Drug',
		'Measurement'
		)
WHERE mh.suppress = 'N'
	AND mh.sab = 'MSH'
	AND mh.lat = 'ENG'
	AND mh.tty = 'NM';

--4. Create concept_relationship_stage
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
SELECT DISTINCT mh.code AS concept_code_1,
	-- Pick existing mapping from UMLS with the following order of predence:
	first_value(c.concept_code) OVER (
		PARTITION BY mh.code ORDER BY CASE c.vocabulary_id
				WHEN 'RxNorm'
					THEN 1
				WHEN 'SNOMED'
					THEN 2
				WHEN 'LOINC'
					THEN 3
				WHEN 'CPT4'
					THEN 4
				ELSE 9
				END
		) AS concept_code_2,
	'MeSH' AS vocabulary_id_1,
	first_value(c.vocabulary_id) OVER (
		PARTITION BY mh.code ORDER BY CASE c.vocabulary_id
				WHEN 'RxNorm'
					THEN 1
				WHEN 'SNOMED'
					THEN 2
				WHEN 'LOINC'
					THEN 3
				WHEN 'CPT4'
					THEN 4
				ELSE 9
				END
		) AS vocabulary_id_2,
	'Maps to' AS relationship_id,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM SOURCES.mrconso mh
-- join to umls cpt4, hcpcs and rxnorm concepts
JOIN SOURCES.mrconso m ON mh.cui = m.cui
	AND m.sab IN (
		'CPT',
		'HCPCS',
		'HCPT',
		'RXNORM',
		'SNOMEDCT_US'
		)
	AND m.suppress = 'N'
	AND m.tty <> 'SY'
JOIN concept c ON c.concept_code = m.code
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
		WHEN 'LNC'
			THEN 'LOINC'
		ELSE m.sab
		END
	AND domain_id IN (
		'Condition',
		'Procedure',
		'Drug',
		'Measurement'
		)
WHERE mh.suppress = 'N'
	AND mh.sab = 'MSH'
	AND mh.lat = 'ENG'
	AND mh.tty IN (
		'NM',
		'MH'
		);

--5. Add synonyms
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_vocabulary_id,
	synonym_name,
	language_concept_id
	)
SELECT DISTINCT c.concept_code AS synonym_concept_code,
	'MeSH' AS synonym_vocabulary_id,
	u.str AS synonym_name,
	4180186 AS language_concept_id -- English 
FROM concept_stage c
JOIN SOURCES.mrconso u ON u.code = c.concept_code
	AND u.sab = 'MSH'
	AND u.suppress = 'N'
	AND u.lat = 'ENG';

--6. Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

--7. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--8. Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script