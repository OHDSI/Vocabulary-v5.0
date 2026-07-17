/**************************************************************************
* Copyright 2016 Observational Health Data Sciences AND Informatics (OHDSI)
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
* Authors: Dmitry Dymshyts, Timur Vakhitov, Seng Chan You, Yiju Park, Masha Khitrun
* Date: 2026
**************************************************************************/

--1. UPDATE latest_update field to new date
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'EDI',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.edi_data LIMIT 1),
	pVocabularyVersion		=> (SELECT vocabulary_version FROM sources.edi_data LIMIT 1),
	pVocabularyDevSchema	=> 'DEV_EDI'
);
END $_$;

-- 2-1. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3. Create concept_stage
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
SELECT TRIM(SUBSTR(e.concept_name, 1, 255)) AS concept_name,
	e.domain_id,
	'EDI' AS vocabulary_id,
	e.concept_class_id,
	NULL AS standard_concept,
	e.concept_code,
	e.valid_start_date,
	e.valid_end_date,
	CASE e.valid_end_date
		WHEN TO_DATE('20991231', 'YYYYMMDD')
			THEN NULL
		ELSE 'D'
		END AS invalid_reason
FROM sources.edi_data e;

--4. Create concept_synonym_stage
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_name,
	synonym_vocabulary_id,
	language_concept_id
	)
SELECT e.concept_code,
	TRIM(SUBSTR(e.concept_name, 1, 1000)) AS synonym_name,
	'EDI' AS synonym_vocabulary_id,
	4180186 AS language_concept_id -- English
FROM sources.edi_data e

UNION ALL

SELECT e.concept_code,
       TRIM(SUBSTR(e.concept_synonym, 1, 1000)),
	'EDI' AS synonym_vocabulary_id,
	4175771 AS language_concept_id -- Korean
FROM sources.edi_data e
WHERE LOWER(TRIM(e.concept_name)) <> LOWER(TRIM(e.concept_synonym))
AND e.concept_synonym != 'NULL';

--5. Process manual tables:
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualConcepts();
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
	PERFORM VOCABULARY_PACK.ProcessManualSynonyms();
END $_$;

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

-- At the end, the three tables concept_stage, concept_relationship_stage AND concept_synonym_stage should be ready to be fed into the generic_update.sql script