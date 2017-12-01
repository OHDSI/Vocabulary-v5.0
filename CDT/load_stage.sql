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
* Authors: Timur Vakhitov
* Date: 2017
**************************************************************************/

--1 Update latest_update field to new date
BEGIN
   DEVV5.VOCABULARY_PACK.SetLatestUpdate (pVocabularyName        => 'CDT',
                                          pVocabularyDate        => TO_DATE ('20170508', 'yyyymmdd'),
                                          pVocabularyVersion     => '2017AA',
                                          pVocabularyDevSchema   => 'DEV_CDT');
END;
COMMIT;

--2 Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3 Load concepts into concept_stage from MRCONSO
-- Main and hierarchical CDT codes. Str picked in certain order to get best concept_name
SELECT DISTINCT FIRST_VALUE(SUBSTR(m.str, 1, 255)) OVER (
		PARTITION BY m.scui ORDER BY CASE 
				WHEN LENGTH(m.str) <= 255
					THEN LENGTH(str)
				ELSE 0
				END DESC,
			LENGTH(str) ROWS BETWEEN UNBOUNDED PRECEDING
				AND UNBOUNDED FOLLOWING
		) AS concept_name,
	COALESCE(c.domain_id, 'Observation') AS domain_id,
	'CDT' AS vocabulary_id,
	CASE 
		WHEN m.tty = 'PT'
			THEN 'CDT'
		ELSE 'CDT Hierarchy'
		END AS concept_class_id,
	'S' AS standard_concept,
	m.scui AS concept_code,
	code,
	(
		SELECT latest_update
		FROM vocabulary
		WHERE vocabulary_id = 'CDT'
		) AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM UMLS.mrconso m
LEFT JOIN concept c ON c.vocabulary_id = 'HCPCS'
	AND c.concept_code = m.scui
WHERE m.sab = 'CDT'
	AND m.tty IN (
		'PT',
		'HT'
		)
	AND suppress NOT IN (
		'E',
		'O',
		'Y'
		);
COMMIT;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script		