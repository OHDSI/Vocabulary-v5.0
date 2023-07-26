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
* Authors: Dmitry Dymshyts, Timur Vakhitov
* Date: 2021
**************************************************************************/

-- 1. Update latest_update field to new date 
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'VANDF',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.rxnatomarchive LIMIT 1),
	pVocabularyVersion		=> (SELECT vocabulary_version FROM sources.rxnatomarchive LIMIT 1),
	pVocabularyDevSchema	=> 'DEV_VANDF'
);
END $_$;

-- 2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3. Insert into concept_stage
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
SELECT DISTINCT ON (rx.code) vocabulary_pack.CutConceptName(rx.str) AS concept_name,
	'Drug' AS domain_id,
	'VANDF' AS vocabulary_id,
	'Drug Product' AS concept_class_id,
	NULL AS standard_concept,
	rx.code AS concept_code,
	CASE
	    WHEN rx.code in (
	        select concept_code from devv5.concept c
	                            where c.vocabulary_id = 'VANDF'
            )
			THEN TO_DATE('19700101', 'yyyymmdd')
		WHEN COALESCE(TO_DATE(rxs.atv, 'yyyymmdd'), TO_DATE('20991231', 'yyyymmdd')) = to_date('20991231', 'yyyymmdd')
			THEN (v.latest_update - 1)
	    WHEN TO_DATE(rxs.atv, 'yyyymmdd') < latest_update
	        THEN TO_DATE(rxs.atv, 'yyyymmdd')
	    ELSE
	        (v.latest_update - 1)
		END AS valid_start_date, --for the first time we put concepts as 1970
	COALESCE(TO_DATE(rxs.atv, 'yyyymmdd'), TO_DATE('20991231', 'yyyymmdd')) AS valid_end_date,
	CASE 
		WHEN rxs.atv IS NULL
			THEN NULL
		ELSE 'D'
		END AS invalid_reason
FROM sources.rxnconso rx
LEFT JOIN sources.rxnsat rxs ON rxs.code = rx.code
	AND rxs.sab = 'VANDF'
	AND rxs.atn = 'NF_INACTIVATE'
CROSS JOIN vocabulary v
WHERE rx.sab = 'VANDF'
	AND rx.tty IN (
		'CD',
		'PT',
		'IN'
		)
	AND v.vocabulary_id = 'VANDF'
ORDER BY rx.code,
	TO_DATE(rxs.atv, 'yyyymmdd') DESC;--some codes have several records in rxnsat with different NF_INACTIVATE, so we take the only one with MAX (atv)

--4. Fill concept_synonym_stage
INSERT INTO concept_synonym_stage (
	synonym_name,
	synonym_concept_code,
	synonym_vocabulary_id,
	language_concept_id
	)
SELECT vocabulary_pack.CutConceptSynonymName(rx.str),
	rx.code,
	'VANDF',
	4180186 -- English
FROM sources.rxnconso rx
LEFT JOIN concept_stage cs ON cs.concept_code = rx.code
	AND cs.concept_name = vocabulary_pack.CutConceptSynonymName(rx.str)
WHERE rx.sab = 'VANDF'
	AND rx.tty NOT IN (
		'CD',
		'PT',
		'IN'
		)
	AND cs.concept_code IS NULL;

--5. Fill relationships
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
SELECT rx.code AS concept_code_1,
	c.concept_code AS concept_code_2,
	'VANDF' AS vocabulary_id_1,
	'RxNorm' AS vocabulary_id_2,
	'Maps to' AS relationship_id,
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM concept c
JOIN sources.rxnconso rx ON rx.rxcui = c.concept_code
CROSS JOIN vocabulary v
WHERE rx.sab = 'VANDF'
	AND rx.tty IN (
		'CD',
		'PT',
		'IN'
		)
	AND c.vocabulary_id = 'RxNorm'
	AND c.standard_concept = 'S'
	AND v.vocabulary_id = 'VANDF';

--6. Append manual relationships
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--7. Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

--8. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--9. Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script