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


DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=>'Cancer Modifier',
	pVocabularyDate			=> CURRENT_DATE,
	pVocabularyVersion		=> 'Cancer Modifier '||TO_CHAR(CURRENT_DATE,'YYYYMMDD'),
	pVocabularyDevSchema	=> 'dev_cancer_modifier'
);
/*	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'NAACCR',
    pVocabularyDate			=> to_date ('2018-03-02', 'yyyy-mm-dd'), -- https://www.naaccr.org/data-standards-data-dictionary/#DataDictionary -- Version 18 Data Standards and Data Dictionary – (posted 3/2/18;
	pVocabularyVersion		=> 'NAACCR v18',
	pVocabularyDevSchema	=> 'dev_cancer_modifier',
	pAppendVocabulary		=> TRUE*/
/*);*/ --commented for the current run
/*    PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'NCIt',
    pVocabularyDate			=> CURRENT_DATE,
	pVocabularyVersion		=> ' NCIt ' ||TO_CHAR(CURRENT_DATE,'YYYYMMDD'),
	pVocabularyDevSchema	=> 'dev_cancer_modifier',
	pAppendVocabulary		=> TRUE
);*/
END $_$;

-- 2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--1   ProcessManualConcepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualConcepts();
END $_$;


--2. Add manual relationships
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--3. Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

--4 Add mapping from deprecated to fresh concepts (necessary for the next step)
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

--5. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script