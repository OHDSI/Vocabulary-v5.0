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
* Date: 2021, 2026
**************************************************************************/


DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'NAACCR',
    pVocabularyDate			=> to_date ('2026-07-13', 'yyyy-mm-dd'), -- https://www.naaccr.org/data-standards-data-dictionary/#DataDictionary -- Version 18 Data Standards and Data Dictionary - (posted 3/2/18;
	pVocabularyVersion		=> 'NAACCR v26',
	pVocabularyDevSchema	=> 'dev_naaccr'
	);
/*	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'ICDO3',
	pVocabularyDate			=> TO_DATE ('20200630', 'yyyymmdd'), -- https://seer.cancer.gov/ICDO3/
	pVocabularyVersion		=> 'ICDO3 SEER Site/Histology Released 06/2020',
	pVocabularyDevSchema	=> 'dev_naaccr',
	pAppendVocabulary		=> TRUE
); --commented for the current run*/
	END $_$;

-- 2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--1. As ProcessManualConcepts to minimize the legacy-tail in manual tables,
-- direct injection of 'externally-produced-stage' content is expected to be omitted direct insert to
INSERT INTO concept_stage (concept_id,
       concept_name,
       domain_id,
       vocabulary_id,
       concept_class_id,
       standard_concept,
       concept_code,
       valid_start_date,
       valid_end_date,
       invalid_reason)
SELECT concept_id,
       concept_name,
       domain_id,
       vocabulary_id,
       concept_class_id,
       standard_concept,
       concept_code,
       valid_start_date,
       valid_end_date,
       invalid_reason
FROM dev_naaccr.naaccr_update_concept_stage ncs
;

--2. As ProcessManualRelationships to minimize the legacy-tail in manual tables,
-- direct injection of 'externally-produced-stage' content is expected to be omitted direct insert to
INSERT INTO concept_relationship_stage (concept_id_1, concept_id_2, concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
SELECT concept_id_1,
       concept_id_2,
       concept_code_1,
       concept_code_2,
       vocabulary_id_1,
       vocabulary_id_2,
       relationship_id,
       valid_start_date,
       valid_end_date,
       invalid_reason
FROM dev_naaccr.naaccr_update_concept_relationship_stage ncrs
;

--3. As ProcessManualSynonyms to minimize the legacy-tail in manual tables,
-- direct injection of 'externally-produced-stage' content is expected to be omitted direct insert to
INSERT INTO concept_synonym_stage (synonym_concept_id, synonym_name, synonym_concept_code, synonym_vocabulary_id, language_concept_id)
SELECT synonym_concept_id,
       synonym_name,
       synonym_concept_code,
       synonym_vocabulary_id,
       language_concept_id
FROM dev_naaccr.naaccr_update_concept_synonym_stage ncss
;


--4. Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

--5. Add mapping from deprecated to fresh concepts (necessary for the next step)
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
	PERFORM VOCABULARY_PACK.AddFreshMapsToValue();
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
-- At the end, the three tables concept_stage, concept_relationship_stage AND concept_synonym_stage should be ready to be fed into the generic_update.sql script
