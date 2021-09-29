/**************************************************************************
* Copyright 2021 Observational Health Data Sciences and Informatics (OHDSI)
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
* Authors: Timur Vakhitov, Dmitry Dymshyts, Eduard Korchmar
* Date: 2021
**************************************************************************/

--1. Update latest_update field to new date 
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'OncoTree',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.oncotree_tree LIMIT 1),
	pVocabularyVersion		=> (SELECT vocabulary_version FROM sources.oncotree_tree LIMIT 1),
	pVocabularyDevSchema	=> 'DEV_ONCOTREE'
);
END $_$;

--2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3. Fill concept_stage with concepts
INSERT INTO concept_stage (
	concept_name,
	domain_id,
	vocabulary_id,
	concept_class_id,
	concept_code,
	valid_start_date,
	valid_end_date
	)
SELECT o.descendant_name,
	'Condition',
	'OncoTree',
	'Condition',
	o.descendant_code,
	/*(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'OncoTree'
		) AS valid_start_date, */ -- remove comments in the next release when we get the actual dates, while there's totally new release we treat all concepts as created sometimes in a past ('19700101')
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM sources.oncotree_tree o;

--4. Put internal hierarchy in concept_relationship_stage
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date
	)
SELECT descendant_code,
	ancestor_code,
	'OncoTree',
	'OncoTree',
	'Is a',
	TO_DATE('19700101', 'yyyymmdd'),
	TO_DATE('20991231', 'yyyymmdd')
FROM sources.oncotree_tree
WHERE ancestor_code IS NOT NULL;

--5. Process manual relationships
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--6. Vocabulary pack procedures
--6.1. Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

--6.2. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script