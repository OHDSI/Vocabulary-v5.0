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

-- Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

-- Add NCCD concepts (Drug Products and Drug Attributes)
INSERT INTO concept_stage
(concept_name,domain_id,vocabulary_id,concept_class_id,standard_concept,concept_code,valid_start_date,valid_end_date,invalid_reason)
SELECT  t_nm as concept_name,       -- English name
       'Drug' as domain_id,
       'NCCD' as vocabulary_id,
       CASE
         WHEN nccd_type = 'IN' THEN 'Ingredient'
         WHEN nccd_type = 'DF' THEN 'Dose Form'
         WHEN nccd_type = 'BN' THEN 'Brand Name'
         ELSE 'Drug Product' 
       END as concept_class_id,
       NULL as standard_concept,
       nccd_code as concept_code,
       TO_DATE('19700101','yyyymmdd') as valid_start_date,
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
       NULL AS invalid_reason
FROM nccd_full_done;

-- Add mappings for NCCD concepts
INSERT INTO concept_relationship_stage
(concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id,valid_start_date,valid_end_date,invalid_reason)
SELECT nccd_code as concept_code_1,
       concept_code as concept_code_2,
       'NCCD' as vocabulary_id_1,
       vocabulary_id as vocabulary_id_2,
       CASE
         WHEN nccd_type in ('DF', 'BN') THEN 'Source - RxNorm eq'
        ELSE 'Maps to' END as relationship_id,
       TO_DATE('19700101','yyyymmdd') as valid_start_date,
       TO_DATE('20991231','yyyymmdd') as valid_end_date,
       NULL AS invalid_reason
FROM nccd_full_done;
-- Add original Chinese names for NCCD concepts
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

-- Add everything from the Manual tables - PLEASE CHECK NEXT TIME the results of all these VOCABULARY_PACKs
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
