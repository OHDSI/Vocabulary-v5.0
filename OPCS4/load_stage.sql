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
* Authors: Timur Vakhitov, Christian Reich
* Date: 2017
**************************************************************************/

-- 1. Update latest_update field to new date 
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'OPCS4',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.opcs LIMIT 1),
	pVocabularyVersion		=> (SELECT EXTRACT (YEAR FROM vocabulary_date)||' Release' FROM sources.opcs LIMIT 1),
	pVocabularyDevSchema	=> 'DEV_OPCS4'
);
END $_$;

-- 2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3. Load into concept_stage from opcs
INSERT INTO concept_stage (
	concept_name,
	domain_id,
	vocabulary_id,
	concept_class_id,
	standard_concept,
	concept_code,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT term AS concept_name, -- probably limit to 255 characters
	'Procedure' AS domain_id,
	'OPCS4' AS vocabulary_id,
	'Procedure' AS concept_class_id,
	'S' AS standard_concept,
	REGEXP_REPLACE(CUI, '([[:print:]]{3})([[:print:]]+)', '\1.\2','g') -- Dot after 3 characters
	AS concept_code,
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM SOURCES.opcs o,
	vocabulary v
WHERE cui NOT LIKE '%-%' -- don't use chapters
	AND term NOT LIKE 'CHAPTER %'
	AND v.vocabulary_id = 'OPCS4';

--4. Create concept_relationship_stage
-- We have to invert the direction of the mapping. The source gives us high OPCS4 to lower SNOMED we need to find the nearest common ancestor of all those lower SNOMED codes
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	relationship_id,
	vocabulary_id_1,
	vocabulary_id_2,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT DISTINCT REGEXP_REPLACE(concept_code, '([[:print:]]{3})([[:print:]]+)', '\1.\2','g') AS concept_code_1,
	first_value(ancestor_code) OVER (
		PARTITION BY concept_code ORDER BY cnt DESC,
			averg rows BETWEEN unbounded preceding
				AND unbounded following
		) AS concept_code_2, -- pick the ancestor with the highest number and the lowest average min_levels_of_separation
	'OPCS4 - SNOMED' AS relationship_id,
	'OPCS4' AS vocabulary_id_1,
	'SNOMED' AS vocabulary_id_2,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date, ---- latest_update starting at 1.1.1970 this time.
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM (
	SELECT DISTINCT concept_code,
		ancestor_code,
		count(*) AS cnt,
		avg(min_levels_of_separation) AS averg -- get for each code all the ancestors, their distance and number
	FROM (
		SELECT opcs_m.scui AS concept_code,
			anc.concept_code AS ancestor_code,
			a.min_levels_of_separation
		FROM SOURCES.opcssctmap opcs_m
		JOIN concept snomed ON snomed.vocabulary_id = 'SNOMED'
			AND snomed.concept_code = opcs_m.tcui -- convert SNOMED code to SNOMED ID
		JOIN (
			-- get all the ancestors of the SNOMED IDs
			SELECT min_levels_of_separation,
				ancestor_concept_id,
				descendant_concept_id
			FROM concept_ancestor
			WHERE ancestor_concept_id NOT IN (
					SELECT descendant_concept_id
					FROM concept_ancestor
					WHERE ancestor_concept_id = 4008453
						AND min_levels_of_separation < 3 -- remove very high up concepts in the hierarchy
					)
			) a ON a.descendant_concept_id = snomed.concept_id
		JOIN concept anc ON anc.concept_id = a.ancestor_concept_id
			AND anc.vocabulary_id = 'SNOMED' -- don't get into MedDRA
		) AS s0
	GROUP BY concept_code,
		ancestor_code
	) AS s1
WHERE concept_code IN (
		-- only codes that are valid
		SELECT cui
		FROM SOURCES.opcs
		WHERE cui NOT LIKE '%-%' -- don't use chapters
			AND term NOT LIKE 'CHAPTER %'
		);

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script