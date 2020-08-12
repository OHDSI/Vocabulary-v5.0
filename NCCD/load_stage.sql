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

--1. Update latest_update field to new date
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate( 
	pVocabularyName			=> 'NCCD',
	pVocabularyDate			=> (SELECT vocabulary_date FROM nccd_vocabulary_vesion LIMIT 1),
	pVocabularyVersion		=> (SELECT vocabulary_version FROM nccd_vocabulary_vesion LIMIT 1),
	pVocabularyDevSchema	=> 'dev_nccd'
);
END $_$;

--2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3. Add NCCD concepts (Drug Products and Drug Attributes)
INSERT INTO concept_stage
(concept_name,domain_id,vocabulary_id,concept_class_id,standard_concept,concept_code,valid_start_date,valid_end_date,invalid_reason)
SELECT DISTINCT t_nm,       -- English name
       'Drug',
       'NCCD',
       CASE
         WHEN nccd_type = 'IN' THEN 'Ingredient'
         WHEN nccd_type = 'DF' THEN 'Dose Form'
         WHEN nccd_type = 'BN' THEN 'Brand Name'
         ELSE 'Drug Product'
       END,
       NULL,
       nccd_code,
       TO_DATE('1970-01-01','yyyy-mm-dd'),
       TO_DATE('20991231','yyyymmdd') AS valid_end_date,
       NULL AS invalid_reason
FROM nccd_full_done -- manually prepared source table
ORDER BY t_nm;

--4. Add mappings for NCCD concepts
INSERT INTO CONCEPT_RELATIONSHIP_STAGE
(concept_code_1,concept_code_2,vocabulary_id_1,vocabulary_id_2,relationship_id,valid_start_date,valid_end_date,invalid_reason)
SELECT DISTINCT 
       nccd_code,
       concept_code,
       'NCCD',
       vocabulary_id,
       'Maps to',
       TO_DATE('1970-01-01','yyyy-mm-dd'),
       TO_DATE('20991231','yyyymmdd'),
       NULL AS invalid_reason
FROM nccd_full_done
ORDER BY nccd_code;

--5. Add original Chinese names for NCCD concepts
INSERT INTO concept_synonym_stage
(
  synonym_name,
  synonym_concept_code,
  synonym_vocabulary_id,
  language_concept_id
)
SELECT DISTINCT nccd_name,
       nccd_code,
       'NCCD',
       4180186
FROM nccd_full_done
WHERE nccd_name <> 'X';
