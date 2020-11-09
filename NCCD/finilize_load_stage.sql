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
* Authors: Polina Talapova, Daryna Ivakhnenko, Dmitry Dymshyts
* Date: 2020
**************************************************************************/
--1. Add original Chinese names for NCCD concepts
INSERT INTO concept_synonym_stage
(
  synonym_name,
  synonym_concept_code,
  synonym_vocabulary_id,
  language_concept_id
)
SELECT nccd_name AS synonym_name,
       nccd_code AS synonym_concept_code,
       'NCCD' AS synonym_vocabulary_id,
       4180186 AS language_concept_id
FROM nccd_full_done
WHERE nccd_name not in ('X', '')
AND   nccd_code IN (SELECT concept_code FROM concept_stage)
; -- 51026

--2. Add everything from the Manual tables - PLEASE CHECK NEXT TIME the results of all these VOCABULARY_PACKs
--Working with manual concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualConcepts();
END $_$;

--Working with manual synonyms
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualSynonyms();
END $_$;

--Working with manual mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

--Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

--Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;

-- select * from qa_tests.Check_Stage_Tables();
