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
* Authors: Maksym Trofymenko, Polina Talapova, Denys Kaduk
* Date: 2026
**************************************************************************/
-- Total script execution time: 1 min 10 second

/****************************************************************************************
 Step 0. Insert a reference row for the new vocabulary (once added, this step should be removed).
****************************************************************************************/
INSERT INTO vocabulary (
    vocabulary_id, 
    vocabulary_name, 
    vocabulary_reference, 
    vocabulary_version, 
    vocabulary_concept_id
)
VALUES (
    'T1DX', 
    'Type 1 Diabetes Exchange', 
    'https://t1dexchange.org/', 
    'T1DX v1.0', 
    0
)
ON CONFLICT (vocabulary_id) DO NOTHING;

/****************************************************************************************
 Step 1. Update vocabulary metadata.
****************************************************************************************/
DO $_$
	BEGIN
		PERFORM vocabulary_pack.SetLatestUpdate(
		pVocabularyName			=> 'T1DX',
		pVocabularyDate			=> '2026-05-01',
		pVocabularyVersion		=> 'T1DX v.1.0',
		pVocabularyDevSchema	=> 'dev_lurie');
	END $_$;

/****************************************************************************************
 Step 2. Clear working stage tables.
 ****************************************************************************************/
TRUNCATE TABLE
    concept_stage,
    concept_relationship_stage,
    concept_synonym_stage,
    pack_content_stage,
    drug_strength_stage;

/****************************************************************************************
 Step 3. Load manual concepts into concept_stage.
****************************************************************************************/
SELECT vocabulary_pack.ProcessManualConcepts();

/****************************************************************************************
 Step 4. Load manual relationships into stage tables.
****************************************************************************************/
SELECT vocabulary_pack.ProcessManualRelationships();

/****************************************************************************************
 Step 5. Load manual synonyms into stage tables.
****************************************************************************************/
SELECT vocabulary_pack.ProcessManualSynonyms();

/****************************************************************************************
 Step 6. Validate replacement mappings.
****************************************************************************************/
SELECT vocabulary_pack.CheckReplacementMappings();

/****************************************************************************************
 Step 7. Propagate Maps to relationships to fresh concepts.
****************************************************************************************/
SELECT vocabulary_pack.AddFreshMAPSTO();

/****************************************************************************************
 Step 8. Deprecate obsolete Maps to relationships.
****************************************************************************************/
SELECT vocabulary_pack.DeprecateWrongMAPSTO();

/****************************************************************************************
 Step 9. Remove ambiguous Maps to relationships.
****************************************************************************************/
SELECT vocabulary_pack.DeleteAmbiguousMAPSTO();

/****************************************************************************************
 Step 10. Deprecate previously active T1DX relationships that are absent from the current
          stage snapshot.
****************************************************************************************/
INSERT INTO concept_relationship_stage (
    concept_code_1,
    concept_code_2,
    vocabulary_id_1,
    vocabulary_id_2,
    relationship_id,
    valid_start_date,
    valid_end_date,
    invalid_reason
)
SELECT
    c1.concept_code AS concept_code_1,
    c2.concept_code AS concept_code_2,
    c1.vocabulary_id AS vocabulary_id_1,
    c2.vocabulary_id AS vocabulary_id_2,
    cr.relationship_id,
    cr.valid_start_date,
    CASE
        /*
         Use the day before the current vocabulary release date as the deprecation date.
         If the existing relationship starts on or after the release date, keep a valid
         date interval by ending it one day after its start date.
        */
        WHEN v.latest_update::date <= cr.valid_start_date
            THEN cr.valid_start_date + 1
        ELSE v.latest_update::date - 1
    END AS valid_end_date,
    'D' AS invalid_reason
FROM concept_relationship cr
JOIN concept c1
  ON c1.concept_id = cr.concept_id_1
 AND c1.vocabulary_id = 'T1DX'
JOIN concept c2
  ON c2.concept_id = cr.concept_id_2
JOIN vocabulary v
  ON v.vocabulary_id = c1.vocabulary_id
WHERE cr.invalid_reason IS NULL
  AND cr.relationship_id NOT IN ('Concept replaced by', 'Concept replaces')
  AND NOT EXISTS (
        SELECT 1
        FROM concept_relationship_stage crs
        WHERE crs.concept_code_1 = c1.concept_code
          AND crs.vocabulary_id_1 = c1.vocabulary_id
          AND crs.concept_code_2 = c2.concept_code
          AND crs.vocabulary_id_2 = c2.vocabulary_id
          AND crs.relationship_id = cr.relationship_id
  );
/****************************************************************************************
 Step 11. Refresh planner statistics for stage tables.
****************************************************************************************/
ANALYZE concept_stage;
ANALYZE concept_relationship_stage;
ANALYZE concept_synonym_stage;

/****************************************************************************************
 Final state:
   concept_stage, concept_relationship_stage, and concept_synonym_stage contain the
   current T1DX vocabulary content and are ready for generic_update.
****************************************************************************************/