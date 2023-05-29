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
* Authors: Oleg Zhuk
* Date: 2023
**************************************************************************/

--1. Set latest update
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'CO-CONNECT',
	pVocabularyDate			=> CURRENT_DATE,
	pVocabularyVersion		=> 'CO-CONNECT '||TO_CHAR(CURRENT_DATE,'YYYY-MM-DD'),
	pVocabularyDevSchema	=> 'dev_co_connect'
	);

	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'CO-CONNECT MIABIS',
	pVocabularyDate			=> CURRENT_DATE,
	pVocabularyVersion		=> 'CO-CONNECT MIABIS '||TO_CHAR(CURRENT_DATE,'YYYY-MM-DD'),
	pVocabularyDevSchema	=> 'dev_co_connect',
	pAppendVocabulary		=> TRUE
	);

	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'CO-CONNECT TWINS',
	pVocabularyDate			=> CURRENT_DATE,
	pVocabularyVersion		=> 'CO-CONNECT TWINS '||TO_CHAR(CURRENT_DATE,'YYYY-MM-DD'),
	pVocabularyDevSchema	=> 'dev_co_connect',
	pAppendVocabulary		=> TRUE
	);
END $_$;


--2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3. Manual concepts
--Append manual concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualConcepts();
END $_$;

--4. Manual mappings
--Append manual relationships
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

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script