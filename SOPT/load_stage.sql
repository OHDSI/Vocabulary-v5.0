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
* Authors: Medical team
* Date: 2021
**************************************************************************/

--1. Update latest_update field to new date
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'SOPT',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.sopt_source LIMIT 1),
	pVocabularyVersion		=> (SELECT vocabulary_version FROM sources.sopt_source LIMIT 1),
	pVocabularyDevSchema	=> 'DEV_SOPT'
);
END $_$;

--2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3. Fill concept_stage
INSERT INTO concept_stage (
	concept_name,
	vocabulary_id,
	domain_id,
	concept_class_id,
	standard_concept,
	concept_code,
	valid_start_date,
	valid_end_date
	)
SELECT COALESCE(c.concept_name, s.concept_name) AS concept_name,
	'SOPT' AS vocabulary_id,
	'Payer' AS domain_id,
	'Payer' AS concept_class_id,
	CASE 
		WHEN s.concept_code IN (
				'92',
				'98',
				'99',
				'9999'
				)
			THEN NULL
		ELSE 'S'
		END AS standard_concept,
	s.concept_code,
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM sources.sopt_source s
JOIN vocabulary v ON v.vocabulary_id = 'SOPT'
LEFT JOIN concept c ON c.concept_code = s.concept_code
	AND c.vocabulary_id = 'SOPT';

--4. Create 'Is a' relationships
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date
	)
SELECT cs2.concept_code AS concept_code_1,
	cs1.concept_code AS concept_code_2,
	'SOPT' AS vocabulary_id_1,
	'SOPT' AS vocabulary_id_2,
	'Is a' AS relationship_id,
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date
FROM concept_stage cs1
JOIN concept_stage cs2 ON cs2.concept_code LIKE cs1.concept_code || '%'
	AND LENGTH(cs2.concept_code) - 1 = LENGTH(cs1.concept_code)
JOIN vocabulary v ON v.vocabulary_id = 'SOPT';

--5. Manual manipulations
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualConcepts();
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script