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
* Authors: Dmitry Dymshyts, Timur Vakhitov
* Date: 2024
**************************************************************************/
SET search_path To dev_edi;

--1. UPDATE latest_update field to new date
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'EDI',
	pVocabularyDate			=> TO_DATE('20231001','YYYYMMDD'),
	pVocabularyVersion		=> 'EDI 2023.10.01',
	pVocabularyDevSchema	=> 'DEV_EDI'
);
END $_$;

-- 2-1. Truncate all working tables
TRUNCATE TABLE dev_edi.concept_stage;
TRUNCATE TABLE dev_edi.concept_relationship_stage;
TRUNCATE TABLE dev_edi.concept_synonym_stage;
TRUNCATE TABLE dev_edi.pack_content_stage;
TRUNCATE TABLE dev_edi.drug_strength_stage;

-- 2-2. formatting the source_code
UPDATE sources.edi_data
SET concept_code = '0'||concept_code
WHERE domain_id = 'Drug' and length(concept_code)=8;

--3. Create concept_stage
INSERT INTO dev_edi.concept_stage (
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

--4. Create concept_relationship_stage only from manual source 
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--5. Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;


--6. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--7. Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;

--8. Create concept_synonym_stage
INSERT INTO dev_edi.concept_synonym_stage (
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
	TRIM(SUBSTR(e.concept_synonym, 1, 1000)) AS synonym_name,
	'EDI' AS synonym_vocabulary_id,
	4175771 AS language_concept_id -- Korean
FROM sources.edi_data e
WHERE LOWER(TRIM(e.concept_name)) <> LOWER(TRIM(e.concept_synonym));


-- At the end, the three tables concept_stage, concept_relationship_stage AND concept_synonym_stage should be ready to be fed into the generic_update.sql script

SELECT * FROM dev_edi.concept_stage;
SELECT * FROM dev_edi.concept_relationship_stage;
SELECT * FROM dev_edi.concept_synonym_stage;


-- GenericUpdate
DO $_$
BEGIN
	PERFORM devv5.GenericUpdate();
END $_$;

-- Check the '_Stage' tables
SELECT * FROM qa_tests.Check_Stage_Tables();
