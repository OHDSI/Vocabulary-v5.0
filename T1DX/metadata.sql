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

/****************************************************************************************
 Step 1. Remove existing T1DX concept metadata (for future refreshes).
****************************************************************************************/
DELETE FROM concept_metadata cmtd
USING concept c
WHERE c.concept_id = cmtd.concept_id
  AND c.vocabulary_id = 'T1DX';

/****************************************************************************************
 Step 2. Insert concept-level metadata for all T1DX concepts.
****************************************************************************************/
INSERT INTO concept_metadata (
    concept_id,
    concept_category,
    reuse_status
)
SELECT
    c.concept_id,
    NULL AS concept_category,
    NULL AS reuse_status
FROM concept c
WHERE c.vocabulary_id = 'T1DX';

/****************************************************************************************
 Step 3. Remove existing T1DX forward-mapping metadata (for future refreshes).
****************************************************************************************/
DELETE FROM concept_relationship_metadata crmd
USING concept c1
WHERE c1.concept_id = crmd.concept_id_1
  AND c1.vocabulary_id = 'T1DX'
  AND crmd.relationship_id = 'Maps to';

/****************************************************************************************
 Step 4. Insert metadata for active, non-self, forward T1DX Maps to relationships.
****************************************************************************************/
INSERT INTO concept_relationship_metadata (
    concept_id_1,
    concept_id_2,
    relationship_id,
    relationship_predicate_id,
    relationship_group,
    mapping_source,
    confidence,
    mapping_tool,
    mapper,
    reviewer
)
SELECT
    cr.concept_id_1,
    cr.concept_id_2,
    cr.relationship_id,
    'exactMatch' AS relationship_predicate_id,
    NULL AS relationship_group,
    'T1DX' AS mapping_source,
    1 AS confidence,
    'MM_C' AS mapping_tool,
    'Eric Williams' AS mapper,
    'Maksym Trofymenko' AS reviewer
FROM concept_relationship cr
JOIN concept c1
  ON c1.concept_id = cr.concept_id_1
JOIN concept c2
  ON c2.concept_id = cr.concept_id_2
WHERE c1.vocabulary_id = 'T1DX'
  AND cr.relationship_id = 'Maps to'
  AND cr.invalid_reason IS NULL
  AND c1.invalid_reason IS NULL
  AND c2.invalid_reason IS NULL
  AND cr.concept_id_1 <> cr.concept_id_2;