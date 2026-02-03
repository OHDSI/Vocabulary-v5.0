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
* Authors: Masha Khitrun
* Date: 2025
**************************************************************************/

-- 1. Populate latest_update
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'NUCC',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.nucc_taxonomy LIMIT 1),
	pVocabularyVersion		=> (SELECT vocabulary_version FROM sources.nucc_taxonomy LIMIT 1),
	pVocabularyDevSchema	=> 'dev_nucc'
);
END $_$;

-- 2. Truncate stages
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE concept_relationship_stage;

-- 3. Populate concept_stage:
INSERT INTO concept_stage
(
 concept_name,
 domain_id,
 vocabulary_id,
 concept_class_id,
 standard_concept,
 concept_code,
 valid_start_date,
 valid_end_date,
 invalid_reason)
SELECT trim(regexp_replace(display_name, 'Deactivated - ', '')) AS concept_name,
       CASE WHEN section_ = 'Individual' THEN 'Provider' ELSE 'Visit' END AS domain_id,
       'NUCC' AS vocabulary_id,
       CASE WHEN grouping_ = 'Allopathic & Osteopathic Physicians' THEN 'Physician Specialty'
           WHEN grouping_ != 'Allopathic & Osteopathic Physicians' AND section_ = 'Individual' THEN 'Provider'
           ELSE 'Visit' END AS concept_class_id,
       'S' AS standard_concept,
       code AS concept_code,
       coalesce(
           (SELECT to_date(substring(notes, '[0-9]/[0-9]/[0-9]{1,4}'), 'MM/DD/YYYY')
        FROM sources.nucc_taxonomy t
        WHERE t.code = s.code
            AND notes not like '%inactive%'),
           '1970-01-01') AS valid_start_date,
       CASE WHEN notes like '%inactive%'
           THEN (SELECT to_date(substring(notes, '[0-9]/[0-9]/[0-9]{1,4}'), 'MM/DD/YYYY')
                FROM sources.nucc_taxonomy t2
                WHERE t2.code = s.code)
           ELSE '2099-12-31'
           END AS valid_end_date,
       CASE WHEN notes like '%inactive%'
           THEN 'D'
           END AS invalid_reason
FROM sources.nucc_taxonomy s;

-- 4.Populate concept_synonym_stage
INSERT INTO concept_synonym_stage
(synonym_name,
 synonym_concept_code,
 synonym_vocabulary_id,
 language_concept_id)
SELECT concat(trim(grouping_), ', ',trim(classification), ', ', trim(specialization)),
       code,
       'NUCC',
       4180186 -- English
FROM sources.nucc_taxonomy
WHERE specialization is not null
;

-- 5.Populate concept_relationship_stage:
--- hierarchy
INSERT INTO concept_relationship_stage
(concept_code_1,
 concept_code_2,
 vocabulary_id_1,
 vocabulary_id_2,
 relationship_id,
 valid_start_date,
 valid_end_date,
 invalid_reason)
SELECT n1.code,
       n2.code,
       'NUCC',
       'NUCC',
       'Is a' AS relationship_id,
       (SELECT latest_update
              FROM vocabulary
                 WHERE vocabulary_id = 'NUCC'),
       '2099-12-31',
       null
FROM sources.nucc_taxonomy n1, sources.nucc_taxonomy n2
WHERE left(n1.code, 4) = left(n2.code, 4)
AND devv5.similarity (n2.classification, regexp_replace(n2.display_name, ' Physician', '')) = 1
AND n1.code != n2.code
AND n2.specialization is null
;

--6. AppEND manual changes
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualConcepts();
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--7. Add mapping FROM deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
	PERFORM VOCABULARY_PACK.AddFreshMapsToValue();
END $_$;

--8. Deprecate 'Maps to' mappings to deprecated AND upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;